@tool
@icon("res://addons/regatta_editor/icons/start.svg")
class_name StartLine
extends Node3D
## Start- und Ziellinie zwischen zwei Tonnen (entlang der lokalen X-Achse).
## Gestartet wird in Pfeilrichtung (lokal -Z), das Ziel ist dieselbe Linie in
## Gegenrichtung. Die Boote starten 30 m hinter der Linie. Drehen erlaubt.

@export_range(15.0, 150.0, 1.0, "suffix:m") var half_width := 45.0:
	set(v):
		half_width = v
		_rebuild()

var _vis: Node3D


func _ready() -> void:
	set_notify_transform(true)
	_rebuild()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint():
		var lvl := get_parent() as Level
		if lvl:
			lvl._update_wind_arrow()


func center2d() -> Vector2:
	return Vector2(global_position.x, global_position.z)


## Startrichtung (Einheitsvektor in der Wasserebene)
func normal2d() -> Vector2:
	var f := -global_basis.z
	return Vector2(f.x, f.z).normalized()


func tangent2d() -> Vector2:
	var x := global_basis.x
	return Vector2(x.x, x.z).normalized()


## > 0 = vor der Linie (Startrichtung), < 0 = dahinter
func signed_dist(p: Vector2) -> float:
	return (p - center2d()).dot(normal2d())


func within(p: Vector2) -> bool:
	return absf((p - center2d()).dot(tangent2d())) <= half_width


const START_OFFSETS := [-15.0, 15.0, -38.0, 38.0]


func start_position(i: int) -> Vector2:
	var off: float = START_OFFSETS[i % START_OFFSETS.size()] * minf(1.0, half_width / 45.0)
	return center2d() - normal2d() * (30.0 + 12.0 * (i / 4)) + tangent2d() * off


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _vis:
		_vis.queue_free()
	_vis = Node3D.new()
	add_child(_vis)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := maxi(6, int(half_width / 2.0))
	for i in n:
		var x0 := -half_width + i * (half_width * 2.0 / n)
		var x1 := x0 + half_width * 2.0 / n * 0.6
		SeaChart.add_line(st, Vector2(x0, 0), Vector2(x1, 0), 0.45, 0.085)
	for x in [-half_width, half_width]:
		SeaChart.add_ring(st, Vector2(x, 0), 1.6, 0.25, 0.085, 24)
	_vis.add_child(SeaChart.mesh_from(st, SeaChart.INK))
	# Pfeil für die Startrichtung
	var ar := SurfaceTool.new()
	ar.begin(Mesh.PRIMITIVE_TRIANGLES)
	SeaChart.add_line(ar, Vector2(0, 14), Vector2(0, 4), 0.6, 0.085)
	SeaChart.add_triangle(ar, Vector2(-2.2, 4.5), Vector2(2.2, 4.5), Vector2(0, 1.0), 0.085)
	_vis.add_child(SeaChart.mesh_from(ar, Color(SeaChart.MAGENTA, 0.8)))

	for x in [-half_width, half_width]:
		var bob := Node3D.new()
		bob.position = Vector3(x, 0, 0)
		_vis.add_child(bob)
		var ball := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 1.1
		sph.height = 2.0
		ball.mesh = sph
		var ym := StandardMaterial3D.new()
		ym.albedo_color = CourseMark.YELLOW
		ball.material_override = ym
		ball.position.y = 0.6
		bob.add_child(ball)
		var flag := MeshInstance3D.new()
		var fb := BoxMesh.new()
		fb.size = Vector3(0.05, 0.6, 0.9)
		flag.mesh = fb
		var fm := StandardMaterial3D.new()
		fm.albedo_color = Color(0.85, 0.15, 0.1)
		flag.material_override = fm
		flag.position = Vector3(0, 2.4, 0.45)
		bob.add_child(flag)
		var pole := MeshInstance3D.new()
		var pc := CylinderMesh.new()
		pc.top_radius = 0.05
		pc.bottom_radius = 0.05
		pc.height = 1.6
		pole.mesh = pc
		pole.position.y = 1.9
		bob.add_child(pole)
		ModelStyle.outline(bob)
	var label := SeaChart.flat_label("START / ZIEL", 64, SeaChart.INK, false, true)
	label.position = Vector3(-22, 0.09, 7.0)
	_vis.add_child(label)
