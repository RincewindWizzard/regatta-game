@tool
@icon("res://addons/regatta_editor/icons/mark.svg")
class_name CourseMark
extends Node3D
## Bahnmarke (gelbe Sondertonne mit liegendem Kreuz, INT 1 Q 130.6).
## Die Reihenfolge der CourseMark-Nodes im Szenenbaum ist die Rundungsreihenfolge.
## Zum Runden muss man in den gestrichelten Kreis fahren.

const MARK_RADIUS := 20.0
const YELLOW := Color(0.98, 0.82, 0.1)

@export var mark_name := "Tonne":
	set(v):
		mark_name = v
		_rebuild()
## Feuerkennung, wie sie auf der Karte steht
@export var light := "Fl.Y.4s":
	set(v):
		light = v
		_rebuild()

var _vis: Node3D
var _bob: Node3D
var _t := 0.0


func _ready() -> void:
	set_notify_transform(true)
	_t = randf() * 10.0
	_rebuild()


func _notification(what: int) -> void:
	if not Engine.is_editor_hint():
		return
	if what == NOTIFICATION_TRANSFORM_CHANGED or what == NOTIFICATION_MOVED_IN_PARENT:
		var lvl := get_parent() as Level
		if lvl:
			lvl._update_wind_arrow()
			if what == NOTIFICATION_MOVED_IN_PARENT:
				for m in lvl.marks():
					m._rebuild()


func pos2d() -> Vector2:
	return Vector2(global_position.x, global_position.z)


func order_number() -> int:
	var lvl := get_parent() as Level
	return lvl.marks().find(self) + 1 if lvl else 1


func _process(delta: float) -> void:
	if _bob:
		_t += delta
		_bob.position.y = sin(_t * 1.4) * 0.15
		_bob.rotation.x = sin(_t * 1.1) * 0.06
		_bob.rotation.z = sin(_t * 0.9) * 0.05


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m


func _mesh(mesh: Mesh, mat: Material, pos: Vector3, rot: Vector3, parent: Node3D) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _vis:
		_vis.queue_free()
	_vis = Node3D.new()
	add_child(_vis)
	_bob = Node3D.new()
	_vis.add_child(_bob)
	var yellow := _mat(YELLOW)
	var dark := _mat(Color(0.15, 0.15, 0.15))

	var body := CylinderMesh.new()
	body.top_radius = 0.55
	body.bottom_radius = 1.3
	body.height = 3.2
	_mesh(body, yellow, Vector3(0, 1.3, 0), Vector3.ZERO, _bob)
	var base := CylinderMesh.new()
	base.top_radius = 1.4
	base.bottom_radius = 1.4
	base.height = 0.3
	_mesh(base, dark, Vector3.ZERO, Vector3.ZERO, _bob)
	var pole := CylinderMesh.new()
	pole.top_radius = 0.07
	pole.bottom_radius = 0.07
	pole.height = 1.2
	_mesh(pole, dark, Vector3(0, 3.4, 0), Vector3.ZERO, _bob)
	var bar := BoxMesh.new()
	bar.size = Vector3(1.6, 0.22, 0.22)
	_mesh(bar, yellow, Vector3(0, 4.3, 0), Vector3(0, 0, PI / 4), _bob)
	_mesh(bar, yellow, Vector3(0, 4.3, 0), Vector3(0, 0, -PI / 4), _bob)
	var lamp := SphereMesh.new()
	lamp.radius = 0.2
	lamp.height = 0.4
	var lm := _mat(YELLOW)
	lm.emission_enabled = true
	lm.emission = YELLOW
	_mesh(lamp, lm, Vector3(0, 3.95, 0), Vector3.ZERO, _bob)
	ModelStyle.outline(_bob)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	SeaChart.add_ring(st, Vector2.ZERO, 1.9, 0.25, 0.08, 24)
	SeaChart.add_ring(st, Vector2.ZERO, MARK_RADIUS, 0.35, 0.08, 72, true)
	_vis.add_child(SeaChart.mesh_from(st, SeaChart.MAGENTA))
	var flare := SurfaceTool.new()
	flare.begin(Mesh.PRIMITIVE_TRIANGLES)
	SeaChart.add_triangle(flare, Vector2(1.6, -1.2), Vector2(7.5, -7.0), Vector2(4.2, -1.6), 0.085)
	SeaChart.add_triangle(flare, Vector2(1.6, -1.2), Vector2(2.2, -4.2), Vector2(7.5, -7.0), 0.085)
	_vis.add_child(SeaChart.mesh_from(flare, Color(SeaChart.MAGENTA, 0.8)))

	var title := mark_name
	if Engine.is_editor_hint():
		title = "%d. %s" % [order_number(), mark_name]
	var name_label := SeaChart.flat_label(title, 60, SeaChart.INK, false, true)
	name_label.position = Vector3(0, 0.09, 6.0)
	_vis.add_child(name_label)
	var ch := SeaChart.flat_label("Y  " + light, 40, SeaChart.MAGENTA)
	ch.position = Vector3(0, 0.09, 8.6)
	_vis.add_child(ch)
