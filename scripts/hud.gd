class_name RaceHud
extends Control
## Bildschirmanzeige im Seekarten-Stil: Kartenrahmen mit Gradeinteilung, Windrose,
## Minikarte, je Spieler ein "Titelfeld" mit Speed, Platz, nächster Tonne und den
## Schot-Balken für Groß und Fock (grüner Strich = optimal).

const PAPER := Color(0.99, 0.98, 0.94, 0.94)
const INK := Color(0.08, 0.08, 0.1)
const MAGENTA := Color(0.78, 0.12, 0.55)
const FRAME := 12.0
const PANEL_W := 360.0

var main: Node
var boats: Array = []
var local_boats: Array = []     ## Boote an diesem Rechner (Panels)
var wind: WindField
var course: Course
var cams: SplitCameraManager

var _font: Font
var _font_b: Font
var _font_i: Font
var _map_tex: ImageTexture
var _ref_dir := 0.0
var _shift_text := ""
var _shift_time := 0.0

var map_rect := Rect2(-260, -440, 520, 500)   ## Kartenausschnitt der Minikarte (vom Level)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = SeaChart.font()
	_font_b = SeaChart.font(false, true)
	_font_i = SeaChart.font(true)
	_ref_dir = wind.current_dir
	# Seitenverhältnis der Minikarte (140 x 135) einhalten
	var want := 140.0 / 135.0
	var r := map_rect
	if r.size.x / r.size.y < want:
		r = r.grow_individual((r.size.y * want - r.size.x) * 0.5, 0, (r.size.y * want - r.size.x) * 0.5, 0)
	else:
		r = r.grow_individual(0, (r.size.x / want - r.size.y) * 0.5, 0, (r.size.x / want - r.size.y) * 0.5)
	map_rect = r
	_map_tex = ImageTexture.create_from_image(SeaChart.make_map_image(r.position, r.end, 112, 108))


func _process(delta: float) -> void:
	var diff := angle_difference(_ref_dir, wind.current_dir)
	if absf(diff) > deg_to_rad(7.0):
		_shift_text = "Winddreher %s" % ("rechts" if diff > 0.0 else "links")
		_shift_time = 2.5
		_ref_dir = wind.current_dir
	_shift_time = maxf(0.0, _shift_time - delta)
	queue_redraw()


func _draw() -> void:
	var vs := get_viewport_rect().size
	_draw_frame(vs)
	_draw_wind(Vector2(vs.x * 0.5, 66.0))
	_draw_minimap(Rect2(vs.x - FRAME - 10.0 - 140.0, FRAME + 12.0, 140.0, 135.0))   # Ecke oben rechts: verdeckt das eigene Boot in der Bildmitte nicht
	var py := vs.y - FRAME - 10.0 - 168.0
	var own: Array = cams.boats
	if own.size() >= 2:
		_draw_panel(own[cams.order[0]], Vector2(FRAME + 10.0, py))
		_draw_panel(own[cams.order[1]], Vector2(vs.x - FRAME - 10.0 - PANEL_W, py))
	elif own.size() == 1:
		_draw_panel(own[0], Vector2(FRAME + 10.0, py))
	_draw_time(Vector2(FRAME + 10.0, FRAME + 10.0))
	if boats.size() > local_boats.size() or boats.size() > 2 or main.net != "":
		_draw_leaderboard(Vector2(FRAME + 10.0, FRAME + 54.0))
	_draw_center(vs)
	_draw_fps(vs)


## Kleine Bildraten-Anzeige unten rechts
func _draw_fps(vs: Vector2) -> void:
	var fps := Engine.get_frames_per_second()
	var col := INK if fps >= 50 else (Color(0.8, 0.45, 0.0) if fps >= 30 else Color(0.8, 0.1, 0.1))
	var txt := "%d FPS" % fps
	var w := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	draw_rect(Rect2(vs.x - FRAME - 14.0 - w - 6.0, vs.y - FRAME - 24.0, w + 12.0, 20.0), Color(PAPER, 0.8))
	_text(txt, Vector2(vs.x - FRAME - 14.0 - w, vs.y - FRAME - 9.0), 13, col, _font)


## Rangliste aller Boote (Netzwerk / mehr als 2 Boote)
func _draw_leaderboard(o: Vector2) -> void:
	var sorted := boats.duplicate()
	sorted.sort_custom(func(a, b): return course.progress(a) > course.progress(b))
	var h := 12.0 + sorted.size() * 24.0
	draw_rect(Rect2(o, Vector2(230, h)), PAPER)
	draw_rect(Rect2(o, Vector2(230, h)), INK, false, 1.2)
	var marks := course.targets.size() - 2
	for i in sorted.size():
		var b: Boat = sorted[i]
		var y := o.y + 26.0 + i * 24.0
		draw_circle(Vector2(o.x + 18, y - 6), 6.0, b.color)
		var row := "%d. %s" % [i + 1, b.player_name]
		_text(row, Vector2(o.x + 32, y), 15, INK, _font_b if local_boats.has(b) else _font)
		var info := ""
		if b.finished:
			info = _fmt_time(b.finish_time)
		elif b.out:
			info = "raus"
		elif b.next_target == 0:
			info = "Start"
		else:
			info = "%d/%d" % [mini(b.next_target - 1, marks), marks]
		var w := _font.get_string_size(info, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		_text(info, Vector2(o.x + 220 - w, y), 14, Color(0.15, 0.3, 0.5), _font_i)


# ---------------------------------------------------------------- Teile

## Kartenrahmen mit abwechselnd schwarz/weißer Minuten-Skala
func _draw_frame(vs: Vector2) -> void:
	var w := FRAME
	draw_rect(Rect2(0, 0, vs.x, w), Color.WHITE)
	draw_rect(Rect2(0, vs.y - w, vs.x, w), Color.WHITE)
	draw_rect(Rect2(0, 0, w, vs.y), Color.WHITE)
	draw_rect(Rect2(vs.x - w, 0, w, vs.y), Color.WHITE)
	var seg := 48.0
	var k := 0
	var x := w
	while x < vs.x - w:
		if k % 2 == 0:
			var len := minf(seg, vs.x - w - x)
			draw_rect(Rect2(x, 3, len, w - 6), INK)
			draw_rect(Rect2(x, vs.y - w + 3, len, w - 6), INK)
		x += seg
		k += 1
	k = 0
	var y := w
	while y < vs.y - w:
		if k % 2 == 0:
			var len := minf(seg, vs.y - w - y)
			draw_rect(Rect2(3, y, w - 6, len), INK)
			draw_rect(Rect2(vs.x - w + 3, y, w - 6, len), INK)
		y += seg
		k += 1
	draw_rect(Rect2(w, w, vs.x - 2 * w, vs.y - 2 * w), INK, false, 1.5)
	draw_rect(Rect2(0.5, 0.5, vs.x - 1, vs.y - 1), INK, false, 1.0)


func _draw_wind(c: Vector2) -> void:
	var r := 44.0
	draw_circle(c, r + 4.0, PAPER)
	draw_arc(c, r, 0.0, TAU, 64, MAGENTA, 1.5, true)
	draw_arc(c, r * 0.86, 0.0, TAU, 64, MAGENTA, 1.0, true)
	for deg in range(0, 360, 10):
		var b := deg_to_rad(float(deg))
		var dir := Vector2(sin(b), -cos(b))
		var len := 0.14 if deg % 30 == 0 else 0.07
		draw_line(c + dir * r * 0.86, c + dir * r * (0.86 + len), MAGENTA, 1.0, true)
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 0.84), c + Vector2(4, -r * 0.62), c + Vector2(-4, -r * 0.62)]), MAGENTA)
	_text_centered("N", c + Vector2(0, -r - 6), 13, MAGENTA, _font_b)
	# Windpfeil (zeigt, wohin der Wind weht)
	var v := wind.blow_dir()
	var a := c - v * r * 0.62
	var b2 := c + v * r * 0.5
	draw_line(a, b2, INK, 3.0, true)
	var side := Vector2(-v.y, v.x)
	draw_colored_polygon(PackedVector2Array([b2 + v * 8.0, b2 - v * 4.0 + side * 6.0, b2 - v * 4.0 - side * 6.0]), INK)
	# Fiederung am Pfeilende wie auf Wetterkarten (je Fieder ~5 kn)
	var kn := wind.base_speed * 1.944
	var feathers := int(round(kn / 5.0))
	for f in feathers:
		var base := a + v * (f * 5.0)
		draw_line(base, base + side * (8.0 if f % 2 == 0 else -8.0) - v * 5.0, INK, 1.5, true)
	var from_deg := wrapf(rad_to_deg(wind.current_dir), 0.0, 360.0)
	_text_centered("Wind %03d°  %d kn" % [roundi(from_deg), roundi(kn)], c + Vector2(0, r + 22), 15, INK, _font_b)
	if _shift_time > 0.0:
		_text_centered(_shift_text, c + Vector2(0, 228), 20, Color(MAGENTA, minf(1.0, _shift_time)), _font_b)


func _draw_minimap(r: Rect2) -> void:
	draw_rect(r.grow(3.0), Color(PAPER, 0.85))
	draw_texture_rect(_map_tex, r, false, Color(1, 1, 1, 0.88))
	draw_rect(r, INK, false, 1.0)
	var to_map := func(p: Vector2) -> Vector2:
		var n := (p - map_rect.position) / map_rect.size
		return r.position + n.clamp(Vector2.ZERO, Vector2.ONE) * r.size
	for z in course.level.danger_zones():
		var zc: Vector2 = to_map.call(z["pos"])
		var zr: float = float(z["radius"]) / map_rect.size.x * r.size.x
		draw_circle(zc, zr, Color(MAGENTA, 0.15))
		draw_arc(zc, zr, 0.0, TAU, 24, MAGENTA, 1.0, true)
	for ln in course.level.lane_lines():
		draw_line(to_map.call(ln["a"]), to_map.call(ln["b"]), Color(MAGENTA, 0.45), 3.0)
	for lane in course.level.shipping_lanes():
		for sh in lane.ships_at(ShippingLane.clock):
			var sp: Vector2 = to_map.call(sh["pos"])
			var sd: Vector2 = sh["dir"]
			draw_line(sp - sd * 4.0, sp + sd * 4.0, Color(0.1, 0.12, 0.2), 3.0)
	for d in course.level.fuel_docks():
		var dc: Vector2 = to_map.call(d.berth())
		draw_circle(dc, 3.5, Color(0.85, 0.15, 0.12))
		draw_arc(dc, 3.5, 0.0, TAU, 12, INK, 1.0)
	var ln := course.line
	var half := ln.tangent2d() * ln.half_width
	draw_line(to_map.call(ln.center2d() - half), to_map.call(ln.center2d() + half), INK, 1.5)
	for t in course.targets:
		if t["type"] == "mark":
			var mp: Vector2 = to_map.call(t["pos"])
			draw_circle(mp, 3.0, CourseMark.YELLOW)
			draw_arc(mp, 3.0, 0.0, TAU, 12, INK, 1.0)
	for b in boats:
		var boat: Boat = b
		var p: Vector2 = to_map.call(boat.pos2d())
		if not boat.finished:
			var tp: Vector2 = to_map.call(course.target_pos(boat.next_target))
			draw_dashed_line(p, tp, Color(boat.color, 0.6), 1.0, 3.0)
			draw_arc(tp, 6.0, 0.0, TAU, 16, boat.color, 1.5)
		draw_circle(p, 3.5, boat.color)
		var f := Vector2(sin(boat.heading), cos(boat.heading))
		draw_line(p, p + f * 8.0, boat.color, 2.0)
	if boats.size() > 0:
		for b in boats:
			if b.tug != null and is_instance_valid(b.tug):
				draw_rect(Rect2(to_map.call(b.tug.pos2d()) - Vector2(2, 2), Vector2(4, 4)), INK)


func _draw_panel(b: Boat, o: Vector2) -> void:
	var w := PANEL_W
	var h := 168.0
	draw_rect(Rect2(o, Vector2(w, h)), PAPER)
	draw_rect(Rect2(o, Vector2(w, h)), INK, false, 1.5)
	draw_rect(Rect2(o + Vector2(3, 3), Vector2(w - 6, h - 6)), INK, false, 0.6)
	draw_rect(Rect2(o + Vector2(3, 3), Vector2(6, h - 6)), b.color)
	if b.kvr_time > 0.0:
		_draw_kvr(b, o)
	var x := o.x + 20.0
	_text("%s  ·  Platz %d" % [b.player_name, main.rank_of(b)], Vector2(x, o.y + 26), 19, b.color.darkened(0.15), _font_b)
	_text("%.1f kn" % (b.speed() * 1.944), Vector2(x, o.y + 60), 28, INK, _font_b)
	if b.finished:
		_text("Im Ziel  " + _fmt_time(b.finish_time), Vector2(x + 118, o.y + 58), 17, Color(0.1, 0.5, 0.2), _font_b)
	else:
		var dist := b.pos2d().distance_to(course.target_pos(b.next_target))
		_text("→ %s  %d m" % [course.target_name(b.next_target), roundi(dist)], Vector2(x + 118, o.y + 58), 16, INK, _font_i)

	_draw_sheet_bar("Schot", b.sheet, b.optimal_sheet(), b.main_status, Vector2(x, o.y + 78), 120.0 if b.has_engine else 155.0)
	if b.has_engine:
		_draw_engine(b, Vector2(x, o.y + 102))
		_draw_fuel_gauge(b, o + Vector2(w - 52, 100))

	var warn := ""
	var warn_col := Color(0.75, 0.1, 0.1)
	if b.towed:
		warn = "Wird abgeschleppt ..."
		warn_col = MAGENTA
	elif b.out:
		warn = "Ausgeschieden!"
	elif b.hold_kind == 1:
		warn = "Polizeikontrolle … noch %d s" % ceili(b.hold_time)
		warn_col = Color(0.1, 0.25, 0.65)
	elif b.hold_kind == 3:
		warn = "Wird aus dem Sperrgebiet geleitet …"
		warn_col = Color(0.1, 0.25, 0.65)
	elif b.hold_kind == 2:
		warn = "Sirenengesang … noch %d s" % ceili(b.hold_time)
		warn_col = MAGENTA
	elif b.tug != null and is_instance_valid(b.tug):
		warn = "Schlepper kommt - noch %d m" % roundi(b.tug.distance_to_boat())
		warn_col = MAGENTA
	elif b.stuck:
		var wait := maxf(0.0, main.STUCK_WAIT - b.stuck_time)
		warn = "Festgefahren! Schlepper in %d s gerufen" % ceili(wait) if wait > 0.0 else "Festgefahren!"
	elif b.outside:
		warn = "Außerhalb des Regattagebiets!"
		warn_col = SeaChart.MAGENTA
	elif b.refueling:
		warn = "Tanken … %d %%" % roundi(b.fuel_fraction() * 100.0)
		warn_col = Color(0.1, 0.45, 0.2)
	elif b.aground:
		warn = "Grundberührung - raus ins Tiefe!"
	elif b.message_time > 0.0:
		warn = b.message
		warn_col = INK
	elif b.in_irons:
		warn = "Im Wind - abfallen!"
		warn_col = Color(0.6, 0.35, 0.0)
	elif b.in_shadow:
		warn = "Windschatten"
		warn_col = Color(0.3, 0.3, 0.35)
	elif b.gust > 0.45:
		warn = "Böe"
		warn_col = Color(0.15, 0.3, 0.55)
	var info := "Tiefe %.1f m" % b.depth
	if b.current.length() > 0.15:
		info += "   ·   Strom %.1f kn" % (b.current.length() * 1.944)
	_text(info, Vector2(x, o.y + 140), 14, Color(0.15, 0.3, 0.5), _font_i)
	if warn != "":
		_text(warn, Vector2(x, o.y + 159), 16, warn_col, _font_b)


## KVR-Einblendung über dem Spielerfeld: grün = Wegerecht, orange = ausweichen, blau = Hinweis
func _draw_kvr(b: Boat, o: Vector2) -> void:
	var col: Color = [Color(0.15, 0.3, 0.55), Color(0.1, 0.55, 0.25), Color(0.85, 0.45, 0.05)][clampi(b.kvr_kind, 0, 2)]
	var fade := clampf(b.kvr_time, 0.0, 1.0)
	var r := Rect2(o + Vector2(0, -50), Vector2(PANEL_W, 44))
	draw_rect(r, Color(PAPER, 0.96 * fade))
	draw_rect(r, Color(INK, fade), false, 1.2)
	draw_rect(Rect2(r.position, Vector2(7, r.size.y)), Color(col, fade))
	_text(b.kvr_title, r.position + Vector2(18, 19), 17, Color(col.darkened(0.2), fade), _font_b)
	_text(b.kvr_sub, r.position + Vector2(18, 37), 14, Color(INK, fade), _font_i)


## Gasstufen als Kästchen und Motorzustand
func _draw_engine(b: Boat, o: Vector2) -> void:
	_text("Gas", o + Vector2(0, 14), 14, INK, _font_b)
	for i in Boat.THROTTLE_MAX:
		var r := Rect2(o + Vector2(50 + i * 22, 3), Vector2(18, 12))
		var on := i < b.throttle
		draw_rect(r, Color(0.85, 0.4, 0.1) if on else Color(0.85, 0.87, 0.9))
		draw_rect(r, INK, false, 1.0)
	var state := "aus"
	var col := Color(INK, 0.55)
	match b.engine:
		Boat.Motor.ANLASSER:
			state = "Anlasser …"
			col = Color(0.75, 0.45, 0.0)
		Boat.Motor.LAEUFT:
			state = "Motor läuft"
			col = Color(0.1, 0.5, 0.2)
	if b.fuel <= 0.01:
		state = "Tank leer"
		col = Color(0.75, 0.1, 0.1)
	_text(state, o + Vector2(50 + Boat.THROTTLE_MAX * 22 + 8, 14), 14, col, _font_i)


## Tankuhr wie im Auto: Halbkreis von E (leer) bis F (voll), rote Reserve
func _draw_fuel_gauge(b: Boat, c: Vector2) -> void:
	var r := 30.0
	var a0 := PI * 1.15      # links unten = leer
	var a1 := PI * 1.85      # rechts unten = voll
	draw_circle(c, r + 5.0, Color(1, 1, 1))
	draw_arc(c, r + 5.0, 0.0, TAU, 40, INK, 1.2, true)
	draw_arc(c, r - 3.0, a0, lerpf(a0, a1, 0.15), 12, Color(0.85, 0.15, 0.1), 5.0, true)
	draw_arc(c, r - 3.0, lerpf(a0, a1, 0.15), a1, 24, Color(INK, 0.25), 5.0, true)
	for k in 5:
		var a := lerpf(a0, a1, k / 4.0)
		var d := Vector2(cos(a), sin(a))
		draw_line(c + d * (r - 8.0), c + d * (r + 1.0), INK, 1.5, true)
	var f := clampf(b.fuel_fraction(), 0.0, 1.0)
	var na := lerpf(a0, a1, f)
	var nd := Vector2(cos(na), sin(na))
	draw_line(c, c + nd * (r - 4.0), Color(0.75, 0.1, 0.1), 2.5, true)
	draw_circle(c, 3.5, INK)
	_text("E", c + Vector2(-r + 2, 12), 12, INK, _font_b)
	_text("F", c + Vector2(r - 9, 12), 12, INK, _font_b)
	_text_centered("%.1f l" % b.fuel, c + Vector2(0, 26), 12, INK, _font_i)


func _draw_sheet_bar(label: String, value: float, optimal: float, status: String, o: Vector2, bar_w := 155.0) -> void:
	_text(label, o + Vector2(0, 14), 14, INK, _font_b)
	var bar := Rect2(o + Vector2(50, 3), Vector2(bar_w, 12))
	draw_rect(bar, Color(0.85, 0.87, 0.9))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * value, bar.size.y)), Color(0.25, 0.35, 0.5))
	draw_rect(bar, INK, false, 1.0)
	var ox := bar.position.x + bar.size.x * optimal
	draw_rect(Rect2(Vector2(ox - 2, bar.position.y - 4), Vector2(4, bar.size.y + 8)), Color(0.1, 0.65, 0.25))
	var good := status == "optimal"
	_text(status, Vector2(bar.end.x + 10, o.y + 14), 14, Color(0.1, 0.5, 0.2) if good else Color(0.7, 0.35, 0.0), _font_i)


func _draw_time(o: Vector2) -> void:
	draw_rect(Rect2(o, Vector2(150, 34)), PAPER)
	draw_rect(Rect2(o, Vector2(150, 34)), INK, false, 1.2)
	_text("Zeit  " + _fmt_time(main.race_time), o + Vector2(12, 24), 19, INK, _font_b)
	if Boat.debug_mode:
		draw_rect(Rect2(o + Vector2(0, 38), Vector2(150, 24)), Color(0.8, 0.1, 0.1))
		_text("DEBUG  F9 = aus", o + Vector2(10, 56), 15, Color.WHITE, _font_b)


func _draw_center(vs: Vector2) -> void:
	var c := Vector2(vs.x * 0.5, vs.y * 0.45)
	match main.state:
		"waiting":
			_big("Warte auf Mitsegler …", c, 54, INK)
		"countdown":
			_big(str(ceili(main.countdown - 0.5)) if main.countdown > 0.5 else "LOS!", c, 110, INK)
			_text_centered("Klar zum Start!", c + Vector2(0, 60), 26, INK, _font_i, true)
		"racing":
			if main.go_flash > 0.0:
				_big("LOS!", c, 110, Color(INK, minf(1.0, main.go_flash)))
		"finished":
			var wnr: Boat = main.winner
			if wnr != null:
				_big("%s gewinnt!" % wnr.player_name, c, 72, wnr.color.darkened(0.1))
			else:
				_big("Alle Boote verloren!", c, 60, INK)
			var hint := "Start/Enter: neues Rennen   ·   Esc: Menü"
			if main.net == "host":
				hint = "Start/Enter: neues Rennen   ·   Esc: zurück in die Lobby"
			elif main.net == "client":
				hint = "Der Host startet das nächste Rennen   ·   Esc: Regatta verlassen"
			var result := "Zeit " + _fmt_time(wnr.finish_time) + "   ·   " if wnr != null else ""
			_text_centered(result + hint, c + Vector2(0, 52), 22, INK, _font_b, true)


# ---------------------------------------------------------------- Helfer

func _text(s: String, pos: Vector2, size: int, col: Color, f: Font = null, halo := false) -> void:
	var fnt := f if f else _font
	if halo:
		draw_string_outline(fnt, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, Color(1, 1, 1, 0.85 * col.a))
	draw_string(fnt, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _text_centered(s: String, pos: Vector2, size: int, col: Color, f: Font = null, halo := false) -> void:
	var fnt := f if f else _font
	var w := fnt.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_text(s, pos - Vector2(w * 0.5, 0), size, col, fnt, halo)


func _big(s: String, pos: Vector2, size: int, col: Color) -> void:
	var w := _font_b.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p := pos - Vector2(w * 0.5, 0)
	draw_string_outline(_font_b, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 14, Color(1, 1, 1, 0.9 * col.a))
	draw_string(_font_b, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _fmt_time(t: float) -> String:
	return "%d:%04.1f" % [int(t) / 60, fmod(t, 60.0)]
