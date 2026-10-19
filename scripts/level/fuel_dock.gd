@tool
@icon("res://addons/regatta_editor/icons/fuel.svg")
class_name FuelDock
extends Node3D
## Tankstelle: Holzsteg vom Ufer ins Wasser (in Pfeilrichtung, lokal -Z) mit
## Zapfsäule und Schild. Am Stegkopf (Liegeplatz) wird getankt – nur mit
## ausgeschaltetem Motor und im Stillstand, und es dauert ein paar Sekunden.
## Den Steg so setzen, dass seine Wurzel an Land liegt und der Kopf im tiefen Wasser.

const ZONE := 13.0          ## Radius des Liegeplatzes

@export_range(10.0, 60.0, 1.0, "suffix:m") var length := 26.0:
	set(v):
		length = v
		_rebuild()
@export var dock_name := "Tankstelle":
	set(v):
		dock_name = v
		_rebuild()

var _vis: Node3D
var _t := 0.0
var _lamp: MeshInstance3D


func _ready() -> void:
	set_notify_transform(true)
	_rebuild()


func pos2d() -> Vector2:
	return Vector2(global_position.x, global_position.z)


## Liegeplatz neben dem Stegkopf (dort tanken)
func berth() -> Vector2:
	var head := global_transform * Vector3(-7.0, 0, -length + 4.0)
	return Vector2(head.x, head.z)


## Der Steg ist für Boote fest
func collision_points() -> Array:
	var out: Array = []
	var k := 0.0
	while k <= length:
		var g := global_transform * Vector3(0, 0, -k)
		out.append([Vector2(g.x, g.z), 1.8])
		k += 3.0
	return out


func _process(delta: float) -> void:
	_t += delta
	if _lamp:
		var m := _lamp.material_override as StandardMaterial3D
		m.emission_energy_multiplier = 1.0 + 1.5 * (0.5 + 0.5 * sin(_t * 3.0))


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m


func _box(size: Vector3, pos: Vector3, c: Color, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = _mat(c)
	mi.position = pos
	parent.add_child(mi)
	return mi


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _vis:
		_vis.queue_free()
	_vis = Node3D.new()
	add_child(_vis)
	var wood := Color(0.55, 0.38, 0.22)
	var dark_wood := Color(0.36, 0.24, 0.14)
	# Steg mit Pfählen
	_box(Vector3(3.2, 0.3, length), Vector3(0, 1.0, -length * 0.5), wood, _vis)
	var z := 0.0
	while z <= length:
		for x in [-1.5, 1.5]:
			var pile := MeshInstance3D.new()
			var c := CylinderMesh.new()
			c.top_radius = 0.22
			c.bottom_radius = 0.22
			c.height = 2.6
			c.radial_segments = 6
			pile.mesh = c
			pile.material_override = _mat(dark_wood)
			pile.position = Vector3(x, 0.6, -z)
			_vis.add_child(pile)
		z += 4.0
	# Querbrett am Kopf
	_box(Vector3(8.0, 0.3, 3.0), Vector3(-2.4, 1.0, -length + 1.5), wood, _vis)
	# Zapfsäule (rot mit weißem Band) und Schlauch
	var pump := Node3D.new()
	pump.position = Vector3(1.0, 1.15, -length + 2.0)
	_vis.add_child(pump)
	_box(Vector3(1.0, 2.0, 0.7), Vector3(0, 1.0, 0), Color(0.85, 0.15, 0.12), pump)
	_box(Vector3(1.05, 0.35, 0.75), Vector3(0, 1.45, 0), Color(0.97, 0.97, 0.95), pump)
	_box(Vector3(0.12, 0.12, 0.9), Vector3(-0.55, 1.0, 0.0), Color(0.1, 0.1, 0.1), pump)
	_lamp = _box(Vector3(0.7, 0.25, 0.5), Vector3(0, 2.15, 0), Color(1.0, 0.85, 0.3), pump)
	var lm := _lamp.material_override as StandardMaterial3D
	lm.emission_enabled = true
	lm.emission = Color(1.0, 0.8, 0.3)
	# kleines Kassenhäuschen
	_box(Vector3(3.0, 2.4, 2.6), Vector3(1.6, 1.2, -1.5), Color(0.96, 0.94, 0.88), _vis)
	var roof := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(3.6, 1.2, 3.0)
	roof.mesh = pm
	roof.material_override = _mat(Color(0.2, 0.45, 0.3))
	roof.position = Vector3(1.6, 3.0, -1.5)
	_vis.add_child(roof)
	ModelStyle.outline(_vis)
	# Schild über dem Steg
	var sign := Label3D.new()
	sign.text = dock_name.to_upper()
	sign.font = SeaChart.font(false, true)
	sign.font_size = 64
	sign.pixel_size = 0.03
	sign.modulate = Color(0.85, 0.15, 0.12)
	sign.outline_size = 12
	sign.outline_modulate = Color(1, 1, 1)
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.no_depth_test = true
	sign.position = Vector3(0, 6.0, -length + 2.0)
	_vis.add_child(sign)
	# Kartensymbol: Zapfsäule (Kreis + "F") am Liegeplatz, Liegeplatz gestrichelt
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	SeaChart.add_ring(st, Vector2(-7.0, -length + 4.0), ZONE, 0.35, 0.09, 40, true)
	_vis.add_child(SeaChart.mesh_from(st, Color(SeaChart.MAGENTA, 0.8)))
	var lab := SeaChart.flat_label("Tankstelle", 40, SeaChart.MAGENTA, false, true)
	lab.position = Vector3(-7.0, 0.09, -length + 4.0 - ZONE - 4.0)
	_vis.add_child(lab)
