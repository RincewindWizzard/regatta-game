extends SceneTree
## Schreibt die Tiefenkarte eines Levels als Bild (ganzes Kartengebiet, Norden oben), mit
## Marken (gelb), Startlinie (rot), Ziellinie (grün) und Tankstellen (orange) zur schnellen Kontrolle.
## Aufruf: godot --headless --path . --script res://tests/depth_png.gd -- <level.tscn> <ausgabe.png>
var _l: Level
var _f := 0


func _initialize() -> void:
	_l = load(OS.get_cmdline_user_args()[0]).instantiate()
	root.add_child(_l)


func _process(_d: float) -> bool:
	_f += 1
	if _f < 3:
		return false
	SeaChart.set_depth_grid(_l.compute_depth(448), 448)
	var amin := SeaChart.AREA_MIN
	var img := SeaChart.make_map_image(amin, amin + Vector2.ONE * SeaChart.AREA_SIZE, 640, 640)
	var dot := func(p: Vector2, c: Color, r := 3) -> void:
		var q := (p - amin) / SeaChart.AREA_SIZE * 640.0
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var x := int(q.x) + dx
				var y := int(q.y) + dy
				if x >= 0 and y >= 0 and x < 640 and y < 640:
					img.set_pixel(x, y, c)
	for m in _l.marks():
		dot.call(m.pos2d(), Color(1, 0.9, 0))
	var sl := _l.start_line()
	for k in range(-int(sl.half_width), int(sl.half_width) + 1, 3):
		dot.call(sl.center2d() + sl.tangent2d() * k, Color(0.9, 0, 0), 1)
	var fl := _l.finish_line()
	if fl:
		for k in range(-int(fl.half_width), int(fl.half_width) + 1, 3):
			dot.call(fl.center2d() + fl.tangent2d() * k, Color(0, 0.7, 0), 1)
	for d in _l.fuel_docks():
		dot.call(d.berth(), Color(1, 0.5, 0), 3)
	for i in 4:
		dot.call(sl.start_position(i), Color(0.6, 0, 0.6), 2)
	img.save_png(OS.get_cmdline_user_args()[1])
	quit()
	return true
