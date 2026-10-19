extends SceneTree
## Headless-Test: Seegrund-Pinsel und Rückwirkung auf die Tiefenberechnung.
## Aufruf: godot --headless --path . --script res://tests/paint_test.gd

var _lvl: Level
var _frame := 0


func _initialize() -> void:
	_lvl = load("res://levels/02_kurzer_up_and_down.tscn").instantiate()
	root.add_child(_lvl)


func _process(_d: float) -> bool:
	_frame += 1
	if _frame < 3:
		return false
	_run(_lvl)
	return true


func _run(lvl: Level) -> void:
	var p := Vector2(220, -420)   # weit weg von den Untiefen
	var res := 256
	var before := _depth(lvl, p, res)
	lvl.begin_stroke()
	for k in 6:
		lvl.paint(p, 30.0, Level.Brush.SHALLOWER, 2.0)
	lvl.depth_paint_png = lvl.end_stroke()
	var shallower := _depth(lvl, p, res)
	lvl.begin_stroke()
	for k in 6:
		lvl.paint(p, 30.0, Level.Brush.LAND, 3.0)
	lvl.depth_paint_png = lvl.end_stroke()
	var land := _depth(lvl, p, res)
	lvl.clear_paint()
	var cleared := _depth(lvl, p, res)
	print("Tiefe vorher %.1f m, nach 'Flacher' %.1f m, nach 'Land' %.1f m, gelöscht %.1f m (PNG %d Bytes)" % [before, shallower, land, cleared, lvl.depth_paint_png.size()])
	print("OK" if shallower < before and land < SeaChart.LAND and absf(cleared - before) < 0.01 else "FEHLER")
	# Untiefe verschieben ändert die Karte
	var s: ShoalArea = lvl.shoals()[0]
	var c := s.pos2d()
	var d0 := _depth(lvl, c, res)
	s.position.x += 300.0
	var d1 := _depth(lvl, c, res)
	print("Untiefe verschoben: Tiefe an alter Stelle %.1f m -> %.1f m %s" % [d0, d1, "OK" if d1 > d0 + 2.0 else "FEHLER"])


func _depth(lvl: Level, p: Vector2, res: int) -> float:
	SeaChart.set_depth_grid(lvl.compute_depth(res), res)
	return SeaChart.depth_at(p)
