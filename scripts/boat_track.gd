class_name BoatTrack
extends MeshInstance3D
## Gestrichelte Kurslinie hinter dem Boot, wie mit Bleistift in die Karte geplottet.

const SPACING := 3.0
const MAX_POINTS := 160
const WIDTH := 0.35

var color := Color.RED
var _points := PackedVector2Array()
var _imesh := ImmediateMesh.new()


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	mesh = _imesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = m


func add_point(p: Vector2) -> void:
	if _points.size() > 0 and _points[_points.size() - 1].distance_to(p) < SPACING:
		return
	_points.append(p)
	if _points.size() > MAX_POINTS:
		_points.remove_at(0)
	_rebuild()


func _rebuild() -> void:
	_imesh.clear_surfaces()
	if _points.size() < 2:
		return
	_imesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := _points.size()
	for i in range(n - 1):
		if i % 2 == 1:
			continue  # Strichelung
		var a := _points[i]
		var b := _points[i + 1]
		var dir := (b - a).normalized()
		var nrm := Vector2(-dir.y, dir.x) * WIDTH * 0.5
		var c := Color(color, 0.55 * float(i + 1) / n)
		var quad := [a + nrm, b + nrm, b - nrm, a - nrm]
		for idx in [0, 1, 2, 0, 2, 3]:
			var q: Vector2 = quad[idx]
			_imesh.surface_set_color(c)
			_imesh.surface_add_vertex(Vector3(q.x, 0.09, q.y))
	_imesh.surface_end()
