extends SceneTree
## Nahaufnahme von Boot und Schlepper (zum Prüfen der Modelle).
## Aufruf (mit Grafik): godot --path . --script res://tests/showroom.gd -- <ausgabeordner>

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
	var b0 = _main.boats[0]
	var b1 = _main.boats[1]
	if _frame == 10:
		_main.countdown = 0.0
		b0.position = Vector3(-30, 0, -205)
		b0.heading = 2.2
		b0.sheet = 0.3
		b1.position = Vector3(-60, 0, -228)
		b1.vel = Vector2.ZERO
		b1.stuck_time = 10.0
	if _frame == 14 and b1.tug != null:
		b1.tug.position = Vector3(-45, 0, -218)
	if _frame == 60:
		_close_up(Vector3(-45, 0, -218), 34.0, 52.0)
	if _frame == 80:
		_save("showroom.png")
		return true
	return false


func _close_up(target: Vector3, dist: float, pitch_deg: float) -> void:
	var cams = _main.cams
	cams.set_process(false)
	cams._containers[1].visible = false
	var vs: Vector2 = root.get_visible_rect().size
	cams._containers[0].size = vs
	cams._divider.visible = false
	var cam: Camera3D = cams._cameras[0]
	var p := deg_to_rad(pitch_deg)
	cam.position = target + Vector3(-dist * 0.35, sin(p) * dist, cos(p) * dist)
	cam.look_at(target, Vector3.UP)


func _save(name: String) -> void:
	root.get_texture().get_image().save_png(_out.path_join(name))
	print("saved ", name)
