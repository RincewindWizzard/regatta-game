@tool
extends EditorPlugin
## Level-Editor für Regatta:
## - Werkzeugleiste "Seegrund" im 3D-Editor, sichtbar wenn ein Level ausgewählt ist
##   Pinsel: Flacher, Tiefer, Land, Glätten, Radierer; Größe und Stärke einstellbar.
##   Linke Maustaste malt. Jeder Strich lässt sich mit Strg+Z rückgängig machen.
## - Knöpfe zum Einfügen neuer Bausteine (Tonne, Untiefe, Insel, Kompassrose, Startlinie)

const BRUSHES := [
	["Aus", 0],
	["Flacher", 1],
	["Tiefer", 2],
	["Land", 3],
	["Glätten", 4],
	["Radierer", 5],
]

var _bar: HBoxContainer
var _brush_buttons: Array[Button] = []
var _radius: SpinBox
var _strength: SpinBox
var _level: Level
var _brush := 0
var _painting := false
var _before := PackedByteArray()
var _cursor_world := Vector3.ZERO
var _cursor_valid := false
var _camera: Camera3D


func _enter_tree() -> void:
	_bar = HBoxContainer.new()
	_bar.add_child(VSeparator.new())
	var title := Label.new()
	title.text = "Seegrund:"
	_bar.add_child(title)
	var group := ButtonGroup.new()
	for b in BRUSHES:
		var btn := Button.new()
		btn.text = b[0]
		btn.toggle_mode = true
		btn.button_group = group
		btn.flat = true
		btn.button_pressed = b[1] == 0
		var id: int = b[1]
		btn.pressed.connect(func(): _brush = id)
		_bar.add_child(btn)
		_brush_buttons.append(btn)
	_bar.add_child(_labelled_spin("Größe", 5, 200, 30, "m"))
	_radius = _bar.get_child(_bar.get_child_count() - 1).get_child(1) as SpinBox
	_bar.add_child(_labelled_spin("Stärke", 0.2, 5, 1, ""))
	_strength = _bar.get_child(_bar.get_child_count() - 1).get_child(1) as SpinBox
	_bar.add_child(VSeparator.new())
	var add := MenuButton.new()
	add.text = "+ Baustein"
	add.flat = false
	var pm := add.get_popup()
	pm.add_item("Bahnmarke (Tonne zum Runden)", 0)
	pm.add_item("Startlinie", 4)
	pm.add_separator("Seegrund")
	pm.add_item("Untiefe", 1)
	pm.add_item("Insel", 2)
	pm.add_item("Insel mit Bäumen und Häusern", 5)
	pm.add_separator("Seezeichen")
	pm.add_item("Kardinaltonne Nord", 10)
	pm.add_item("Kardinaltonne Ost", 11)
	pm.add_item("Kardinaltonne Süd", 12)
	pm.add_item("Kardinaltonne West", 13)
	pm.add_item("Einzelgefahrstelle", 14)
	pm.add_item("Fahrwassertonne rot", 15)
	pm.add_item("Fahrwassertonne grün", 16)
	pm.add_item("Ansteuerungstonne", 17)
	pm.add_item("Kardinaltonnen um ausgewählte Untiefe", 20)
	pm.add_separator("Wasser")
	pm.add_item("Strömung", 30)
	pm.add_item("Flusslauf (Kurve zeichnen)", 31)
	pm.add_item("See (Binnenrevier)", 32)
	pm.add_separator("Bauwerke")
	pm.add_item("Tankstelle", 33)
	pm.add_item("Felsmole mit Molenfeuer", 6)
	pm.add_item("Leuchtturm", 7)
	pm.add_item("Kompassrose", 3)
	pm.id_pressed.connect(_add_piece)
	_bar.add_child(add)
	var clear := Button.new()
	clear.text = "Gemalten Grund löschen"
	clear.flat = true
	clear.pressed.connect(_clear_paint)
	_bar.add_child(clear)
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, _bar)
	_bar.hide()


func _exit_tree() -> void:
	remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, _bar)
	_bar.queue_free()


func _labelled_spin(text: String, mn: float, mx: float, val: float, suffix: String) -> HBoxContainer:
	var box := HBoxContainer.new()
	var l := Label.new()
	l.text = text
	box.add_child(l)
	var s := SpinBox.new()
	s.min_value = mn
	s.max_value = mx
	s.step = 0.1 if mx < 10 else 1.0
	s.value = val
	s.suffix = suffix
	s.custom_minimum_size.x = 80
	box.add_child(s)
	return box


func _handles(object: Object) -> bool:
	return object is Level or object is ShoalArea or object is SeaMark or object is Mole or object is Lighthouse or object is CourseMark or object is CurrentArea or object is FuelDock


func _edit(object: Object) -> void:
	if object is Level:
		_level = object
	elif object is Node and object.get_parent() is Level:
		_level = object.get_parent()
	else:
		_level = null


func _make_visible(visible: bool) -> void:
	_bar.visible = visible
	if not visible:
		_painting = false
		_cursor_valid = false
		update_overlays()


# ---------------------------------------------------------------- Malen

func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	if _level == null or _brush == 0 or not is_instance_valid(_level):
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	_camera = camera
	if event is InputEventMouseMotion:
		_update_cursor(camera, event.position)
		if _painting and _cursor_valid:
			_level.paint(Vector2(_cursor_world.x, _cursor_world.z), _radius.value, _brush, _strength.value)
		update_overlays()
		return EditorPlugin.AFTER_GUI_INPUT_STOP if _painting else EditorPlugin.AFTER_GUI_INPUT_PASS
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_update_cursor(camera, event.position)
			if not _cursor_valid:
				return EditorPlugin.AFTER_GUI_INPUT_PASS
			_painting = true
			_before = _level.depth_paint_png
			_level.begin_stroke()
			_level.paint(Vector2(_cursor_world.x, _cursor_world.z), _radius.value, _brush, _strength.value)
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		elif _painting:
			_painting = false
			var after := _level.end_stroke()
			var ur := get_undo_redo()
			ur.create_action("Seegrund malen", UndoRedo.MERGE_DISABLE, _level)
			ur.add_do_property(_level, "depth_paint_png", after)
			ur.add_undo_property(_level, "depth_paint_png", _before)
			ur.commit_action()
			return EditorPlugin.AFTER_GUI_INPUT_STOP
	return EditorPlugin.AFTER_GUI_INPUT_PASS


func _update_cursor(camera: Camera3D, pos: Vector2) -> void:
	var o := camera.project_ray_origin(pos)
	var d := camera.project_ray_normal(pos)
	if absf(d.y) < 0.0001:
		_cursor_valid = false
		return
	var t := -o.y / d.y
	_cursor_valid = t > 0.0
	_cursor_world = o + d * t


func _forward_3d_draw_over_viewport(overlay: Control) -> void:
	if not _cursor_valid or _brush == 0 or _camera == null:
		return
	var pts := PackedVector2Array()
	for k in 49:
		var a := TAU * k / 48.0
		var w := _cursor_world + Vector3(cos(a), 0, sin(a)) * _radius.value
		if _camera.is_position_behind(w):
			return
		pts.append(_camera.unproject_position(w))
	var col := Color(0.2, 0.6, 1.0) if _brush != 3 else Color(0.9, 0.7, 0.2)
	overlay.draw_polyline(pts, col, 2.0, true)
	overlay.draw_string(ThemeDB.fallback_font, pts[0] + Vector2(6, 0), BRUSHES[_brush][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, col)


# ---------------------------------------------------------------- Bausteine einfügen

func _add_piece(id: int) -> void:
	var root := get_editor_interface().get_edited_scene_root()
	var lvl := root as Level
	if lvl == null:
		push_warning("Bitte zuerst eine Level-Szene öffnen (Wurzel-Node vom Typ Level).")
		return
	if id == 20:
		_cardinals_around_selection(lvl)
		return
	var node: Node3D
	match id:
		0:
			var m := CourseMark.new()
			m.name = "Tonne"
			m.mark_name = "Tonne %d" % (lvl.marks().size() + 1)
			node = m
		1:
			var s := ShoalArea.new()
			s.name = "Untiefe"
			node = s
		2:
			var s := ShoalArea.new()
			s.name = "Insel"
			s.kind = ShoalArea.Kind.INSEL
			s.area_name = "Insel"
			s.radius = 50.0
			s.rock_symbol = false
			node = s
		3:
			node = ChartRose.new()
			node.name = "Kompassrose"
		4:
			node = StartLine.new()
			node.name = "StartZiel"
		5:
			var s := ShoalArea.new()
			s.name = "Insel"
			s.kind = ShoalArea.Kind.INSEL
			s.area_name = "Insel"
			s.radius = 60.0
			s.rock_symbol = false
			s.trees = 25
			s.houses = 3
			node = s
		6:
			node = Mole.new()
			node.name = "Mole"
		7:
			node = Lighthouse.new()
			node.name = "Leuchtturm"
		30:
			node = CurrentArea.new()
			node.name = "Stroemung"
		31:
			var r := RiverChannel.new()
			r.name = "Fluss"
			var c := Curve3D.new()
			c.add_point(Vector3(0, 0, 150), Vector3.ZERO, Vector3(0, 0, -60))
			c.add_point(Vector3(60, 0, 0), Vector3(0, 0, 60), Vector3(0, 0, -60))
			c.add_point(Vector3(0, 0, -150), Vector3(0, 0, 60), Vector3.ZERO)
			r.curve = c
			node = r
		32:
			var s := ShoalArea.new()
			s.name = "See"
			s.kind = ShoalArea.Kind.SEE
			s.area_name = "See"
			s.radius = 120.0
			s.rock_symbol = false
			node = s
		33:
			node = FuelDock.new()
			node.name = "Tankstelle"
		10, 11, 12, 13, 14, 15, 16, 17:
			var m := SeaMark.new()
			m.kind = id - 10
			m.name = ["Nordtonne", "Osttonne", "Suedtonne", "Westtonne", "Einzelgefahr", "Rot", "Gruen", "Ansteuerung"][id - 10]
			node = m
	# in die Mitte der aktuellen Ansicht setzen
	var pos := Vector3.ZERO
	if _camera:
		var vp := _camera.get_viewport().get_visible_rect().size
		_update_cursor(_camera, vp * 0.5)
		if _cursor_valid:
			pos = Vector3(_cursor_world.x, 0, _cursor_world.z)
	var ur := get_undo_redo()
	ur.create_action("Baustein einfügen", UndoRedo.MERGE_DISABLE, lvl)
	ur.add_do_method(lvl, "add_child", node, true)
	ur.add_do_method(node, "set_owner", lvl)
	ur.add_do_property(node, "position", pos)
	ur.add_do_reference(node)
	ur.add_undo_method(lvl, "remove_child", node)
	ur.commit_action()
	get_editor_interface().get_selection().clear()
	get_editor_interface().get_selection().add_node(node)


func _clear_paint() -> void:
	if _level == null:
		return
	var ur := get_undo_redo()
	ur.create_action("Gemalten Seegrund löschen", UndoRedo.MERGE_DISABLE, _level)
	ur.add_do_property(_level, "depth_paint_png", PackedByteArray())
	ur.add_undo_property(_level, "depth_paint_png", _level.depth_paint_png)
	ur.commit_action()


## Setzt Nord-, Ost-, Süd- und West-Kardinaltonnen um die ausgewählte(n) Untiefe(n)
func _cardinals_around_selection(lvl: Level) -> void:
	var shoals: Array[ShoalArea] = []
	for n in get_editor_interface().get_selection().get_selected_nodes():
		if n is ShoalArea and n.kind == ShoalArea.Kind.UNTIEFE:
			shoals.append(n)
	if shoals.is_empty():
		push_warning("Bitte zuerst eine oder mehrere Untiefen auswählen.")
		return
	var ur := get_undo_redo()
	ur.create_action("Kardinaltonnen setzen", UndoRedo.MERGE_DISABLE, lvl)
	for s in shoals:
		var ext: Vector2 = Vector2(s.global_basis.x.length(), s.global_basis.z.length()) * s.radius
		var d := maxf(ext.x, ext.y) * 1.35 + 12.0
		var dirs := [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]
		for k in 4:
			var m := SeaMark.new()
			m.kind = k
			m.name = s.name + ["_N", "_O", "_S", "_W"][k]
			var p: Vector2 = s.pos2d() + dirs[k] * d
			ur.add_do_method(lvl, "add_child", m, true)
			ur.add_do_method(m, "set_owner", lvl)
			ur.add_do_property(m, "position", Vector3(p.x, 0, p.y))
			ur.add_do_reference(m)
			ur.add_undo_method(lvl, "remove_child", m)
	ur.commit_action()
