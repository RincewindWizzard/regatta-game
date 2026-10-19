@tool
@icon("res://addons/regatta_editor/icons/lighthouse.svg")
class_name Lighthouse
extends Node3D
## Leuchtturm auf einer kleinen Felsklippe, mit drehendem Lichtkegel.
## Die Klippe ist Land – nicht dagegen segeln.

enum Style { ROT_WEISS, SCHWARZ_WEISS, WEISS, GRUEN_WEISS }

@export var style := Style.ROT_WEISS:
	set(v):
		style = v
		_rebuild()
@export_range(10.0, 40.0, 1.0, "suffix:m") var tower_height := 20.0:
	set(v):
		tower_height = v
		_rebuild()
@export_range(6.0, 40.0, 1.0, "suffix:m") var rock_radius := 11.0:
	set(v):
		rock_radius = v
		_changed()
@export var tower_name := "Leuchtturm":
	set(v):
		tower_name = v
		_rebuild()
@export var characteristic := "Fl(2)W.10s 24m 15M":
	set(v):
		characteristic = v
		_rebuild()
@export var rotating_beam := true

var _vis: Node3D
var _beam: Node3D
var _inv := Transform3D.IDENTITY


func _ready() -> void:
	set_notify_transform(true)
	_rebuild()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint() and is_inside_tree():
		var lvl := get_parent() as Level
		if lvl:
			lvl.queue_preview()


func _changed() -> void:
	_rebuild()
	if Engine.is_editor_hint() and is_inside_tree():
		var lvl := get_parent() as Level
		if lvl:
			lvl.queue_preview()


func _process(delta: float) -> void:
	if _beam and rotating_beam:
		_beam.rotation.y += delta * 0.9


func pos2d() -> Vector2:
	return Vector2(global_position.x, global_position.z)


func reach() -> float:
	_inv = global_transform.affine_inverse()
	return rock_radius * 3.0


func depth_profile(p: Vector2) -> float:
	var l := _inv * Vector3(p.x, 0, p.y)
	var k := Vector2(l.x, l.z).length() / rock_radius
	return 4.0 * (k * k - 1.0) + SeaChart.LAND


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _vis:
		_vis.queue_free()
	_vis = Node3D.new()
	add_child(_vis)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(rock_radius * 31.0) + style
	var items: Array = []
	for ring in 3:
		var r := rock_radius * (0.35 + ring * 0.3)
		var n := 6 + ring * 6
		for k in n:
			var a := TAU * k / n + rng.randf() * 0.4
			items.append([Vector3(cos(a) * r, 1.6 - ring * 0.7, sin(a) * r), rng.randf_range(2.2, 3.6) - ring * 0.3])
	Deco.rocks(_vis, items, rng.seed)
	var bands: Array
	match style:
		Style.ROT_WEISS:
			bands = [Color(0.85, 0.15, 0.12), Color(0.97, 0.97, 0.95), Color(0.85, 0.15, 0.12), Color(0.97, 0.97, 0.95), Color(0.85, 0.15, 0.12)]
		Style.SCHWARZ_WEISS:
			bands = [Color(0.12, 0.12, 0.13), Color(0.97, 0.97, 0.95), Color(0.12, 0.12, 0.13), Color(0.97, 0.97, 0.95)]
		Style.WEISS:
			bands = [Color(0.97, 0.97, 0.95)]
		Style.GRUEN_WEISS:
			bands = [Color(0.12, 0.5, 0.25), Color(0.97, 0.97, 0.95), Color(0.12, 0.5, 0.25)]
	var tower := Node3D.new()
	tower.position.y = 2.0
	_vis.add_child(tower)
	var lamp_y := Deco.tower(tower, bands, tower_height, 2.4, Color(1.0, 0.92, 0.6))
	ModelStyle.outline(tower)
	if rotating_beam:
		_beam = Deco.beam(tower, lamp_y, 120.0, Color(1.0, 0.92, 0.55))
	# Kartensymbol
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	SeaChart.add_triangle(st, Vector2(2.0, -2.0), Vector2(12.0, -12.5), Vector2(6.0, -2.6), 0.09)
	SeaChart.add_triangle(st, Vector2(2.0, -2.0), Vector2(2.6, -6.0), Vector2(12.0, -12.5), 0.09)
	_vis.add_child(SeaChart.mesh_from(st, Color(SeaChart.MAGENTA, 0.85)))
	var name_label := SeaChart.flat_label(tower_name, 56, SeaChart.INK, true)
	name_label.position = Vector3(0, 0.09, rock_radius + 9.0)
	_vis.add_child(name_label)
	var ch := SeaChart.flat_label(characteristic, 38, SeaChart.MAGENTA)
	ch.position = Vector3(rock_radius + 16.0, 0.09, -8.0)
	_vis.add_child(ch)
