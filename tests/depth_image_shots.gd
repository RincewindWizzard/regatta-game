extends SceneTree
## Vergleichsbild gegen Kachelmuster: grobes 16 x 16 Tiefenbild auf einer 1280-m-Karte, links ohne
## Rauschen, rechts mit Rauschen (Standardwerte). Aufruf: ... --script res://tests/depth_image_shots.gd -- <ausgabe.png>
func _initialize() -> void:
	var out := OS.get_cmdline_user_args()[0]
	var img := Image.create(16, 16, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for y in 16:
		for x in 16:
			var d := Vector2(x - 7.5, y - 7.5).length()
			var v := clampf(0.15 + d / 12.0 + rng.randf_range(-0.05, 0.05), 0.0, 1.0)   # Becken mit Ufer rundherum
			img.set_pixel(x, y, Color(v, v, v))
	img.save_png("user://grob.png")
	var res := 400
	var pics: Array[Image] = []
	for noisy in [false, true]:
		var l := Level.new()
		l.depth_image = "user://grob.png"
		l.depth_image_black = -3.0
		l.depth_image_white = 12.0
		l.coast_east = false
		l.coast_west = false
		l.depth_image_warp = 4.0 if noisy else 0.0
		l.depth_image_noise = 0.4 if noisy else 0.0
		SeaChart.set_depth_grid(l.compute_depth(res), res)
		# Tiefenstufen einfärben (jede Stufe 1 m), damit Tiefenlinien sichtbar werden
		var p := Image.create(res, res, false, Image.FORMAT_RGB8)
		for j in res:
			for i in res:
				var w := SeaChart.area_min + Vector2(i + 0.5, j + 0.5) * (SeaChart.area_size / res)
				var dd := SeaChart.depth_at(w)
				var band := floorf(dd)
				var c := Color.from_hsv(0.58, 0.55, 0.35 + 0.05 * fposmod(band, 12.0)) if dd >= -0.8 else Color(0.96, 0.87, 0.62)
				p.set_pixel(i, j, c)
		pics.append(p)
	var both := Image.create(res * 2 + 10, res, false, Image.FORMAT_RGB8)
	both.fill(Color.WHITE)
	both.blit_rect(pics[0], Rect2i(0, 0, res, res), Vector2i(0, 0))
	both.blit_rect(pics[1], Rect2i(0, 0, res, res), Vector2i(res + 10, 0))
	both.save_png(out)
	print("gespeichert ", out)
	quit()
