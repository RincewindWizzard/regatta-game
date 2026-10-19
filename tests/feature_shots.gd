extends SceneTree
## Rendert Bilder der Tiere, Wracks, Gefahrengebiete und des Segel-Overlays.
## Aufruf (mit Grafik): godot --path . --script res://tests/feature_shots.gd -- <ausgabeordner> [Filter]

const L1 := "res://levels/01_mittelgrund.tscn"
const L3 := "res://levels/03_rund_um_moewenhoern.tscn"
const L4 := "res://levels/04_hafenausfahrt.tscn"
const L6 := "res://levels/06_schaerengarten.tscn"

## [Level, Blickpunkt, Abstand, Neigung (Grad), Datei, Vorbereitung, Frame der Aufnahme]
var _shots := [
	[L1, Vector2(100, -470), 80.0, 62.0, "tuemmler.png", "dolphins", 30],
	[L1, Vector2(-280, -440), 120.0, 55.0, "wal.png", "whale", 30],
	[L1, Vector2(255, -270), 130.0, 60.0, "moewen.png", "", 30],
	[L1, Vector2(80, -230), 45.0, 60.0, "seehunde.png", "", 30],
	[L1, Vector2(140, 40), 70.0, 60.0, "wrack.png", "", 30],
	[L3, Vector2(330, -60), 190.0, 62.0, "minenfeld.png", "", 30],
	[L4, Vector2(-200, -60), 90.0, 62.0, "polizei_gebiet.png", "", 30],
	[L4, Vector2(-200, -60), 45.0, 55.0, "polizei_kontrolle.png", "police", 120],
	[L6, Vector2(-150, 385), 190.0, 62.0, "sireneninsel.png", "", 40],
	[L6, Vector2(-150, 320), 120.0, 58.0, "sirenengesang.png", "siren", 150],
	[L6, Vector2(-150, 80), 130.0, 60.0, "tankstelle_granholm.png", "", 30],
	[L1, Vector2(0, -20), 35.0, 60.0, "trimm_gut.png", "trim_good", 90],
	[L1, Vector2(0, -20), 35.0, 60.0, "trimm_schlecht.png", "trim_bad", 90],
	[L1, Vector2(0, -20), 55.0, 55.0, "explosion.png", "boom", 70],
]

var _out := "user://"
var _filter := ""
var _i := 0
var _frame := 0
var _main: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_filter = args[1]
	_next_valid()
	_load()


func _next_valid() -> void:
	while _i < _shots.size() and _filter != "" and not String(_shots[_i][4]).contains(_filter):
		_i += 1


func _load() -> void:
	if _main:
		_main.queue_free()
	GameState.net_mode = ""
	GameState.level_path = _shots[_i][0]
	GameState.crew_choice = 0
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)
	_frame = 0


func _life(node_name: String) -> SeaLife:
	return _main.level.get_node(node_name) as SeaLife


func _process(_d: float) -> bool:
	if _i >= _shots.size():
		return true
	_frame += 1
	var shot: Array = _shots[_i]
	var b: Boat = _main.boats[0]
	if _frame == 3:
		_main.countdown = 0.0
		_main.boats[1].position = Vector3(0, 0, 400)
		var focus: Vector2 = shot[1]
		match shot[5]:
			"dolphins":
				var d := _life("Tuemmler")
				d._t = 4.6 * 2 + 0.4
			"whale":
				var w := _life("Wal")
				w._critters[0]["off"] = 0.0
				w._t = 24.0 * 0.28
				w._critters[0]["prev"] = 0.27
			"police":
				b.position = Vector3(focus.x - 20, 0, focus.y)
				b.heading = PI / 2
				b.vel = Vector2.ZERO
			"siren":
				b.position = Vector3(-150, 0, 320)
				b.heading = 0.0
			"trim_good", "trim_bad", "boom":
				b.position = Vector3(0, 0, -30)
				b.heading = deg_to_rad(110.0)
		if shot[5] in ["trim_good", "trim_bad", "boom"]:
			b.local_human = true
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
	match shot[5]:
		"police":
			if _frame == 20:
				b.start_hold(1)
		"siren":
			if _frame == 20:
				b.start_hold(2, Vector2(-150, 385))
		"trim_good":
			b.sheet = clampf(b.sheet + (b.optimal_sheet() - b.sheet) * 0.2, 0.0, 1.0)
		"trim_bad":
			b.sheet = clampf(b.optimal_sheet() + 0.35, 0.0, 1.0)
		"boom":
			if _frame == 40:
				b.explode()
	if _frame == shot[6]:
		root.get_texture().get_image().save_png(_out.path_join(shot[4]))
		print("saved ", shot[4])
		_i += 1
		_next_valid()
		if _i >= _shots.size():
			return true
		_load()
	return false
