class_name LandPoly
extends RefCounted
## Zerlegter Umriss einer Landform (LandShape) mit allen Rechenregeln. Unabhängig vom Szenenbaum,
## damit SeaChart den Umriss auch nach dem Level-Wechsel sicher halten kann.
##   Land:   innen fest (Tiefe fällt ab Ufer um 0,5 m je m), außen steigt die Tiefe mit `slope`
##   Wasser: innen Wasser (Tiefe steigt vom Ufer mit `slope` bis `water_depth`), außen unverändert
## Die Uferlinie (Tiefe LAND) liegt exakt auf dem Umriss.

const BLEND := 15.0         ## Überblendung zur Grundlage am Rand des Gebiets (m)
const BAND := 4.0           ## Mindestbreite des fein aufgelösten Streifens an der Kante (m)
const INSIDE_SLOPE := 0.5   ## Tiefenabfall im Land (m je m)
const INSIDE_MIN := -6.0    ## tiefer als LAND wird es im Land nicht

var pts := PackedVector2Array()
var water := false
var slope := 0.22
var zone := 60.0
var water_depth := 8.0
var bounds := Rect2()
var zone_rect := Rect2()
## Breite des Streifens an der Kante, in dem die Grundlage vom groben Raster verwischt sein kann
## (mindestens BAND, bei groben Zellen entsprechend mehr); setzt prepare()
var band := BAND
## Raster vor dieser Form (nur Wasserformen): ungestörte Tiefe an Land direkt neben dem Becken
var _base := PackedFloat32Array()
var _gw := 0
var _gh := 0
var _gmin := Vector2.ZERO
var _gstep := Vector2.ONE


func setup(points: PackedVector2Array, is_water: bool, shore_slope: float, zone_m: float, depth_m: float) -> void:
	pts = points
	water = is_water
	slope = shore_slope
	zone = zone_m
	water_depth = depth_m
	if pts.size() == 0:
		bounds = Rect2()
		zone_rect = Rect2()
		return
	var lo := pts[0]
	var hi := pts[0]
	for p in pts:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	bounds = Rect2(lo, hi - lo)
	zone_rect = bounds if water else bounds.grow(zone)


## Vor dem Anwenden aufrufen: merkt sich das Raster ohne diese Form (Wasserformen) und setzt die Streifenbreite
func prepare(grid: PackedFloat32Array, gw: int, gh: int, gmin: Vector2, gstep: Vector2) -> void:
	band = maxf(BAND, 1.2 * maxf(gstep.x, gstep.y))
	zone_rect = bounds.grow(band) if water else bounds.grow(zone)
	if water:
		_base = grid.duplicate()
		_gw = gw
		_gh = gh
		_gmin = gmin
		_gstep = gstep
	else:
		_base = PackedFloat32Array()


## Tiefe des Rasters vor dieser Form an p (bilinear); ohne prepare der Ersatzwert d
func base_depth(p: Vector2, d: float) -> float:
	if _base.is_empty():
		return d
	var f := (p - _gmin) / _gstep - Vector2(0.5, 0.5)
	var i := clampi(int(floorf(f.x)), 0, _gw - 2)
	var j := clampi(int(floorf(f.y)), 0, _gh - 2)
	var fx := clampf(f.x - i, 0.0, 1.0)
	var fy := clampf(f.y - j, 0.0, 1.0)
	var a := lerpf(_base[j * _gw + i], _base[j * _gw + i + 1], fx)
	var b := lerpf(_base[(j + 1) * _gw + i], _base[(j + 1) * _gw + i + 1], fx)
	return lerpf(a, b, fy)


func valid() -> bool:
	return pts.size() >= 3


## Wasserseitiger Abstand zur Kante: > 0 auf der Wasserseite (bei Land außen, bei Wasser innen), < 0 an Land
func signed_water(p: Vector2) -> float:
	var best := INF
	var inside := false
	var j := pts.size() - 1
	for i in pts.size():
		var a := pts[j]
		var b := pts[i]
		if (a.y > p.y) != (b.y > p.y) and p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x:
			inside = not inside
		var ab := b - a
		var l2 := ab.length_squared()
		var t := 0.0
		if l2 > 0.0:
			t = clampf((p - a).dot(ab) / l2, 0.0, 1.0)
		best = minf(best, (a + ab * t - p).length_squared())
		j = i
	var dist := sqrt(best)
	return dist if inside == water else -dist


## Tiefe nach Anwendung dieser Form auf den bisherigen Wert d an Weltposition p
func apply(p: Vector2, d: float) -> float:
	if not valid() or not zone_rect.has_point(p):
		return d
	var s := signed_water(p)
	if water:
		if s <= 0.0:
			# direkt neben dem Becken ist das grobe Raster vom Becken verwischt: ungestörten Wert nehmen
			return base_depth(p, d) if s > -band else d
		return minf(SeaChart.LAND + s * slope, water_depth)
	if s <= 0.0:
		return maxf(SeaChart.LAND + INSIDE_MIN, SeaChart.LAND + s * INSIDE_SLOPE)
	var w := 1.0 - smoothstep(zone - BLEND, zone, s)
	return lerpf(d, SeaChart.LAND + s * slope, w)


## Wert (Tiefe, Gewicht) für den fein aufgelösten Streifen an der Kante; c = Weltposition des Texels
func edge_sample(s: float, c: Vector2) -> Vector2:
	var w := 1.0 - smoothstep(band * 0.6, band, absf(s))
	if water:
		if s <= 0.0:
			return Vector2(base_depth(c, SeaChart.LAND - 2.0) if not _base.is_empty() else 0.0, w if not _base.is_empty() else 0.0)
		return Vector2(minf(SeaChart.LAND + s * slope, water_depth), w)
	var prof := SeaChart.LAND + s * (slope if s > 0.0 else INSIDE_SLOPE)
	return Vector2(prof, w)


## Zeichnet den Streifen an der Kante in data (RG-Paare: Tiefe·Gewicht, Gewicht), Zellgröße cell
func rasterize_into(data: PackedFloat32Array, origin: Vector2, cell: float, w: int, h: int) -> void:
	if not valid():
		return
	var best := PackedFloat32Array()
	best.resize(w * h)
	best.fill(INF)
	var touched := PackedInt32Array()
	var limit := band * band
	var j := pts.size() - 1
	for i in pts.size():
		var a := pts[j]
		var b := pts[i]
		j = i
		var ab := b - a
		var l2 := ab.length_squared()
		var x0 := clampi(int((minf(a.x, b.x) - band - origin.x) / cell), 0, w - 1)
		var x1 := clampi(int((maxf(a.x, b.x) + band - origin.x) / cell) + 1, 0, w - 1)
		var y0 := clampi(int((minf(a.y, b.y) - band - origin.y) / cell), 0, h - 1)
		var y1 := clampi(int((maxf(a.y, b.y) + band - origin.y) / cell) + 1, 0, h - 1)
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				var c := origin + Vector2(x + 0.5, y + 0.5) * cell
				var t := 0.0
				if l2 > 0.0:
					t = clampf((c - a).dot(ab) / l2, 0.0, 1.0)
				var d2 := (a + ab * t - c).length_squared()
				if d2 < limit:
					var k := y * w + x
					if best[k] == INF:
						touched.append(k)
					if d2 < best[k]:
						best[k] = d2
	for k in touched:
		var c := origin + Vector2(k % w + 0.5, k / w + 0.5) * cell
		var s := signed_water(c)
		var e := edge_sample(s, c)
		if e.y > 0.0:
			data[k * 2] = e.x * e.y
			data[k * 2 + 1] = e.y


## Bild (RGF) für den Kartenshader über alle Formen; leer, wenn es keine gültige Form gibt
static func edge_image(polys: Array) -> Dictionary:
	var rect := Rect2()
	var first := true
	for lp in polys:
		if not lp.valid():
			continue
		var r: Rect2 = lp.bounds.grow(lp.band + 1.0)
		rect = r if first else rect.merge(r)
		first = false
	if first:
		return {}
	var cell := maxf(1.0, maxf(rect.size.x, rect.size.y) / 2048.0)
	var w := maxi(2, ceili(rect.size.x / cell))
	var h := maxi(2, ceili(rect.size.y / cell))
	var data := PackedFloat32Array()
	data.resize(w * h * 2)
	for lp in polys:
		lp.rasterize_into(data, rect.position, cell, w, h)
	return {
		"image": Image.create_from_data(w, h, false, Image.FORMAT_RGF, data.to_byte_array()),
		"min": rect.position,
		"size": Vector2(w, h) * cell,
	}


## Bézier-Segment in Strecken zerlegen (Abweichung < tol), hängt die Endpunkte an out an (ohne p0)
static func flatten(p0: Vector2, c1: Vector2, c2: Vector2, p3: Vector2, out: PackedVector2Array, tol := 0.04, depth := 0) -> void:
	var chord := p3 - p0
	var l := chord.length()
	var dev: float
	if l < 0.001:
		dev = maxf((c1 - p0).length(), (c2 - p0).length())
	else:
		dev = maxf(absf(chord.cross(c1 - p0)), absf(chord.cross(c2 - p0))) / l
	if dev <= tol or depth >= 12:
		out.append(p3)
		return
	var p01 := p0.lerp(c1, 0.5)
	var p12 := c1.lerp(c2, 0.5)
	var p23 := c2.lerp(p3, 0.5)
	var a := p01.lerp(p12, 0.5)
	var b := p12.lerp(p23, 0.5)
	var m := a.lerp(b, 0.5)
	flatten(p0, p01, a, m, out, tol, depth + 1)
	flatten(m, b, p23, p3, out, tol, depth + 1)
