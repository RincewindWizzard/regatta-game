extends SceneTree
## Rennen nur mit Computerbooten, ohne Grafik und so schnell wie möglich.
## Aufruf: godot --headless --fixed-fps 60 --path . --script res://tests/ai_race.gd -- <level.tscn> [stärke 0-2|mix]
## Gibt Zieleinläufe, Zeiten, Grundberührungen und Schleppereinsätze aus.

const MAX_TIME := 1500.0

var _main: Node
var _t := 0.0
var _stats := {}
var _level := ""
var _mix := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_level = args[0]
	GameState.net_mode = ""
	GameState.level_path = _level
	GameState.crew_choice = 4
	if args.size() > 1 and args[1] == "mix":
		_mix = true
	elif args.size() > 1:
		GameState.ai_level = int(args[1])
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)


func _setup() -> void:
	if _mix:
		var lv := [0, 1, 2, 2]
		for i in _main.boats.size():
			var b: Boat = _main.boats[i]
			b.input = AIInput.new(b, _main.wind, _main.course, lv[i], _main._fixed_points)
			b.input.docks = _main._docks
			b.player_name = ["Leicht", "Mittel", "Schwer A", "Schwer B"][i]
	for b in _main.boats:
		_stats[b] = {"aground": 0, "tugs": 0, "outside": 0, "was_aground": false, "had_tug": false, "was_out": false, "refuels": 0, "was_ref": false, "motor": 0.0, "where": []}


func _physics_process(delta: float) -> bool:
	if _stats.is_empty():
		if _main.boats.is_empty():
			return false
		_setup()
	_t += delta
	if OS.has_environment("AI_DEBUG") and int(_t / 30.0) != int((_t - delta) / 30.0):
		for b in _main.boats:
			var ai := b.input as AIInput
			print("t=%4d %-8s thr=%d want=%d eng=%d fuel=%.1f has=%s pos=%s" % [_t, b.player_name, b.throttle, ai._want_throttle if ai else -1, b.engine, b.fuel, b.has_engine, b.pos2d()])
	for b in _main.boats:
		var s: Dictionary = _stats[b]
		if b.aground and not s["was_aground"]:
			s["aground"] += 1
			if s["where"].size() < 4:
				s["where"].append("(%d,%d)%s" % [b.pos2d().x, b.pos2d().y, "M" if b.engine != Boat.Motor.AUS else ""])
		s["was_aground"] = b.aground
		var has_tug: bool = b.tug != null
		if has_tug and not s["had_tug"]:
			s["tugs"] += 1
		s["had_tug"] = has_tug
		if b.outside and not s["was_out"]:
			s["outside"] += 1
		s["was_out"] = b.outside
		if b.refueling and not s["was_ref"]:
			s["refuels"] += 1
		s["was_ref"] = b.refueling
		if b.engine == Boat.Motor.LAEUFT:
			s["motor"] += delta
	var all_done := true
	for b in _main.boats:
		if not b.finished:
			all_done = false
	if all_done or _t > MAX_TIME:
		_report()
		return true
	return false


func _report() -> void:
	print("=== %s  (Wind %.1f kn) ===" % [_main.level.level_name, _main.wind.base_speed * 1.944])
	var marks: int = _main.course.targets.size()
	for b in _main.boats:
		var s: Dictionary = _stats[b]
		var res: String = "ZIEL %d:%04.1f" % [int(b.finish_time) / 60, fmod(b.finish_time, 60.0)] if b.finished else "nicht im Ziel (Ziel %d/%d, %s)" % [b.next_target, marks, b.pos2d()]
		print("  %-12s %-34s Grund %d  Schlepper %d  Gebiet verlassen %d  Motor %3ds  Tanken %d  %s" % [b.player_name, res, s["aground"], s["tugs"], s["outside"], s["motor"], s["refuels"], " ".join(s["where"])])
