extends SceneTree
## Nahaufnahme eines Punktes in einem Level (Spielkamera-Winkel).
## Aufruf: godot --path . --script res://tests/closeup.gd -- <ordner> <level> <x> <z> <abstand> <datei> [neigung]

var _out := "user://"
var _main: Node
var _frame := 0
var _args: PackedStringArray


func _initialize() -> void:
	_args = OS.get_cmdline_user_args()
	_out = _args[0]
	GameState.net_mode = ""
	GameState.level_path = _args[1]
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)


func _process(_d: float) -> bool:
	_frame += 1
	if _frame == 5:
		var cams = _main.cams
		cams.set_process(false)
		cams._containers[1].visible = false
		cams._containers[0].size = root.get_visible_rect().size
		cams._divider.visible = false
		var cam: Camera3D = cams._cameras[0]
		var t := Vector3(float(_args[2]), 0, float(_args[3]))
		var dist := float(_args[4])
		var p := deg_to_rad(float(_args[6]) if _args.size() > 6 else 68.0)
		cam.position = t + Vector3(0, sin(p), cos(p)) * dist
		cam.look_at(t, Vector3.UP)
		_main.hud.visible = false
	if _frame == 30:
		root.get_texture().get_image().save_png(_out.path_join(_args[5]))
		print("saved ", _args[5])
		return true
	return false
