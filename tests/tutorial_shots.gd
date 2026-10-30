extends SceneTree
## Bilder der Segelschule (mit Grafik): Anleitung, Fortschritt, Mann über Bord, Abschluss.
## Aufruf: godot --path . --script res://tests/tutorial_shots.gd -- <ausgabeordner>
var _main: Node
var _frame := 0
var _out := "user://"


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		_out = a[0]
	GameState.net_mode = ""
	GameState.level_path = "res://levels/09_segelschule.tscn"
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)


func _shot(name: String) -> void:
	root.get_texture().get_image().save_png(_out.path_join(name))
	print("saved ", name)


func _process(_d: float) -> bool:
	_frame += 1
	var tut: Tutorial = _main.tutorial
	var b: Boat = _main.boats[0]
	if _frame == 90:
		tut.progress = 0.55
		tut.hint = "Zu hoch am Wind (38°): etwas abfallen."
		_shot("tutorial_aufgabe.png")
	if _frame == 100:
		tut.index = 5
		tut.progress = 0.4
		tut.hint = ""
		tut.flash = 0.0
		tut._eight_stage = 0
	if _frame == 130:
		_shot("tutorial_achten.png")
	if _frame == 140:
		tut.index = 7
		tut.flash = 0.0
		b.heading = deg_to_rad(120.0)
		tut._drop_mob()
	if _frame == 190:
		tut.flash = 0.0
		_shot("tutorial_mob.png")
	if _frame == 200:
		tut.done = true
		tut.done_time = 245.0
		_main.state = "finished"
	if _frame == 230:
		_shot("tutorial_ende.png")
		quit()
		return true
	return false
