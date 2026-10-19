extends SceneTree
## Screenshots: Startmenü und ein Rennstart auf Level 3.
## Aufruf (mit Grafik): godot --path . --script res://tests/menu_shot.gd -- <ausgabeordner>

var _frame := 0
var _out := "user://"
var _main: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	GameState.level_path = "res://levels/06_schaerengarten.tscn"
	GameState.crew_choice = 2
	root.add_child(load("res://scenes/menu.tscn").instantiate())


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 40:
		_save("shot_menu.png")
		for c in root.get_children():
			if c.name == "Menu":
				c.queue_free()
		_main = load("res://scenes/main.tscn").instantiate()
		root.add_child(_main)
	if _frame == 60 and _main:
		_main.countdown = 0.0
	if _frame == 45:
		_save("shot_level3.png")
		return true
	return false


func _save(name: String) -> void:
	root.get_texture().get_image().save_png(_out.path_join(name))
	print("saved ", name)
