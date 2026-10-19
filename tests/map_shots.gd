extends SceneTree
## Rendert von jeder Bahn die ganze Karte senkrecht von oben (Norden oben), ohne Boote und HUD,
## zugeschnitten auf das Regattagebiet mit etwas Rand.
## Aufruf (mit Grafik): godot --path . --resolution 1600x1000 --script res://tests/map_shots.gd -- <ausgabeordner>
## Die Dateien heißen map_<Dateiname der Bahn>.png.

var _out := "user://"
var _levels := PackedStringArray()
var _i := 0
var _frame := 0
var _main: Node
var _center := Vector2.ZERO
var _h := 1.0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	_levels = GameState.list_levels()
	_load()


func _load() -> void:
	if _main:
		_main.queue_free()
	GameState.net_mode = ""
	GameState.level_path = _levels[_i]
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)
	_frame = 0


func _process(_d: float) -> bool:
	_frame += 1
	if _frame == 5:
		var vs := root.get_visible_rect().size
		var b: Rect2 = _main.level.map_bounds(40.0)
		var want := vs.x / vs.y
		var h := maxf(b.size.y, b.size.x / want)         # Höhe, bei der die Bahn ins Bild passt
		_center = b.get_center()
		_h = h
		var cams = _main.cams
		cams.set_process(false)
		cams._containers[1].visible = false
		cams._containers[0].size = vs
		cams._divider.visible = false
		var cam: Camera3D = cams._cameras[0]
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = h
		cam.far = 4000.0
		cam.position = Vector3(b.get_center().x, 2000.0, b.get_center().y)
		cam.rotation_degrees = Vector3(-90.0, 0.0, 0.0)  # senkrecht nach unten, Norden (−z) oben
		_main.hud.visible = false
		for boat in _main.boats:
			boat.visible = false
	if _frame == 60:
		var name := _levels[_i].get_file().get_basename()
		var img := root.get_texture().get_image()
		# auf das Regattagebiet (plus 30 m Rand) zuschneiden
		var vs := Vector2(img.get_size())
		var scale := vs.y / _h                              # Pixel je Meter
		var area: Rect2 = _main.level.race_area().grow(30.0)
		var tl := (area.position - _center) * scale + vs * 0.5
		var br := (area.end - _center) * scale + vs * 0.5
		var crop := Rect2i(Vector2i(tl.max(Vector2.ZERO)), Vector2i((br.min(vs) - tl.max(Vector2.ZERO)).ceil()))
		img.get_region(crop).save_png(_out.path_join("map_%s.png" % name))
		print("saved ", name)
		_i += 1
		if _i >= _levels.size():
			return true
		_load()
	return false
