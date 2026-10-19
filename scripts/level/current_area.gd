@tool
@icon("res://addons/regatta_editor/icons/current.svg")
class_name CurrentArea
extends Node3D
## Strömung in einem Rechteck (z. B. in einer Engstelle zwischen Inseln).
## Das Wasser fließt in Pfeilrichtung (lokal -Z). Zu den Rändern hin wird die
## Strömung weich schwächer. Mit Drehen ausrichten, Länge/Breite im Inspector.
## Auf der Karte: Strompfeile mit Geschwindigkeit, im Spiel fließende Schlieren.

@export_range(0.2, 5.0, 0.1, "suffix:kn") var speed_kn := 1.5:
	set(v):
		speed_kn = v
		_rebuild()
@export_range(20.0, 600.0, 5.0, "suffix:m") var length := 160.0:
	set(v):
		length = v
		_rebuild()
@export_range(10.0, 300.0, 5.0, "suffix:m") var width := 60.0:
	set(v):
		width = v
		_rebuild()
## Gezeitenstrom: kehrt mit dieser Periode die Richtung um (0 = konstant)
@export_range(0.0, 600.0, 10.0, "suffix:s") var tide_period := 0.0

var _vis: Node3D
var _streaks: MultiMesh
var _streak_pos := PackedVector2Array()   # lokal (x quer, y entlang)
var _inv := Transform3D.IDENTITY
var _dir := Vector2(0, -1)
var _time := 0.0


func _ready() -> void:
	set_notify_transform(true)
	_rebuild()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		prepare_current()


func pos2d() -> Vector2:
	return Vector2(global_position.x, global_position.z)


func prepare_current() -> void:
	if not is_inside_tree():
		return
	_inv = global_transform.affine_inverse()
	var f := -global_basis.z
	_dir = Vector2(f.x, f.z).normalized()


func _tide() -> float:
	if tide_period <= 0.0:
		return 1.0
	return sin(_time * TAU / tide_period)


## Strömung an Weltposition p (m/s)
func current_at(p: Vector2) -> Vector2:
	var l := _inv * Vector3(p.x, 0, p.y)
	var ax := absf(l.x) / (width * 0.5)
	var az := absf(l.z) / (length * 0.5)
	if ax >= 1.0 or az >= 1.0:
		return Vector2.ZERO
	var f := (1.0 - smoothstep(0.55, 1.0, ax)) * (1.0 - smoothstep(0.65, 1.0, az))
	return _dir * speed_kn / 1.944 * f * _tide()


func _process(delta: float) -> void:
	_time += delta
	if _streaks == null:
		return
	# Schlieren treiben mit dem Strom
	var v := speed_kn / 1.944 * _tide()
	for i in _streak_pos.size():
		var q := _streak_pos[i]
		q.y -= v * delta * (0.8 + 0.4 * fposmod(i * 0.618, 1.0))
		if q.y < -length * 0.5:
			q.y += length
		elif q.y > length * 0.5:
			q.y -= length
		_streak_pos[i] = q
		var f := (1.0 - smoothstep(0.55, 1.0, absf(q.x) / (width * 0.5))) * (1.0 - smoothstep(0.65, 1.0, absf(q.y) / (length * 0.5)))
		var t := Transform3D(Basis.from_scale(Vector3(1, 1, 2.0 + 3.0 * absf(v))), Vector3(q.x, 0.12, q.y))
		_streaks.set_instance_transform(i, t)
		_streaks.set_instance_color(i, Color(1, 1, 1, 0.55 * f))


func _rebuild() -> void:
	if not is_inside_tree():
		return
	prepare_current()
	if _vis:
		_vis.queue_free()
	_vis = Node3D.new()
	add_child(_vis)
	# Kartensymbol: Strompfeile (INT 1 H 40) mit Geschwindigkeit
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows := maxi(1, int(length / 90.0))
	var cols := maxi(1, int(width / 70.0))
	for r in rows:
		for c in cols:
			var x := (c + 0.5) / cols * width - width * 0.5
			var z := (r + 0.5) / rows * length - length * 0.5
			var a := Vector2(x, z + 14.0)
			var b := Vector2(x, z - 14.0)
			SeaChart.add_line(st, a, b, 0.8, 0.09)
			SeaChart.add_triangle(st, b + Vector2(-3.2, 4.0), b + Vector2(3.2, 4.0), b + Vector2(0, -3.0), 0.09)
			# Fiedern am Pfeilende
			SeaChart.add_line(st, a, a + Vector2(-2.5, 3.0), 0.6, 0.09)
			SeaChart.add_line(st, a + Vector2(0, -3.0), a + Vector2(-2.5, 0.0), 0.6, 0.09)
			var lab := SeaChart.flat_label("%.1f kn" % speed_kn, 40, SeaChart.INK, true)
			lab.position = Vector3(x + 9.0, 0.09, z)
			lab.rotation = Vector3(-PI / 2, 0, PI / 2)
			_vis.add_child(lab)
	_vis.add_child(SeaChart.mesh_from(st, Color(SeaChart.INK, 0.8)))
	# Schlieren
	var streak := BoxMesh.new()
	streak.size = Vector3(0.35, 0.02, 1.0)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	streak.material = m
	_streaks = MultiMesh.new()
	_streaks.transform_format = MultiMesh.TRANSFORM_3D
	_streaks.use_colors = true
	_streaks.mesh = streak
	var n := clampi(int(length * width / 260.0), 12, 260)
	_streaks.instance_count = n
	_streak_pos.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(length + width * 7.0)
	for i in n:
		_streak_pos[i] = Vector2(rng.randf_range(-0.5, 0.5) * width, rng.randf_range(-0.5, 0.5) * length)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = _streaks
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_vis.add_child(mmi)
	# Im Editor: Umriss
	if Engine.is_editor_hint():
		var o := SurfaceTool.new()
		o.begin(Mesh.PRIMITIVE_TRIANGLES)
		var hw := width * 0.5
		var hl := length * 0.5
		var pts := [Vector2(-hw, -hl), Vector2(hw, -hl), Vector2(hw, hl), Vector2(-hw, hl)]
		for k in 4:
			SeaChart.add_line(o, pts[k], pts[(k + 1) % 4], 0.6, 0.3)
		_vis.add_child(SeaChart.mesh_from(o, Color(0.1, 0.5, 0.9, 0.7)))
