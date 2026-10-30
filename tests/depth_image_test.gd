extends SceneTree
## Prüft das Tiefenbild eines Levels (Zuordnung der Graustufen, Kartengröße, Rauschen) ohne Grafik.
## Aufruf: godot --headless --path . --script res://tests/depth_image_test.gd

var _fails := 0


func _check(name: String, ok: bool) -> void:
	print(("OK    " if ok else "FEHLER ") + name)
	if not ok:
		_fails += 1


## kleines PNG schreiben: w x h, Farbe je Pixel aus fn(x, y)
func _png(path: String, w: int, h: int, fn: Callable) -> void:
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	for y in h:
		for x in w:
			img.set_pixel(x, y, fn.call(x, y))
	img.save_png(path)


func _level(path: String, black := 0.0, white := 20.0, invert := false) -> Level:
	var l := Level.new()
	l.depth_image = path
	l.depth_image_black = black
	l.depth_image_white = white
	l.depth_image_invert = invert
	l.depth_image_warp = 0.0
	l.depth_image_noise = 0.0
	l.coast_east = false                  # feste Küstenlinien der alten Level aus
	l.coast_west = false
	return l


## Level berechnen und die Tiefe an Weltpunkten lesen
func _depth(l: Level, p: Vector2, res := 256) -> float:
	SeaChart.set_depth_grid(l.compute_depth(res), res)
	return SeaChart.depth_at(p)


func _initialize() -> void:
	var tmp := "user://dt_"
	_png(tmp + "grau.png", 4, 4, func(_x, _y): return Color8(128, 128, 128))
	_png(tmp + "rot.png", 4, 4, func(_x, _y): return Color8(255, 0, 0))
	_png(tmp + "halb.png", 8, 4, func(x, _y): return Color8(0, 0, 0) if x < 4 else Color8(255, 255, 255))

	# Standardkarte
	var d := Level.new()
	d.apply_area()
	_check("Standardkarte 1280 x 1280 m (Nordwestecke -640/-840)", SeaChart.area_rect() == Rect2(-640, -840, 1280, 1280))

	# Zuordnung Grau -> Tiefe
	var l := _level(tmp + "grau.png")
	_check("Grau 128 mit 0..20 m -> rund 10 m", absf(_depth(l, Vector2(0, -300)) - 128.0 / 255.0 * 20.0) < 0.05)
	var li := _level(tmp + "grau.png", 0.0, 20.0, true)
	_check("Umkehr: Grau 128 -> rund 10 m (vertauscht 20..0)", absf(_depth(li, Vector2(0, -300)) - (20.0 - 128.0 / 255.0 * 20.0)) < 0.05)
	var lc := _level(tmp + "rot.png")
	_check("Farbbild: Rot (255,0,0) zählt als Helligkeit 1/3 -> 6,7 m", absf(_depth(lc, Vector2(0, -300)) - 20.0 / 3.0) < 0.05)
	var lo := _level(tmp + "grau.png", -8.0, 17.5)
	_check("Standardzuordnung -8..17,5 m: Grau 128 -> 4,8 m", absf(_depth(lo, Vector2(0, -300)) - (-8.0 + 128.0 / 255.0 * 25.5)) < 0.05)

	# Kartengröße 2000 x 800 m: Bild wird gestreckt (links schwarz, rechts weiß)
	var lb := _level(tmp + "halb.png")
	lb.map_size = Vector2(2000, 800)
	lb.map_origin = Vector2(-1000, -400)
	var dl := _depth(lb, Vector2(-900, 0), 400)
	var dr := _depth(lb, Vector2(900, 0), 400)
	_check("Karte 2000 x 800: Rechteck stimmt", SeaChart.area_rect() == Rect2(-1000, -400, 2000, 800))
	_check("Karte 2000 x 800: Bild gestreckt, links 0 m (%.2f), rechts 20 m (%.2f)" % [dl, dr], absf(dl) < 0.3 and absf(dr - 20.0) < 0.3)
	var dims := SeaChart.grid_dims(400)
	_check("Gitter folgt dem Seitenverhältnis (%d x %d)" % [dims.x, dims.y], dims.x == 400 and dims.y == 160)
	_check("Ausserhalb der Karte gilt Tiefwasser (kein Absturz)", SeaChart.depth_at(Vector2(5000, 5000)) > 10.0)

	# Begrenzung der Kartengröße
	var lm := Level.new()
	lm.map_size = Vector2(50, 9000)
	_check("Kartengröße wird auf 300..3000 m begrenzt", lm.map_size == Vector2(300, 3000))

	# Rauschen: deterministisch und wirksam
	var n1 := _level(tmp + "halb.png")
	n1.depth_image_warp = 3.0
	n1.depth_image_noise = 0.3
	var n2 := _level(tmp + "halb.png")
	n2.depth_image_warp = 3.0
	n2.depth_image_noise = 0.3
	var g1 := n1.compute_depth(128)
	var g2 := n2.compute_depth(128)
	var g0 := _level(tmp + "halb.png").compute_depth(128)
	_check("Rauschen deterministisch: zwei Läufe liefern denselben Grund", g1 == g2)
	_check("Rauschen wirksam: Grund unterscheidet sich vom glatten Grund", g1 != g0)
	n2.seabed_seed = 99
	_check("anderer Seed ergibt anderes Rauschen", n2.compute_depth(128) != g1)

	# Rauschen aus: glatte Abtastung ohne Zufall, eine Zeile verläuft monoton über die Kante
	var mono := true
	var prev := -1.0
	for x in range(-600, 600, 20):
		var dd := _depth(lb, Vector2(x * 1.5, 0), 400)
		if dd < prev - 0.05:
			mono = false
		prev = dd
	_check("Rauschen 0: Verlauf über die Kante ist monoton", mono)

	print("ERGEBNIS: ", "BESTANDEN" if _fails == 0 else "%d FEHLER" % _fails)
	quit(0 if _fails == 0 else 1)
