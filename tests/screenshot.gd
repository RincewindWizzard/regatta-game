extends SceneTree
## Rendert Testbilder: gemeinsame Kamera, Splitscreen und Schlepper-Einsatz.
## Aufruf (mit Grafik): godot --path . --script res://tests/screenshot.gd -- <ausgabeordner>

var _main: Node
var _frame := 0
var _out := "user://"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_frame += 1
	var b0: Node3D = _main.boats[0]
	var b1: Node3D = _main.boats[1]
	if _frame == 30:
		_main.countdown = 0.0
		for b in _main.boats:
			b.sheet = 0.25
	if _frame == 60:
		_save("shot_merged.png")
		b1.position = Vector3(-150, 0, -250)
		b0.position = Vector3(20, 0, -40)
	if _frame == 61:
		_save("shot_split.png")
		# Boot 1 am Rand des Mittelgrunds festsetzen, Schlepper in der Nähe
		b1.position = Vector3(-60, 0, -228)
		b1.vel = Vector2.ZERO
		b1.stuck_time = 10.0
	if _frame == 64 and b1.tug != null:
		var tp: Vector2 = b1.pos2d() + Vector2(14, 12)
		b1.tug.position = Vector3(tp.x, 0, tp.y)
	if _frame == 150:
		_save("shot_tug.png")
		return true
	return false


func _save(name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(_out.path_join(name))
	print("saved ", name)
