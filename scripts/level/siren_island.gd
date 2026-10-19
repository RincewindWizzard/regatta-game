@tool
@icon("res://addons/regatta_editor/icons/siren.svg")
class_name SirenIsland
extends ShoalArea
## Sirenen-Insel: Wer sich ihr bis auf song_range nähert, hört den Gesang der Sirenen,
## bleibt stehen und lauscht eine Weile (das Boot dreht sich zur Insel). Danach kurze
## Schonfrist, damit man wieder wegsegeln kann. Die Computergegner halten Abstand.
## Die Insel ist eine normale ShoalArea (Art Insel) mit Sirenen auf den Felsen.

const NOTE_COUNT := 4

## Abstand vom Ufer, ab dem der Gesang wirkt
@export_range(30.0, 200.0, 1.0, "suffix:m") var song_range := 70.0:
	set(v):
		song_range = v
		_rebuild()

var _sirens: Array[Node3D] = []
var _rings: Array[MeshInstance3D] = []
var _notes: Node3D
var _state := {}
var _st := 0.0


func _init() -> void:
	kind = Kind.INSEL


## Entfernung vom Mittelpunkt, ab der der Gesang wirkt
func capture_radius() -> float:
	return radius * maxf(global_basis.x.length(), global_basis.z.length()) + song_range


func danger_circle() -> Array:
	return [pos2d(), capture_radius() + 6.0]


func _rebuild() -> void:
	if not is_inside_tree():
		return
	super._rebuild()
	_sirens.clear()
	_rings.clear()
	_notes = null
	if _vis == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(radius * 11.0) + area_name.length()
	# Sirenen auf Felsen am Ufer
	for k in 3:
		var a := TAU * k / 3.0 + rng.randf() * 0.5
		var p := _island_point(Vector2(cos(a), sin(a)) * 0.42)
		var siren := _siren_figure()
		siren.position = p
		siren.rotation.y = a + PI * 0.5
		_vis.add_child(siren)
		_sirens.append(siren)
		Deco.rocks(_vis, [[p + Vector3(0, -0.2, 0), 2.6], [p + Vector3(1.6, -0.2, 0.8), 1.8]], rng.seed + k)
	# Notenwolke über der Insel
	_notes = HazardVisuals.siren_notes()
	_vis.add_child(_notes)
	# Wellenringe, die vom Ufer nach außen wandern, und die Grenze des Gesangs auf der Karte
	var r_cap := capture_radius()
	for k in 3:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		SeaChart.add_ring(st, Vector2.ZERO, 1.0, 0.035, 0.1, 64)
		var ring := SeaChart.mesh_from(st, Color(0.25, 0.75, 0.8, 0.5))
		_vis.add_child(ring)
		_rings.append(ring)
	var chart := SurfaceTool.new()
	chart.begin(Mesh.PRIMITIVE_TRIANGLES)
	SeaChart.add_ring(chart, Vector2.ZERO, r_cap, 0.9, 0.1, maxi(24, int(r_cap * TAU / 10.0)), true)
	_vis.add_child(SeaChart.mesh_from(chart, Color(SeaChart.MAGENTA, 0.8)))
	var lab := SeaChart.flat_label("Sirenengesang", 40, SeaChart.MAGENTA, true)
	lab.position = Vector3(0, 0.1, -r_cap - 5.0)
	_vis.add_child(lab)


func _siren_figure() -> Node3D:
	var root := Node3D.new()
	var skin := Color(0.96, 0.8, 0.7)
	var teal := Color(0.2, 0.62, 0.6)
	var hair := Color(0.9, 0.62, 0.15)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.5
	cone.bottom_radius = 0.9
	cone.height = 2.4
	cone.radial_segments = 8
	var torso := CapsuleMesh.new()
	torso.radius = 0.5
	torso.height = 1.9
	var head := SphereMesh.new()
	head.radius = 0.45
	head.height = 0.9
	var fin := PrismMesh.new()
	fin.size = Vector3(1.8, 1.2, 0.12)
	_part(root, cone, teal, Vector3(0, 1.2, 0))
	_part(root, fin, teal.lightened(0.15), Vector3(0, 0.15, -0.9), Vector3(PI / 2, 0, 0))
	_part(root, torso, skin, Vector3(0, 3.0, 0))
	_part(root, head, skin, Vector3(0, 4.35, 0))
	_part(root, head, hair, Vector3(0, 4.3, -0.28), Vector3.ZERO, Vector3(1.15, 1.35, 1.0))
	ModelStyle.outline(root)
	return root


func _part(parent: Node3D, mesh: Mesh, col: Color, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> void:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	m.material_override = mat
	m.position = pos
	m.rotation = rot
	m.scale = scl
	parent.add_child(m)


func _process(delta: float) -> void:
	_st += delta
	var r0 := radius * (global_basis.x.length() + global_basis.z.length()) * 0.5
	var r_cap := capture_radius()
	for i in _rings.size():
		var ph := fposmod(_st / 3.2 + float(i) / _rings.size(), 1.0)
		var r := lerpf(r0, r_cap, ph)
		_rings[i].scale = Vector3(r, 1.0, r)
		(_rings[i].material_override as StandardMaterial3D).albedo_color = Color(0.25, 0.75, 0.8, 0.55 * (1.0 - ph))
	for i in _sirens.size():
		_sirens[i].rotation.z = sin(_st * 1.2 + i * 2.0) * 0.07
	if _notes:
		for i in _notes.get_child_count():
			var ph := fposmod(_st * 0.28 + float(i) / NOTE_COUNT, 1.0)
			var a := _st * 0.4 + TAU * i / NOTE_COUNT
			var n: Node3D = _notes.get_child(i)
			n.position = Vector3(cos(a), 0.0, sin(a)) * (6.0 + ph * 16.0) + Vector3(0, 5.0 + ph * 9.0, 0)
			n.scale = Vector3.ONE * sin(ph * PI) * 1.4
			n.rotation.z = sin(_st * 2.0 + i) * 0.3


## Jeden Physikschritt für jedes Boot (nur Host bzw. lokal)
func update_boat(b: Boat, _delta: float) -> void:
	if b.out or b.towed or b.finished:
		return
	var st: Dictionary = _state.get(b, {"near": false})
	_state[b] = st
	var d := b.pos2d().distance_to(pos2d())
	var r_cap := capture_radius()
	var near := d < r_cap + 40.0
	if near and not st["near"]:
		b.show_message("Sirenen-Insel voraus – nicht zu nah ran!", 3.0)
	st["near"] = near
	if d < r_cap and b.hold_kind == 0 and b.immune_time <= 0.0:
		b.start_hold(2, pos2d())
		b.show_message("Sirenengesang … du kannst nicht weg!", 3.0)
		Sfx.play("siren_song", -2.0)
