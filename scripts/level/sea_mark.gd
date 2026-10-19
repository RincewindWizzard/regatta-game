@tool
@icon("res://addons/regatta_editor/icons/seamark.svg")
class_name SeaMark
extends Node3D
## Seezeichen nach IALA-Region A (Europa), zur Dekoration und als Warnung:
##   Kardinaltonnen Nord/Ost/Süd/West – das Fahrwasser liegt in der genannten Richtung
##   Einzelgefahrstelle (schwarz-rot-schwarz) – direkt auf einer kleinen Gefahr
##   Lateraltonnen rot (Backbord) / grün (Steuerbord) – Fahrwasserbegrenzung
##   Ansteuerungstonne (rot-weiß) – sicheres Wasser rundum
## Boote prallen an den Tonnen ab.

enum Kind { NORD, OST, SUED, WEST, EINZELGEFAHR, ROT, GRUEN, ANSTEUERUNG }

const RADIUS := 2.6
## Darstellungsgröße (echte Tonnen sind von oben sonst kaum zu erkennen)
const SCALE := 1.9
const YELLOW := Color(0.98, 0.82, 0.1)
const BLACK := Color(0.1, 0.1, 0.11)
const RED := Color(0.85, 0.13, 0.1)
const GREEN := Color(0.1, 0.55, 0.25)
const WHITE := Color(0.97, 0.97, 0.95)

## Farbbänder von unten nach oben, Toppzeichen, Kartenkürzel, Feuer
const SPECS := {
	Kind.NORD: {"bands": [YELLOW, BLACK], "top": "nord", "abbr": "BY", "light": "Q", "shape": "pillar"},
	Kind.OST: {"bands": [BLACK, YELLOW, BLACK], "top": "ost", "abbr": "BYB", "light": "Q(3)10s", "shape": "pillar"},
	Kind.SUED: {"bands": [BLACK, YELLOW], "top": "sued", "abbr": "YB", "light": "Q(6)+LFl.15s", "shape": "pillar"},
	Kind.WEST: {"bands": [YELLOW, BLACK, YELLOW], "top": "west", "abbr": "YBY", "light": "Q(9)15s", "shape": "pillar"},
	Kind.EINZELGEFAHR: {"bands": [BLACK, RED, BLACK], "top": "balls", "abbr": "BRB", "light": "Fl(2)5s", "shape": "pillar"},
	Kind.ROT: {"bands": [RED], "top": "can", "abbr": "R", "light": "Fl.R.4s", "shape": "can"},
	Kind.GRUEN: {"bands": [GREEN], "top": "cone", "abbr": "G", "light": "Fl.G.4s", "shape": "cone"},
	Kind.ANSTEUERUNG: {"bands": [RED, WHITE, RED, WHITE], "top": "ball", "abbr": "RW", "light": "Iso.8s", "shape": "sphere"},
}

@export var kind := Kind.NORD:
	set(v):
		kind = v
		_rebuild()
## Name auf der Karte (leer = keiner)
@export var mark_label := "":
	set(v):
		mark_label = v
		_rebuild()

var _vis: Node3D
var _bob: Node3D
var _t := 0.0


func _ready() -> void:
	_t = randf() * 10.0
	_rebuild()


func pos2d() -> Vector2:
	return Vector2(global_position.x, global_position.z)


func _process(delta: float) -> void:
	if _bob:
		_t += delta
		_bob.position.y = sin(_t * 1.3) * 0.15
		_bob.rotation.x = sin(_t * 1.05) * 0.07
		_bob.rotation.z = sin(_t * 0.85 + 1.0) * 0.06


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m


func _mi(mesh: Mesh, c: Color, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(c)
	mi.position = pos
	mi.rotation = rot
	_bob.add_child(mi)
	return mi


func _cone(up: bool, y: float) -> void:
	var c := CylinderMesh.new()
	c.top_radius = 0.0 if up else 0.42
	c.bottom_radius = 0.42 if up else 0.0
	c.height = 0.55
	c.radial_segments = 12
	_mi(c, BLACK, Vector3(0, y, 0))


func _ball(y: float, c: Color, r := 0.27) -> void:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 12
	s.rings = 6
	_mi(s, c, Vector3(0, y, 0))


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _vis:
		_vis.queue_free()
	_vis = Node3D.new()
	add_child(_vis)
	_bob = Node3D.new()
	_bob.scale = Vector3.ONE * SCALE
	_vis.add_child(_bob)
	var spec: Dictionary = SPECS[kind]
	var bands: Array = spec["bands"]

	# Körper
	var h := 3.0
	var top_y := h
	match spec["shape"]:
		"pillar":
			var n := bands.size()
			for i in n:
				var c := CylinderMesh.new()
				var t0 := float(i) / n
				var t1 := float(i + 1) / n
				c.bottom_radius = lerpf(1.25, 0.5, t0)
				c.top_radius = lerpf(1.25, 0.5, t1)
				c.height = h / n
				c.radial_segments = 16
				_mi(c, bands[i], Vector3(0, (t0 + t1) * 0.5 * h - 0.3, 0))
			top_y = h - 0.3
		"can":
			var c := CylinderMesh.new()
			c.top_radius = 0.95
			c.bottom_radius = 0.95
			c.height = 2.4
			c.radial_segments = 16
			_mi(c, bands[0], Vector3(0, 0.9, 0))
			top_y = 2.1
		"cone":
			var c := CylinderMesh.new()
			c.top_radius = 0.0
			c.bottom_radius = 1.15
			c.height = 3.0
			c.radial_segments = 16
			_mi(c, bands[0], Vector3(0, 1.2, 0))
			top_y = 2.7
		"sphere":
			var s := SphereMesh.new()
			s.radius = 1.3
			s.height = 2.6
			s.radial_segments = 16
			_mi(s, WHITE, Vector3(0, 0.9, 0))
			# rot-weiße senkrechte Streifen als dünne Halbschalen
			for k in 4:
				var b := BoxMesh.new()
				b.size = Vector3(0.3, 2.5, 2.62)
				_mi(b, RED, Vector3(0, 0.9, 0), Vector3(0, k * PI / 4, 0))
			top_y = 2.2
	# Stange
	var pole := CylinderMesh.new()
	pole.top_radius = 0.06
	pole.bottom_radius = 0.06
	pole.height = 1.6
	_mi(pole, BLACK, Vector3(0, top_y + 0.8, 0))
	var ty := top_y + 1.7
	match spec["top"]:
		"nord":
			_cone(true, ty + 0.6)
			_cone(true, ty)
		"sued":
			_cone(false, ty + 0.6)
			_cone(false, ty)
		"ost":
			_cone(true, ty + 0.62)
			_cone(false, ty)
		"west":
			_cone(false, ty + 0.62)
			_cone(true, ty)
		"balls":
			_ball(ty + 0.62, BLACK)
			_ball(ty, BLACK)
		"can":
			var c := CylinderMesh.new()
			c.top_radius = 0.35
			c.bottom_radius = 0.35
			c.height = 0.6
			_mi(c, RED, Vector3(0, ty, 0))
		"cone":
			var c := CylinderMesh.new()
			c.top_radius = 0.0
			c.bottom_radius = 0.42
			c.height = 0.6
			_mi(c, GREEN, Vector3(0, ty, 0))
		"ball":
			_ball(ty, RED, 0.33)
	ModelStyle.outline(_bob)

	# Kartensymbol: Positionskreis, Feuerschein, Kürzel und Kennung
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	SeaChart.add_ring(st, Vector2.ZERO, 2.9, 0.25, 0.08, 24)
	_vis.add_child(SeaChart.mesh_from(st, SeaChart.INK))
	var flare := SurfaceTool.new()
	flare.begin(Mesh.PRIMITIVE_TRIANGLES)
	SeaChart.add_triangle(flare, Vector2(2.6, -2.0), Vector2(6.8, -5.8), Vector2(4.2, -2.3), 0.085)
	SeaChart.add_triangle(flare, Vector2(2.6, -2.0), Vector2(3.0, -3.8), Vector2(6.8, -5.8), 0.085)
	_vis.add_child(SeaChart.mesh_from(flare, Color(SeaChart.MAGENTA, 0.55)))
	var abbr := SeaChart.flat_label(spec["abbr"], 40, SeaChart.INK, false, true)
	abbr.position = Vector3(-6.5, 0.09, 5.0)
	_vis.add_child(abbr)
	var lt := SeaChart.flat_label(spec["light"], 34, SeaChart.MAGENTA)
	lt.position = Vector3(7.5, 0.09, 5.0)
	_vis.add_child(lt)
	if mark_label != "":
		var nl := SeaChart.flat_label(mark_label, 40, SeaChart.INK, true)
		nl.position = Vector3(0, 0.09, 8.5)
		_vis.add_child(nl)
