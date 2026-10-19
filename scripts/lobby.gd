extends Control
## Lobby für Netzwerk-Rennen (LAN und Internet).
## Links: Name, Spieler an diesem Rechner, Spiel eröffnen, gefundene Spiele, direkt verbinden.
## Rechts: die Regatta, in der man gerade ist – Mitsegler, Bahn & Wetter (stellt der Host ein), Start.

const INK := UIStyle.INK
const BLUE := UIStyle.BLUE
const MAGENTA := UIStyle.MAGENTA
const BOAT_COLORS := [Color(0.85, 0.18, 0.15), Color(0.15, 0.4, 0.85), Color(0.12, 0.6, 0.3), Color(0.95, 0.55, 0.1)]

var _name_edit: LineEdit
var _count_btn: Button
var _host_btn: Button
var _games_box: VBoxContainer
var _addr_edit: LineEdit
var _join_btn: Button
var _back_btn: Button
var _status: Label
var _right: VBoxContainer
var _levels := PackedStringArray()
var _level_names := {}


func _ready() -> void:
	Sfx.ensure(get_tree())
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UIStyle.make_theme()
	_levels = GameState.list_levels()
	for p in _levels:
		var inst: Level = load(p).instantiate()
		_level_names[p] = inst.level_name
		inst.free()
	_build_left()
	_right = VBoxContainer.new()
	_right.position = Vector2(712, 132)
	_right.size = Vector2(760, 660)
	_right.add_theme_constant_override("separation", 6)
	add_child(_right)
	_status = Label.new()
	_status.position = Vector2(80, 836)
	_status.size = Vector2(1440, 30)
	_status.add_theme_font_override("font", SeaChart.font(true))
	_status.add_theme_font_size_override("font_size", 18)
	_status.add_theme_color_override("font_color", MAGENTA)
	add_child(_status)

	Net.status.connect(_on_status)
	Net.lobby_changed.connect(_refresh)
	Net.games_changed.connect(_refresh_games)
	if GameState.status_message != "":
		_on_status(GameState.status_message)
		GameState.status_message = ""
	_refresh()
	_refresh_games()
	_host_btn.grab_focus()


func _exit_tree() -> void:
	Net.stop_listening()


func _draw() -> void:
	var vs := get_viewport_rect().size
	UIStyle.draw_paper(self, vs)
	draw_string(SeaChart.font(false, true), Vector2(80, 128), "MEHRSPIELER", HORIZONTAL_ALIGNMENT_LEFT, -1, 64, INK)
	draw_string(SeaChart.font(true), Vector2(84, 166), "LAN & Internet · bis zu 4 Boote · je Rechner 1–2 Skipper", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, BLUE)
	var card := Rect2(680, 100, 820, 720)
	draw_rect(card.grow(6), Color.WHITE)
	draw_rect(card, Color(UIStyle.PAPER, 1.0))
	draw_rect(card, INK, false, 2.0)
	draw_rect(card.grow(6), INK, false, 1.0)


# ---------------------------------------------------------------- linke Spalte

func _build_left() -> void:
	var col := VBoxContainer.new()
	col.position = Vector2(80, 196)
	col.size = Vector2(540, 620)
	col.add_theme_constant_override("separation", 9)
	add_child(col)

	col.add_child(UIStyle.heading("Dein Name"))
	_name_edit = LineEdit.new()
	_name_edit.text = GameState.player_name
	_name_edit.max_length = 14
	_name_edit.custom_minimum_size = Vector2(500, 42)
	_name_edit.text_changed.connect(func(t: String):
		GameState.player_name = t.strip_edges() if t.strip_edges() != "" else "Skipper"
		Net.my_name = GameState.player_name)
	col.add_child(_name_edit)
	Net.my_name = GameState.player_name

	_count_btn = Button.new()
	_count_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_count_btn.custom_minimum_size = Vector2(500, 42)
	_count_btn.pressed.connect(_cycle_count)
	_count_btn.gui_input.connect(func(ev: InputEvent):
		if ev.is_action_pressed("ui_left") or ev.is_action_pressed("ui_right"):
			_cycle_count()
			_count_btn.accept_event())
	col.add_child(_count_btn)

	_host_btn = Button.new()
	_host_btn.text = "Spiel eröffnen"
	_host_btn.custom_minimum_size = Vector2(500, 50)
	UIStyle.style_primary(_host_btn, 24)
	_host_btn.pressed.connect(func(): Net.host())
	col.add_child(_host_btn)

	col.add_child(_spacer(6))
	col.add_child(UIStyle.heading("Offene Spiele im Netzwerk"))
	_games_box = VBoxContainer.new()
	_games_box.add_theme_constant_override("separation", 6)
	_games_box.custom_minimum_size = Vector2(500, 120)
	col.add_child(_games_box)

	col.add_child(UIStyle.heading("Direkt verbinden (Internet)"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_addr_edit = LineEdit.new()
	_addr_edit.placeholder_text = "IP-Adresse des Hosts"
	_addr_edit.custom_minimum_size = Vector2(340, 42)
	_addr_edit.text_submitted.connect(func(_t): Net.join(_addr_edit.text))
	row.add_child(_addr_edit)
	_join_btn = Button.new()
	_join_btn.text = "Beitreten"
	_join_btn.custom_minimum_size = Vector2(150, 42)
	_join_btn.pressed.connect(func(): Net.join(_addr_edit.text))
	row.add_child(_join_btn)
	col.add_child(row)

	col.add_child(_spacer(6))
	_back_btn = Button.new()
	_back_btn.text = "Zurück zum Menü"
	_back_btn.custom_minimum_size = Vector2(500, 42)
	_back_btn.pressed.connect(_back)
	col.add_child(_back_btn)
	_update_count_label()


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	return c


func _cycle_count() -> void:
	Net.set_local_players(2 if Net.local_players == 1 else 1)
	_update_count_label()


func _update_count_label() -> void:
	_count_btn.text = "Skipper an diesem Rechner:   ◀  %d  ▶" % Net.local_players


func _back() -> void:
	Net.leave()
	get_tree().change_scene_to_file(Net.MENU_SCENE)


func _on_status(text: String) -> void:
	_status.text = text


func _refresh_games() -> void:
	for c in _games_box.get_children():
		c.queue_free()
	if Net.is_online():
		var l := Label.new()
		l.text = "(du bist bereits in einer Regatta)"
		l.add_theme_color_override("font_color", Color(INK, 0.5))
		_games_box.add_child(l)
		return
	if Net.found_games.is_empty():
		var l := Label.new()
		l.text = "Suche im LAN … noch nichts gefunden"
		l.add_theme_font_override("font", SeaChart.font(true))
		l.add_theme_color_override("font_color", Color(INK, 0.55))
		_games_box.add_child(l)
		return
	for key in Net.found_games:
		var g: Dictionary = Net.found_games[key]
		var b := Button.new()
		var lvl: String = _level_names.get(g.get("level", ""), "?")
		var full: bool = int(g["boats"]) >= int(g["max"]) or not bool(g["open"])
		b.text = "⚓  %s  ·  %s  ·  %d/%d Boote%s" % [g["name"], lvl, int(g["boats"]), int(g["max"]), "  (voll/läuft)" if full else ""]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(500, 40)
		b.disabled = full
		var addr := "%s:%d" % [g["ip"], int(g["port"])]
		b.pressed.connect(func(): Net.join(addr))
		_games_box.add_child(b)


# ---------------------------------------------------------------- rechte Seite

func _refresh() -> void:
	var online := Net.is_online()
	_host_btn.disabled = online
	_join_btn.disabled = online
	_addr_edit.editable = not online
	_name_edit.editable = not online
	if online:
		Net.stop_listening()
	else:
		Net.start_listening()
	_refresh_games()
	for c in _right.get_children():
		c.queue_free()
	if not online:
		_build_help()
	elif Net.players.is_empty():
		_right.add_child(_big_label("Verbinde …"))
	else:
		_build_room()


func _big_label(text: String, size := 30) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", SeaChart.font(false, true))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _small_label(text: String, italic := true, col := INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", SeaChart.font(italic))
	l.add_theme_font_size_override("font_size", 17)
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 740
	return l


func _build_help() -> void:
	_right.add_child(_big_label("So geht's"))
	_right.add_child(_small_label(
		"Im selben Netzwerk (LAN/WLAN):\n" +
		"  Einer klickt „Spiel eröffnen“. Bei allen anderen erscheint das Spiel links unter " +
		"„Offene Spiele“ – einfach anklicken.", false))
	_right.add_child(_small_label(
		"Übers Internet:\n" +
		"  Der Host gibt im Router den Port %d (UDP) für seinen Rechner frei und schickt den " % Net.GAME_PORT +
		"anderen seine öffentliche IP-Adresse (z. B. über eine „Wie ist meine IP“-Seite). " +
		"Die anderen tragen sie unter „Direkt verbinden“ ein.", false))
	_right.add_child(_small_label(
		"Pro Rechner können 1 oder 2 Skipper mitsegeln (Tastatur oder Controller), " +
		"insgesamt bis zu %d Boote. Der Host wählt Bahn und Wetter und startet das Rennen." % Net.MAX_BOATS, false))
	_right.add_child(_small_label("Alle brauchen dieselbe Spielversion und dieselben Bahnen im Ordner levels/.", true, BLUE))


func _build_room() -> void:
	var host_name: String = Net.players.get(1, {"name": "?"})["name"]
	_right.add_child(_big_label("Regatta von %s" % host_name, 28))

	# Mitsegler
	_right.add_child(UIStyle.heading("Mitsegler (%d/%d Boote)" % [Net.boat_count(), Net.MAX_BOATS]))
	var slots := Net.build_slots()
	for i in Net.MAX_BOATS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var sw := ColorRect.new()
		sw.custom_minimum_size = Vector2(22, 22)
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 18)
		if i < slots.size():
			var s: Dictionary = slots[i]
			sw.color = BOAT_COLORS[i]
			var tags := []
			if s.get("bot", false):
				tags.append(AIInput.NAMES[int(s["ai"])].to_lower())
			elif int(s["peer"]) == 1:
				tags.append("Host")
			if int(s["peer"]) == Net.my_id() and not s.get("bot", false):
				tags.append("du")
			l.text = s["name"] + ("   (" + ", ".join(tags) + ")" if tags.size() > 0 else "")
		else:
			sw.color = Color(INK, 0.1)
			l.text = "– frei –"
			l.add_theme_color_override("font_color", Color(INK, 0.4))
		row.add_child(sw)
		row.add_child(l)
		_right.add_child(row)

	# Bahn und Wetter
	_right.add_child(_spacer(4))
	_right.add_child(UIStyle.heading("Bahn & Wetter" + ("" if Net.is_host() else "  (stellt der Host ein)")))
	var lvl_path: String = Net.settings.get("level", "")
	var lvl_btn := _setting_button("Bahn:   ◀  %s  ▶" % _level_names.get(lvl_path, lvl_path.get_file()), func(d: int):
		var i := _levels.find(lvl_path)
		Net.set_setting("level", _levels[wrapi(i + d, 0, _levels.size())]))
	var w := int(Net.settings.get("wind", 0))
	var wind_btn := _setting_button("Windstärke:   ◀  %s  ▶" % GameState.WIND_OPTIONS[w][0], func(d: int):
		Net.set_setting("wind", wrapi(w + d, 0, GameState.WIND_OPTIONS.size())))
	var g := int(Net.settings.get("gust", 0))
	var gust_btn := _setting_button("Böen & Dreher:   ◀  %s  ▶" % GameState.GUST_OPTIONS[g][0], func(d: int):
		Net.set_setting("gust", wrapi(g + d, 0, GameState.GUST_OPTIONS.size())))
	var bots := int(Net.settings.get("bots", 0))
	var free := Net.MAX_BOATS - Net.human_boats()
	var bots_btn := _setting_button("Computergegner:   ◀  %d  ▶   (frei: %d)" % [bots, free], func(d: int):
		Net.set_setting("bots", wrapi(bots + d, 0, free + 1)))
	var ai := int(Net.settings.get("ai", 1))
	var ai_btn := _setting_button("Computer-Stärke:   ◀  %s  ▶" % AIInput.NAMES[ai], func(d: int):
		Net.set_setting("ai", wrapi(ai + d, 0, AIInput.NAMES.size())))
	_right.add_child(lvl_btn)
	_right.add_child(wind_btn)
	_right.add_child(gust_btn)
	var fu := int(Net.settings.get("fuel", 0))
	var fuel_btn := _setting_button("Treibstoff:   ◀  %s  ▶" % GameState.FUEL_OPTIONS[fu][0], func(d: int):
		Net.set_setting("fuel", wrapi(fu + d, 0, GameState.FUEL_OPTIONS.size())))
	_right.add_child(fuel_btn)
	_right.add_child(bots_btn)
	_right.add_child(ai_btn)

	_right.add_child(_spacer(6))
	if Net.is_host():
		var start := Button.new()
		start.text = "Rennen starten"
		start.custom_minimum_size = Vector2(740, 50)
		UIStyle.style_primary(start, 28)
		start.pressed.connect(func(): Net.start_race())
		_right.add_child(start)
		var ips := Net.local_ips()
		_right.add_child(_small_label("Im LAN findet man dich automatisch%s.  Übers Internet: Port %d (UDP) im Router freigeben und die öffentliche IP weitergeben." % [
			(" (Adresse " + ", ".join(ips) + ")") if ips.size() > 0 else "", Net.GAME_PORT], true, BLUE))
		start.grab_focus()
	else:
		_right.add_child(_big_label("Warte auf den Host …", 24))
	var leave := Button.new()
	leave.text = "Regatta verlassen"
	leave.custom_minimum_size = Vector2(300, 36)
	leave.pressed.connect(func():
		Net.leave()
		_on_status("Regatta verlassen"))
	_right.add_child(leave)


func _setting_button(text: String, change: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(740, 36)
	b.add_theme_font_size_override("font_size", 18)
	b.disabled = not Net.is_host()
	b.pressed.connect(func(): change.call(1))
	b.gui_input.connect(func(ev: InputEvent):
		if ev.is_action_pressed("ui_left") or ev.is_action_pressed("ui_right"):
			change.call(1 if ev.is_action_pressed("ui_right") else -1)
			b.accept_event())
	return b
