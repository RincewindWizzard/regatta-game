@tool
@icon("res://addons/regatta_editor/icons/level.svg")
class_name Level
extends Node3D
## Wurzel einer Regattabahn. Alles Weitere sind Kinder-Nodes, die man im Editor
## verschiebt:
##   StartLine   – Start- und Ziellinie (Start in Pfeilrichtung, Ziel zurück)
##   CourseMark  – Bahnmarken; die Reihenfolge im Szenenbaum ist die Rundungsreihenfolge
##   ShoalArea   – Untiefe oder Insel (Größe/Form auch über Skalieren und Drehen)
##   SeaMark     – Seezeichen: Kardinal-, Einzelgefahr-, Fahrwasser-, Ansteuerungstonne
##   Mole        – Felsmole mit Molenfeuer
##   Lighthouse  – Leuchtturm auf einer Felsklippe
##   ChartRose   – Kompassrose als Dekoration
##   CurrentArea – Strömung (z. B. in Engstellen)
##   RiverChannel – Flusslauf (Path3D: Kurve im Editor zeichnen), mit Strömung
##   FuelDock    – Tankstelle: Steg mit Zapfsäule, dort im Stillstand tanken
##   SeaLife     – Tümmler, Wale, Möwen, Seehunde und Wracks als Dekoration
##   RestrictedArea – Sperrgebiet: Minenfeld (Boot explodiert) oder Polizeikontrolle
##   SirenIsland – Insel, deren Gesang vorbeisegelnde Boote festhält
## Binnenrevier: "inland" einschalten – dann ist alles Land, und Flüsse sowie
## Seen (ShoalArea, Art „See“) graben das Wasser aus.
## Das Regattagebiet (magenta Grenze) umschließt die Bahn mit dem Abstand area_margin.
## Den Seegrund kann man zusätzlich mit dem Pinsel malen (Werkzeugleiste "Seegrund"
## oben im 3D-Editor, sobald das Level ausgewählt ist).

const PAINT_RES := 256
const PAINT_STEP := 0.15        ## Meter pro Graustufe im Malbild
const PREVIEW_RES := 256        ## Auflösung der Editor-Vorschau

@export var level_name := "Neue Bahn"
@export_multiline var description := ""

@export_group("Wind")
## Richtung, aus der der Wind kommt (0 = Nord, 90 = Ost)
@export_range(0, 359, 1, "degrees") var wind_from_deg := 0.0:
	set(v):
		wind_from_deg = v
		_update_wind_arrow()
@export_range(2.0, 12.0, 0.5, "suffix:m/s") var wind_speed := 6.0
@export_range(0, 40, 1, "degrees") var wind_shift_deg := 17.0
@export_range(0.0, 1.5, 0.05) var gusts := 0.9

@export_group("Motor")
## Tankfüllung beim Start (Liter, Tank fasst 20 l). 0 = ohne Motor.
@export_range(0.0, 20.0, 0.5, "suffix:l") var fuel_liters := 6.0

@export_group("Regattagebiet")
## Abstand der Gebietsgrenze zur Bahn (Start, Tonnen)
@export_range(80.0, 450.0, 5.0, "suffix:m") var area_margin := 200.0:
	set(v):
		area_margin = v
		_update_wind_arrow()

@export_group("Seegrund")
@export_range(3.0, 40.0, 0.5, "suffix:m") var base_depth := 14.0:
	set(v):
		base_depth = v
		_base_cache.clear()
		queue_preview()
@export_range(0.0, 20.0, 0.5, "suffix:m") var depth_variation := 9.0:
	set(v):
		depth_variation = v
		_base_cache.clear()
		queue_preview()
@export var seabed_seed := 4711:
	set(v):
		seabed_seed = v
		_base_cache.clear()
		queue_preview()
## Binnenrevier: Grundfläche ist Land, Wasser kommt nur aus Flüssen und Seen
@export var inland := false:
	set(v):
		inland = v
		_base_cache.clear()
		queue_preview()
@export var coast_east := true:
	set(v):
		coast_east = v
		queue_preview()
@export var coast_west := true:
	set(v):
		coast_west = v
		queue_preview()
## Gemalter Seegrund (PNG, Graustufe 128 = unverändert). Wird vom Pinsel geschrieben.
@export_storage var depth_paint_png := PackedByteArray():
	set(v):
		depth_paint_png = v
		_paint_img = null
		queue_preview()

var _paint_img: Image
var _stroke_start: Image
var _delta_img: Image
var _delta_tex: ImageTexture
var _base_cache := {}
var _preview: SeaChart
var _wind_arrow: Node3D
var _dirty := false
var _dirty_timer := 0.0
var _border: Node3D


func _ready() -> void:
	_update_border()
	if Engine.is_editor_hint():
		_preview = SeaChart.new()
		_preview.soundings = true
		add_child(_preview)
		_build_wind_arrow()
		_recompute(PREVIEW_RES)
		set_process(true)


func _process(delta: float) -> void:
	if not Engine.is_editor_hint() or not _dirty:
		return
	_dirty_timer -= delta
	if _dirty_timer <= 0.0:
		_dirty = false
		_recompute(PREVIEW_RES)


## Im Editor: Karte nach einer Änderung kurz verzögert neu berechnen
func queue_preview() -> void:
	if Engine.is_editor_hint() and is_inside_tree():
		_dirty = true
		_dirty_timer = 0.15


func _recompute(res: int) -> void:
	SeaChart.set_depth_grid(compute_depth(res), res)
	if _preview:
		_preview.refresh()


## Für das Spiel: Tiefen in voller Auflösung berechnen und global setzen
func prepare_for_game() -> void:
	SeaChart.set_depth_grid(compute_depth(SeaChart.RES), SeaChart.RES)


# ---------------------------------------------------------------- Bahn auslesen

func start_line() -> StartLine:
	for c in get_children():
		if c is StartLine:
			return c
	return null


func marks() -> Array[CourseMark]:
	var out: Array[CourseMark] = []
	for c in get_children():
		if c is CourseMark:
			out.append(c)
	return out


## Alles, was den Seegrund flacher macht (Untiefen, Inseln, Molen, Leuchtturmklippen)
func obstacles() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for c in get_children():
		if c.has_method("depth_profile") and not (c.has_method("carves") and c.carves()):
			out.append(c)
	return out


## Alles, was Wasser ausgräbt (Flüsse, Seen)
func carvers() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for c in get_children():
		if c.has_method("carves") and c.carves():
			out.append(c)
	return out


## Strömungsquellen (CurrentArea, RiverChannel)
func current_sources() -> Array:
	var out: Array = []
	for c in get_children():
		if c.has_method("current_at"):
			out.append(c)
	return out


func fuel_docks() -> Array:
	var out: Array = []
	for c in get_children():
		if c is FuelDock:
			out.append(c)
	return out


## Gefahrengebiete (Minenfeld, Polizei, Sirenen): haben update_boat(boat, delta)
func hazards() -> Array:
	var out: Array = []
	for c in get_children():
		if c.has_method("update_boat"):
			out.append(c)
	return out


## Kartenausschnitt für Vorschau und Minikarte: Bahn plus Warngebiete und Tankstellen
func map_bounds(margin := 80.0) -> Rect2:
	var r := course_bounds(margin)
	for z in danger_zones():
		var rad: float = float(z["radius"]) + 10.0
		r = r.merge(Rect2(z["pos"] - Vector2(rad, rad), Vector2(rad, rad) * 2.0))
	for d in fuel_docks():
		r = r.merge(Rect2(d.berth() - Vector2(25, 25), Vector2(50, 50)))
	return r


## Gefahrengebiete für Kartenvorschau und Minikarte: [{pos, radius, kind}],
## kind 0 = Minenfeld, 1 = Polizei, 2 = Sirenengesang
func danger_zones() -> Array:
	var out: Array = []
	for c in get_children():
		if c is RestrictedArea:
			out.append({"pos": c.pos2d(), "radius": c.radius, "kind": int(c.kind)})
		elif c is SirenIsland:
			out.append({"pos": c.pos2d(), "radius": c.capture_radius(), "kind": 2})
	return out


## Kreise [Mitte, Radius], die die Computergegner meiden
func danger_circles() -> Array:
	var out: Array = []
	for c in get_children():
		if c.has_method("danger_circle"):
			out.append(c.danger_circle())
	return out


## Feste Punkte, an denen Boote abprallen: [Position, Radius]
func collision_points() -> Array:
	var out: Array = []
	for c in get_children():
		if c is SeaMark:
			out.append([c.pos2d(), SeaMark.RADIUS])
		elif c is CourseMark:
			out.append([c.pos2d(), 1.5])
		elif c is FuelDock or c is SeaLife:
			out.append_array(c.collision_points())
	return out


## Regattagebiet (innerhalb der Karte)
func race_area() -> Rect2:
	var r := course_bounds(area_margin)
	var chart := Rect2(SeaChart.AREA_MIN + Vector2(30, 30), Vector2.ONE * (SeaChart.AREA_SIZE - 60.0))
	return r.intersection(chart)


func shoals() -> Array[ShoalArea]:
	var out: Array[ShoalArea] = []
	for c in get_children():
		if c is ShoalArea:
			out.append(c)
	return out


## Umriss aller Bahnpunkte (für Minikarte und Kamera)
func course_bounds(margin := 80.0) -> Rect2:
	var pts: Array[Vector2] = []
	var sl := start_line()
	if sl:
		pts.append(sl.center2d())
		pts.append(sl.start_position(0))
		pts.append(sl.start_position(1))
	for m in marks():
		pts.append(m.pos2d())
	if pts.is_empty():
		return Rect2(-200, -400, 400, 500)
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	return r.grow(margin)


# ---------------------------------------------------------------- Tiefenmodell

func compute_depth(res: int) -> PackedFloat32Array:
	var grid: PackedFloat32Array = _base_grid(res).duplicate()
	var step := SeaChart.AREA_SIZE / res
	var amin := SeaChart.AREA_MIN

	# 1. gemalter Seegrund
	var paint := _get_paint()
	if paint:
		var img: Image = paint.duplicate()
		img.resize(res, res, Image.INTERPOLATE_BILINEAR)
		var bytes := img.get_data()
		for k in bytes.size():
			var v := bytes[k]
			if v != 128:
				grid[k] += (v - 128) * PAINT_STEP

	# 2. Küsten (nicht im Binnenrevier)
	if not inland and (coast_east or coast_west):
		var cn := FastNoiseLite.new()
		cn.seed = seabed_seed + 1
		cn.frequency = 0.006
		for j in res:
			var z := amin.y + (j + 0.5) * step
			var ex := 430.0 + cn.get_noise_1d(z) * 60.0
			var wx := -440.0 - cn.get_noise_1d(z + 500.0) * 60.0
			for i in res:
				var x := amin.x + (i + 0.5) * step
				var dist := INF
				if coast_east:
					dist = ex - x
				if coast_west:
					dist = minf(dist, x - wx)
				if dist < 180.0:
					var k := j * res + i
					grid[k] = minf(grid[k], dist * 0.12 + SeaChart.LAND - 0.7)

	# 3. Flüsse und Seen graben Wasser aus
	for c in carvers():
		c.carve_grid(grid, res)

	# 4. Untiefen und Inseln
	var warp := FastNoiseLite.new()
	warp.seed = seabed_seed + 2
	warp.frequency = 0.03
	for s in obstacles():
		var reach: float = s.reach()
		var c: Vector2 = s.pos2d()
		var warped := s is ShoalArea
		var i0 := clampi(int((c.x - reach - amin.x) / step), 0, res - 1)
		var i1 := clampi(int((c.x + reach - amin.x) / step) + 1, 0, res - 1)
		var j0 := clampi(int((c.y - reach - amin.y) / step), 0, res - 1)
		var j1 := clampi(int((c.y + reach - amin.y) / step) + 1, 0, res - 1)
		for j in range(j0, j1 + 1):
			for i in range(i0, i1 + 1):
				var p := amin + Vector2(i + 0.5, j + 0.5) * step
				var w := Vector2.ZERO
				if warped:
					w = Vector2(warp.get_noise_2d(p.x, p.y), warp.get_noise_2d(p.y + 99.0, p.x - 37.0)) * 7.0
				var k := j * res + i
				grid[k] = minf(grid[k], s.depth_profile(p + w))
	return grid


func _base_grid(res: int) -> PackedFloat32Array:
	if _base_cache.has(res):
		return _base_cache[res]
	var n := FastNoiseLite.new()
	n.seed = seabed_seed
	n.frequency = 0.004
	var g := PackedFloat32Array()
	g.resize(res * res)
	var step := SeaChart.AREA_SIZE / res
	for j in res:
		for i in res:
			var p := SeaChart.AREA_MIN + Vector2(i + 0.5, j + 0.5) * step
			if inland:
				g[j * res + i] = SeaChart.LAND - 2.5 - absf(n.get_noise_2dv(p)) * 2.0
			else:
				g[j * res + i] = base_depth + n.get_noise_2dv(p) * depth_variation
	_base_cache[res] = g
	return g


# ---------------------------------------------------------------- Malen (vom Editor-Plugin genutzt)

enum Brush { SHALLOWER = 1, DEEPER = 2, LAND = 3, SMOOTH = 4, ERASE = 5 }


func _get_paint() -> Image:
	if _paint_img == null and depth_paint_png.size() > 0:
		_paint_img = Image.new()
		if _paint_img.load_png_from_buffer(depth_paint_png) != OK:
			_paint_img = null
		elif _paint_img.get_format() != Image.FORMAT_L8:
			_paint_img.convert(Image.FORMAT_L8)
	return _paint_img


func _ensure_paint() -> Image:
	var img := _get_paint()
	if img == null:
		img = Image.create(PAINT_RES, PAINT_RES, false, Image.FORMAT_L8)
		img.fill(Color8(128, 128, 128))
		_paint_img = img
	return img


func begin_stroke() -> void:
	_stroke_start = _ensure_paint().duplicate() as Image
	_delta_img = Image.create(PAINT_RES, PAINT_RES, false, Image.FORMAT_L8)
	_delta_img.fill(Color8(128, 128, 128))
	_delta_tex = ImageTexture.create_from_image(_delta_img)
	if _preview:
		_preview.set_paint_delta(_delta_tex)


## Pinselstrich an Weltposition p (x, z) mit Radius in Metern
func paint(p: Vector2, radius: float, brush: int, strength: float) -> void:
	var img := _ensure_paint()
	var px := (p - SeaChart.AREA_MIN) / SeaChart.AREA_SIZE * PAINT_RES
	var pr := radius / SeaChart.AREA_SIZE * PAINT_RES
	var x0 := clampi(int(px.x - pr) - 1, 0, PAINT_RES - 1)
	var x1 := clampi(int(px.x + pr) + 1, 0, PAINT_RES - 1)
	var y0 := clampi(int(px.y - pr) - 1, 0, PAINT_RES - 1)
	var y1 := clampi(int(px.y + pr) + 1, 0, PAINT_RES - 1)
	var src: Image = img.duplicate() if brush == Brush.SMOOTH else null
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(px) / maxf(pr, 0.5)
			if d >= 1.0:
				continue
			var f := 1.0 - smoothstep(0.3, 1.0, d)
			var v := img.get_pixel(x, y).r8
			var nv := float(v)
			match brush:
				Brush.SHALLOWER:
					nv -= f * strength * 2.0
				Brush.DEEPER:
					nv += f * strength * 2.0
				Brush.LAND:
					nv -= f * strength * 8.0
				Brush.ERASE:
					nv = lerpf(nv, 128.0, f * 0.25 * strength)
				Brush.SMOOTH:
					var sum := 0.0
					for oy in range(-2, 3):
						for ox in range(-2, 3):
							sum += src.get_pixel(clampi(x + ox, 0, PAINT_RES - 1), clampi(y + oy, 0, PAINT_RES - 1)).r8
					nv = lerpf(nv, sum / 25.0, f * 0.5 * strength)
			var iv := clampi(int(round(nv)), 0, 255)
			# kleine Pinselstärken sollen trotzdem wirken
			if iv == v and brush != Brush.SMOOTH and brush != Brush.ERASE and f > 0.2:
				iv = clampi(v + (1 if brush == Brush.DEEPER else -1), 0, 255)
			img.set_pixel(x, y, Color8(iv, iv, iv))
			if _delta_img:
				var dv := clampi(128 + iv - _stroke_start.get_pixel(x, y).r8, 0, 255)
				_delta_img.set_pixel(x, y, Color8(dv, dv, dv))
	if _delta_tex:
		_delta_tex.update(_delta_img)


## Strich beenden: gibt das neue Malbild als PNG zurück (für Undo/Redo im Plugin)
func end_stroke() -> PackedByteArray:
	var bytes := _ensure_paint().save_png_to_buffer()
	_delta_img = null
	_delta_tex = null
	if _preview:
		_preview.set_paint_delta(null)
	return bytes


func clear_paint() -> void:
	depth_paint_png = PackedByteArray()


# ---------------------------------------------------------------- Editor-Hilfen

func _build_wind_arrow() -> void:
	_wind_arrow = Node3D.new()
	add_child(_wind_arrow)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	SeaChart.add_line(st, Vector2(0, -40), Vector2(0, 30), 3.0, 0.2)
	SeaChart.add_triangle(st, Vector2(-9, 26), Vector2(9, 26), Vector2(0, 46), 0.2)
	var mi := SeaChart.mesh_from(st, Color(SeaChart.MAGENTA, 0.8))
	_wind_arrow.add_child(mi)
	var lab := SeaChart.flat_label("WIND", 160, SeaChart.MAGENTA, false, true)
	lab.position = Vector3(10, 0.2, -30)
	lab.rotation = Vector3(-PI / 2, 0, PI / 2)
	_wind_arrow.add_child(lab)
	_update_wind_arrow()


func _update_wind_arrow() -> void:
	_update_border()
	if _wind_arrow == null:
		return
	# Pfeil zeigt, wohin der Wind weht; steht nördlich der Bahn
	var b := course_bounds(0.0)
	var from := deg_to_rad(wind_from_deg)
	var dir := Vector2(sin(from), -cos(from))
	var p := b.get_center() + dir * (maxf(b.size.x, b.size.y) * 0.5 + 90.0)
	_wind_arrow.position = Vector3(p.x, 0, p.y)
	_wind_arrow.rotation.y = -from


## Grenze des Regattagebiets: magenta Strichlinie mit „T“-Zeichen (INT 1 N 2.2)
func _update_border() -> void:
	if not is_inside_tree():
		return
	if _border:
		_border.queue_free()
	_border = Node3D.new()
	_border.top_level = true
	add_child(_border)
	var r := race_area()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for e in 4:
		var a: Vector2 = corners[e]
		var b: Vector2 = corners[(e + 1) % 4]
		var dir := (b - a).normalized()
		var inward := Vector2(-dir.y, dir.x)
		if (r.get_center() - a).dot(inward) < 0.0:
			inward = -inward
		var length := a.distance_to(b)
		var t := 0.0
		var k := 0
		while t < length:
			var t1 := minf(t + 9.0, length)
			SeaChart.add_line(st, a + dir * t, a + dir * t1, 0.9, 0.1)
			if k % 4 == 0:
				var m := a + dir * (t + 4.5)
				SeaChart.add_line(st, m, m + inward * 5.0, 0.9, 0.1)
			t += 14.0
			k += 1
	_border.add_child(SeaChart.mesh_from(st, Color(SeaChart.MAGENTA, 0.75)))
	var lab := SeaChart.flat_label("REGATTAGEBIET", 120, Color(SeaChart.MAGENTA, 0.8), false, true)
	lab.position = Vector3(r.get_center().x, 0.1, r.position.y + 14.0)
	_border.add_child(lab)
