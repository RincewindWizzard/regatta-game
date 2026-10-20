@tool
class_name ShipModel
extends RefCounted
## 3D-Modelle der Berufsschifffahrt (Containerschiff, Tanker, Massengutfrachter) im Stil von
## Schlepper, Polizeiboot und Segelboot: gestraker Rumpf aus Spanten (Loft), Wulstbug, runde
## Bordkanten, Unterwasseranstrich, Brücke mit Fensterband, Schornstein, Mast mit Radar, Kräne und
## Ladung. Bug zeigt nach lokal +Z, Wasserlinie bei y = 0, Brücke achtern.
##
## Wie beim Polizeiboot liegen entlang der Länge Querschnitte ("Spanten"); half_beam(t) gibt die
## halbe Breite, bottom(t) den Kiel. t läuft von 0 (Heck) bis 1 (Bug).

const NX := 40                  ## Spanten längs
const NS := 10                  ## Punkte je Spant
const FREEBOARD := 6.0          ## Höhe der Deckskante über der Wasserlinie

const WHITE := Color(0.95, 0.95, 0.93)
const GLASS := Color(0.07, 0.12, 0.2)
const BOTTOM := Color(0.5, 0.11, 0.09)
const DECK := Color(0.33, 0.35, 0.36)
const STEEL := Color(0.55, 0.58, 0.6)
const DARK := Color(0.16, 0.17, 0.2)

const HULL_COLORS := [Color(0.1, 0.2, 0.38), Color(0.5, 0.12, 0.1), Color(0.14, 0.32, 0.26)]
const STACK_COLORS := [Color(0.85, 0.15, 0.12), Color(0.95, 0.75, 0.1), Color(0.9, 0.9, 0.9)]


static func half_beam(t: float, beam: float) -> float:
	var hb := beam * 0.5
	var stern := 0.72 + 0.28 * sin(minf(t / 0.08, 1.0) * PI * 0.5)
	var u := maxf(0.0, (t - 0.74) / 0.26)
	var bow := pow(maxf(1.0 - pow(u, 2.1), 0.0), 0.65)
	return hb * stern * maxf(bow, 0.03)


## Kiel: mittschiffs tief, achtern und vorn hochgezogen (Wulstbug bleibt unter Wasser)
static func bottom(t: float) -> float:
	var stern := 1.0 - 0.5 * smoothstep(0.1, 0.0, t)
	return -3.2 * stern * (1.0 - 0.35 * smoothstep(0.88, 1.0, t))


static func _mat(c: Color, rough := 0.55) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func _box(parent: Node3D, size: Vector3, pos: Vector3, c: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = _mat(c)
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func _cyl(parent: Node3D, r0: float, r1: float, h: float, pos: Vector3, c: Color, rot := Vector3.ZERO, seg := 10) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.bottom_radius = r0
	m.top_radius = r1
	m.height = h
	m.radial_segments = seg
	mi.mesh = m
	mi.material_override = _mat(c)
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


## Gesamtes Schiff. type 0 = Containerschiff, 1 = Tanker, 2 = Massengutfrachter
static func build(type: int, length: float, beam: float) -> Node3D:
	var root := Node3D.new()
	var hull_c: Color = HULL_COLORS[type]
	_hull(root, length, beam, hull_c)
	_superstructure(root, length, beam, type)
	match type:
		0: _containers(root, length, beam)
		1: _tanker(root, length, beam)
		2: _bulker(root, length, beam)
	_bow_and_stern(root, length, beam, hull_c)
	ModelStyle.outline(root)
	ModelStyle.no_shadows(root)
	return root


static func _hull(root: Node3D, L: float, beam: float, hull_c: Color) -> void:
	var rows := []
	for i in NX + 1:
		var t := float(i) / NX
		var z := -L * 0.5 + L * t
		var hb := half_beam(t, beam)
		var bot := bottom(t)
		var u := maxf(0.0, (t - 0.74) / 0.26)
		var top := FREEBOARD + 1.2 * u * u          # Decksprung am Bug
		var row := []
		for j in NS + 1:
			var a := PI * j / NS
			var s := sin(a)
			var x := hb * signf(cos(a)) * pow(absf(cos(a)), 0.45)
			x *= 1.0 + 0.18 * u * (1.0 - pow(s, 0.6))      # Ausfall am Bug
			var y := top - (top - bot) * pow(s, 0.4)
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
			var hc: float = (q[0].y + q[1].y + q[2].y + q[3].y) * 0.25
			var k := 0                                     # Bordwand
			if hc < 0.9:
				k = 1                                      # Unterwasseranstrich
			for idx in [0, 1, 2, 0, 2, 3]:
				sts[k].add_vertex(q[idx])
	# Deck: Band zwischen Backbord- und Steuerbordkante
	for i in NX:
		var q := [rows[i][0], rows[i + 1][0], rows[i + 1][NS], rows[i][NS]]
		for idx in [0, 1, 2, 0, 2, 3]:
			sts[2].add_vertex(q[idx])
	var mats := [_mat(hull_c), _mat(BOTTOM), _mat(DECK, 0.8)]
	for k in 3:
		sts[k].generate_normals()
		var mi := MeshInstance3D.new()
		mi.mesh = sts[k].commit()
		mi.material_override = mats[k]
		root.add_child(mi)
	# Schanzkleid: dünne helle Reling-Leiste entlang beider Bordkanten
	for s in [-1.0, 1.0]:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in NX:
			var a0: Vector3 = rows[i][0 if s > 0 else NS]
			var a1: Vector3 = rows[i + 1][0 if s > 0 else NS]
			var h := 0.9
			var q := [a0, a1, a1 + Vector3(0, h, 0), a0 + Vector3(0, h, 0)]
			for idx in [0, 1, 2, 0, 2, 3]:
				st.add_vertex(q[idx])
		st.generate_normals()
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = _mat(hull_c.lightened(0.15))
		root.add_child(mi)


static func _superstructure(root: Node3D, L: float, beam: float, type: int) -> void:
	var zb := -L * 0.36
	var w := beam * 0.74
	var top0 := FREEBOARD + 0.9
	# Aufbau in vier Decks, nach oben schmaler; Fensterbänder dunkel
	var decks := 4
	for k in decks:
		var ww := w * (1.0 - 0.07 * k)
		var d := L * (0.12 - 0.012 * k)
		var y := top0 + 1.5 + k * 3.0
		_box(root, Vector3(ww, 3.0, d), Vector3(0, y, zb), WHITE)
		_box(root, Vector3(ww + 0.06, 1.0, d + 0.06), Vector3(0, y + 0.2, zb + 0.0), GLASS)
	# Brückenhaus mit Nocken (Wings) und Frontfenstern
	var by := top0 + 1.5 + decks * 3.0 + 0.4
	_box(root, Vector3(beam * 0.9, 2.2, L * 0.06), Vector3(0, by, zb + L * 0.01), WHITE)
	_box(root, Vector3(beam * 0.9 + 0.06, 1.0, L * 0.06 + 0.06), Vector3(0, by + 0.2, zb + L * 0.01), GLASS)
	_box(root, Vector3(beam * 0.96, 0.3, L * 0.07), Vector3(0, by + 1.3, zb + L * 0.01), DARK)
	# Schornstein mit Farbband und Kappe
	var sc: Color = STACK_COLORS[type]
	var sz := zb - L * 0.065
	_box(root, Vector3(beam * 0.3, 7.0, L * 0.05), Vector3(0, top0 + 4.0 + decks * 2.0, sz), WHITE)
	_box(root, Vector3(beam * 0.3 + 0.1, 2.4, L * 0.05 + 0.1), Vector3(0, top0 + 7.8 + decks * 2.0, sz), sc)
	_box(root, Vector3(beam * 0.3 + 0.2, 0.4, L * 0.05 + 0.2), Vector3(0, top0 + 9.2 + decks * 2.0, sz), DARK)
	# Mast mit Radar
	var my := by + 1.3
	_cyl(root, 0.18, 0.12, 6.0, Vector3(0, my + 3.0, zb + L * 0.01), STEEL, Vector3.ZERO, 6)
	_box(root, Vector3(3.6, 0.35, 0.5), Vector3(0, my + 5.2, zb + L * 0.01), STEEL)
	_box(root, Vector3(2.6, 0.3, 0.45), Vector3(0, my + 6.0, zb + L * 0.01), DARK)
	# Rettungsboote (orange) an beiden Seiten
	for s in [-1.0, 1.0]:
		var lb := _box(root, Vector3(1.6, 1.2, 6.0), Vector3(s * (w * 0.5 + 1.0), top0 + 4.5, zb - L * 0.01), Color(0.95, 0.45, 0.08))
		lb.scale = Vector3(1, 1, 1)


static func _bow_and_stern(root: Node3D, L: float, beam: float, hull_c: Color) -> void:
	# Poller-Gruppen und Ankerwinde auf dem Vorschiff, Hecklaterne
	var zf := L * 0.42
	_box(root, Vector3(beam * 0.3, 1.2, 4.0), Vector3(0, FREEBOARD + 1.4, zf), DARK)
	for s in [-1.0, 1.0]:
		_cyl(root, 0.35, 0.35, 1.0, Vector3(s * beam * 0.18, FREEBOARD + 1.2, L * 0.46), STEEL, Vector3.ZERO, 6)
	_cyl(root, 0.1, 0.1, 4.0, Vector3(0, FREEBOARD + 3.2, L * 0.47), STEEL, Vector3.ZERO, 6)
	_box(root, Vector3(0.9, 0.6, 0.9), Vector3(0, FREEBOARD + 5.3, L * 0.47), Color(0.95, 0.9, 0.5))


static func _containers(root: Node3D, L: float, beam: float) -> void:
	var cols := [Color(0.82, 0.22, 0.15), Color(0.2, 0.42, 0.72), Color(0.92, 0.7, 0.14), Color(0.22, 0.58, 0.34), Color(0.72, 0.72, 0.74), Color(0.9, 0.9, 0.88), Color(0.35, 0.22, 0.5)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var cw := beam * 0.17                       # Containerbreite
	var cl := L * 0.075
	var z := -L * 0.26
	var bays := 0
	while z < L * 0.3:
		var rows_n := 5
		var hgt := 2 + (bays * 7) % 3            # Stapelhöhe 2..4 Lagen
		for r in rows_n:
			var x := (r - (rows_n - 1) * 0.5) * (cw + 0.12)
			var layers := clampi(hgt + rng.randi_range(-1, 1), 1, 5)
			for k in layers:
				_box(root, Vector3(cw, 2.5, cl), Vector3(x, FREEBOARD + 1.6 + k * 2.55, z), cols[rng.randi() % cols.size()])
		z += cl + 0.5
		bays += 1


static func _tanker(root: Node3D, L: float, beam: float) -> void:
	var pipe := Color(0.24, 0.24, 0.26)
	# Mittelgang mit Rohrleitung über die ganze Länge, Querleitungen und Tankdome
	_box(root, Vector3(0.9, 0.7, L * 0.6), Vector3(0, FREEBOARD + 1.5, L * 0.04), pipe)
	_box(root, Vector3(beam * 0.05, 0.4, L * 0.6), Vector3(beam * 0.12, FREEBOARD + 1.25, L * 0.04), Color(0.7, 0.68, 0.6))
	for i in 7:
		var z := -L * 0.22 + i * L * 0.085
		_box(root, Vector3(beam * 0.55, 0.5, 0.5), Vector3(0, FREEBOARD + 1.6, z), pipe)
		for s in [-1.0, 1.0]:
			_cyl(root, beam * 0.07, beam * 0.07, 0.9, Vector3(s * beam * 0.24, FREEBOARD + 1.3, z), STEEL, Vector3.ZERO, 8)
	# Ladegeschirr (Manifold) und Kranausleger
	_box(root, Vector3(beam * 0.6, 0.5, 0.8), Vector3(0, FREEBOARD + 2.1, L * 0.05), Color(0.85, 0.6, 0.1))
	_box(root, Vector3(0.5, 6.0, 0.5), Vector3(beam * 0.3, FREEBOARD + 4.0, L * 0.05), Color(0.85, 0.6, 0.1))


static func _bulker(root: Node3D, L: float, beam: float) -> void:
	var hatch := Color(0.72, 0.7, 0.58)
	for i in 5:
		var z := -L * 0.24 + i * L * 0.135
		_box(root, Vector3(beam * 0.68, 1.4, L * 0.1), Vector3(0, FREEBOARD + 1.6, z), hatch)
		_box(root, Vector3(beam * 0.68 + 0.2, 0.3, L * 0.1 + 0.2), Vector3(0, FREEBOARD + 2.4, z), hatch.darkened(0.2))
	# Deckskräne zwischen den Luken
	for i in 2:
		var z := -L * 0.08 + i * L * 0.27
		_box(root, Vector3(1.6, 1.0, 1.6), Vector3(beam * 0.34, FREEBOARD + 1.5, z), Color(0.9, 0.55, 0.1))
		_cyl(root, 0.5, 0.6, 7.0, Vector3(beam * 0.34, FREEBOARD + 5.0, z), Color(0.9, 0.55, 0.1))
		_box(root, Vector3(0.4, 0.4, 12.0), Vector3(beam * 0.28, FREEBOARD + 8.0, z + 3.0), Color(0.9, 0.55, 0.1), Vector3(-0.35, 0, 0))
