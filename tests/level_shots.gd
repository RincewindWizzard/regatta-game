extends SceneTree
## Rendert Übersichtsbilder von Leveln aus freier Kameraposition.
## Aufruf: godot --path . --script res://tests/level_shots.gd -- <ausgabeordner>

const SHOTS := [
	["res://levels/07_flussregatta.tscn", Vector2(10, -20), 640.0, 80.0, "lvl_fluss.png"],
	["res://levels/07_flussregatta.tscn", Vector2(30, -20), 170.0, 62.0, "lvl_fluss_mitte.png"],
	["res://levels/05_lotsenrinne.tscn", Vector2(285, -360), 70.0, 55.0, "lvl_tankstelle.png"],
	["res://levels/01_mittelgrund.tscn", Vector2(12, -245), 160.0, 65.0, "lvl_strom.png"],
]

var _out := "user://"
var _i := 0
var _frame := 0
var _main: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	_load()


func _load() -> void:
	if _main:
		_main.queue_free()
	GameState.net_mode = ""
	GameState.level_path = SHOTS[_i][0]
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)
	_frame = 0


func _process(_d: float) -> bool:
	_frame += 1
	var shot: Array = SHOTS[_i]
	if _frame == 5:
		var cams = _main.cams
		cams.set_process(false)
		cams._containers[1].visible = false
		cams._containers[0].size = root.get_visible_rect().size
		cams._divider.visible = false
		var cam: Camera3D = cams._cameras[0]
		var t := Vector3(shot[1].x, 0, shot[1].y)
		var p := deg_to_rad(shot[3])
		cam.position = t + Vector3(0, sin(p), cos(p)) * shot[2]
		cam.look_at(t, Vector3.UP)
		_main.hud.visible = false
	if _frame == 40:
		root.get_texture().get_image().save_png(_out.path_join(shot[4]))
		print("saved ", shot[4])
		_i += 1
		if _i >= SHOTS.size():
			return true
		_load()
	return false
