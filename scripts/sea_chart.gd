@tool
class_name SeaChart
extends Node3D
## Die Seekarte im Stil von Karte 1 / INT 1:
## - Tiefenstufen: 0-2 m kräftig blau, 2-5 m hellblau, 5-10 m blassblau, tiefer weiß
## - Tiefenlinien (2, 5, 10, 20 m), trockenfallende Flächen grün, Land gelblich mit Uferlinie
## - Lotungen (Tiefenzahlen) und Kartennetz
##
## Die Tiefen kommen aus dem Level (Level.compute_depth). Sie sind zugleich die
## Spiellogik: Wo die Karte flacher als der Tiefgang ist, läuft man auf Grund.
## Tonnen, Untiefen-Symbole, Inseln und Kompassrosen zeichnen ihre Nodes selbst.

const AREA_MIN := Vector2(-640, -840)
const AREA_SIZE := 1280.0
const RES := 448
const DRAFT := 1.0      ## Tiefgang: flacher als das = Grundberührung
const HARD := 0.55      ## flacher als das = festgefahren
const LAND := -0.8      ## Uferlinie: darunter festes Land

const MAGENTA := Color(0.78, 0.12, 0.55)
const INK := Color(0.08, 0.08, 0.1)

static var _depth := PackedFloat32Array()
static var _res := 0
static var _fonts := {}

var material: ShaderMaterial
var soundings := true
var _depth_tex: ImageTexture
var _soundings_root: Node3D


# ---------------------------------------------------------------- Tiefen (global)

## Setzt das aktuelle Tiefenraster (vom Level berechnet)
static func set_depth_grid(grid: PackedFloat32Array, res: int) -> void:
	_depth = grid
	_res = res


## Wassertiefe an einer Position (negativ = Land)
static func depth_at(p: Vector2) -> float:
	if _res == 0:
		return 20.0
	var f := (p - AREA_MIN) / AREA_SIZE * _res - Vector2(0.5, 0.5)
	if f.x < 0.0 or f.y < 0.0 or f.x >= _res - 1 or f.y >= _res - 1:
		return 20.0
	var i := int(f.x)
	var j := int(f.y)
	var fx := f.x - i
	var fy := f.y - j
	var a := lerpf(_depth[j * _res + i], _depth[j * _res + i + 1], fx)
	var b := lerpf(_depth[(j + 1) * _res + i], _depth[(j + 1) * _res + i + 1], fx)
	return lerpf(a, b, fy)


static func depth_color(d: float) -> Color:
	if d < LAND:
		return Color(0.96, 0.87, 0.62)
	if d < 0.0:
		return Color(0.72, 0.82, 0.58)
	if d < 2.0:
		return Color(0.55, 0.76, 0.9)
	if d < 5.0:
		return Color(0.74, 0.87, 0.95)
	if d < 10.0:
		return Color(0.88, 0.94, 0.98)
	return Color(0.99, 0.99, 0.97)


## Kleines eingefärbtes Kartenbild für Minikarte und Menü
static func make_map_image(world_min: Vector2, world_max: Vector2, w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var p := world_min + (world_max - world_min) * Vector2((x + 0.5) / w, (y + 0.5) / h)
			img.set_pixel(x, y, depth_color(depth_at(p)))
	return img


## Nächster Punkt mit mindestens min_depth Wasser (für den Schlepper)
static func find_deep_water(from: Vector2, min_depth: float, max_radius := 200.0) -> Vector2:
	var r := 4.0
	while r <= max_radius:
		var best := Vector2.INF
		var best_d := -INF
		for k in 24:
			var a := TAU * k / 24.0
			var p := from + Vector2(cos(a), sin(a)) * r
			var d := depth_at(p)
			if d >= min_depth and d > best_d:
				best_d = d
				best = p
		if best != Vector2.INF:
			return best
		r += 4.0
	return from


## Ist die gerade Strecke a->b frei von Land?
static func path_clear(a: Vector2, b: Vector2) -> bool:
	var n := int(a.distance_to(b) / 4.0) + 1
	for k in n + 1:
		if depth_at(a.lerp(b, float(k) / n)) < LAND + 0.3:
			return false
	return true


# ---------------------------------------------------------------- Schriften

## Serifenschrift wie auf der Karte (fällt auf die Standardschrift zurück)
static func font(italic := false, bold := false) -> Font:
	var key := "%s%s" % [italic, bold]
	if _fonts.has(key):
		return _fonts[key]
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Georgia", "Times New Roman", "DejaVu Serif", "Liberation Serif", "Noto Serif", "FreeSerif", "serif"])
	f.font_italic = italic
	f.font_weight = 700 if bold else 400
	_fonts[key] = f
	return f


## Flach auf dem Wasser liegende Beschriftung (Oberkante zeigt nach Norden)
static func flat_label(text: String, size: int, col: Color, italic := false, bold := false) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = font(italic, bold)
	l.font_size = size
	l.pixel_size = 0.035
	l.modulate = col
	l.outline_size = 0
	l.shaded = false
	l.double_sided = true
	l.rotation = Vector3(-PI / 2, 0, 0)
	return l


# ---------------------------------------------------------------- Linien-Geometrie

static func add_line(st: SurfaceTool, a: Vector2, b: Vector2, width: float, y: float) -> void:
	var dir := (b - a).normalized()
	var n := Vector2(-dir.y, dir.x) * width * 0.5
	var v := [a + n, b + n, b - n, a - n]
	for idx in [0, 1, 2, 0, 2, 3]:
		var q: Vector2 = v[idx]
		st.add_vertex(Vector3(q.x, y, q.y))


static func add_ring(st: SurfaceTool, c: Vector2, r: float, width: float, y: float, segments := 96, dashed := false) -> void:
	for k in segments:
		if dashed and k % 2 == 1:
			continue
		var a0 := TAU * k / segments
		var a1 := TAU * (k + 1) / segments
		add_line(st, c + Vector2(cos(a0), sin(a0)) * r, c + Vector2(cos(a1), sin(a1)) * r, width, y)


static func add_triangle(st: SurfaceTool, a: Vector2, b: Vector2, c: Vector2, y: float) -> void:
	for q in [a, b, c]:
		var v: Vector2 = q
		st.add_vertex(Vector3(v.x, y, v.y))


static func ink_material(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if col.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


static func mesh_from(st: SurfaceTool, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = ink_material(col)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


# ---------------------------------------------------------------- Kartensymbole (für die Level-Nodes)

## Kompassrose in Magenta, Mittelpunkt im Ursprung von parent
static func build_compass_rose(parent: Node3D, r: float) -> void:
	var c := Vector2.ZERO
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var y := 0.065
	add_ring(st, c, r, 0.35, y, 120)
	add_ring(st, c, r * 0.9, 0.25, y, 120)
	add_ring(st, c, r * 0.55, 0.2, y, 96)
	for deg in range(0, 360, 2):
		var b := deg_to_rad(float(deg))
		var dir := Vector2(sin(b), -cos(b))
		var len := 0.04 if deg % 10 != 0 else 0.1
		if deg % 30 == 0:
			len = 0.14
		add_line(st, c + dir * r * 0.9, c + dir * r * (0.9 + len), 0.18, y)
		if deg % 30 == 0 and deg != 0:
			var lab := flat_label(str(deg), 40, MAGENTA)
			lab.position = Vector3(dir.x * r * 0.76, y, dir.y * r * 0.76)
			lab.rotation = Vector3(-PI / 2, -b, 0)
			parent.add_child(lab)
	var n := Vector2(0, -1)
	var e := Vector2(1, 0)
	add_triangle(st, c + n * r * 0.88, c + e * r * 0.07, c - e * r * 0.07, y)
	add_triangle(st, c - n * r * 0.4, c + e * r * 0.05, c - e * r * 0.05, y)
	add_line(st, c - e * r * 0.4, c + e * r * 0.4, 0.25, y)
	var star := flat_label("★", 64, MAGENTA)
	star.position = Vector3(0, y, -r * 0.98)
	parent.add_child(star)
	parent.add_child(mesh_from(st, MAGENTA))


## Leuchtturm mit Feuersymbol und Kennung, im Ursprung von parent
static func build_lighthouse(parent: Node3D, characteristic: String) -> void:
	for k in 4:
		var seg := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 1.6 - k * 0.25
		cyl.bottom_radius = 1.85 - k * 0.25
		cyl.height = 2.5
		seg.mesh = cyl
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.85, 0.15, 0.12) if k % 2 == 0 else Color(0.97, 0.97, 0.95)
		seg.material_override = m
		seg.position.y = 1.25 + k * 2.5
		parent.add_child(seg)
	var lamp := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 1.0
	sph.height = 1.6
	lamp.mesh = sph
	var lm := StandardMaterial3D.new()
	lm.albedo_color = Color(1.0, 0.95, 0.6)
	lm.emission_enabled = true
	lm.emission = Color(1.0, 0.9, 0.4)
	lamp.material_override = lm
	lamp.position.y = 10.8
	parent.add_child(lamp)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var p := Vector2.ZERO
	add_triangle(st, p + Vector2(1.5, -1.5), p + Vector2(9.0, -9.5), p + Vector2(4.5, -2.0), 0.08)
	add_triangle(st, p + Vector2(1.5, -1.5), p + Vector2(2.0, -4.5), p + Vector2(9.0, -9.5), 0.08)
	parent.add_child(mesh_from(st, Color(MAGENTA, 0.85)))
	var ch := flat_label(characteristic, 40, MAGENTA)
	ch.position = Vector3(18.0, 0.08, -10.0)
	parent.add_child(ch)


# ---------------------------------------------------------------- Aufbau

func _ready() -> void:
	_build_ground()
	refresh()


## Nach einer Änderung der Tiefen neu zeichnen
func refresh() -> void:
	if _res == 0:
		return
	var img := Image.create_from_data(_res, _res, false, Image.FORMAT_RF, _depth.to_byte_array())
	if _depth_tex and _depth_tex.get_width() == _res:
		_depth_tex.update(img)
	else:
		_depth_tex = ImageTexture.create_from_image(img)
		material.set_shader_parameter("depth_tex", _depth_tex)
	if soundings:
		_build_soundings()


func set_gust_texture(tex: Texture2D, gmin: Vector2, gsize: float) -> void:
	material.set_shader_parameter("gust_tex", tex)
	material.set_shader_parameter("gust_min", gmin)
	material.set_shader_parameter("gust_size", gsize)


func set_wind(blow: Vector2) -> void:
	material.set_shader_parameter("wind_blow", blow)


## Live-Vorschau beim Malen (Differenz zum Stand bei Strichbeginn)
func set_paint_delta(tex: Texture2D) -> void:
	material.set_shader_parameter("paint_delta", tex)
	material.set_shader_parameter("use_paint_delta", tex != null)


func _build_ground() -> void:
	var shader := Shader.new()
	shader.code = CHART_SHADER
	material = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("area_min", AREA_MIN)
	material.set_shader_parameter("area_size", AREA_SIZE)
	var plane := PlaneMesh.new()
	plane.size = Vector2(4000, 4000)
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _build_soundings() -> void:
	if _soundings_root:
		_soundings_root.queue_free()
	_soundings_root = Node3D.new()
	add_child(_soundings_root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var spacing := 38.0
	var x := -440.0
	while x <= 440.0:
		var z := -640.0
		while z <= 240.0:
			var p := Vector2(x, z) + Vector2(rng.randf_range(-12, 12), rng.randf_range(-12, 12))
			z += spacing
			var d := depth_at(p)
			if d < 0.3:
				continue
			var whole := int(d)
			var root := Node3D.new()
			root.position = Vector3(p.x, 0.06, p.y)
			_soundings_root.add_child(root)
			root.add_child(flat_label(str(whole), 44, Color(INK, 0.85)))
			if d < 10.0:
				var dec := flat_label(str(int((d - whole) * 10.0)), 30, Color(INK, 0.85))
				dec.position = Vector3(0.75 if whole < 10 else 1.3, 0.0, 0.55)
				root.add_child(dec)
		x += spacing


const CHART_SHADER := """
shader_type spatial;
render_mode unshaded;

uniform sampler2D depth_tex : filter_linear, repeat_disable;
uniform vec2 area_min;
uniform float area_size;
uniform sampler2D gust_tex : filter_linear, repeat_disable, hint_default_black;
uniform vec2 gust_min;
uniform float gust_size = 1.0;
uniform vec2 wind_blow = vec2(0.0, 1.0);
uniform sampler2D paint_delta : filter_linear, repeat_disable;
uniform bool use_paint_delta = false;
uniform float paint_step = 0.15;

uniform vec3 c_land : source_color = vec3(0.96, 0.87, 0.62);
uniform vec3 c_dry : source_color = vec3(0.72, 0.82, 0.58);
uniform vec3 c_d2 : source_color = vec3(0.55, 0.76, 0.9);
uniform vec3 c_d5 : source_color = vec3(0.74, 0.87, 0.95);
uniform vec3 c_d10 : source_color = vec3(0.88, 0.94, 0.98);
uniform vec3 c_deep : source_color = vec3(0.99, 0.99, 0.97);
uniform vec3 c_contour : source_color = vec3(0.22, 0.38, 0.55);
uniform vec3 c_ink : source_color = vec3(0.08, 0.08, 0.1);
uniform vec3 c_grid : source_color = vec3(0.45, 0.5, 0.55);
uniform vec3 c_gust : source_color = vec3(0.16, 0.3, 0.5);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float iso(float d, float level, float width) {
	float fw = max(fwidth(d), 1e-4);
	return 1.0 - smoothstep(0.0, width, abs(d - level) / fw);
}

void fragment() {
	vec2 p = wpos.xz;
	vec2 uv = (p - area_min) / area_size;
	float d = texture(depth_tex, clamp(uv, vec2(0.001), vec2(0.999))).r;
	float outside = step(1.0, max(max(-uv.x, uv.x - 1.0), max(-uv.y, uv.y - 1.0)) + 1.0);
	if (use_paint_delta) {
		d += (texture(paint_delta, clamp(uv, vec2(0.0), vec2(1.0))).r * 255.0 - 128.0) * paint_step;
	}
	d = mix(d, 20.0, outside);

	vec3 col = c_deep;
	if (d < 10.0) col = c_d10;
	if (d < 5.0) col = c_d5;
	if (d < 2.0) col = c_d2;
	if (d < 0.0) col = c_dry;
	if (d < -0.8) col = c_land;

	// Kartennetz alle 100 m
	vec2 g = abs(fract(p / 100.0 + 0.5) - 0.5) * 100.0;
	vec2 gw = max(fwidth(p), vec2(1e-4));
	float grid = 1.0 - smoothstep(0.4, 1.2, min(g.x / gw.x, g.y / gw.y));
	if (d > -0.8) col = mix(col, c_grid, grid * 0.45);

	// Böen als Riffel-Schraffur quer zum Wind
	vec2 guv = (p - gust_min) / gust_size;
	float gust = texture(gust_tex, clamp(guv, vec2(0.0), vec2(1.0))).r;
	if (d > 0.0) {
		float s = dot(p, wind_blow) / 3.2;
		float a = abs(fract(s + 0.5) - 0.5) / max(fwidth(s), 1e-4);
		float hatch = 1.0 - smoothstep(0.5, 1.4, a);
		float along = dot(p, vec2(-wind_blow.y, wind_blow.x));
		float dash = step(0.6, fract(along / 7.0 + floor(s) * 0.37));
		col = mix(col, c_gust, hatch * dash * gust * 0.45);
	}

	// Tiefenlinien
	float c = max(max(iso(d, 2.0, 1.0), iso(d, 5.0, 1.0)), max(iso(d, 10.0, 1.0), iso(d, 20.0, 1.0)));
	col = mix(col, c_contour, c * 0.8);
	col = mix(col, c_contour, iso(d, 0.0, 0.9) * 0.6);
	col = mix(col, c_ink, iso(d, -0.8, 1.7));

	ALBEDO = col;
}
"""
