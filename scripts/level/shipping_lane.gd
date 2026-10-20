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
	var g := global_transform * Vector3(0, 0, -length)
	return Vector2(g.x, g.z)


## Alle Schiffe zum Zeitpunkt t: [{id, pos, dir, vel, half, radius, name, type}]
func ships_at(t: float) -> Array:
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
			var g := global_transform * Vector3(side, 0, -along)
			var f := -global_basis.z
			var dir := Vector2(f.x, f.z).normalized() * (1.0 if dir_i == 0 else -1.0)
			var id := k * 2 + dir_i
			out.append({"id": id, "pos": Vector2(g.x, g.z), "dir": dir, "vel": dir * speed,
				"half": ship_length * 0.5, "radius": beam * 0.5 + 1.5,
				"name": NAMES[posmod(id, NAMES.size())], "type": posmod(id, 3)})
	return out


## Abstand eines Punktes zum Schiffsrumpf (Strecke Bug–Heck), abzüglich Rumpfradius
static func hull_distance(sh: Dictionary, p: Vector2) -> float:
	var a: Vector2 = sh["pos"] - sh["dir"] * sh["half"]
	var b: Vector2 = sh["pos"] + sh["dir"] * sh["half"]
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)) - float(sh["radius"])


# ---------------------------------------------------------------- Spiellogik

## Jeden Physikschritt für jedes Boot (nur Host bzw. lokal)
func update_boat(b: Boat, _delta: float) -> void:
	if b.out or b.towed:
		return
	var p := b.pos2d()
	for sh in ships_at(clock):
		var a: Vector2 = sh["pos"] - sh["dir"] * sh["half"]
		var e: Vector2 = sh["pos"] + sh["dir"] * sh["half"]
		var cp := Geometry2D.get_closest_point_to_segment(p, a, e)
		var d := p.distance_to(cp)
		var reach: float = float(sh["radius"]) + Boat.BOAT_RADIUS
		if d < reach:
			# Zusammenstoß: aus dem Rumpf schieben, zurückwerfen, bestrafen
			var n := (p - cp) / d if d > 0.01 else Vector2(-sh["dir"].y, sh["dir"].x)
			b.position += Vector3(n.x, 0, n.y) * (reach - d)
			b.ship_hit(n, sh["vel"])
			continue
		if d - reach < WARN_DIST and b.penalty <= 0.5:
			var key := [b, sh["id"]]
			if clock - float(_warned.get(key, -1000.0)) > WARN_PAUSE:
				_warned[key] = clock
				b.show_message("%s: Berufsschiff! Ausweichen!" % sh["name"], 3.0)
				b.show_kvr("KVR 9 – Enges Fahrwasser", "Berufsschifffahrt hat Vorrang: nicht behindern", 2)
				Sfx.play("ship_horn", -4.0)


# ---------------------------------------------------------------- Aufbau und Bewegung

func _rebuild() -> void:
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
		var dz := -1.0 if dir_i == 0 else 1.0                      # Fahrtrichtung entlang lokal z
		var z := 60.0
		while z < length - 40.0:
			var a := _to_world(Vector2(side, -z + 14.0 * dz))          # Pfeilspitze
			var tail := _to_world(Vector2(side, -z - 14.0 * dz))
			SeaChart.add_line(st, tail, a, 1.1, 0.1)
			var f := (a - tail).normalized()
			var n := Vector2(-f.y, f.x)
			SeaChart.add_triangle(st, a + f * 7.0, a + n * 4.0, a - n * 4.0, 0.1)
			z += 130.0
	_vis.add_child(SeaChart.mesh_from(st, Color(SeaChart.MAGENTA, 0.7)))
	var lab := SeaChart.flat_label(lane_name, 50, SeaChart.MAGENTA, true, true)
	var lp := _to_world(Vector2(lane_offset + 38.0, -length * 0.5))
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


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m


func _box(parent: Node3D, size: Vector3, pos: Vector3, c: Color) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = _mat(c)
	mi.position = pos
	parent.add_child(mi)


## Schiff mit dem Bug nach lokal +Z. type 0 = Containerschiff, 1 = Tanker, 2 = Massengutfrachter
func _build_ship(type: int, ship_name: String) -> Node3D:
	var root := Node3D.new()
	var body := Node3D.new()
	root.add_child(body)
	var L := ship_length
	var hulls := [Color(0.1, 0.2, 0.38), Color(0.55, 0.12, 0.1), Color(0.14, 0.32, 0.26)]
	var hull_c: Color = hulls[type]
	var white := Color(0.96, 0.96, 0.94)
	# Rumpf mit Bug (Prisma) und rotem Unterwasseranstrich am Rand
	_box(body, Vector3(beam, 5.0, L * 0.82), Vector3(0, 2.0, -L * 0.09), hull_c)
	var bow := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(beam, L * 0.18, 5.0)
	bow.mesh = pm
	bow.material_override = _mat(hull_c)
	bow.position = Vector3(0, 2.0, L * 0.41)
	bow.rotation = Vector3(PI / 2, 0, 0)
	body.add_child(bow)
	_box(body, Vector3(beam + 0.3, 1.0, L * 0.82), Vector3(0, -0.2, -L * 0.09), Color(0.62, 0.15, 0.12))
	# Aufbauten am Heck: Brücke, Schornstein
	_box(body, Vector3(beam * 0.8, 6.0, L * 0.12), Vector3(0, 7.5, -L * 0.38), white)
	_box(body, Vector3(beam * 0.9, 1.0, L * 0.13), Vector3(0, 11.0, -L * 0.38), Color(0.2, 0.22, 0.26))
	var stack := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.5
	cm.bottom_radius = 1.8
	cm.height = 5.0
	stack.mesh = cm
	stack.material_override = _mat(Color(0.85, 0.15, 0.12))
	stack.position = Vector3(0, 12.5, -L * 0.46)
	body.add_child(stack)
	match type:
		0:   # Container in Stapeln
			var cols := [Color(0.85, 0.25, 0.15), Color(0.2, 0.45, 0.75), Color(0.9, 0.7, 0.15), Color(0.25, 0.6, 0.35), Color(0.7, 0.7, 0.72)]
			var z := -L * 0.28
			var k := 0
			while z < L * 0.34:
				for x in [-0.28, 0.0, 0.28]:
					var h := 3.0 + float((k + int(x * 10)) % 3)
					_box(body, Vector3(beam * 0.26, h, L * 0.06), Vector3(x * beam, 4.5 + h * 0.5, z), cols[(k + int(x * 10) + 10) % cols.size()])
				z += L * 0.065
				k += 1
		1:   # Tanker: Rohrleitungen und Tankdeckel
			_box(body, Vector3(1.0, 0.8, L * 0.6), Vector3(0, 5.8, 0.0), Color(0.2, 0.2, 0.22))
			for i in 5:
				var tank := MeshInstance3D.new()
				var tm := CylinderMesh.new()
				tm.top_radius = beam * 0.3
				tm.bottom_radius = beam * 0.3
				tm.height = 0.7
				tank.mesh = tm
				tank.material_override = _mat(Color(0.35, 0.37, 0.4))
				tank.position = Vector3(0, 5.3, -L * 0.25 + i * L * 0.12)
				body.add_child(tank)
		2:   # Massengutfrachter: Lukendeckel und Kräne
			for i in 4:
				_box(body, Vector3(beam * 0.7, 1.6, L * 0.12), Vector3(0, 5.8, -L * 0.25 + i * L * 0.16), Color(0.75, 0.72, 0.6))
			for i in 2:
				_box(body, Vector3(1.2, 8.0, 1.2), Vector3(0, 9.0, -L * 0.17 + i * L * 0.32), Color(0.9, 0.55, 0.1))
	ModelStyle.outline(body)
	ModelStyle.no_shadows(body)
	# Bug- und Heckwelle, Kielwasser
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s in [-1.0, 1.0]:
		var a := Vector2(s * beam * 0.5, L * 0.35)
		var b := Vector2(s * beam * 0.5, -L * 0.5)
		var c := Vector2(s * (beam * 0.5 + 26.0), -L * 0.5 - 130.0)
		SeaChart.add_triangle(st, a, b, c, 0.14)
		SeaChart.add_triangle(st, a, c, Vector2(s * (beam * 0.5 + 9.0), L * 0.2), 0.14)
	SeaChart.add_ring(st, Vector2(0, L * 0.5), 5.0, 1.2, 0.15, 24)
	root.add_child(SeaChart.mesh_from(st, Color(1, 1, 1, 0.42)))
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
