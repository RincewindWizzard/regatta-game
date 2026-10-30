extends SceneTree
## Prüft die Vektorformen (LandShape): exakte Kante, Bézier, Wasser über Land, Vorrang vor dem Raster.
## Aufruf: godot --headless --path . --script res://tests/land_shape_test.gd

var _fails := 0


func _check(name: String, ok: bool) -> void:
	print(("OK    " if ok else "FEHLER ") + name)
	if not ok:
		_fails += 1


func _shape(lvl: Level, corners: Array, water := false, handles := false) -> LandShape:
	var s := LandShape.new()
	if water:
		s.kind = LandShape.Kind.WASSER
	var c := Curve3D.new()
	for v in corners:
		c.add_point(Vector3(v.x, 0, v.y))
	s.curve = c
	lvl.add_child(s)
	return s


func _circle(lvl: Level, r: float, center := Vector2.ZERO) -> LandShape:
	var s := LandShape.new()
	var c := Curve3D.new()
	var g := r * 0.5522847
	c.add_point(Vector3(center.x, 0, center.y - r), Vector3(-g, 0, 0), Vector3(g, 0, 0))
	c.add_point(Vector3(center.x + r, 0, center.y), Vector3(0, 0, -g), Vector3(0, 0, g))
	c.add_point(Vector3(center.x, 0, center.y + r), Vector3(g, 0, 0), Vector3(-g, 0, 0))
	c.add_point(Vector3(center.x - r, 0, center.y), Vector3(0, 0, g), Vector3(0, 0, -g))
	s.curve = c
	lvl.add_child(s)
	return s


func _level() -> Level:
	var l := Level.new()
	l.coast_east = false
	l.coast_west = false
	root.add_child(l)
	return l


func _build(l: Level, res := 256) -> void:
	l.apply_area()
	SeaChart.set_depth_grid(l.compute_depth(res), res)


func _initialize() -> void:
	var L := SeaChart.LAND

	# --- Rechteck: Kante und Ecke
	var l := _level()
	_shape(l, [Vector2(-50, -30), Vector2(50, -30), Vector2(50, 30), Vector2(-50, 30)])
	_build(l)
	var ok := true
	for x in [-40.0, 0.0, 33.3, 49.0]:
		ok = ok and SeaChart.depth_at(Vector2(x, 30.2)) > L and SeaChart.depth_at(Vector2(x, 29.8)) < L
		ok = ok and SeaChart.depth_at(Vector2(x, -30.2)) > L and SeaChart.depth_at(Vector2(x, -29.8)) < L
	_check("Rechteck: Uferlinie liegt auf der Kante (±0,2 m)", ok)
	_check("Rechteck: Ecke bleibt scharf", SeaChart.depth_at(Vector2(50.15, 30.15)) > L and SeaChart.depth_at(Vector2(49.85, 29.85)) < L)
	_check("Rechteck: außerhalb der Ecke diagonal Wasser, innen Land", SeaChart.depth_at(Vector2(52, 32)) > L and SeaChart.depth_at(Vector2(0, 0)) < L)
	_check("Rechteck: Grund fällt vom Ufer ab (10 m weg ≈ +1,4 m)", absf(SeaChart.depth_at(Vector2(0, 40)) - (L + 10.0 * 0.22)) < 0.3)
	_check("Rechteck: Grundlage weit weg unverändert", SeaChart.depth_at(Vector2(0, 400)) > 5.0)
	l.queue_free()

	# --- Bézier-Kreis
	var lc := _level()
	var cs := _circle(lc, 50.0)
	_build(lc)
	var o := cs.outline()
	var maxdev := 0.0
	for p in o:
		maxdev = maxf(maxdev, absf(p.length() - 50.0))
	_check("Bézier-Kreis r=50: Umriss weicht höchstens 0,06 m ab (%.3f m, %d Punkte)" % [maxdev, o.size()], maxdev < 0.06)
	var ring := true
	for a in 24:
		var d := Vector2.from_angle(a * TAU / 24.0 + 0.13)
		ring = ring and SeaChart.depth_at(d * 50.15) > L and SeaChart.depth_at(d * 49.85) < L
	_check("Bézier-Kreis: Uferlinie auf dem Kreis (±0,2 m) in 24 Richtungen", ring)
	lc.queue_free()

	# --- Wasser über Land (Loch)
	var lw := _level()
	_shape(lw, [Vector2(-100, -100), Vector2(100, -100), Vector2(100, 100), Vector2(-100, 100)])
	_shape(lw, [Vector2(-20, -20), Vector2(20, -20), Vector2(20, 20), Vector2(-20, 20)], true)
	_build(lw)
	_check("Hafenbecken: Mitte ist Wasser (20 m vom Ufer: -0,8 + 20 * 0,22 = 3,6 m)", absf(SeaChart.depth_at(Vector2.ZERO) - 3.6) < 0.3)
	_check("Hafenbecken: Kante exakt (19,8 Wasser, 20,2 Land)", SeaChart.depth_at(Vector2(19.8, 0)) > L and SeaChart.depth_at(Vector2(20.2, 0)) < L)
	_check("Hafenbecken: Land ringsum bleibt Land", SeaChart.depth_at(Vector2(60, 60)) < L)
	lw.queue_free()

	# --- Vorrang vor dem Raster: Binnenrevier (alles Land) + Wasserform
	var li := _level()
	li.inland = true
	_shape(li, [Vector2(-60, -40), Vector2(60, -40), Vector2(60, 40), Vector2(-60, 40)], true)
	_build(li)
	_check("Binnenrevier: Wasserform ersetzt Rasterland (innen Wasser, außen Land)", SeaChart.depth_at(Vector2(0, 0)) > 3.0 and SeaChart.depth_at(Vector2(0, 80)) < L)
	li.queue_free()

	# --- Vorrang vor Tiefenbild-Land: Raster zeigt Land, Landform sagt Wasser außerhalb
	var lp := _level()
	var img := Image.create(4, 4, false, Image.FORMAT_RGB8)
	img.fill(Color8(0, 0, 0))
	img.save_png("user://ls_land.png")
	lp.depth_image = "user://ls_land.png"
	lp.depth_image_black = -5.0
	lp.depth_image_white = -5.0
	lp.depth_image_noise = 0.0
	lp.depth_image_warp = 0.0
	_shape(lp, [Vector2(-30, -30), Vector2(30, -30), Vector2(30, 30), Vector2(-30, 30)])
	_build(lp)
	_check("Tiefenbild nur Land: Landform ändert das Land nicht (innen Land)", SeaChart.depth_at(Vector2.ZERO) < L)
	lp.queue_free()

	# --- Untiefenmarkierung ersetzt flachere Grundlage
	var lu := _level()
	var img2 := Image.create(4, 4, false, Image.FORMAT_RGB8)
	img2.fill(Color8(0, 0, 0))
	img2.save_png("user://ls_flach.png")
	lu.depth_image = "user://ls_flach.png"
	lu.depth_image_black = 0.1
	lu.depth_image_white = 0.1
	lu.depth_image_noise = 0.0
	lu.depth_image_warp = 0.0
	var sh := ShoalArea.new()
	sh.center_depth = 0.3
	sh.radius = 30.0
	lu.add_child(sh)
	_build(lu)
	_check("Untiefe 0,3 m über Grundlage 0,1 m: Mitte 0,3 m", absf(SeaChart.depth_at(Vector2.ZERO) - 0.3) < 0.1)
	lu.queue_free()

	# --- keine Naht am Gebietsrand: Tiefe entlang eines Strahls ohne Sprung
	var ln := _level()
	_shape(ln, [Vector2(-50, -50), Vector2(50, -50), Vector2(50, 50), Vector2(-50, 50)])
	_build(ln)
	var prev := SeaChart.depth_at(Vector2(51, 0))
	var jump := 0.0
	for k in range(52, 200):
		var d := SeaChart.depth_at(Vector2(k, 0))
		jump = maxf(jump, absf(d - prev))
		prev = d
	_check("Gebietsrand: Tiefe springt entlang eines Strahls nicht (max Schritt %.2f m je m)" % jump, jump < 0.6)
	ln.queue_free()

	# --- ohne Formen unverändert, grobes Raster exakt
	var l0 := _level()
	_build(l0)
	var base_g := l0.compute_depth(256)
	_check("Ohne Formen keine Vektorebene", l0.land_polys().is_empty())
	l0.queue_free()
	var lg := _level()
	lg.depth_cell = 8.0
	_shape(lg, [Vector2(-50, -30), Vector2(50, -30), Vector2(50, 30), Vector2(-50, 30)])
	lg.apply_area()
	var res := SeaChart.game_res()
	var dims := SeaChart.grid_dims(res)
	SeaChart.set_depth_grid(lg.compute_depth(res), res)
	_check("Zellgröße 8 m: Gitter %d x %d (statt ca. 2,9 m)" % [dims.x, dims.y], absf(SeaChart.area_size.x / dims.x - 8.0) < 0.5)
	_check("Zellgröße 8 m: Kante bleibt exakt", SeaChart.depth_at(Vector2(0, 30.2)) > L and SeaChart.depth_at(Vector2(0, 29.8)) < L)

	# --- Laufzeit depth_at nahe der Form
	var t := Time.get_ticks_usec()
	var acc := 0.0
	for k in 20000:
		acc += SeaChart.depth_at(Vector2(-60.0 + (k % 120), -40.0 + (k % 80)))
	var us := (Time.get_ticks_usec() - t) / 20000.0
	print("depth_at nahe einer Form: %.1f µs je Aufruf" % us)
	_check("depth_at nahe einer Form unter 100 µs", us < 100.0)
	lg.queue_free()

	print("ERGEBNIS: " + ("BESTANDEN" if _fails == 0 else "%d FEHLER" % _fails))
	quit(1 if _fails > 0 else 0)
