@tool
@icon("res://addons/regatta_editor/icons/mole.svg")
class_name Mole
extends Node3D
## Felsmole / Wellenbrecher entlang der lokalen X-Achse (von -Länge/2 bis +Länge/2).
## Für Boote ist sie Land. Am Kopf (+X-Ende) optional ein Molenfeuer (rot/grün/weiß).
## Mit Drehen ausrichten, mehrere Molen ergeben eine Hafeneinfahrt.

enum HeadLight { KEINES, ROT, GRUEN, WEISS }

@export_range(20.0, 500.0, 1.0, "suffix:m") var length := 120.0:
	set(v):
		length = v
		_changed()
@export_range(4.0, 30.0, 0.5, "suffix:m") var width := 9.0:
	set(v):
		width = v
		_changed()
@export var head_light := HeadLight.ROT:
	set(v):
		head_light = v
		_rebuild()
@export var light_characteristic := "":
	set(v):
		light_characteristic = v
		_rebuild()

var _vis: Node3D
var _inv := Transform3D.IDENTITY


func _ready() -> void:
	set_notify_transform(true)
	_rebuild()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		_notify_level()


func _changed() -> void:
	_rebuild()
	_notify_level()


func _notify_level() -> void:
	if Engine.is_editor_hint() and is_inside_tree():
		var lvl := get_parent() as Level
		if lvl:
			lvl.queue_preview()


func pos2d() -> Vector2:
	return Vector2(global_position.x, global_position.z)


func reach() -> float:
	_inv = global_transform.affine_inverse()
	return length * 0.5 + width + 25.0


## Wassertiefe: auf der Mole Land, daneben steiler Steinfuß
func depth_profile(p: Vector2) -> float:
	var l := _inv * Vector3(p.x, 0, p.y)
	var x := clampf(l.x, -length * 0.5, length * 0.5)
	var d := Vector2(l.x - x, l.z).length() - width * 0.5
	if d <= 0.0:
		return SeaChart.LAND - 2.0
	return SeaChart.LAND - 2.0 + d * 1.6


func light_text() -> String:
	if light_characteristic != "":
		return light_characteristic
	match head_light:
		HeadLight.ROT: return "Fl.R.4s"
		HeadLight.GRUEN: return "Fl.G.4s"
		HeadLight.WEISS: return "Oc.6s"
	return ""


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _vis:
		_vis.queue_free()
	_vis = Node3D.new()
	add_child(_vis)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(length * 17.0 + width * 3.0)
	var items: Array = []
	var x := -length * 0.5
	while x <= length * 0.5:
		for side in [-1.0, 1.0]:
			var z: float = side * width * rng.randf_range(0.3, 0.55)
			items.append([Vector3(x + rng.randf_range(-1.0, 1.0), rng.randf_range(0.2, 0.8), z), rng.randf_range(1.6, 2.8)])
		items.append([Vector3(x, 1.0, rng.randf_range(-0.8, 0.8)), rng.randf_range(1.4, 2.0)])
		x += 2.6
	# runder Molenkopf
	for k in 10:
		var a := TAU * k / 10.0
		items.append([Vector3(length * 0.5 + cos(a) * width * 0.5, 0.5, sin(a) * width * 0.5), rng.randf_range(2.0, 3.0)])
	Deco.rocks(_vis, items, rng.seed)
	# Betonkrone als Weg
	var crown := MeshInstance3D.new()
	var cb := BoxMesh.new()
	cb.size = Vector3(length, 0.6, width * 0.35)
	crown.mesh = cb
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.74, 0.73, 0.7)
	crown.material_override = cm
	crown.position.y = 1.9
	crown.material_overlay = ModelStyle.outline_material()
	_vis.add_child(crown)

	if head_light != HeadLight.KEINES:
		var col := Color(0.85, 0.15, 0.12)
		var lamp := Color(1.0, 0.3, 0.25)
		match head_light:
			HeadLight.GRUEN:
				col = Color(0.12, 0.55, 0.25)
				lamp = Color(0.4, 1.0, 0.5)
			HeadLight.WEISS:
				col = Color(0.95, 0.95, 0.92)
				lamp = Color(1.0, 0.95, 0.7)
		var head := Node3D.new()
		head.position = Vector3(length * 0.5, 2.2, 0)
		_vis.add_child(head)
		Deco.tower(head, [col, Color(0.95, 0.95, 0.92), col], 6.0, 1.2, lamp)
		ModelStyle.outline(head)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var p := Vector2(length * 0.5, 0)
		SeaChart.add_triangle(st, p + Vector2(1.2, -1.0), p + Vector2(7.0, -7.0), p + Vector2(3.6, -1.5), 0.09)
		SeaChart.add_triangle(st, p + Vector2(1.2, -1.0), p + Vector2(1.7, -3.8), p + Vector2(7.0, -7.0), 0.09)
		_vis.add_child(SeaChart.mesh_from(st, Color(SeaChart.MAGENTA, 0.8)))
		var lab := SeaChart.flat_label(light_text(), 36, SeaChart.MAGENTA)
		lab.position = Vector3(length * 0.5 + 10.0, 0.09, 6.0)
		_vis.add_child(lab)
