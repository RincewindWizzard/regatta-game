class_name UIStyle
extends RefCounted
## Gemeinsamer Seekarten-Look für Menü und Lobby: Papier, Kartenrahmen, Knöpfe.

const PAPER := Color(0.985, 0.975, 0.94)
const PAPER_DARK := Color(0.94, 0.92, 0.86)
const INK := Color(0.08, 0.08, 0.1)
const MAGENTA := Color(0.78, 0.12, 0.55)
const BLUE := Color(0.15, 0.3, 0.5)


static func box(bg: Color, border: Color, w: int) -> StyleBoxFlat:
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


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = SeaChart.font(false, true)
	t.default_font_size = 20
	t.set_stylebox("normal", "Button", box(PAPER, Color(INK, 0.5), 1))
	t.set_stylebox("hover", "Button", box(PAPER_DARK, INK, 1))
	t.set_stylebox("pressed", "Button", box(Color(0.86, 0.92, 0.97), INK, 2))
	t.set_stylebox("hover_pressed", "Button", box(Color(0.86, 0.92, 0.97), INK, 2))
	t.set_stylebox("disabled", "Button", box(Color(PAPER, 0.6), Color(INK, 0.2), 1))
	t.set_stylebox("focus", "Button", box(Color(1, 1, 1, 0), MAGENTA, 3))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, "Button", INK)
	t.set_color("font_disabled_color", "Button", Color(INK, 0.45))
	t.set_color("font_color", "Label", INK)
	t.set_stylebox("normal", "LineEdit", box(Color.WHITE, Color(INK, 0.5), 1))
	t.set_stylebox("focus", "LineEdit", box(Color(1, 1, 1, 0), MAGENTA, 3))
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("caret_color", "LineEdit", INK)
	t.set_color("font_placeholder_color", "LineEdit", Color(INK, 0.4))
	t.set_font("font", "LineEdit", SeaChart.font())
	return t


## Hervorgehobener Hauptknopf (magenta)
static func style_primary(b: Button, size := 28) -> void:
	b.add_theme_font_size_override("font_size", size)
	for c in ["font_color", "font_focus_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(c, Color.WHITE)
	b.add_theme_stylebox_override("normal", box(MAGENTA.darkened(0.1), INK, 2))
	b.add_theme_stylebox_override("hover", box(MAGENTA, INK, 2))
	b.add_theme_stylebox_override("focus", box(MAGENTA, INK, 4))
	b.add_theme_stylebox_override("pressed", box(MAGENTA.darkened(0.3), INK, 2))
	b.add_theme_stylebox_override("disabled", box(Color(MAGENTA, 0.35), Color(INK, 0.3), 1))


static func heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", SeaChart.font(true))
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", BLUE)
	return l


## Papier mit feinem Kartennetz und Rahmen mit Minuten-Skala
static func draw_paper(ci: CanvasItem, vs: Vector2) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, vs), PAPER)
	var grid := Color(0.55, 0.6, 0.65, 0.18)
	var x := 0.0
	while x < vs.x:
		ci.draw_line(Vector2(x, 0), Vector2(x, vs.y), grid, 1.0)
		x += 100.0
	var y := 0.0
	while y < vs.y:
		ci.draw_line(Vector2(0, y), Vector2(vs.x, y), grid, 1.0)
		y += 100.0
	var w := 14.0
	var seg := 50.0
	for side in 4:
		var length := vs.x if side < 2 else vs.y
		var k := 0
		var p := w
		while p < length - w:
			if k % 2 == 0:
				var l := minf(seg, length - w - p)
				match side:
					0: ci.draw_rect(Rect2(p, 3, l, w - 6), INK)
					1: ci.draw_rect(Rect2(p, vs.y - w + 3, l, w - 6), INK)
					2: ci.draw_rect(Rect2(3, p, w - 6, l), INK)
					3: ci.draw_rect(Rect2(vs.x - w + 3, p, w - 6, l), INK)
			p += seg
			k += 1
	ci.draw_rect(Rect2(w, w, vs.x - 2 * w, vs.y - 2 * w), INK, false, 1.5)
	ci.draw_rect(Rect2(0.5, 0.5, vs.x - 1, vs.y - 1), INK, false, 1.0)
