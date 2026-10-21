@tool
@icon("res://addons/regatta_editor/icons/ship.svg")
class_name ShippingLane
extends Node3D
## Schifffahrtsweg mit Berufsschifffahrt: Frachter, Tanker und Massengutschiffe fahren in
## Pfeilrichtung (lokal −Z) und zurück, jeweils rechts im Fahrwasser (Rechtsfahrgebot).
## Boote müssen ihnen ausweichen: Ein Zusammenstoß wirft das Boot zurück und kostet viel Fahrt.
##
## Die Schiffe haben keinen eigenen Zustand: Ihre Position folgt allein aus der Rennzeit
## (siehe ships_at). Dadurch sehen Host, Clients und KI dieselben Schiffe, ohne dass etwas über
## das Netzwerk übertragen werden muss.

const NAMES := ["Nordstern", "Hanse Trader", "Baltic Star", "Elbe Express", "Ostsee Pionier", "Kap Arkona"]
const WARN_DIST := 95.0        ## so nah (bis zum Rumpf), dann Warnung und Signalhorn
const WARN_PAUSE := 25.0       ## Sekunden bis zur nächsten Warnung für dasselbe Schiff

## Rennzeit in Sekunden; setzt main.gd (Host/lokal jeden Schritt, Client aus dem Schnappschuss)
static var clock := 0.0
var _ships_cache := {}          # Zeit -> Schiffe (mehrfache Abfragen im selben Bild kosten nichts)
static var running := false

@export_range(100.0, 1500.0, 10.0, "suffix:m") var length := 900.0:
	set(v):
		length = v
		_rebuild()
@export_range(2.0, 12.0, 0.5, "suffix:kn") var speed_kn := 7.0
## Abstand zwischen zwei Schiffen derselben Richtung
@export_range(40.0, 400.0, 5.0, "suffix:s") var interval := 140.0
## Abfahrt des ersten Schiffs in Pfeilrichtung bzw. zurück (Sekunden Rennzeit, auch negativ)
@export_range(-400.0, 400.0, 5.0, "suffix:s") var phase_out := 60.0
@export_range(-400.0, 400.0, 5.0, "suffix:s") var phase_back := -40.0
## seitlicher Abstand der Fahrspur von der Mittellinie
@export_range(8.0, 60.0, 1.0, "suffix:m") var lane_offset := 22.0:
	set(v):
		lane_offset = v
		_rebuild()
## Knick im Weg: nach bend_at Metern dreht der Weg um bend_deg (positiv = nach rechts, negativ =
## nach links). So kann ein Schifffahrtsweg z. B. aus einer Kanalmündung seitlich ausfahren und
## dann der Förde folgen. 0 = geradeaus.
@export_range(0.0, 1500.0, 10.0, "suffix:m") var bend_at := 0.0:
	set(v):
		bend_at = v
		_rebuild()
@export_range(-120.0, 120.0, 1.0, "degrees") var bend_deg := 0.0:
	set(v):
		bend_deg = v
		_rebuild()
@export_range(30.0, 160.0, 5.0, "suffix:m") var ship_length := 80.0
@export_range(6.0, 30.0, 1.0, "suffix:m") var beam := 16.0
@export var lane_name := "Berufsschifffahrt":
	set(v):
		lane_name = v
		_rebuild()

var _vis: Node3D
var _nodes := {}               ## Schiffs-Id -> Node3D
var _t := 0.0
var _warned := {}              ## [Boot, Schiffs-Id] -> Zeitpunkt der letzten Warnung


func _ready() -> void:
	_t = 30.0
	_rebuild()


func pos2d() -> Vector2:
	return Vector2(global_position.x, global_position.z)


func lane_start() -> Vector2:
	return pos2d()


func lane_end() -> Vector2:
	return _pose(length, 0.0)[0]


## Stützpunkte der Mittellinie in Weltkoordinaten: Start, ggf. Knick, Ende
func polyline() -> Array:
	var pts: Array = [lane_start()]
	if bend_at > 0.0 and bend_at < length and absf(bend_deg) > 0.5:
		pts.append(_pose(bend_at, 0.0)[0])
	pts.append(lane_end())
	return pts


## Lage auf dem Weg: [Weltposition, Fahrtrichtung] bei Wegstrecke along und Seitenversatz side.
## Um den Knick herum dreht sich die Richtung weich (über 120 m), damit die Schiffe nicht springen.
func _pose(along: float, side: float) -> Array:
	var center := Vector2(0.0, -along)
	var h := 0.0
	if bend_at > 0.0 and absf(bend_deg) > 0.5:
		var a := deg_to_rad(bend_deg)
		if along > bend_at:
			var seg := Vector2(sin(a), -cos(a))
			center = Vector2(0.0, -bend_at) + seg * (along - bend_at)
		h = a * smoothstep(bend_at - 60.0, bend_at + 60.0, along)
	var dir_l := Vector2(sin(h), -cos(h))
	var side_l := Vector2(cos(h), sin(h))
	var local := center + side_l * side
	var g := global_transform * Vector3(local.x, 0, local.y)
	var f := global_basis * Vector3(dir_l.x, 0, dir_l.y)
	return [Vector2(g.x, g.z), Vector2(f.x, f.z).normalized()]


## Alle Schiffe zum Zeitpunkt t: [{id, pos, dir, vel, length, beam, name, type}]
func ships_at(t: float) -> Array:
	if _ships_cache.has(t):
		return _ships_cache[t]
	var out: Array = []
	var speed := speed_kn / 1.944
	var dur := (length + ship_length) / speed
	for dir_i in 2:
		var phase := phase_out if dir_i == 0 else phase_back
		var k_min := ceili((t - dur - phase) / interval)
		var k_max := floori((t - phase) / interval)
		for k in range(k_min, k_max + 1):
			var c := speed * (t - (phase + k * interval)) - ship_length * 0.5   # Schiffsmitte entlang der Bahn
			var along := c if dir_i == 0 else length - c
			var side := lane_offset if dir_i == 0 else -lane_offset          # rechts fahren
			var pose := _pose(along, side)
			var dir: Vector2 = pose[1] * (1.0 if dir_i == 0 else -1.0)
			var id := k * 2 + dir_i
			out.append({"id": id, "pos": pose[0], "dir": dir, "vel": dir * speed,
				"length": ship_length, "beam": beam,
				"name": NAMES[posmod(id, NAMES.size())], "type": posmod(id, 3)})
	if _ships_cache.size() > 24:
		_ships_cache.clear()
	_ships_cache[t] = out
	return out


## Nächster Punkt der Rumpfkontur zu p: {cp (Weltkoordinaten), d (Abstand zur Außenhaut, negativ innen)}
static func hull_query(sh: Dictionary, p: Vector2, coarse := false) -> Dictionary:
	var dir: Vector2 = sh["dir"]
	var right := Vector2(dir.y, -dir.x)
	var rel: Vector2 = p - sh["pos"]
	var local := Vector2(rel.dot(right), rel.dot(dir))
	var half_l: float = float(sh["length"]) * 0.5
	var half_b: float = float(sh["beam"]) * 0.5
	# weit weg: grobe Untergrenze genügt (spart Rechenzeit für die KI)
	var gap := Vector2(maxf(absf(local.x) - half_b, 0.0), maxf(absf(local.y) - half_l, 0.0))
	if gap.length() > 30.0:
		return {"cp": p, "d": gap.length()}
	var poly := ShipModel.outline(int(sh["type"]), float(sh["length"]), float(sh["beam"]), coarse)
	var best := INF
	var best_pt := Vector2.ZERO
	for i in poly.size():
		var c := Geometry2D.get_closest_point_to_segment(local, poly[i], poly[(i + 1) % poly.size()])
		var dd := local.distance_to(c)
		if dd < best:
			best = dd
			best_pt = c
	var inside := Geometry2D.is_point_in_polygon(local, poly)
	var cp: Vector2 = sh["pos"] + right * best_pt.x + dir * best_pt.y
	return {"cp": cp, "d": -best if inside else best}


## Abstand eines Punktes zur Außenhaut des Schiffs (negativ im Rumpf)
static func hull_distance(sh: Dictionary, p: Vector2) -> float:
	return float(hull_query(sh, p, true)["d"])      # grobes Vieleck genügt für die KI


# ---------------------------------------------------------------- Spiellogik

## Jeden Physikschritt für jedes Boot (nur Host bzw. lokal)
func update_boat(b: Boat, _delta: float) -> void:
	if b.out or b.towed:
		return
	var p := b.pos2d()
	for sh in ships_at(clock):
		var q := hull_query(sh, p)
		var d: float = q["d"]
		if d < Boat.BOAT_RADIUS:
			# Zusammenstoß: aus dem Rumpf schieben, Boot scheidet aus
			var cp: Vector2 = q["cp"]
			var n := (p - cp).normalized() if d >= 0.0 else (cp - p).normalized()
			if n.length() < 0.5:
				n = Vector2(-sh["dir"].y, sh["dir"].x)
			b.position += Vector3(n.x, 0, n.y) * (Boat.BOAT_RADIUS - d)
			b.ship_hit(n, sh["vel"])
			continue
		if d - Boat.BOAT_RADIUS < WARN_DIST and b.penalty <= 0.5:
			var key := [b, sh["id"]]
			if clock - float(_warned.get(key, -1000.0)) > WARN_PAUSE:
				_warned[key] = clock
				b.show_message("%s: Berufsschiff! Ausweichen!" % sh["name"], 3.0)
				b.show_kvr("KVR 9 – Enges Fahrwasser", "Berufsschifffahrt hat Vorrang: nicht behindern", 2)
				Sfx.play("ship_horn", -4.0)


# ---------------------------------------------------------------- Aufbau und Bewegung

func _rebuild() -> void:
	_ships_cache.clear()
	if not is_inside_tree():
		return
	if _vis:
		_vis.queue_free()
	_vis = Node3D.new()
	_vis.top_level = true
	add_child(_vis)
	# Kartenzeichen: zwei Fahrspuren mit Richtungspfeilen (magenta) und Beschriftung
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for dir_i in 2:
		var side := lane_offset if dir_i == 0 else -lane_offset
		var sgn := 1.0 if dir_i == 0 else -1.0                    # Fahrtrichtung entlang der Wegstrecke
		var z := 60.0
		while z < length - 40.0:
			var a: Vector2 = _pose(z + 14.0 * sgn, side)[0]          # Pfeilspitze
			var tail: Vector2 = _pose(z - 14.0 * sgn, side)[0]
			SeaChart.add_line(st, tail, a, 1.1, 0.1)
			var f := (a - tail).normalized()
			var n := Vector2(-f.y, f.x)
			SeaChart.add_triangle(st, a + f * 7.0, a + n * 4.0, a - n * 4.0, 0.1)
			z += 130.0
	_vis.add_child(SeaChart.mesh_from(st, Color(SeaChart.MAGENTA, 0.7)))
	var lab := SeaChart.flat_label(lane_name, 50, SeaChart.MAGENTA, true, true)
	var lp: Vector2 = _pose(length * 0.5, lane_offset + 38.0)[0]
	lab.position = Vector3(lp.x, 0.1, lp.y)
	lab.rotation = Vector3(-PI / 2, -global_rotation.y + PI * 0.5, 0)
	_vis.add_child(lab)
	for n in _nodes.values():
		n.queue_free()
	_nodes.clear()


func _to_world(local_xz: Vector2) -> Vector2:
	var g := global_transform * Vector3(local_xz.x, 0, local_xz.y)
	return Vector2(g.x, g.z)


func _process(delta: float) -> void:
	if _vis == null:
		return
	if Engine.is_editor_hint():
		_t += delta
	else:
		if running:
			_t += delta
		if not running or absf(_t - clock) > 0.25:
			_t = clock
	var ships := ships_at(_t)
	var alive := {}
	for sh in ships:
		var id: int = sh["id"]
		alive[id] = true
		var n: Node3D = _nodes.get(id)
		if n == null:
			n = _build_ship(int(sh["type"]), String(sh["name"]))
			add_child(n)
			n.top_level = true
			_nodes[id] = n
		var p: Vector2 = sh["pos"]
		var d: Vector2 = sh["dir"]
		n.position = Vector3(p.x, 0.0, p.y)
		n.rotation = Vector3(sin(_t * 0.6 + id) * 0.012, atan2(d.x, d.y), sin(_t * 0.45 + id * 2.0) * 0.02)
	for id in _nodes.keys():
		if not alive.has(id):
			_nodes[id].queue_free()
			_nodes.erase(id)


## Schiff mit dem Bug nach lokal +Z (Modell aus Blender, siehe ShipModel)
func _build_ship(type: int, ship_name: String) -> Node3D:
	var root := Node3D.new()
	root.add_child(ShipModel.build(type, ship_length, beam))
	var tag := Label3D.new()
	tag.text = ship_name
	tag.font = SeaChart.font(true)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.font_size = 56
	tag.outline_size = 10
	tag.outline_modulate = Color(1, 1, 1, 0.9)
	tag.modulate = Color(0.1, 0.1, 0.2)
	tag.pixel_size = 0.035
	tag.position = Vector3(0, 22.0, 0)
	root.add_child(tag)
	return root
