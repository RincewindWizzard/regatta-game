@tool
@icon("res://addons/regatta_editor/icons/sealife.svg")
class_name SeaLife
extends Node3D
## Tiere und Wracks als lebendige Dekoration auf der Seekarte:
##   Tümmler    – eine Gruppe springt in Bögen um den Mittelpunkt
##   Wal        – zieht Kreise, bläst, taucht mit hochgereckter Fluke ab
##   Möwen      – kreisen mit Schlagflügeln und Schatten über dem Wasser
##   Seehunde   – liegen in einer Gruppe auf Fels oder Untiefe
##   Wrack      – gestrandetes Schiff, für Boote fest (solid)
## range_m ist der Kreisradius der Tiere. Die Tiere stören die Boote nicht.

enum Kind { TUEMMLER, WAL, MOEWEN, SEEHUNDE, WRACK }

@export var kind := Kind.TUEMMLER:
	set(v):
		kind = v
		_rebuild()
@export_range(1, 12) var count := 3:
	set(v):
		count = v
		_rebuild()
## Kreisradius (Tümmler, Wal, Möwen) bzw. Gruppenradius (Seehunde)
@export_range(3.0, 150.0, 1.0, "suffix:m") var range_m := 40.0:
	set(v):
		range_m = v
		_rebuild()
## Wrack: Boote prallen ab (und die Computergegner umfahren es)
@export var solid := true
@export var label := "":
	set(v):
		label = v
		_rebuild()

var _vis: Node3D
var _body: Node3D
var _t := 0.0
var _critters: Array[Dictionary] = []


func _ready() -> void:
	set_notify_transform(true)
	_t = randf() * 20.0
	_rebuild()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and _vis:
		_vis.global_position = Vector3(global_position.x, 0, global_position.z)


func pos2d() -> Vector2:
	return Vector2(global_position.x, global_position.z)


## Wrack: feste Punkte entlang des Rumpfes [Position, Radius]
func collision_points() -> Array:
	var out: Array = []
	if kind != Kind.WRACK or not solid:
		return out
	for z in [-8.0, -3.5, 1.0, 5.5, 9.0]:
		var g := global_transform * Vector3(0, 0, z)
		out.append([Vector2(g.x, g.z), 3.4])
	return out


# ---------------------------------------------------------------- Aufbau

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.8
	return m


func _mi(parent: Node3D, mesh: Mesh, col: Color, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(col)
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi


func _sphere(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 12
	m.rings = 6
	return m


func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


func _prism(size: Vector3) -> PrismMesh:
	var m := PrismMesh.new()
	m.size = size
	return m


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _vis:
		_vis.queue_free()
	if _body:
		_body.queue_free()
	_critters.clear()
	# Karten-Symbole und Beschriftung: unverzerrt, unabhängig von Drehung
	_vis = Node3D.new()
	_vis.top_level = true
	add_child(_vis)
	_vis.global_position = Vector3(global_position.x, 0, global_position.z)
	_body = Node3D.new()
	add_child(_body)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(global_position.x * 7.0 + global_position.z * 13.0) + count * 31 + int(kind)
	match kind:
		Kind.TUEMMLER:
			for i in count:
				var d := _dolphin()
				_body.add_child(d)
				_critters.append({"node": d, "i": i, "prev": 0.0, "dir": 1.0, "off": rng.randf() * 0.2})
		Kind.WAL:
			for i in count:
				var w := _whale()
				_body.add_child(w["root"])
				_critters.append({"node": w["root"], "spout": w["spout"], "i": i, "prev": 0.0, "off": rng.randf()})
		Kind.MOEWEN:
			for i in count:
				var g := _gull()
				_body.add_child(g["root"])
				var sh := _mi(_vis, _disc(0.9), Color(0, 0, 0, 0.0))
				var sm := sh.material_override as StandardMaterial3D
				sm.albedo_color = Color(0.0, 0.1, 0.2, 0.22)
				sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				_critters.append({"node": g["root"], "wing_l": g["wing_l"], "wing_r": g["wing_r"], "shadow": sh,
					"r": range_m * rng.randf_range(0.45, 1.0), "h": rng.randf_range(5.0, 12.0),
					"v": rng.randf_range(7.0, 10.0), "a0": rng.randf() * TAU, "dir": 1.0 if rng.randf() < 0.5 else -1.0,
					"cx": rng.randf_range(-8.0, 8.0), "cz": rng.randf_range(-8.0, 8.0), "ph": rng.randf() * TAU})
		Kind.SEEHUNDE:
			_build_seals(rng)
		Kind.WRACK:
			_build_wreck()
	if label != "" or kind == Kind.WRACK:
		var text := label if label != "" else "Wrack"
		var lab := SeaChart.flat_label(text, 44, SeaChart.INK, true)
		lab.position = Vector3(0, 0.08, 16.0 if kind == Kind.WRACK else range_m * 0.5 + 6.0)
		_vis.add_child(lab)


func _disc(r: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = 0.02
	m.radial_segments = 14
	return m


func _dolphin() -> Node3D:
	var root := Node3D.new()
	var inner := Node3D.new()
	inner.scale = Vector3.ONE * 1.35
	root.add_child(inner)
	var gray := Color(0.42, 0.52, 0.62)
	_mi(inner, _sphere(0.55), gray, Vector3.ZERO, Vector3.ZERO, Vector3(0.8, 0.8, 2.4))
	_mi(inner, _sphere(0.55), Color(0.92, 0.94, 0.96), Vector3(0, -0.14, 0.1), Vector3.ZERO, Vector3(0.75, 0.5, 2.2))
	var cm := CylinderMesh.new()
	cm.top_radius = 0.1
	cm.bottom_radius = 0.17
	cm.height = 0.75
	cm.radial_segments = 8
	_mi(inner, cm, gray.lightened(0.1), Vector3(0, -0.05, 1.45), Vector3(PI / 2, 0, 0))
	_mi(inner, _prism(Vector3(0.12, 0.6, 0.7)), gray.darkened(0.15), Vector3(0, 0.62, -0.1))
	_mi(inner, _prism(Vector3(1.3, 0.55, 0.1)), gray.darkened(0.1), Vector3(0, 0.0, -1.45), Vector3(PI / 2, 0, 0))
	for s in [-1.0, 1.0]:
		_mi(inner, _prism(Vector3(0.5, 0.55, 0.08)), gray.darkened(0.1), Vector3(s * 0.55, -0.25, 0.55), Vector3(PI / 2, 0, s * 0.8))
	ModelStyle.outline(inner)
	ModelStyle.no_shadows(inner)
	return root


func _whale() -> Dictionary:
	var root := Node3D.new()
	var inner := Node3D.new()
	root.add_child(inner)
	var blue := Color(0.27, 0.34, 0.43)
	_mi(inner, _sphere(1.0), blue, Vector3(0, 0, 0.5), Vector3.ZERO, Vector3(2.0, 1.7, 6.0))
	_mi(inner, _sphere(1.0), blue.lightened(0.04), Vector3(0, 0.0, 3.6), Vector3.ZERO, Vector3(1.9, 1.5, 2.6))
	_mi(inner, _sphere(1.0), Color(0.82, 0.86, 0.9), Vector3(0, -0.5, 1.4), Vector3.ZERO, Vector3(1.7, 1.0, 5.2))
	_mi(inner, _sphere(1.0), blue.darkened(0.05), Vector3(0, 0.1, -5.2), Vector3.ZERO, Vector3(0.9, 0.8, 3.6))
	for s in [-1.0, 1.0]:
		_mi(inner, _prism(Vector3(1.0, 3.2, 0.2)), blue.darkened(0.12), Vector3(s * 2.3, -0.5, 2.0), Vector3(PI / 2, 0, s * 1.1))
		_mi(inner, _prism(Vector3(2.2, 1.6, 0.25)), blue.darkened(0.08), Vector3(s * 1.1, 0.0, -8.0), Vector3(PI / 2, 0, s * 0.35))
	_mi(inner, _prism(Vector3(0.3, 1.0, 1.4)), blue.darkened(0.1), Vector3(0, 1.55, -2.4))
	ModelStyle.outline(inner)
	ModelStyle.no_shadows(inner)
	root.set_meta("inner", inner)
	# Blas: Wasserfontäne aus Partikeln, wird beim Auftauchen ausgelöst
	var spout := CPUParticles3D.new()
	spout.mesh = _sphere(0.28)
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(1, 1, 1, 0.85)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spout.material_override = sm
	spout.position = Vector3(0, 1.9, 3.4)
	spout.amount = 22
	spout.lifetime = 1.3
	spout.one_shot = true
	spout.emitting = false
	spout.explosiveness = 0.55
	spout.direction = Vector3.UP
	spout.spread = 14.0
	spout.initial_velocity_min = 5.5
	spout.initial_velocity_max = 8.0
	spout.gravity = Vector3(0, -9.0, 0)
	spout.scale_amount_min = 0.6
	spout.scale_amount_max = 1.2
	inner.add_child(spout)
	return {"root": root, "spout": spout}


func _gull() -> Dictionary:
	var root := Node3D.new()
	var inner := Node3D.new()
	inner.scale = Vector3.ONE * 1.9
	root.add_child(inner)
	var white := Color(0.97, 0.97, 0.95)
	_mi(inner, _sphere(0.4), white, Vector3.ZERO, Vector3.ZERO, Vector3(0.7, 0.6, 1.7))
	_mi(inner, _sphere(0.22), white, Vector3(0, 0.1, 0.7))
	_mi(inner, _prism(Vector3(0.12, 0.3, 0.1)), Color(0.95, 0.65, 0.1), Vector3(0, 0.08, 0.98), Vector3(PI / 2, 0, 0))
	_mi(inner, _prism(Vector3(0.45, 0.6, 0.06)), white.darkened(0.08), Vector3(0, 0.0, -0.85), Vector3(PI / 2, 0, 0))
	var wings := []
	for s in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(s * 0.18, 0.08, 0.05)
		inner.add_child(pivot)
		_mi(pivot, _box(Vector3(1.0, 0.05, 0.55)), white, Vector3(s * 0.5, 0, 0))
		_mi(pivot, _box(Vector3(0.45, 0.05, 0.42)), Color(0.25, 0.27, 0.3), Vector3(s * 1.2, 0, -0.04))
		wings.append(pivot)
	ModelStyle.outline(inner)
	ModelStyle.no_shadows(inner)
	return {"root": root, "wing_l": wings[0], "wing_r": wings[1]}


func _build_seals(rng: RandomNumberGenerator) -> void:
	# ein paar Felsen als Liegeplatz
	var rocks: Array = []
	for k in 4:
		var a := rng.randf() * TAU
		rocks.append([Vector3(cos(a), 0.0, sin(a)) * range_m * 0.5, rng.randf_range(2.0, 3.4)])
	Deco.rocks(_body, rocks, rng.seed)
	for i in count:
		var a := TAU * i / count + rng.randf() * 0.6
		var seal := _seal()
		seal.position = Vector3(cos(a), 0.3, sin(a)) * range_m * rng.randf_range(0.2, 0.8)
		seal.rotation.y = rng.randf() * TAU
		_body.add_child(seal)
		_critters.append({"node": seal, "ph": rng.randf() * TAU, "head": seal.get_meta("head")})


func _seal() -> Node3D:
	var root := Node3D.new()
	var fur := Color(0.58, 0.52, 0.45)
	_mi(root, _sphere(0.5), fur, Vector3(0, 0.3, 0), Vector3(-0.1, 0, 0), Vector3(0.95, 0.75, 2.2))
	_mi(root, _sphere(0.5), fur.lightened(0.25), Vector3(0, 0.12, 0.05), Vector3.ZERO, Vector3(0.85, 0.5, 2.0))
	var head := Node3D.new()
	head.position = Vector3(0, 0.6, 1.0)
	root.add_child(head)
	_mi(head, _sphere(0.36), fur.darkened(0.05), Vector3.ZERO)
	_mi(head, _sphere(0.2), fur.lightened(0.15), Vector3(0, -0.06, 0.3))
	_mi(head, _sphere(0.08), Color(0.05, 0.05, 0.06), Vector3(0, -0.02, 0.5))
	for s in [-1.0, 1.0]:
		_mi(root, _prism(Vector3(0.5, 0.7, 0.08)), fur.darkened(0.1), Vector3(s * 0.28, 0.3, -1.2), Vector3(PI / 2, 0, s * 0.3))
		_mi(root, _prism(Vector3(0.3, 0.5, 0.08)), fur.darkened(0.1), Vector3(s * 0.45, 0.15, 0.45), Vector3(PI / 2, 0, s * 1.0))
	ModelStyle.outline(root)
	ModelStyle.no_shadows(root)
	root.set_meta("head", head)
	return root


func _build_wreck() -> void:
	var wood := Color(0.34, 0.24, 0.16)
	var deck := Color(0.5, 0.42, 0.32)
	var rust := Color(0.5, 0.28, 0.18)
	var weed := Color(0.2, 0.42, 0.25)
	var ship := Node3D.new()
	ship.position.y = -1.0
	ship.rotation = Vector3(-0.06, 0.0, 0.32)       # krängt nach Backbord, Bug leicht hoch
	_body.add_child(ship)
	_mi(ship, _box(Vector3(6.0, 3.4, 16.0)), wood, Vector3(0, 0.7, -2.0))
	_mi(ship, _prism(Vector3(6.0, 6.0, 3.4)), wood, Vector3(0, 0.7, 9.0), Vector3(PI / 2, 0, 0))
	_mi(ship, _box(Vector3(5.4, 0.25, 15.5)), deck, Vector3(0, 2.45, -2.0))
	# Spanten ragen aus dem aufgebrochenen Rumpf
	for k in 6:
		for s in [-1.0, 1.0]:
			var h := 2.4 if k % 2 == 0 else 1.7
			_mi(ship, _box(Vector3(0.26, h, 0.3)), wood.darkened(0.15), Vector3(s * 2.8, 2.5 + h * 0.5, -8.0 + k * 2.4), Vector3(0, 0, s * 0.12))
	# Achteraufbau (Reste), gebrochener Mast, Rah
	_mi(ship, _box(Vector3(4.2, 2.4, 3.4)), deck.darkened(0.1), Vector3(0, 3.5, -6.0))
	_mi(ship, _box(Vector3(4.4, 0.25, 3.6)), rust, Vector3(0, 4.8, -6.0), Vector3(0.0, 0.0, 0.12))
	var mast := CylinderMesh.new()
	mast.top_radius = 0.2
	mast.bottom_radius = 0.3
	mast.height = 9.0
	mast.radial_segments = 6
	_mi(ship, mast, wood.lightened(0.1), Vector3(-1.0, 6.5, 2.0), Vector3(0.3, 0, 0.55))
	_mi(ship, _box(Vector3(5.5, 0.18, 0.18)), wood.lightened(0.1), Vector3(-3.5, 9.5, 1.0), Vector3(0.2, 0.3, 0.8))
	# Tang am Bug und im Rumpf
	for p in [Vector3(2.4, 2.6, 6.0), Vector3(-2.6, 1.4, 3.0), Vector3(1.5, 2.6, -9.5)]:
		_mi(ship, _sphere(0.8), weed, p, Vector3.ZERO, Vector3(1.2, 0.5, 1.2))
	ModelStyle.outline(ship)
	# Karte: Umriss und Tonne "Wk"
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	SeaChart.add_ring(st, Vector2.ZERO, 17.0, 0.4, 0.09, 40, true)
	SeaChart.add_line(st, Vector2(-2.2, -2.2), Vector2(2.2, 2.2), 0.35, 0.09)
	SeaChart.add_line(st, Vector2(-2.2, 2.2), Vector2(2.2, -2.2), 0.35, 0.09)
	_vis.add_child(SeaChart.mesh_from(st, SeaChart.INK))


# ---------------------------------------------------------------- Bewegung

func _process(delta: float) -> void:
	_t += delta
	match kind:
		Kind.TUEMMLER:
			for c in _critters:
				_step_dolphin(c)
		Kind.WAL:
			for c in _critters:
				_step_whale(c)
		Kind.MOEWEN:
			for c in _critters:
				_step_gull(c)
		Kind.SEEHUNDE:
			for c in _critters:
				var head: Node3D = c["head"]
				head.rotation.x = -0.35 * maxf(0.0, sin(_t * 0.7 + c["ph"]))
				head.rotation.y = sin(_t * 0.4 + c["ph"]) * 0.5
				var node: Node3D = c["node"]
				node.scale.y = 1.0 + sin(_t * 1.6 + c["ph"]) * 0.03


func _step_dolphin(c: Dictionary) -> void:
	var node: Node3D = c["node"]
	var i: int = c["i"]
	const CYCLE := 4.6
	const JUMP := 0.3
	var speed := 5.5
	var r := range_m * (0.85 + 0.15 * (i % 2))
	var a := _t * speed / r + i * 0.32
	var u := fposmod(_t / CYCLE + i * 0.06 + float(c["off"]), 1.0)
	var y := -2.0
	var pitch := 0.0
	if u < JUMP:
		var s := u / JUMP
		y = 2.5 * sin(s * PI) - 0.7
		var dy := 2.5 * PI * cos(s * PI) / (JUMP * CYCLE)
		pitch = atan2(dy, speed)
	var prev: float = c["prev"]
	# Spritzer beim Auftauchen und Eintauchen
	if (prev < 0.027 and u >= 0.027) or (prev < 0.273 and u >= 0.273):
		Fx.ripple(self, node.global_position, 5.0, 1.0)
	c["prev"] = u
	node.position = Vector3(cos(a) * r, y, sin(a) * r)
	node.rotation = Vector3(-pitch, atan2(-sin(a), cos(a)), 0.0)
	node.visible = y > -1.9


func _step_whale(c: Dictionary) -> void:
	var node: Node3D = c["node"]
	var inner: Node3D = node.get_meta("inner")
	const CYCLE := 24.0
	var r := range_m
	var speed := 1.6
	var a := _t * speed / r + float(c["i"]) * 2.2
	var u := fposmod(_t / CYCLE + float(c["off"]), 1.0)
	var y := -0.45
	var pitch := 0.0
	if u < 0.12:
		var s := smoothstep(0.0, 1.0, u / 0.12)
		y = lerpf(-14.0, -0.45, s)
		pitch = lerpf(1.2, 0.0, s)
	elif u < 0.62:
		y = -0.45 + 0.12 * sin(_t * 0.9)
		pitch = 0.03 * sin(_t * 0.7)
	elif u < 0.78:
		var s := (u - 0.62) / 0.16
		y = -0.45 - 4.0 * s
		pitch = 1.1 * s
	else:
		var s := smoothstep(0.0, 1.0, (u - 0.78) / 0.12)
		y = lerpf(-4.45, -14.0, s)
		pitch = lerpf(1.1, 1.2, s)
	var prev: float = c["prev"]
	for mark in [0.14, 0.3, 0.46, 0.58]:
		if prev < mark and u >= mark:
			var spout: CPUParticles3D = c["spout"]
			spout.restart()
			spout.emitting = true
			Fx.ripple(self, node.global_position + node.global_basis.z * 3.5, 9.0, 1.8)
	c["prev"] = u
	node.position = Vector3(cos(a) * r, y, sin(a) * r)
	node.rotation = Vector3(pitch, atan2(-sin(a), cos(a)), 0.0)
	node.visible = y > -13.0
	inner.rotation.z = sin(_t * 0.5) * 0.02


func _step_gull(c: Dictionary) -> void:
	var node: Node3D = c["node"]
	var dir: float = c["dir"]
	var r: float = c["r"]
	var a: float = c["a0"] + dir * _t * float(c["v"]) / r
	var x: float = c["cx"] + cos(a) * r
	var z: float = c["cz"] + sin(a) * r
	var y: float = c["h"] + sin(_t * 0.8 + float(c["ph"])) * 0.8
	node.position = Vector3(x, y, z)
	node.rotation = Vector3(0.0, atan2(-sin(a) * dir, cos(a) * dir), -0.3 * dir)
	var flap := sin(_t * 9.0 + float(c["ph"])) * 0.45
	(c["wing_l"] as Node3D).rotation.z = flap
	(c["wing_r"] as Node3D).rotation.z = -flap
	var sh: Node3D = c["shadow"]
	var wp := global_transform * Vector3(x, 0.0, z)
	sh.global_position = Vector3(wp.x, 0.12, wp.z)
