@tool
class_name HazardVisuals
extends RefCounted
## Gemeinsame Bauteile der Gefahrengebiete: Polizeiboot, Seemine, schwebende Noten.


static func mat(c: Color, emissive := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	if emissive:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 2.0
	return m


static func _box(parent: Node3D, size: Vector3, pos: Vector3, c: Color, emissive := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat(c, emissive)
	mi.position = pos
	parent.add_child(mi)
	return mi


## Boot der Wasserschutzpolizei (Modell: police_boat.gd, Bug nach lokal +Z)
static func police_boat() -> Node3D:
	return PoliceBoat.build()


## Blaulicht blinkt abwechselnd
static func flash_lamps(police: Node3D, t: float) -> void:
	var lamps: Array = police.get_meta("lamps", [])
	for i in lamps.size():
		var mi: MeshInstance3D = lamps[i]
		var on := sin(t * 11.0 + i * PI) > 0.0
		var m := mi.material_override as StandardMaterial3D
		m.emission_energy_multiplier = 3.5 if on else 0.15
		m.albedo_color = Color(0.0, 0.25, 1.0) if on else Color(0.03, 0.08, 0.3)
	var radar: Node3D = police.get_meta("radar", null)
	if radar:
		radar.rotation.y = t * 4.0


## Seemine: schwarze Kugel mit Stacheln und rot blinkendem Licht. Gibt den Wurzelknoten zurück.
static func mine() -> Node3D:
	var root := Node3D.new()
	var body := Node3D.new()
	root.add_child(body)
	var ball := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.3
	sm.height = 2.6
	sm.radial_segments = 14
	sm.rings = 8
	ball.mesh = sm
	ball.material_override = mat(Color(0.14, 0.15, 0.17))
	body.add_child(ball)
	var dirs := [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK,
		Vector3(1, 1, 0).normalized(), Vector3(-1, 1, 0).normalized(), Vector3(0, 1, 1).normalized(), Vector3(0, 1, -1).normalized()]
	for d in dirs:
		var spike := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.28
		cm.height = 0.9
		cm.radial_segments = 6
		spike.mesh = cm
		spike.material_override = mat(Color(0.55, 0.5, 0.42))
		spike.position = d * 1.55
		spike.basis = Basis(Quaternion(Vector3.UP, d))
		body.add_child(spike)
	ModelStyle.outline(body)
	ModelStyle.no_shadows(body)
	var lamp := MeshInstance3D.new()
	var lm := SphereMesh.new()
	lm.radius = 0.32
	lm.height = 0.64
	lamp.mesh = lm
	lamp.material_override = mat(Color(1.0, 0.1, 0.05), true)
	lamp.position = Vector3(0, 1.75, 0)
	body.add_child(lamp)
	root.set_meta("body", body)
	root.set_meta("lamp", lamp)
	return root


## Vier Noten, die um ein Boot kreisen (Sirenengesang)
static func siren_notes() -> Node3D:
	var root := Node3D.new()
	var cols := [Color(0.95, 0.4, 0.7), Color(0.2, 0.75, 0.75), Color(0.95, 0.75, 0.2), Color(0.6, 0.45, 0.95)]
	for i in 4:
		var note := Node3D.new()
		var head := MeshInstance3D.new()
		var hm := SphereMesh.new()
		hm.radius = 0.7
		hm.height = 1.0
		head.mesh = hm
		head.material_override = mat(cols[i], true)
		note.add_child(head)
		_box(note, Vector3(0.14, 2.2, 0.14), Vector3(0.6, 1.0, 0), cols[i], true)
		_box(note, Vector3(0.7, 0.3, 0.14), Vector3(0.95, 2.0, 0), cols[i], true)
		root.add_child(note)
	return root


static func orbit_notes(notes: Node3D, t: float) -> void:
	var n := notes.get_child_count()
	for i in n:
		var a := t * 1.1 + TAU * i / n
		var note: Node3D = notes.get_child(i)
		note.position = Vector3(cos(a) * 7.5, 4.5 + sin(t * 2.0 + i * 1.7) * 1.0, sin(a) * 7.5)
		note.rotation.y = -a
		note.rotation.z = sin(t * 2.5 + i) * 0.25
