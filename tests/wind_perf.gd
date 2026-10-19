extends SceneTree
## Misst, wie lange ein voller Durchlauf des Windfelds (alle Windstriche) dauert.
## Aufruf: godot --headless --path . --script res://tests/wind_perf.gd

var _main: Node
var _frame := 0


func _initialize() -> void:
	GameState.level_path = "res://levels/06_schaerengarten.tscn"
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)


func _process(_d: float) -> bool:
	_frame += 1
	if _frame < 3:
		return false
	var wind: WindField = _main.wind
	var b: Rect2 = _main.level.course_bounds(60.0)
	var n := 0
	var t0 := Time.get_ticks_usec()
	var y := b.position.y
	while y < b.end.y:
		var x := b.position.x
		while x < b.end.x:
			wind.get_wind(Vector2(x, y))
			n += 1
			x += 16.0
		y += 16.0
	var dt := (Time.get_ticks_usec() - t0) / 1000.0
	print("%d Windpunkte in %.1f ms (%.1f µs je Punkt)" % [n, dt, dt * 1000.0 / n])
	return true
