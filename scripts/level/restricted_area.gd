@tool
@icon("res://addons/regatta_editor/icons/restricted.svg")
class_name RestrictedArea
extends Node3D
## Sperrgebiet mit magenta Grenze und gelben Sperrtonnen:
##   Minenfeld  – wer eine Seemine berührt, fliegt in die Luft und scheidet aus
##   Polizei    – die Wasserschutzpolizei hält Boote im Gebiet an und durchsucht sie eine
##                Weile (danach kurze Schonfrist, damit man wieder herauskommt)
## Die Computergegner umfahren das Gebiet. Die Logik läuft nur beim Host bzw. lokal.

enum Kind { MINEN, POLIZEI }

const MINE_HIT := 4.8          ## Abstand zur Mine, bei dem sie zündet
const GRACE := 1.6             ## so lange im Gebiet, bevor die Polizei zugreift

@export var kind := Kind.MINEN:
	set(v):
		kind = v
		_rebuild()
@export var area_name := "":
	set(v):
		area_name = v
		_rebuild()
@export_range(20.0, 250.0, 1.0, "suffix:m") var radius := 60.0:
	set(v):
		radius = v
		_rebuild()
@export_range(3, 60) var mine_count := 14:
	set(v):
		mine_count = v
		_rebuild()

var _vis: Node3D
var _mines: Array[Node3D] = []
var _mine_pos: Array[Vector2] = []
var _buoys: Array[Node3D] = []
var _state := {}               ## Boot -> {inside, warned, dwell}
var _t := 0.0


func _ready() -> void:
	set_notify_transform(true)
	_t = randf() * 10.0
	_rebuild()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and _vis:
		_vis.global_position = Vector3(global_position.x, 0, global_position.z)


func pos2d() -> Vector2:
	return Vector2(global_position.x, global_position.z)


## Kreis, den die Computergegner meiden: [Mitte, Radius]
func danger_circle() -> Array:
	return [pos2d(), radius]


func display_name() -> String:
	if area_name != "":
		return area_name
	return "Minenfeld" if kind == Kind.MINEN else "Sperrgebiet"


# ---------------------------------------------------------------- Aufbau

func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _vis:
		_vis.queue_free()
	_mines.clear()
	_mine_pos.clear()
	_buoys.clear()
	_vis = Node3D.new()
	_vis.top_level = true
	add_child(_vis)
	_vis.global_position = Vector3(global_position.x, 0, global_position.z)

	# Kartenzeichen: magenta Strichlinie mit kurzen Zähnen nach innen (INT 1 N 20)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := maxi(24, int(radius * TAU / 10.0))
	for k in segs:
		if k % 2 == 0:
			var a0 := TAU * k / segs
			var a1 := TAU * (k + 1) / segs
			SeaChart.add_line(st, Vector2(cos(a0), sin(a0)) * radius, Vector2(cos(a1), sin(a1)) * radius, 0.9, 0.1)
		if k % 4 == 0:
			var a := TAU * (k + 0.5) / segs
			SeaChart.add_line(st, Vector2(cos(a), sin(a)) * radius, Vector2(cos(a), sin(a)) * (radius - 5.0), 0.9, 0.1)
	_vis.add_child(SeaChart.mesh_from(st, Color(SeaChart.MAGENTA, 0.85)))
	var lab := SeaChart.flat_label(display_name(), 56, SeaChart.MAGENTA, false, true)
	lab.position = Vector3(0, 0.1, -radius * 0.78)
	_vis.add_child(lab)
	var sub := SeaChart.flat_label("Einfahrt verboten – Minengefahr" if kind == Kind.MINEN else "Einfahrt verboten – Kontrolle", 30, SeaChart.MAGENTA, true)
	sub.position = Vector3(0, 0.1, -radius * 0.78 + 5.5)
	_vis.add_child(sub)

	# Sperrtonnen (gelb mit Kreuz) rund um das Gebiet
	var n := maxi(8, int(radius * TAU / 24.0))
	for k in n:
		var a := TAU * k / n
		var b := _buoy()
		b.position = Vector3(cos(a) * radius, 0.0, sin(a) * radius)
		_vis.add_child(b)
		_buoys.append(b)

	if kind == Kind.MINEN:
		_place_mines()


func _buoy() -> Node3D:
	var root := Node3D.new()
	var yellow := Color(0.98, 0.82, 0.1)
	var body := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.7
	cm.bottom_radius = 1.0
	cm.height = 2.2
	cm.radial_segments = 8
	body.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = yellow
	body.material_override = m
	body.position.y = 0.6
	root.add_child(body)
	for rot in [PI / 4, -PI / 4]:
		var bar := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.18, 1.5, 0.18)
		bar.mesh = bm
		bar.material_override = HazardVisuals.mat(Color(0.1, 0.1, 0.11))
		bar.position.y = 2.6
		bar.rotation.z = rot
		root.add_child(bar)
	ModelStyle.outline(root)
	ModelStyle.no_shadows(root)
	return root


func _place_mines() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(global_position.x * 7.0 + global_position.z * 13.0) + int(radius) * 31 + mine_count
	var tries := 0
	while _mine_pos.size() < mine_count and tries < mine_count * 40:
		tries += 1
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * (radius - 8.0)
		var p := Vector2(cos(a), sin(a)) * r
		var ok := true
		for q in _mine_pos:
			if q.distance_to(p) < 12.0:
				ok = false
				break
		if ok:
			_mine_pos.append(p)
	for p in _mine_pos:
		var mine := HazardVisuals.mine()
		mine.position = Vector3(p.x, 0.0, p.y)
		mine.set_meta("ph", rng.randf() * TAU)
		_vis.add_child(mine)
		_mines.append(mine)


func _process(delta: float) -> void:
	_t += delta
	for m in _mines:
		var ph: float = m.get_meta("ph")
		var body: Node3D = m.get_meta("body")
		body.position.y = 0.2 + sin(_t * 1.3 + ph) * 0.2
		body.rotation.x = sin(_t * 0.9 + ph) * 0.12
		body.rotation.z = sin(_t * 0.7 + ph * 2.0) * 0.12
		var lamp: MeshInstance3D = m.get_meta("lamp")
		(lamp.material_override as StandardMaterial3D).emission_energy_multiplier = 0.3 if fmod(_t + ph, 1.6) > 0.25 else 4.0
	for i in _buoys.size():
		_buoys[i].position.y = sin(_t * 1.2 + i * 1.7) * 0.15
		_buoys[i].rotation.z = sin(_t * 0.9 + i) * 0.06


# ---------------------------------------------------------------- Spiellogik

## Jeden Physikschritt für jedes Boot (nur Host bzw. lokal)
func update_boat(b: Boat, delta: float) -> void:
	if b.out or b.towed or b.finished:
		return
	var st: Dictionary = _state.get(b, {"inside": false, "near": false, "dwell": 0.0})
	_state[b] = st
	var p := b.pos2d()
	var d := p.distance_to(pos2d())
	if kind == Kind.MINEN:
		var near := d < radius + 30.0
		if near and not st["near"]:
			b.show_message("Achtung: Minenfeld voraus!", 3.0)
		st["near"] = near
		if d < radius + MINE_HIT:
			for m in _mine_pos:
				if p.distance_to(pos2d() + m) < MINE_HIT:
					b.explode()
					return
		return
	# Polizei
	var inside := d < radius
	if inside and not st["inside"]:
		b.show_message("Sperrgebiet! Sofort umkehren!", 2.5)
	st["inside"] = inside
	if not inside:
		st["dwell"] = maxf(0.0, float(st["dwell"]) - 2.0 * delta)
		return
	if b.hold_kind != 0 or b.immune_time > 0.0:
		return
	st["dwell"] += delta
	if st["dwell"] >= GRACE:
		st["dwell"] = 0.0
		b.start_hold(1, _exit_point(p))
		b.show_message("Wasserschutzpolizei: Stopp – Kontrolle!", 3.0)
		Sfx.play("police_siren", -2.0)


## Punkt knapp außerhalb des Gebiets, zu dem die Polizei das Boot schleppt: bevorzugt
## in Richtung des Bootes, sonst der nächste Winkel mit freiem Wasser
func _exit_point(p: Vector2) -> Vector2:
	var out_dir := (p - pos2d())
	var base := out_dir.angle() if out_dir.length() > 1.0 else 0.0
	for k in 12:
		var a := base + (k + 1) / 2 * 0.5 * (1.0 if k % 2 == 0 else -1.0)
		var q := pos2d() + Vector2(cos(a), sin(a)) * (radius + 14.0)
		if SeaChart.depth_at(q) > SeaChart.DRAFT + 1.0 and SeaChart.path_clear(p, q):
			return q
	return Vector2.INF
