@tool
class_name Deco
extends RefCounted
## Bausteine für Landschaft im Spielzeug-Stil: Felsen, Bäume, Häuser, Feuertürme.

const ROCK_COLS := [Color(0.48, 0.47, 0.45), Color(0.56, 0.54, 0.5), Color(0.42, 0.41, 0.4), Color(0.6, 0.58, 0.53)]


static func _mat(c: Color, rough := 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


## Viele Felsbrocken als ein MultiMesh. items: [Vector3 pos, float size]
static func rocks(parent: Node3D, items: Array, seed_val: int) -> MultiMeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var mesh := SphereMesh.new()
	mesh.radial_segments = 7
	mesh.rings = 4
	mesh.radius = 1.0
	mesh.height = 1.4
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.95
	mesh.material = m
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = items.size()
	for i in items.size():
		var it: Array = items[i]
		var p: Vector3 = it[0]
		var s: float = it[1]
		var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.3, 0.3))
		b = b * Basis.from_scale(Vector3(s * rng.randf_range(0.8, 1.3), s * rng.randf_range(0.5, 0.8), s * rng.randf_range(0.8, 1.2)))
		mm.set_instance_transform(i, Transform3D(b, p))
		mm.set_instance_color(i, ROCK_COLS[rng.randi() % ROCK_COLS.size()])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_overlay = ModelStyle.outline_material()
	parent.add_child(mi)
	return mi


static func tree(parent: Node3D, pos: Vector3, rng: RandomNumberGenerator) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = rng.randf() * TAU
	var s := rng.randf_range(0.8, 1.4)
	root.scale = Vector3.ONE * s
	parent.add_child(root)
	var trunk := MeshInstance3D.new()
	var tc := CylinderMesh.new()
	tc.top_radius = 0.18
	tc.bottom_radius = 0.25
	tc.height = 1.6
	tc.radial_segments = 6
	trunk.mesh = tc
	trunk.material_override = _mat(Color(0.42, 0.28, 0.16))
	trunk.position.y = 0.8
	root.add_child(trunk)
	if rng.randf() < 0.55:
		# Kiefer: zwei Kegel
		for k in 2:
			var c := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.0
			cm.bottom_radius = 1.5 - k * 0.4
			cm.height = 2.4
			cm.radial_segments = 7
			c.mesh = cm
			c.material_override = _mat(Color(0.16, 0.38, 0.22).lightened(rng.randf() * 0.1))
			c.position.y = 2.4 + k * 1.3
			root.add_child(c)
	else:
		# Laubbaum: Kugel
		var c := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 1.6
		sm.height = 2.8
		sm.radial_segments = 8
		sm.rings = 5
		c.mesh = sm
		c.material_override = _mat(Color(0.3, 0.52, 0.22).lightened(rng.randf() * 0.12))
		c.position.y = 2.8
		root.add_child(c)
	ModelStyle.outline(root)


static func house(parent: Node3D, pos: Vector3, rot: float, rng: RandomNumberGenerator) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = rot
	parent.add_child(root)
	var walls := [Color(0.96, 0.94, 0.88), Color(0.86, 0.36, 0.26), Color(0.95, 0.85, 0.6)]
	var w := rng.randf_range(4.0, 6.0)
	var d := rng.randf_range(5.0, 8.0)
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w, 2.8, d)
	body.mesh = bm
	body.material_override = _mat(walls[rng.randi() % walls.size()])
	body.position.y = 1.4
	root.add_child(body)
	var roof := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(w + 0.6, 2.0, d + 0.6)
	roof.mesh = pm
	roof.material_override = _mat(Color(0.62, 0.2, 0.15) if rng.randf() < 0.6 else Color(0.25, 0.27, 0.3))
	roof.position.y = 3.8
	root.add_child(roof)
	var door := MeshInstance3D.new()
	var dm := BoxMesh.new()
	dm.size = Vector3(0.9, 1.6, 0.1)
	door.mesh = dm
	door.material_override = _mat(Color(0.2, 0.25, 0.35))
	door.position = Vector3(0, 0.8, d * 0.5 + 0.02)
	root.add_child(door)
	ModelStyle.outline(root)


## Turm mit Farbbändern, Galerie, Laternenhaus. Gibt die Höhe des Lichts zurück.
static func tower(parent: Node3D, bands: Array, height: float, radius: float, lamp_col: Color) -> float:
	var n := bands.size()
	var seg_h := height / n
	for k in n:
		var seg := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		var t0 := float(k) / n
		var t1 := float(k + 1) / n
		cyl.bottom_radius = lerpf(radius, radius * 0.65, t0)
		cyl.top_radius = lerpf(radius, radius * 0.65, t1)
		cyl.height = seg_h
		cyl.radial_segments = 16
		seg.mesh = cyl
		seg.material_override = _mat(bands[k], 0.6)
		seg.position.y = seg_h * (k + 0.5)
		parent.add_child(seg)
	var top_r := radius * 0.65
	var gallery := MeshInstance3D.new()
	var gm := CylinderMesh.new()
	gm.top_radius = top_r * 1.45
	gm.bottom_radius = top_r * 1.45
	gm.height = 0.3
	gallery.mesh = gm
	gallery.material_override = _mat(Color(0.15, 0.15, 0.17))
	gallery.position.y = height + 0.15
	parent.add_child(gallery)
	var lantern := MeshInstance3D.new()
	var lm := CylinderMesh.new()
	lm.top_radius = top_r * 0.85
	lm.bottom_radius = top_r * 0.85
	lm.height = 1.6
	lantern.mesh = lm
	var glass := _mat(lamp_col, 0.2)
	glass.emission_enabled = true
	glass.emission = lamp_col
	glass.emission_energy_multiplier = 1.5
	lantern.material_override = glass
	lantern.position.y = height + 1.1
	parent.add_child(lantern)
	var cap := MeshInstance3D.new()
	var cm := SphereMesh.new()
	cm.radius = top_r
	cm.height = top_r * 1.2
	cap.mesh = cm
	cap.material_override = _mat(Color(0.18, 0.2, 0.22))
	cap.position.y = height + 1.95
	parent.add_child(cap)
	return height + 1.1


## Drehender Lichtkegel (Lichtfächer, von oben gut sichtbar)
static func beam(parent: Node3D, y: float, length: float, col: Color) -> Node3D:
	var pivot := Node3D.new()
	pivot.position.y = y
	parent.add_child(pivot)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [1.0, -1.0]:
		var a := 0.12
		st.set_color(Color(col, 0.16))
		st.add_vertex(Vector3.ZERO)
		st.set_color(Color(col, 0.0))
		st.add_vertex(Vector3(sin(a) * length, 0, cos(a) * length) * side)
		st.set_color(Color(col, 0.0))
		st.add_vertex(Vector3(sin(-a) * length, 0, cos(-a) * length) * side)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(mi)
	return pivot
