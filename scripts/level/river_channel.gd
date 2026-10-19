@tool
@icon("res://addons/regatta_editor/icons/river.svg")
class_name RiverChannel
extends Path3D
## Flusslauf für Binnenreviere. Die Kurve zeichnet man im Editor mit Godots
## Pfad-Werkzeug (Punkte setzen/ziehen in der 3D-Ansicht, Num 7 = Draufsicht).
## Der Fluss gräbt Wasser aus und hat eine Strömung vom ersten zum letzten Punkt.
## Wo er schmaler ist (width_curve), fließt er schneller – wie in echt.

@export_range(15.0, 200.0, 1.0, "suffix:m") var width := 70.0:
	set(v):
		width = v
		_changed()
## Breite entlang des Flusses (0..1 = Anfang..Ende), Faktor auf width. Leer = gleich breit.
@export var width_curve: Curve:
	set(v):
		width_curve = v
		_changed()
@export_range(1.5, 20.0, 0.5, "suffix:m") var depth := 6.0:
	set(v):
		depth = v
		_changed()
## Fließgeschwindigkeit bei normaler Breite (0 = stehendes Gewässer, z. B. Kanal)
@export_range(0.0, 4.0, 0.1, "suffix:kn") var flow_kn := 1.2:
	set(v):
		flow_kn = v
		_changed()
@export var river_name := "":
	set(v):
		river_name = v
		_changed()
@export_range(0, 200) var bank_trees := 40:
	set(v):
		bank_trees = v
		_changed()

var _pts := PackedVector2Array()     # Mittellinie (Welt, x/z)
var _w := PackedFloat32Array()       # Breite je Punkt
var _cum := PackedFloat32Array()     # Lauflänge je Punkt
var _tree_info: Array[Dictionary] = []   # Uferbäume: Knoten, Mittelpunkt, Richtung nach außen
var _vis: Node3D
var _streaks: MultiMesh
var _streak_s := PackedFloat32Array()
var _streak_o := PackedFloat32Array()


func _ready() -> void:
	set_notify_transform(true)
	if curve and not curve.changed.is_connected(_changed):
		curve.changed.connect(_changed)
	_changed()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		_changed()


func _changed() -> void:
	if not is_inside_tree():
		return
	if curve and not curve.changed.is_connected(_changed):
		curve.changed.connect(_changed)
	prepare_current()
	_rebuild()
	if Engine.is_editor_hint():
		var lvl := get_parent() as Level
		if lvl:
			lvl.queue_preview()


func carves() -> bool:
	return true


func pos2d() -> Vector2:
	return Vector2(global_position.x, global_position.z)


func prepare_current() -> void:
	_pts = PackedVector2Array()
	_w = PackedFloat32Array()
	_cum = PackedFloat32Array()
	if curve == null or curve.point_count < 2:
		return
	var baked := curve.get_baked_points()
	var total := 0.0
	var prev := Vector2.INF
	for i in baked.size():
		var g := global_transform * baked[i]
		var q := Vector2(g.x, g.z)
		if prev != Vector2.INF:
			if q.distance_to(prev) < 4.0 and i < baked.size() - 1:
				continue
			total += q.distance_to(prev)
		_pts.append(q)
		_cum.append(total)
		prev = q
	for i in _pts.size():
		var t := _cum[i] / maxf(total, 1.0)
		var f := width_curve.sample(t) if width_curve else 1.0
		_w.append(maxf(8.0, width * f))


## nächstgelegener Punkt der Mittellinie: [Abstand, Index, Anteil im Segment]
func _nearest(p: Vector2) -> Array:
	var best := INF
	var bi := 0
	var bt := 0.0
	for i in _pts.size() - 1:
		var a := _pts[i]
		var b := _pts[i + 1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		var d := p.distance_squared_to(a + ab * t)
		if d < best:
			best = d
			bi = i
			bt = t
	return [sqrt(best), bi, bt]


func current_at(p: Vector2) -> Vector2:
	if _pts.size() < 2 or flow_kn <= 0.0:
		return Vector2.ZERO
	var n := _nearest(p)
	var i: int = n[1]
	var w := lerpf(_w[i], _w[i + 1], n[2])
	var k: float = n[0] / (w * 0.5)
	if k >= 1.0:
		return Vector2.ZERO
	var dir := (_pts[i + 1] - _pts[i]).normalized()
	# Kontinuität: schmal = schnell; Strommitte schneller als am Ufer
	return dir * flow_kn / 1.944 * (width / w) * (1.0 - k * k) * 1.3


## Wasser ausgraben: Segment für Segment, nur Zellen in der Nähe
func carve_grid(grid: PackedFloat32Array, res: int) -> void:
	if _pts.size() < 2:
		prepare_current()
	if _pts.size() < 2:
		return
	var step := SeaChart.AREA_SIZE / res
	var amin := SeaChart.AREA_MIN
	var warp := FastNoiseLite.new()
	warp.seed = int(width) + _pts.size()
	warp.frequency = 0.025
	for i in _pts.size() - 1:
		var a := _pts[i]
		var b := _pts[i + 1]
		var hw := maxf(_w[i], _w[i + 1]) * 0.5 + 6.0
		var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(hw, hw)
		var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2(hw, hw)
		var i0 := clampi(int((lo.x - amin.x) / step), 0, res - 1)
		var i1 := clampi(int((hi.x - amin.x) / step) + 1, 0, res - 1)
		var j0 := clampi(int((lo.y - amin.y) / step), 0, res - 1)
		var j1 := clampi(int((hi.y - amin.y) / step) + 1, 0, res - 1)
		var ab := b - a
		var len2 := maxf(ab.length_squared(), 0.001)
		for j in range(j0, j1 + 1):
			for ii in range(i0, i1 + 1):
				var p := amin + Vector2(ii + 0.5, j + 0.5) * step
				var t := clampf((p - a).dot(ab) / len2, 0.0, 1.0)
				var d := p.distance_to(a + ab * t) + warp.get_noise_2dv(p) * 4.0
				var w := lerpf(_w[i], _w[i + 1], t) * 0.5
				var k := d / w
				if k < 1.15:
					var depth_here := depth * (1.0 - k * k * k * k) + SeaChart.LAND * smoothstep(0.9, 1.15, k)
					var idx := j * res + ii
					grid[idx] = maxf(grid[idx], depth_here)


## Uferbäume auf festes Land setzen: von der Flussmitte nach außen laufen, bis Land
## kommt (Seen, Mündungen und Biegungen machen das Ufer unregelmäßig). Braucht die
## fertige Tiefenkarte, deshalb erst beim Start des Rennens.
func prune_trees() -> void:
	if _vis == null:
		prepare_current()
		_rebuild()
	for info in _tree_info:
		var t: Node3D = info["node"]
		var placed := false
		var off := 6.0
		while off < 220.0:
			var q: Vector2 = info["center"] + info["side"] * off
			if SeaChart.depth_at(q) < SeaChart.LAND - 1.5:
				var q2: Vector2 = q + info["side"] * float(info["extra"])
				if SeaChart.depth_at(q2) < SeaChart.LAND - 1.5:
					q = q2
				t.position = Vector3(q.x, 0, q.y)
				placed = true
				break
			off += 5.0
		if not placed:
			t.queue_free()
	_tree_info.clear()


func _rebuild() -> void:
	_tree_info.clear()
	if _vis:
		_vis.queue_free()
		_vis = null
	if _pts.size() < 2:
		return
	_vis = Node3D.new()
	_vis.top_level = true
	add_child(_vis)
	var rng := RandomNumberGenerator.new()
	rng.seed = _pts.size() * 31 + int(width)
	# Bäume am Ufer
	for k in bank_trees:
		var i := rng.randi_range(0, _pts.size() - 2)
		var dir := (_pts[i + 1] - _pts[i]).normalized()
		var side := Vector2(-dir.y, dir.x) * (1.0 if rng.randf() < 0.5 else -1.0)
		var q := _pts[i] + side * (_w[i] * 0.5 + rng.randf_range(12.0, 34.0))
		Deco.tree(_vis, Vector3(q.x, 0, q.y), rng)
		_tree_info.append({"node": _vis.get_child(_vis.get_child_count() - 1), "center": _pts[i],
			"side": side, "extra": rng.randf_range(2.0, 25.0)})
	# Strompfeile und Name
	if flow_kn > 0.0:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var every := 130.0
		var next := every * 0.5
		for i in _pts.size() - 1:
			if _cum[i] >= next:
				next += every
				var dir := (_pts[i + 1] - _pts[i]).normalized()
				var c := _pts[i]
				SeaChart.add_line(st, c - dir * 12.0, c + dir * 12.0, 0.8, 0.09)
				var tip := c + dir * 15.0
				var nrm := Vector2(-dir.y, dir.x)
				SeaChart.add_triangle(st, tip, c + dir * 10.0 + nrm * 3.0, c + dir * 10.0 - nrm * 3.0, 0.09)
				var lab := SeaChart.flat_label("%.1f kn" % (flow_kn * width / _w[i]), 38, SeaChart.INK, true)
				lab.position = Vector3(c.x + nrm.x * 9.0, 0.09, c.y + nrm.y * 9.0)
				lab.rotation = Vector3(-PI / 2, -atan2(dir.y, dir.x), 0)
				_vis.add_child(lab)
		_vis.add_child(SeaChart.mesh_from(st, Color(SeaChart.INK, 0.8)))
	if river_name != "":
		var mid := _pts.size() / 2
		var dir := (_pts[mid + 1] - _pts[mid]).normalized() if mid + 1 < _pts.size() else Vector2.RIGHT
		var lab := SeaChart.flat_label(river_name, 90, Color(0.15, 0.25, 0.45), true)
		lab.position = Vector3(_pts[mid].x, 0.09, _pts[mid].y)
		var ang := atan2(dir.y, dir.x)
		if absf(ang) > PI * 0.5:
			ang += PI
		lab.rotation = Vector3(-PI / 2, -ang, 0)
		_vis.add_child(lab)
	# fließende Schlieren
	if flow_kn > 0.0:
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
		var total := _cum[_cum.size() - 1]
		var n := clampi(int(total * width / 300.0), 20, 400)
		_streaks.instance_count = n
		_streak_s.resize(n)
		_streak_o.resize(n)
		for k in n:
			_streak_s[k] = rng.randf() * total
			_streak_o[k] = rng.randf_range(-0.42, 0.42)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = _streaks
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_vis.add_child(mmi)
	else:
		_streaks = null


func _process(delta: float) -> void:
	if _streaks == null or _pts.size() < 2:
		return
	var total := _cum[_cum.size() - 1]
	var i := 0
	for k in _streak_s.size():
		var s := _streak_s[k]
		# Punkt zur Lauflänge s finden (Schlieren sind nicht sortiert -> einfache Suche)
		i = clampi(int(s / maxf(total, 1.0) * (_pts.size() - 1)), 0, _pts.size() - 2)
		while i > 0 and _cum[i] > s:
			i -= 1
		while i < _pts.size() - 2 and _cum[i + 1] < s:
			i += 1
		var seg := maxf(_cum[i + 1] - _cum[i], 0.01)
		var t := clampf((s - _cum[i]) / seg, 0.0, 1.0)
		var dir := (_pts[i + 1] - _pts[i]) / seg
		var w := lerpf(_w[i], _w[i + 1], t)
		var nrm := Vector2(-dir.y, dir.x)
		var q := _pts[i].lerp(_pts[i + 1], t) + nrm * _streak_o[k] * w
		var v := flow_kn / 1.944 * (width / w) * (1.0 - 4.0 * _streak_o[k] * _streak_o[k])
		s += v * delta
		if s > total:
			s -= total
		_streak_s[k] = s
		var fade := sin(PI * fposmod(s / 60.0, 1.0))
		var basis := Basis(Vector3.UP, atan2(dir.x, dir.y)) * Basis.from_scale(Vector3(1, 1, 2.0 + 2.5 * v))
		_streaks.set_instance_transform(k, Transform3D(basis, Vector3(q.x, 0.12, q.y)))
		_streaks.set_instance_color(k, Color(1, 1, 1, 0.5 * fade))
