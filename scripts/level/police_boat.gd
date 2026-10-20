@tool
class_name PoliceBoat
extends RefCounted
## 3D-Modell des Wasserschutzpolizei-Bootes im Look von Schlepper und Segelboot: gestrecktes
## Streifenboot mit gestrakter Rumpfform (Spantenloft), weißen Bordwänden, blauem Streifen,
## Steuerhaus mit dunklen Scheiben, Blaulichtbalken, Radar, Suchscheinwerfer, Fendern und
## Schriftzug. Bug zeigt nach lokal +Z, Wasserlinie bei y = 0, Länge 12 m, Breite 3,4 m.
##
## Wie der Rumpf entsteht: Entlang der Länge liegen Querschnitte ("Spanten"). Jeder Spant ist ein
## Halbkreis-artiges Profil mit der Breite half_beam(z), dem Deckssprung sheer(z) und dem Kiel
## bottom(z). Benachbarte Spanten werden mit Vierecken verbunden (siehe _hull_surfaces).

const L := 12.0                 ## Länge
const NX := 26                  ## Spanten längs
const NS := 12                  ## Punkte je Spant (Backbord-Deck über den Kiel nach Steuerbord-Deck)

const WHITE := Color(0.95, 0.95, 0.93)
const BLUE := Color(0.08, 0.22, 0.6)
const BOTTOM := Color(0.42, 0.1, 0.09)
const DECK := Color(0.36, 0.4, 0.42)
const GLASS := Color(0.07, 0.12, 0.2)
const STEEL := Color(0.6, 0.62, 0.65)
const BLACK := Color(0.05, 0.05, 0.055)


static func _t(z: float) -> float:
	return clampf((z + L * 0.5) / L, 0.0, 1.0)


## halbe Breite entlang der Länge: rundes Heck, schlanker, spitzer Bug
static func half_beam(z: float) -> float:
	var t := _t(z)
	var stern := 0.86 + 0.14 * sin(minf(t / 0.2, 1.0) * PI * 0.5)
	var bow := pow(cos(maxf(0.0, (t - 0.5) / 0.5) * PI * 0.5), 0.75)
	return 1.7 * stern * maxf(bow, 0.05)


## Höhe der Deckskante über der Wasserlinie: vorn höher (Decksprung)
static func sheer(z: float) -> float:
	return 1.35 + 0.75 * pow(_t(z), 2.0)


## Kiel: achtern flach (Gleiter), zum Bug hin hochgezogen
static func bottom(z: float) -> float:
	return -0.55 + 0.5 * maxf(0.0, _t(z) - 0.7) / 0.3


static func _mat(c: Color, rough := 0.5, emissive := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.cull_mode = BaseMaterial3D.CULL_DISABLED      # Rumpfflächen von beiden Seiten
	if emissive:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 2.5
	return m


static func _box(parent: Node3D, size: Vector3, pos: Vector3, c: Color, rot := Vector3.ZERO, emissive := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = ModelStyle.rounded_box(size, minf(0.12, minf(size.x, minf(size.y, size.z)) * 0.3), 2)
	mi.material_override = _mat(c, 0.5, emissive)
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func _cyl(parent: Node3D, r: float, h: float, pos: Vector3, c: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = h
	m.radial_segments = 8
	mi.mesh = m
	mi.material_override = _mat(c)
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func _sphere(parent: Node3D, r: float, pos: Vector3, c: Color, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 10
	m.rings = 6
	mi.mesh = m
	mi.material_override = _mat(c)
	mi.position = pos
	mi.scale = scl
	parent.add_child(mi)
	return mi


## Rumpf als drei Flächen: weiße Bordwand, blauer Streifen, roter Unterwasseranstrich
static func _hull_surfaces() -> Array:
	var rows := []
	for i in NX + 1:
		var z := -L * 0.5 + L * i / NX
		var hb := half_beam(z)
		var top := sheer(z)
		var bot := bottom(z)
		var row := []
		for j in NS + 1:
			var a := PI * j / NS
			var x := hb * cos(a) * (0.78 + 0.22 * (1.0 - pow(sin(a), 4.0)))      # Boden etwas eingezogen
			var y := top - (top - bot) * pow(sin(a), 0.7)
			row.append(Vector3(x, y, z))
		rows.append(row)
	var sts: Array[SurfaceTool] = []
	for k in 3:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_smooth_group(1)
		sts.append(st)
	for i in NX:
		for j in NS:
			var q := [rows[i][j], rows[i + 1][j], rows[i + 1][j + 1], rows[i][j + 1]]
			var zc: float = (q[0].z + q[1].z) * 0.5
			var hc: float = (q[0].y + q[1].y + q[2].y + q[3].y) * 0.25
			var rel := hc - sheer(zc)
			var k := 0                                     # weiß
			if hc < 0.08:
				k = 2                                      # Unterwasseranstrich
			elif rel < -0.12 and rel > -0.5:
				k = 1                                      # blauer Streifen
			for idx in [0, 1, 2, 0, 2, 3]:
				sts[k].add_vertex(q[idx])
	var out: Array = []
	for st in sts:
		st.generate_normals()
		out.append(st.commit())
	return out


static func build() -> Node3D:
	var root := Node3D.new()
	var hull := Node3D.new()
	root.add_child(hull)
	var surf := _hull_surfaces()
	var cols := [WHITE, BLUE, BOTTOM]
	for k in 3:
		var mi := MeshInstance3D.new()
		mi.mesh = surf[k]
		mi.material_override = _mat(cols[k], 0.45)
		hull.add_child(mi)
	# Deck (Fläche innerhalb der Deckskante) mit Antirutsch-Grau
	var dst := SurfaceTool.new()
	dst.begin(Mesh.PRIMITIVE_TRIANGLES)
	var outline: Array[Vector2] = []
	for i in NX + 1:
		var z := -L * 0.5 + L * i / NX
		outline.append(Vector2(half_beam(z) * 0.93, z))
	for i in NX:
		var a := outline[i]
		var b := outline[i + 1]
		var ya := sheer(a.y) - 0.12
		var yb := sheer(b.y) - 0.12
		for idx in [Vector3(-a.x, ya, a.y), Vector3(a.x, ya, a.y), Vector3(a.x, yb, b.y),
				Vector3(-a.x, ya, a.y), Vector3(a.x, yb, b.y), Vector3(-b.x, yb, b.y)]:
			dst.add_vertex(idx)
	dst.generate_normals()
	var deck_mi := MeshInstance3D.new()
	deck_mi.mesh = dst.commit()
	deck_mi.material_override = _mat(DECK, 0.8)
	hull.add_child(deck_mi)

	# Fender: schwarze Wulste entlang der Deckskante
	for i in range(1, NX, 2):
		var z := -L * 0.5 + L * i / NX
		if _t(z) > 0.82:
			continue
		for s in [-1.0, 1.0]:
			_sphere(hull, 0.3, Vector3(s * (half_beam(z) + 0.05), sheer(z) - 0.32, z), BLACK, Vector3(0.9, 1.3, 1.5))
	# Reling am Bug: Rohre mit Stützen
	for s in [-1.0, 1.0]:
		for z in [1.5, 2.6, 3.7]:
			_cyl(hull, 0.04, 0.8, Vector3(s * half_beam(z) * 0.9, sheer(z) + 0.3, z), STEEL)
		var z0 := 1.5
		var z1 := 3.7
		_cyl(hull, 0.035, z1 - z0, Vector3(s * half_beam(2.6) * 0.9, sheer(2.6) + 0.68, (z0 + z1) * 0.5), STEEL, Vector3(PI / 2, 0, 0))
	# Poller, Anker, Bugscheinwerfer
	_cyl(hull, 0.16, 0.35, Vector3(0, sheer(4.8) + 0.12, 4.8), STEEL)
	_box(hull, Vector3(0.5, 0.12, 0.7), Vector3(0, sheer(3.6) - 0.03, 3.5), Color(0.25, 0.27, 0.3))

	# Steuerhaus mit schrägen Scheiben
	var cab := Node3D.new()
	cab.position = Vector3(0, sheer(-0.6), -0.9)
	root.add_child(cab)
	_box(cab, Vector3(2.7, 1.35, 3.1), Vector3(0, 0.68, 0), WHITE)
	_box(cab, Vector3(2.76, 0.28, 3.14), Vector3(0, 0.3, 0), BLUE)                    # blauer Streifen am Haus
	_box(cab, Vector3(2.9, 0.16, 3.3), Vector3(0, 1.42, 0), WHITE)                    # Dach mit Überstand
	# Frontscheibe geneigt, Seitenscheiben
	_box(cab, Vector3(2.5, 0.8, 0.12), Vector3(0, 0.95, 1.62), GLASS, Vector3(-0.35, 0, 0))
	for s in [-1.0, 1.0]:
		_box(cab, Vector3(0.1, 0.62, 2.2), Vector3(s * 1.38, 0.88, 0.05), GLASS)
		_box(cab, Vector3(0.1, 0.5, 0.7), Vector3(s * 1.38, 0.88, -1.02), Color(0.07, 0.12, 0.2))
	_box(cab, Vector3(2.0, 0.55, 0.1), Vector3(0, 0.9, -1.58), GLASS)                  # Heckfenster
	# Blaulichtbalken und Suchscheinwerfer auf dem Dach
	_box(cab, Vector3(1.5, 0.12, 0.34), Vector3(0, 1.56, 0.6), Color(0.15, 0.15, 0.18))
	var lamp_a := _box(cab, Vector3(0.62, 0.2, 0.3), Vector3(-0.52, 1.7, 0.6), Color(0.0, 0.25, 1.0), Vector3.ZERO, true)
	var lamp_b := _box(cab, Vector3(0.62, 0.2, 0.3), Vector3(0.52, 1.7, 0.6), Color(0.0, 0.25, 1.0), Vector3.ZERO, true)
	_cyl(cab, 0.12, 0.3, Vector3(0.0, 1.68, -0.2), STEEL)
	_sphere(cab, 0.2, Vector3(0.0, 1.9, -0.2), Color(1.0, 0.95, 0.7))
	# Radarmast mit drehender Antenne
	_cyl(cab, 0.07, 1.2, Vector3(0.0, 2.2, -1.1), STEEL)
	var radar := Node3D.new()
	radar.position = Vector3(0.0, 2.85, -1.1)
	cab.add_child(radar)
	_box(radar, Vector3(1.0, 0.08, 0.16), Vector3.ZERO, Color(0.85, 0.87, 0.9))
	_box(cab, Vector3(0.05, 0.9, 0.05), Vector3(0.9, 2.0, -1.2), STEEL)                # Funkantennen
	_box(cab, Vector3(0.05, 0.7, 0.05), Vector3(-0.9, 1.9, -1.2), STEEL)

	# Heck: Motorkasten, zwei Außenborder, Heckflagge
	_box(root, Vector3(2.3, 0.5, 1.5), Vector3(0, sheer(-5.0) + 0.2, -4.7), Color(0.9, 0.9, 0.88))
	for s in [-1.0, 1.0]:
		_box(root, Vector3(0.55, 0.9, 0.6), Vector3(s * 0.8, sheer(-5.8) + 0.05, -6.2), BLACK)
		_box(root, Vector3(0.18, 0.7, 0.35), Vector3(s * 0.8, -0.3, -6.3), BLACK)
	_cyl(root, 0.03, 1.8, Vector3(0.0, sheer(-5.9) + 0.9, -5.9), STEEL)
	_box(root, Vector3(0.7, 0.14, 0.02), Vector3(0.38, sheer(-5.9) + 1.65, -5.9), BLACK)
	_box(root, Vector3(0.7, 0.14, 0.02), Vector3(0.38, sheer(-5.9) + 1.51, -5.9), Color(0.8, 0.1, 0.1))
	_box(root, Vector3(0.7, 0.14, 0.02), Vector3(0.38, sheer(-5.9) + 1.37, -5.9), Color(0.95, 0.75, 0.1))
	# Rettungsring am Steuerhaus
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.18
	tm.outer_radius = 0.34
	ring.mesh = tm
	ring.material_override = _mat(Color(0.95, 0.4, 0.08))
	ring.position = Vector3(1.4, sheer(-0.6) + 0.7, -1.4)
	ring.rotation = Vector3(0, 0, PI / 2)
	root.add_child(ring)

	# Schriftzug "POLIZEI" an beiden Seiten
	for s in [-1.0, 1.0]:
		var lab := Label3D.new()
		lab.text = "POLIZEI"
		lab.font = SeaChart.font(false, true)
		lab.font_size = 64
		lab.pixel_size = 0.016
		lab.modulate = Color(0.98, 0.98, 0.98)
		lab.shaded = false
		lab.double_sided = false
		lab.position = Vector3(s * (half_beam(1.2) + 0.03), sheer(1.2) - 0.45, 1.2)
		lab.rotation = Vector3(0, s * PI * 0.5, 0)
		root.add_child(lab)

	ModelStyle.outline(root)
	ModelStyle.no_shadows(root)
	root.set_meta("lamps", [lamp_a, lamp_b])
	root.set_meta("radar", radar)
	root.scale = Vector3.ONE * 1.15                       # passt in der Größe zu Schlepper und Segelboot
	return root
