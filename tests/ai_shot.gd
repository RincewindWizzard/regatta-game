extends SceneTree
## Screenshot: 1 Spieler gegen 3 Computerboote, nach einer Weile Rennen.
## Aufruf (mit Grafik): godot --path . --fixed-fps 30 --script res://tests/ai_shot.gd -- <ausgabeordner> [level] [frames] [datei]

var _out := "user://"
var _main: Node
var _frame := 0
var _frames := 1500
var _file := "ai_race.png"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	GameState.net_mode = ""
	GameState.level_path = args[1] if args.size() > 1 else "res://levels/01_mittelgrund.tscn"
	if args.size() > 2:
		_frames = int(args[2])
	if args.size() > 3:
		_file = args[3]
	GameState.crew_choice = 2
	GameState.ai_level = 2
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)


func _process(_d: float) -> bool:
	_frame += 1
	if _frame == 3:
		_main.countdown = 0.0
		# der Mensch segelt einfach am Wind hinterher
		var b: Boat = _main.boats[0]
		b.input = AIInput.new(b, _main.wind, _main.course, 2, _main._fixed_points)
		b.input.docks = _main._docks
	if _frame == _frames:
		root.get_texture().get_image().save_png(_out.path_join(_file))
		print("saved ", _file)
		return true
	return false
