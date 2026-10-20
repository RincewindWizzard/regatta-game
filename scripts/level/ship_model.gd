@tool
class_name ShipModel
extends RefCounted
## 3D-Modelle der Berufsschifffahrt (Containerschiff, Tanker, Massengutfrachter).
##
## Die Modelle entstehen in Blender (`tools/build_ships.py`) und liegen als `models/ship_*.glb`
## im Projekt: geschlossene, gestrake Rümpfe, Brücke, Schornstein, Ladung und ein flacher
## Schaumstreifen („Foam“) am Wasserpass. Dasselbe Skript schreibt die Rumpfkontur nach
## `models/ship_hulls.json`; daraus berechnet `outline()` das Kollisionsvieleck, sodass die
## Kollision genau zur sichtbaren Rumpfform passt.
##
## Bug nach lokal +Z, Wasserlinie y = 0. Die Modelle sind 80 x 16 m groß und werden auf die
## Länge und Breite der ShippingLane skaliert.

const KINDS := ["container", "tanker", "bulker"]
const HULLS_PATH := "res://models/ship_hulls.json"

static var _hulls := {}
static var _base_length := 80.0
static var _base_beam := 16.0
static var _outlines := {}


## Gesamtes Schiff. type 0 = Containerschiff, 1 = Tanker, 2 = Massengutfrachter
static func build(type: int, length: float, beam: float) -> Node3D:
	var root := Node3D.new()
	var path := "res://models/ship_%s.glb" % KINDS[type % KINDS.size()]
	if not ResourceLoader.exists(path):
		return root
	var model: Node3D = load(path).instantiate()
	_load_hulls()
	model.scale = Vector3(beam / _base_beam, 1.0, length / _base_length)
	root.add_child(model)
	for mi in ModelStyle.meshes_of(model):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if not String(mi.name).begins_with("Foam"):
			mi.material_overlay = ModelStyle.outline_material()
	return root


## Rumpfkontur als Vieleck in Schiffskoordinaten: x = quer, y = längs (Bug +)
static func outline(type: int, length: float, beam: float) -> PackedVector2Array:
	var key := "%d:%.1f:%.1f" % [type, length, beam]
	if _outlines.has(key):
		return _outlines[key]
	_load_hulls()
	var out := PackedVector2Array()
	var rows: Array = _hulls.get(KINDS[type % KINDS.size()], [])
	var side := PackedVector2Array()
	for r in rows:
		side.append(Vector2(float(r[1]) * beam * 0.5, float(r[0]) * length))
	out.append_array(side)
	for i in range(side.size() - 1, -1, -1):
		if absf(side[i].x) > 0.001:
			out.append(Vector2(-side[i].x, side[i].y))
	if out.size() < 4:                      # Notfall: einfaches Rechteck
		out = PackedVector2Array([Vector2(-beam * 0.5, -length * 0.5), Vector2(beam * 0.5, -length * 0.5),
			Vector2(beam * 0.5, length * 0.5), Vector2(-beam * 0.5, length * 0.5)])
	_outlines[key] = out
	return out


static func _load_hulls() -> void:
	if not _hulls.is_empty():
		return
	var f := FileAccess.open(HULLS_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		_base_length = float(data.get("length", 80.0))
		_base_beam = float(data.get("beam", 16.0))
		_hulls = data.get("hulls", {})
