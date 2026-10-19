class_name WindField
extends Node
## Liefert den Wind an jeder Position der Bahn:
## - Grundrichtung mit langsamen Winddrehern
## - wandernde Böen und Flauten (Noise, treibt mit dem Wind)
## - leichte örtliche Richtungsunterschiede
## - Windschatten hinter jedem Boot und im Lee von Land (Inseln, Molen, Ufer)
##
## Koordinaten: 2D-Vektoren (x, z) der 3D-Welt. Norden = -Z.

## Richtung, AUS der der Wind kommt (Radiant). 0 = aus Norden, PI/2 = aus Osten.
@export var base_dir := 0.0
@export var base_speed := 6.0          ## m/s (~12 kn)
@export var shift_amplitude := 0.30    ## großer, langsamer Dreher (rad, ~17°)
@export var gust_strength := 0.9       ## 0 = keine Böen
@export var shadow_length := 50.0      ## Länge des Windschattens in m
@export var shadow_strength := 0.5     ## max. Windverlust direkt hinter einem Boot
@export var land_shadow_length := 170.0   ## so weit reicht der Windschatten von Land (m)
@export var land_shadow_strength := 0.88  ## Windverlust direkt im Lee von Land

var time := 0.0
## feste Zufallswerte (Netzwerk: alle Rechner sehen dieselben Böen); -1 = zufällig
var gust_seed := -1
var dir_seed := -1
var current_dir := 0.0
var boats: Array = []

var _gust_noise := FastNoiseLite.new()
var _dir_noise := FastNoiseLite.new()


func _ready() -> void:
	_gust_noise.seed = gust_seed if gust_seed >= 0 else randi()
	_gust_noise.frequency = 0.012
	_gust_noise.fractal_octaves = 2
	_dir_noise.seed = dir_seed if dir_seed >= 0 else randi()
	_dir_noise.frequency = 0.005
	_update_dir()


func _physics_process(delta: float) -> void:
	time += delta
	_update_dir()


func _update_dir() -> void:
	current_dir = base_dir \
		+ shift_amplitude * sin(time * TAU / 80.0) \
		+ shift_amplitude * 0.4 * sin(time * TAU / 31.0 + 1.3)


## Richtung, in die der Wind weht, als Einheitsvektor.
static func dir_to_blow(dir: float) -> Vector2:
	return Vector2(-sin(dir), cos(dir))


func blow_dir() -> Vector2:
	return dir_to_blow(current_dir)


func _drift_pos(p: Vector2) -> Vector2:
	# Böenfeld treibt mit dem Wind über die Bahn
	return p - blow_dir() * time * base_speed * 0.5


## Böenwert an einer Position: -1 (Flaute) .. +1 (kräftige Böe)
func gust_at(p: Vector2) -> float:
	var q := _drift_pos(p)
	return clampf(_gust_noise.get_noise_3d(q.x, q.y, time * 0.5) * 1.6, -1.0, 1.0)


func dir_at(p: Vector2) -> float:
	var q := _drift_pos(p)
	return current_dir + _dir_noise.get_noise_3d(q.x, q.y, time * 0.15) * 0.35


## Wahrer Wind an Position p (Vektor in Blasrichtung, Länge = m/s).
## exclude: Boot, dessen eigener Windschatten ignoriert wird.
func get_wind(p: Vector2, exclude: Node = null) -> Vector2:
	var bd := dir_to_blow(dir_at(p))
	var spd := maxf(1.5, base_speed * (1.0 + gust_at(p) * gust_strength * 0.5))
	return bd * spd * shadow_factor(p, bd, exclude)


## 1.0 = freier Wind, kleiner = im Windschatten eines anderen Bootes
func shadow_factor(p: Vector2, bd: Vector2, exclude: Node = null) -> float:
	var f := _land_shadow(p, bd)
	for b in boats:
		if b == exclude:
			continue
		var rel: Vector2 = p - b.pos2d()
		var along := rel.dot(bd)
		if along < 1.0 or along > shadow_length:
			continue
		var lat := absf(rel.cross(bd))
		var width := 3.0 + along * 0.2
		if lat >= width:
			continue
		var s := (1.0 - along / shadow_length) * (1.0 - lat / width)
		f *= 1.0 - shadow_strength * s
	return f


## Windschatten im Lee von Land: Strahlen gegen den Wind (mittig und leicht seitlich).
## Je näher das Land, desto stärker der Windverlust.
func _land_shadow(p: Vector2, bd: Vector2) -> float:
	var side := Vector2(-bd.y, bd.x)
	var total := 0.0
	for off in [-14.0, 0.0, 14.0]:
		var origin: Vector2 = p + side * off
		var hit := land_shadow_length
		var d := 6.0
		while d < land_shadow_length:
			if SeaChart.depth_at(origin - bd * d) < SeaChart.LAND:
				hit = d
				break
			d += 8.0
		var k := 1.0 - hit / land_shadow_length
		total += land_shadow_strength * pow(k, 0.7)
	return 1.0 - total / 3.0
