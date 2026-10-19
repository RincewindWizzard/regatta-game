extends Control
## Startmenü im Seekarten-Stil: Bahn wählen, Wind und Böen einstellen, Leinen los.
## Bedienung mit Maus, Tastatur (Pfeile/Enter) oder Controller (Steuerkreuz/A).

const PAPER := Color(0.985, 0.975, 0.94)
const PAPER_DARK := Color(0.94, 0.92, 0.86)
const INK := Color(0.08, 0.08, 0.1)
const MAGENTA := Color(0.78, 0.12, 0.55)
const BLUE := Color(0.15, 0.3, 0.5)
const GAME_SCENE := "res://scenes/main.tscn"

var _levels := PackedStringArray()
var _info := {}            # Pfad -> {name, desc, wind, gusts, length, marks, image, bounds, pts}
var _selected := 0
var _level_buttons: Array[Button] = []
var _wind_btn: Button
var _gust_btn: Button
var _crew_btn: Button
var _ai_btn: Button
var _fuel_btn: Button
var _music_btn: Button
var _start_btn: Button
var _net_btn: Button
var _preview: Control
var _desc: Label
var _facts: Label
var _title_font: Font
var _font: Font
var _font_b: Font
var _font_i: Font
var _t := 0.0


func _ready() -> void:
	Sfx.ensure(get_tree())
	if not Input.joy_connection_changed.is_connected(_on_joy):
		Input.joy_connection_changed.connect(_on_joy)
	for id in Input.get_connected_joypads():
		print("Joypad %d: %s  (GUID %s, bekannt: %s)" % [id, Input.get_joy_name(id), Input.get_joy_guid(id), Input.is_joy_known(id)])
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_font = SeaChart.font(false, true)
	_font = SeaChart.font()
	_font_b = SeaChart.font(false, true)
	_font_i = SeaChart.font(true)
	theme = _make_theme()
	_levels = GameState.list_levels()
	for p in _levels:
		_info[p] = _read_level(p)
	_selected = maxi(0, _levels.find(GameState.current_level_path()))
	_build_ui()
	_select(_selected)
	if _level_buttons.size() > 0:
		_level_buttons[_selected].grab_focus()
	else:
		_start_btn.grab_focus()
	await get_tree().process_frame
	await get_tree().process_frame
	_update_labels()


func _on_joy(id: int, connected: bool) -> void:
	print("Joypad %d %s: %s  (GUID %s, bekannt: %s)" % [id, "verbunden" if connected else "getrennt",
		Input.get_joy_name(id), Input.get_joy_guid(id), Input.is_joy_known(id)])


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _preview:
		_preview.queue_redraw()


# ---------------------------------------------------------------- Level einlesen

func _read_level(path: String) -> Dictionary:
	var lvl: Level = load(path).instantiate()
	add_child(lvl)                       # damit globale Positionen stimmen
	lvl.visible = false
	var bounds := lvl.map_bounds(90.0)
	# Seitenverhältnis der Vorschau (4:3)
	var want := 4.0 / 3.0
	if bounds.size.x / bounds.size.y < want:
		bounds = bounds.grow_individual((bounds.size.y * want - bounds.size.x) * 0.5, 0, (bounds.size.y * want - bounds.size.x) * 0.5, 0)
	else:
		bounds = bounds.grow_individual(0, (bounds.size.x / want - bounds.size.y) * 0.5, 0, (bounds.size.x / want - bounds.size.y) * 0.5)
	SeaChart.set_depth_grid(lvl.compute_depth(160), 160)
	var img := SeaChart.make_map_image(bounds.position, bounds.end, 240, 180)
	var marks: Array = []
	for m in lvl.marks():
		marks.append(m.pos2d())
	var line := lvl.start_line()
	var info := {
		"name": lvl.level_name,
		"desc": lvl.description,
		"wind_from": lvl.wind_from_deg,
		"fuel": lvl.fuel_liters,
		"docks": lvl.fuel_docks().size(),
		"dock_pos": lvl.fuel_docks().map(func(d): return d.berth()),
		"zones": lvl.danger_zones(),
		"wind": lvl.wind_speed,
		"gusts": lvl.gusts,
		"shift": lvl.wind_shift_deg,
		"length": Course.course_length(lvl),
		"marks": marks,
		"line_a": line.center2d() - line.tangent2d() * line.half_width if line else Vector2.ZERO,
		"line_b": line.center2d() + line.tangent2d() * line.half_width if line else Vector2.ZERO,
		"bounds": bounds,
		"tex": ImageTexture.create_from_image(img),
	}
	lvl.queue_free()
	return info


# ---------------------------------------------------------------- Aufbau

func _build_ui() -> void:
	var left := VBoxContainer.new()
	left.position = Vector2(80, 36)
	left.size = Vector2(520, 780)
	left.add_theme_constant_override("separation", 5)
	add_child(left)

	left.add_child(_spacer(124))     # Platz für den gezeichneten Titel

	left.add_child(_heading("Bahn wählen"))
	for i in _levels.size():
		var b := Button.new()
		b.text = "  %d.  %s" % [i + 1, _info[_levels[i]]["name"]]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(480, 32)
		b.add_theme_font_size_override("font_size", 18)
		var idx := i
		b.pressed.connect(func(): _select(idx))
		b.focus_entered.connect(func(): _select(idx))
		left.add_child(b)
		_level_buttons.append(b)

	left.add_child(_spacer(4))
	left.add_child(_heading("Mitsegler & Wetter"))
	_crew_btn = _selector_button(func(d: int):
		GameState.crew_choice = wrapi(GameState.crew_choice + d, 0, GameState.CREW_OPTIONS.size())
		_update_labels())
	left.add_child(_crew_btn)
	_ai_btn = _selector_button(func(d: int):
		GameState.ai_level = wrapi(GameState.ai_level + d, 0, AIInput.NAMES.size())
		_update_labels())
	left.add_child(_ai_btn)
	_wind_btn = _selector_button(_cycle_wind)
	left.add_child(_wind_btn)
	_gust_btn = _selector_button(_cycle_gust)
	left.add_child(_gust_btn)
	_fuel_btn = _selector_button(func(d: int):
		GameState.fuel_choice = wrapi(GameState.fuel_choice + d, 0, GameState.FUEL_OPTIONS.size())
		_update_labels())
	left.add_child(_fuel_btn)

	left.add_child(_spacer(8))
	_start_btn = Button.new()
	_start_btn.text = "Leinen los!"
	_start_btn.custom_minimum_size = Vector2(480, 54)
	_start_btn.add_theme_font_size_override("font_size", 30)
	_start_btn.add_theme_color_override("font_color", Color.WHITE)
	_start_btn.add_theme_color_override("font_focus_color", Color.WHITE)
	_start_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	_start_btn.add_theme_stylebox_override("normal", _box(MAGENTA.darkened(0.1), INK, 2))
	_start_btn.add_theme_stylebox_override("hover", _box(MAGENTA, INK, 2))
	_start_btn.add_theme_stylebox_override("focus", _box(MAGENTA, INK, 4))
	_start_btn.add_theme_stylebox_override("pressed", _box(MAGENTA.darkened(0.3), INK, 2))
	_start_btn.pressed.connect(_start)
	left.add_child(_start_btn)

	_net_btn = Button.new()
	_net_btn.text = "Mehrspieler  (LAN / Internet)"
	_net_btn.custom_minimum_size = Vector2(480, 40)
	_net_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/lobby.tscn"))
	left.add_child(_net_btn)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.position = Vector2(1030, 46)
	_music_btn = Button.new()
	_music_btn.custom_minimum_size = Vector2(235, 36)
	_music_btn.pressed.connect(func():
		Sfx.toggle_music()
		_update_labels())
	row.add_child(_music_btn)
	var quit := Button.new()
	quit.text = "Beenden"
	quit.custom_minimum_size = Vector2(235, 36)
	quit.pressed.connect(func(): get_tree().quit())
	row.add_child(quit)
	add_child(row)

	# rechte Seite: Kartenvorschau und Beschreibung
	_preview = Control.new()
	_preview.position = Vector2(680, 110)
	_preview.size = Vector2(820, 615)
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview.draw.connect(_draw_preview)
	add_child(_preview)
	_desc = Label.new()
	_desc.position = Vector2(680, 735)
	_desc.size = Vector2(820, 60)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.add_theme_font_override("font", _font_i)
	_desc.add_theme_font_size_override("font_size", 19)
	_desc.add_theme_color_override("font_color", INK)
	add_child(_desc)
	_facts = Label.new()
	_facts.position = Vector2(680, 800)
	_facts.size = Vector2(820, 30)
	_facts.add_theme_font_override("font", _font_b)
	_facts.add_theme_font_size_override("font_size", 16)
	_facts.add_theme_color_override("font_color", BLUE)
	add_child(_facts)

	# Fokus-Kette für Controller
	var chain: Array[Control] = []
	chain.append_array(_level_buttons)
	chain.append_array([_crew_btn, _ai_btn, _wind_btn, _gust_btn, _fuel_btn, _start_btn, _net_btn, _music_btn])
	for i in chain.size():
		chain[i].focus_neighbor_bottom = chain[(i + 1) % chain.size()].get_path()
		chain[i].focus_neighbor_top = chain[(i - 1 + chain.size()) % chain.size()].get_path()
	_update_labels()


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	return c


func _heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _font_i)
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", BLUE)
	return l


## Auswahlknopf: Klick/Enter = weiter, links/rechts = blättern
func _selector_button(change: Callable) -> Button:
	var b := Button.new()
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(480, 36)
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(func(): change.call(1))
	b.gui_input.connect(func(ev: InputEvent):
		if ev.is_action_pressed("ui_left") or ev.is_action_pressed("ui_right"):
			change.call(1 if ev.is_action_pressed("ui_right") else -1)
			b.accept_event())
	return b


func _box(bg: Color, border: Color, w: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(w)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb


func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = _font_b
	t.default_font_size = 20
	t.set_stylebox("normal", "Button", _box(PAPER, Color(INK, 0.5), 1))
	t.set_stylebox("hover", "Button", _box(PAPER_DARK, INK, 1))
	t.set_stylebox("pressed", "Button", _box(Color(0.86, 0.92, 0.97), INK, 2))
	t.set_stylebox("hover_pressed", "Button", _box(Color(0.86, 0.92, 0.97), INK, 2))
	t.set_stylebox("focus", "Button", _box(Color(1, 1, 1, 0), MAGENTA, 3))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, "Button", INK)
	t.set_color("font_color", "Label", INK)
	return t


# ---------------------------------------------------------------- Aktionen

func _select(i: int) -> void:
	if _levels.is_empty():
		return
	_selected = i
	GameState.level_path = _levels[i]
	for k in _level_buttons.size():
		_level_buttons[k].set_pressed_no_signal(k == i)
	var info: Dictionary = _info[_levels[i]]
	_desc.text = info["desc"]
	_update_labels()


func _cycle_wind(d: int) -> void:
	GameState.wind_choice = wrapi(GameState.wind_choice + d, 0, GameState.WIND_OPTIONS.size())
	_update_labels()


func _cycle_gust(d: int) -> void:
	GameState.gust_choice = wrapi(GameState.gust_choice + d, 0, GameState.GUST_OPTIONS.size())
	_update_labels()


func _update_labels() -> void:
	_crew_btn.text = "Besetzung:   ◀  %s  ▶" % GameState.CREW_OPTIONS[GameState.crew_choice][0]
	var bots := int(GameState.CREW_OPTIONS[GameState.crew_choice][2])
	_ai_btn.text = "Computer-Stärke:   ◀  %s  ▶" % AIInput.NAMES[GameState.ai_level]
	_ai_btn.modulate.a = 0.45 if bots == 0 else 1.0
	_fuel_btn.text = "Treibstoff:   ◀  %s  ▶" % GameState.FUEL_OPTIONS[GameState.fuel_choice][0]
	_wind_btn.text = "Windstärke:   ◀  %s  ▶" % GameState.WIND_OPTIONS[GameState.wind_choice][0]
	_gust_btn.text = "Böen & Dreher:   ◀  %s  ▶" % GameState.GUST_OPTIONS[GameState.gust_choice][0]
	_music_btn.text = "Musik: " + ("an" if Sfx.music_on() else "aus")
	if _levels.is_empty():
		return
	var info: Dictionary = _info[_levels[_selected]]
	var wind: float = info["wind"]
	var w: Array = GameState.WIND_OPTIONS[GameState.wind_choice]
	if w[1] > 0.0:
		wind = w[1]
	var fuel: float = GameState.FUEL_OPTIONS[GameState.fuel_choice][1]
	if fuel < 0.0:
		fuel = info["fuel"]
	_facts.text = "Bahnlänge %.2f sm   ·   %d Tonnen   ·   Wind aus %03d°, %d kn   ·   %s" % [
		float(info["length"]) / 1852.0, info["marks"].size(), roundi(info["wind_from"]), roundi(wind * 1.944),
		("Tank %d l, %d Tankstelle(n)" % [roundi(fuel), info["docks"]]) if fuel > 0.0 else "ohne Motor"]


func _start() -> void:
	if _levels.is_empty():
		return
	GameState.net_mode = ""
	GameState.level_path = _levels[_selected]
	Sfx.play("go", -6.0)
	get_tree().change_scene_to_file(GAME_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START:
		_start()
	elif event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		get_tree().quit()


# ---------------------------------------------------------------- Zeichnen

func _draw() -> void:
	var vs := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vs), PAPER)
	# feines Kartennetz
	var grid := Color(0.55, 0.6, 0.65, 0.18)
	var x := 0.0
	while x < vs.x:
		draw_line(Vector2(x, 0), Vector2(x, vs.y), grid, 1.0)
		x += 100.0
	var y := 0.0
	while y < vs.y:
		draw_line(Vector2(0, y), Vector2(vs.x, y), grid, 1.0)
		y += 100.0
	_draw_rose(Vector2(600, 96), 52.0)
	_draw_frame(vs)
	# Titel
	draw_string(_title_font, Vector2(80, 118), "REGATTA", HORIZONTAL_ALIGNMENT_LEFT, -1, 80, INK)
	draw_string(_font_i, Vector2(84, 152), "Zwei Skipper · ein Ziel · Seekarte 1 : 5 000", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, BLUE)
	# Steuerungshinweis
	var hint := "Spieler 1: A/D lenken · W/S Schoten · E/Q Gas      Spieler 2: J/L · I/K · O/U      Controller: Stick lenken · RT/LT Schoten · A/B Gas"

	draw_string(_font, Vector2(80, vs.y - 34), hint, HORIZONTAL_ALIGNMENT_LEFT, vs.x - 160, 15, Color(INK, 0.75))
	# erkannte Controller (hilft bei Verbindungsproblemen)
	var pads := PlayerInput.describe()
	var ok := not pads.begins_with("Kein")
	draw_string(_font_i, Vector2(680, 850), pads, HORIZONTAL_ALIGNMENT_LEFT, vs.x - 680 - 60, 15,
		Color(0.1, 0.45, 0.2) if ok else Color(0.7, 0.3, 0.0))


func _draw_frame(vs: Vector2) -> void:
	var w := 14.0
	var seg := 50.0
	for side in 4:
		var horizontal := side < 2
		var length := vs.x if horizontal else vs.y
		var k := 0
		var p := w
		while p < length - w:
			if k % 2 == 0:
				var l := minf(seg, length - w - p)
				match side:
					0: draw_rect(Rect2(p, 3, l, w - 6), INK)
					1: draw_rect(Rect2(p, vs.y - w + 3, l, w - 6), INK)
					2: draw_rect(Rect2(3, p, w - 6, l), INK)
					3: draw_rect(Rect2(vs.x - w + 3, p, w - 6, l), INK)
			p += seg
			k += 1
	draw_rect(Rect2(w, w, vs.x - 2 * w, vs.y - 2 * w), INK, false, 1.5)
	draw_rect(Rect2(0.5, 0.5, vs.x - 1, vs.y - 1), INK, false, 1.0)


func _draw_rose(c: Vector2, r: float) -> void:
	var col := Color(MAGENTA, 0.75)
	draw_arc(c, r, 0, TAU, 96, col, 1.5, true)
	draw_arc(c, r * 0.88, 0, TAU, 96, col, 1.0, true)
	for deg in range(0, 360, 5):
		var b := deg_to_rad(float(deg))
		var d := Vector2(sin(b), -cos(b))
		var len := 0.12 if deg % 30 == 0 else (0.07 if deg % 10 == 0 else 0.035)
		draw_line(c + d * r * 0.88, c + d * r * (0.88 + len), col, 1.0, true)
	var swing := sin(_t * 0.4) * 0.05
	var n := Vector2(sin(swing), -cos(swing))
	var e := Vector2(-n.y, n.x)
	draw_colored_polygon(PackedVector2Array([c + n * r * 0.8, c + e * r * 0.08, c - e * r * 0.08]), col)
	draw_colored_polygon(PackedVector2Array([c - n * r * 0.45, c + e * r * 0.06, c - e * r * 0.06]), Color(col, 0.5))
	draw_string(_font_b, c + n * r * 1.18 - Vector2(6, -5), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col)


func _draw_preview() -> void:
	if _levels.is_empty():
		_preview.draw_string(_font_i, Vector2(20, 40), "Keine Level in res://levels/ gefunden.", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, INK)
		return
	var info: Dictionary = _info[_levels[_selected]]
	var r := Rect2(Vector2.ZERO, _preview.size)
	_preview.draw_rect(r.grow(8), Color.WHITE)
	_preview.draw_texture_rect(info["tex"], r, false)
	_preview.draw_rect(r, INK, false, 2.0)
	_preview.draw_rect(r.grow(8), INK, false, 1.0)
	var b: Rect2 = info["bounds"]
	var to_p := func(p: Vector2) -> Vector2:
		return (p - b.position) / b.size * r.size
	# Kurslinie
	var pts: Array[Vector2] = []
	var la: Vector2 = info["line_a"]
	var lb: Vector2 = info["line_b"]
	var lc := (la + lb) * 0.5
	pts.append(lc)
	for m in info["marks"]:
		pts.append(m)
	pts.append(lc)
	for i in pts.size() - 1:
		_preview.draw_dashed_line(to_p.call(pts[i]), to_p.call(pts[i + 1]), Color(MAGENTA, 0.75), 2.0, 9.0)
	_preview.draw_line(to_p.call(la), to_p.call(lb), INK, 3.0)
	for i in info["marks"].size():
		var mp: Vector2 = to_p.call(info["marks"][i])
		var bob := sin(_t * 2.0 + i) * 1.5
		_preview.draw_circle(mp + Vector2(0, bob), 9.0, CourseMark.YELLOW)
		_preview.draw_arc(mp + Vector2(0, bob), 9.0, 0, TAU, 20, INK, 1.5)
		_preview.draw_string(_font_b, mp + Vector2(13, 6), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, INK)
	# Warngebiete (magenta gestrichelt) und Tankstellen (rote Zapfsäule)
	for z in info["zones"]:
		var zc: Vector2 = to_p.call(z["pos"])
		var zr: float = float(z["radius"]) / b.size.x * r.size.x
		_preview.draw_circle(zc, zr, Color(MAGENTA, 0.10))
		_preview.draw_arc(zc, zr, 0, TAU, 48, Color(MAGENTA, 0.9), 2.0, true)
		var zname: String = ["Minen", "Sperrgebiet", "Sirenen"][int(z["kind"])]
		_preview.draw_string(_font_b, zc + Vector2(-30, 5), zname, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, MAGENTA)
	for dp in info["dock_pos"]:
		var dc: Vector2 = to_p.call(dp)
		_preview.draw_circle(dc, 9.0, Color(0.85, 0.15, 0.12))
		_preview.draw_arc(dc, 9.0, 0, TAU, 20, INK, 1.5)
		_preview.draw_string(_font_b, dc + Vector2(-4, 5), "F", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
	# Windpfeil
	var from := deg_to_rad(float(info["wind_from"]))
	var blow := Vector2(-sin(from), cos(from))
	var wc := Vector2(r.size.x - 70, 70)
	_preview.draw_circle(wc, 46, Color(1, 1, 1, 0.85))
	_preview.draw_arc(wc, 46, 0, TAU, 48, MAGENTA, 1.5)
	_preview.draw_line(wc - blow * 30, wc + blow * 22, INK, 4.0, true)
	var side := Vector2(-blow.y, blow.x)
	_preview.draw_colored_polygon(PackedVector2Array([wc + blow * 34, wc + blow * 18 + side * 9, wc + blow * 18 - side * 9]), INK)
	_preview.draw_string(_font_b, wc + Vector2(-20, 64), "WIND", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, INK)
	# Titelfeld
	var title_r := Rect2(16, 16, 380, 48)
	_preview.draw_rect(title_r, Color(PAPER, 0.92))
	_preview.draw_rect(title_r, INK, false, 1.5)
	_preview.draw_string(_font_b, title_r.position + Vector2(14, 33), info["name"], HORIZONTAL_ALIGNMENT_LEFT, 360, 24, INK)
