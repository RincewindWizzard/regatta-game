@tool
@icon("res://addons/regatta_editor/icons/land.svg")
class_name LandShape
extends Path3D
## Landmasse (oder Wasserfläche) als geschlossener Umriss mit Bézier-Kurven. Die Kurve zeichnet man
## mit Godots Pfad-Werkzeug (Punkte setzen, Griffe ziehen; Num 7 = Draufsicht). Punkte ohne Griffe
## sind Ecken. Der Umriss schließt sich vom letzten zum ersten Punkt.
## Die Uferlinie liegt exakt auf dem Umriss – das Tiefenraster ist nur die Grundlage.
##   Land:   fester Boden innen, außen fällt der Grund mit shore_slope ab
##   Wasser: gräbt innen Wasser aus (z. B. Hafenbecken); mehrere Formen wirken in Szenenreihenfolge

enum Kind { LAND, WASSER }

@export var kind := Kind.LAND:
	set(v):
		kind = v
		_changed()
## Anstieg des Grundes vom Ufer weg (Meter Tiefe je Meter Abstand)
@export_range(0.05, 1.0, 0.01) var shore_slope := 0.22:
	set(v):
		shore_slope = v
		_changed()
## Breite des Streifens um das Land, in dem die Form die Grundlage ersetzt
@export_range(10.0, 300.0, 5.0, "suffix:m") var zone := 60.0:
	set(v):
		zone = v
		_changed()
## Wassertiefe in der Fläche einer Wasserform
@export_range(1.5, 30.0, 0.5, "suffix:m") var water_depth := 8.0:
	set(v):
		water_depth = v
		_changed()

var _poly: LandPoly
var _outline: MeshInstance3D


func _ready() -> void:
	set_notify_transform(true)
	if curve and not curve.changed.is_connected(_changed):
		curve.changed.connect(_changed)
	_changed()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		_changed()


func _changed() -> void:
	_poly = null
	if not is_inside_tree():
		return
	if Engine.is_editor_hint():
		_rebuild_outline()
		update_configuration_warnings()
		var n := get_parent()
		while n and not (n is Level):
			n = n.get_parent()
		if n:
			n.queue_preview()


## Umriss in Weltkoordinaten (x/z) als Linienzug, Bézier-Segmente fein zerlegt, geschlossen
func outline() -> PackedVector2Array:
	var out := PackedVector2Array()
	if curve == null or curve.point_count < 2:
		return out
	var n := curve.point_count
	var gt := global_transform if is_inside_tree() else transform
	var first := _w(gt, curve.get_point_position(0))
	out.append(first)
	for i in n:
		var k := (i + 1) % n
		var a := curve.get_point_position(i)
		var b := curve.get_point_position(k)
		var pa := _w(gt, a)
		var pb := _w(gt, b)
		if k == 0 and pa.distance_to(pb) < 0.01:
			break       # letzter Punkt liegt schon auf dem ersten (Kurve schließen)
		var c1 := _w(gt, a + curve.get_point_out(i))
		var c2 := _w(gt, b + curve.get_point_in(k))
		LandPoly.flatten(pa, c1, c2, pb, out)
	# Schlusspunkt = Startpunkt wird weggelassen (Polygon schließt implizit)
	if out.size() > 1 and out[out.size() - 1].distance_to(out[0]) < 0.01:
		out.remove_at(out.size() - 1)
	return out


func _w(gt: Transform3D, v: Vector3) -> Vector2:
	var g := gt * v
	return Vector2(g.x, g.z)


func poly() -> LandPoly:
	if _poly == null:
		_poly = LandPoly.new()
		_poly.setup(outline(), kind == Kind.WASSER, shore_slope, zone, water_depth)
	return _poly


func _get_configuration_warnings() -> PackedStringArray:
	var w := PackedStringArray()
	var o := outline()
	if o.size() < 3:
		w.append("Der Umriss braucht mindestens drei Punkte (Pfad-Werkzeug in der 3D-Ansicht).")
	elif o.size() <= 800 and _self_intersects(o):
		w.append("Der Umriss überschneidet sich selbst – die Fläche ist dann nach Even-Odd gefüllt.")
	return w


func _self_intersects(o: PackedVector2Array) -> bool:
	var n := o.size()
	for i in n:
		var a := o[i]
		var b := o[(i + 1) % n]
		for j in range(i + 2, n):
			if i == 0 and j == n - 1:
				continue
			var c := o[j]
			var d := o[(j + 1) % n]
			if Geometry2D.segment_intersects_segment(a, b, c, d) != null:
				return true
	return false


func _rebuild_outline() -> void:
	if _outline:
		_outline.queue_free()
		_outline = null
	var o := outline()
	if o.size() < 2:
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var inv := global_transform.affine_inverse()
	for i in o.size():
		var a := o[i]
		var b := o[(i + 1) % o.size()]
		var la := inv * Vector3(a.x, 0, a.y)
		var lb := inv * Vector3(b.x, 0, b.y)
		SeaChart.add_line(st, Vector2(la.x, la.z), Vector2(lb.x, lb.z), 0.6, 0.35)
	var col := Color(0.15, 0.4, 0.8, 0.8) if kind == Kind.WASSER else Color(0.7, 0.45, 0.1, 0.8)
	_outline = SeaChart.mesh_from(st, col)
	add_child(_outline)
