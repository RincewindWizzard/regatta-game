class_name WindVisuals
extends Node3D
## Macht den Wind lesbar, im Stil der Karte:
## - kurze dunkle Striche zeigen die Windrichtung (länger/kräftiger = mehr Wind)
## - Böen erscheinen als Riffel-Schraffur auf der Karte (gezeichnet im Karten-Shader)

const SPACING := 16.0
const GUST_RES := 128

var area := Rect2(-300, -500, 600, 640)   ## Bereich mit Windstrichen (vom Level)
var _gust_min := Vector2(-400, -600)
var _gust_size := 800.0

var wind: WindField
var chart: SeaChart

var _mm: MultiMesh
var _cells := PackedVector2Array()
var _phase := PackedFloat32Array()
var _cell_wind := PackedVector2Array()
var _sample_idx := 0
var _gust_img: Image
var _gust_tex: ImageTexture
var _gust_timer := 0.0
var _time := 0.0


func _ready() -> void:
	var cols := int(area.size.x / SPACING)
	var rows := int(area.size.y / SPACING)
	_gust_size = maxf(area.size.x, area.size.y) + 200.0
	_gust_min = area.get_center() - Vector2.ONE * _gust_size * 0.5
	for j in rows:
		for i in cols:
			var jitter := Vector2(randf_range(-6, 6), randf_range(-6, 6))
			_cells.append(area.position + Vector2(i + 0.5, j + 0.5) * SPACING + jitter)
			_phase.append(randf())
	_cell_wind.resize(_cells.size())

	var streak := BoxMesh.new()
	streak.size = Vector3(0.16, 0.02, 1.0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	streak.material = mat
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	_mm.mesh = streak
	_mm.instance_count = _cells.size()
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = _mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	_sample_wind()

	_gust_img = Image.create(GUST_RES, GUST_RES, false, Image.FORMAT_R8)
	_update_gusts()
	_gust_tex = ImageTexture.create_from_image(_gust_img)
	chart.set_gust_texture(_gust_tex, _gust_min, _gust_size)


func _sample_wind() -> void:
	for k in _cells.size():
		_cell_wind[k] = wind.get_wind(_cells[k])


## Windfeld reihum in kleinen Portionen neu messen (der Landschatten ist teuer; so gibt es
## keine Ruckler). Ein voller Durchlauf dauert etwa 0,25 s.
func _sample_chunk() -> void:
	var n := _cells.size()
	var chunk := maxi(1, int(ceil(n / 15.0)))
	for k in chunk:
		var i := (_sample_idx + k) % n
		_cell_wind[i] = wind.get_wind(_cells[i])
	_sample_idx = (_sample_idx + chunk) % n


func _update_gusts() -> void:
	var step := _gust_size / GUST_RES
	for j in GUST_RES:
		for i in GUST_RES:
			var p := _gust_min + Vector2(i + 0.5, j + 0.5) * step
			var g := clampf((wind.gust_at(p) - 0.15) * 1.4, 0.0, 1.0)
			_gust_img.set_pixel(i, j, Color(g, 0, 0))


func _process(delta: float) -> void:
	if wind == null:
		return
	_time += delta
	chart.set_wind(wind.blow_dir())
	_sample_chunk()
	_gust_timer -= delta
	if _gust_timer <= 0.0:
		_gust_timer = 0.3
		_update_gusts()
		_gust_tex.update(_gust_img)

	for k in _cells.size():
		var w := _cell_wind[k]
		var spd := w.length()
		var bd := w / maxf(spd, 0.001)
		var cyc := fmod(_phase[k] + _time * spd * 0.12, 1.0)
		var p := _cells[k] + bd * (cyc - 0.5) * SPACING
		var length := 1.2 + spd * 0.4
		var basis := Basis(Vector3.UP, atan2(bd.x, bd.y)) * Basis.from_scale(Vector3(1, 1, length))
		_mm.set_instance_transform(k, Transform3D(basis, Vector3(p.x, 0.1, p.y)))
		var a := sin(cyc * PI) * clampf(0.2 + (spd - 4.0) * 0.1, 0.12, 0.6)
		_mm.set_instance_color(k, Color(0.12, 0.22, 0.38, a))
