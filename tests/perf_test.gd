extends SceneTree
## Misst die CPU-Zeit je Bild mit vier Computerbooten (ohne Grafik).
## Aufruf: godot --headless --path . --script res://tests/perf_test.gd -- <level.tscn> [Startzeit in s]

var _main: Node
var _frames := 0
var _phys := 0.0
var _proc := 0.0
var _t0 := 0


func _initialize() -> void:
	GameState.net_mode = ""
	GameState.level_path = OS.get_cmdline_user_args()[0]
	GameState.crew_choice = 4
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)


func _process(_d: float) -> bool:
	if _main.state == "waiting" or _main.state == "countdown":
		_main.race_time = 0.0
	if _main.state != "racing":
		return false
	_frames += 1
	if _frames == 2 and OS.get_cmdline_user_args().size() > 1:
		_main.race_time = float(OS.get_cmdline_user_args()[1])     # z. B. 60: Schiffe sind gerade in Startnähe
	if _frames == 60:
		_t0 = Time.get_ticks_usec()
	if _frames > 60:
		_phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		_proc += Performance.get_monitor(Performance.TIME_PROCESS)
	if _frames == 660:
		var n := 600.0
		print("Wanduhr %.2f ms je Bild" % ((Time.get_ticks_usec() - _t0) / 600000.0))
		print("Physik %.2f ms, Prozess %.2f ms je Bild (Boote: %d)" % [_phys / n * 1000.0, _proc / n * 1000.0, _main.boats.size()])
		quit()
		return true
	return false
