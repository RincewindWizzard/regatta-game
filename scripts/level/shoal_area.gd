@tool
@icon("res://addons/regatta_editor/icons/shoal.svg")
class_name ShoalArea
extends Node3D
## Untiefe, Insel oder See. Form: Kreis mit Radius; mit Skalieren (X/Z) und Drehen
## werden daraus Ellipsen. Der Rand ist leicht unregelmäßig wie auf einer echten Karte.
##   Untiefe: in der Mitte flach (Mitteltiefe), am Radius 1 m (= Tiefgang)
##   Insel:   am Radius liegt die Uferlinie, innen Land
##   See:     gräbt im Binnenrevier Wasser aus (Tiefe = see_depth in der Mitte)

enum Kind { UNTIEFE, INSEL, SEE }

@export var kind := Kind.UNTIEFE:
	set(v):
		kind = v
		_changed()
@export var area_name := "Untiefe":
	set(v):
		area_name = v
		_rebuild()
@export_range(5.0, 250.0, 1.0, "suffix:m") var radius := 30.0:
	set(v):
		radius = v
		_changed()
## Wassertiefe in der Mitte einer Untiefe
@export_range(0.1, 0.95, 0.05, "suffix:m") var center_depth := 0.3:
	set(v):
		center_depth = v
		_changed()
## Wassertiefe in der Mitte eines Sees
@export_range(2.0, 30.0, 0.5, "suffix:m") var see_depth := 8.0:
	set(v):
		see_depth = v
		_changed()
@export var rock_symbol := true:
	set(v):
		rock_symbol = v
		_rebuild()
@export var lighthouse := false:
	set(v):
		lighthouse = v
		_rebuild()
@export var light_characteristic := "Fl(3)WR.15s 21m 12M":
	set(v):
		light_characteristic = v
		_rebuild()
@export_group("Insel-Ausstattung")
## Bäume auf der Insel
@export_range(0, 80) var trees := 0:
	set(v):
		trees = v
		_rebuild()
## kleine Häuser auf der Insel
@export_range(0, 20) var houses := 0:
	set(v):
		houses = v
		_rebuild()
## Felsen entlang des Ufers
@export var shore_rocks := true:
	set(v):
		shore_rocks = v
		_rebuild()

var _vis: Node3D
var _outline: MeshInstance3D
var _inv := Transform3D.IDENTITY


func _ready() -> void:
	set_notify_transform(true)
	_rebuild()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		if _vis:
			_vis.global_position = Vector3(global_position.x, 0, global_position.z)
		_notify_level()


func _changed() -> void:
	_rebuild()
	_notify_level()


func _notify_level() -> void:
	if Engine.is_editor_hint() and is_inside_tree():
		var lvl := get_parent() as Level
		if lvl:
			lvl.queue_preview()


func pos2d() -> Vector2:
	return Vector2(global_position.x, global_position.z)


## Wie weit die Form den Seegrund beeinflusst (Meter)
func reach() -> float:
	_inv = global_transform.affine_inverse()
	var s := maxf(absf(global_basis.x.length()), absf(global_basis.z.length()))
	if kind == Kind.INSEL:
		return radius * s + 90.0
	if kind == Kind.SEE:
		return radius * s * 1.3 + 12.0
	return radius * s * 4.0


func carves() -> bool:
	return kind == Kind.SEE


## See: Wasser ausgraben (Maximum mit dem bestehenden Raster)
func carve_grid(grid: PackedFloat32Array, res: int) -> void:
	var reach_m := reach()
	var c := pos2d()
	var step := SeaChart.AREA_SIZE / res
	var amin := SeaChart.AREA_MIN
	var warp := FastNoiseLite.new()
	warp.seed = int(radius * 7.0) + 5
	warp.frequency = 0.02
	var i0 := clampi(int((c.x - reach_m - amin.x) / step), 0, res - 1)
	var i1 := clampi(int((c.x + reach_m - amin.x) / step) + 1, 0, res - 1)
	var j0 := clampi(int((c.y - reach_m - amin.y) / step), 0, res - 1)
	var j1 := clampi(int((c.y + reach_m - amin.y) / step) + 1, 0, res - 1)
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var p := amin + Vector2(i + 0.5, j + 0.5) * step
			var w := Vector2(warp.get_noise_2d(p.x, p.y), warp.get_noise_2d(p.y + 50.0, p.x)) * 10.0
			var l := _inv * Vector3(p.x + w.x, 0, p.y + w.y)
			var k := Vector2(l.x, l.z).length() / radius
			if k < 1.25:
				var d := see_depth * (1.0 - k * k) + SeaChart.LAND * smoothstep(0.85, 1.25, k)
				var idx := j * res + i
				grid[idx] = maxf(grid[idx], d)


## Wassertiefe dieser Form an Weltposition p (vorher reach() aufrufen)
func depth_profile(p: Vector2) -> float:
	var l := _inv * Vector3(p.x, 0, p.y)
	var k := Vector2(l.x, l.z).length() / radius
	if kind == Kind.INSEL:
		# Uferhang in Metern: ca. 1 m Tiefe pro 4,5 m Abstand vom Ufer
		return SeaChart.LAND + (k - 1.0) * radius * 0.22
	return center_depth + k * k * (SeaChart.DRAFT - center_depth)


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _vis:
		_vis.queue_free()
	if _outline:
		_outline.queue_free()
		_outline = null
	# Symbole unverzerrt (unabhängig von Skalierung/Drehung)
	_vis = Node3D.new()
	_vis.top_level = true
	add_child(_vis)
	_vis.global_position = Vector3(global_position.x, 0, global_position.z)
	if kind == Kind.SEE:
		var lab := SeaChart.flat_label(area_name, 72, Color(0.15, 0.25, 0.45), true)
		lab.position = Vector3(0, 0.08, 0)
		_vis.add_child(lab)
	elif kind == Kind.UNTIEFE:
		if rock_symbol:
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			SeaChart.add_line(st, Vector2(-1.6, 0), Vector2(1.6, 0), 0.35, 0.07)
			SeaChart.add_line(st, Vector2(0, -1.6), Vector2(0, 1.6), 0.35, 0.07)
			SeaChart.add_ring(st, Vector2.ZERO, 4.0, 0.3, 0.07, 20, true)
			_vis.add_child(SeaChart.mesh_from(st, SeaChart.INK))
		var lab := SeaChart.flat_label(area_name, 52, Color(0.15, 0.25, 0.45), true)
		lab.position = Vector3(0, 0.07, radius * 0.35 + 3.0)
		_vis.add_child(lab)
	else:
		var lab := SeaChart.flat_label(area_name, 64, SeaChart.INK, true)
		lab.position = Vector3(0, 0.08, radius * 0.45)
		_vis.add_child(lab)
		if lighthouse:
			var tower := Node3D.new()
			_vis.add_child(tower)
			SeaChart.build_lighthouse(tower, light_characteristic)
			ModelStyle.outline(tower)
		_build_island_deco()
	# Im Editor: gestrichelter Umriss zum Anfassen
	if Engine.is_editor_hint():
		var st2 := SurfaceTool.new()
		st2.begin(Mesh.PRIMITIVE_TRIANGLES)
		SeaChart.add_ring(st2, Vector2.ZERO, radius, 0.5, 0.3, 64, true)
		_outline = SeaChart.mesh_from(st2, Color(0.9, 0.3, 0.1, 0.7))
		add_child(_outline)


## Punkt in der (ggf. gedrehten/gestreckten) Inselform relativ zur Inselmitte
func _island_point(u: Vector2) -> Vector3:
	var g := global_transform * Vector3(u.x * radius, 0, u.y * radius)
	return Vector3(g.x - global_position.x, 0, g.z - global_position.z)


func _build_island_deco() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(radius * 13.0) + trees * 7 + houses * 3 + area_name.length()
	if shore_rocks:
		var items: Array = []
		var n := int(radius * 0.6)
		for k in n:
			var a := TAU * k / n + rng.randf() * 0.2
			var r := rng.randf_range(0.9, 1.08)
			items.append([_island_point(Vector2(cos(a), sin(a)) * r) + Vector3(0, rng.randf_range(-0.2, 0.4), 0), rng.randf_range(1.2, 2.6)])
		if n > 0:
			Deco.rocks(_vis, items, rng.seed)
	var taken: Array[Vector3] = []
	if lighthouse:
		taken.append(Vector3.ZERO)
	for k in houses:
		var p := _free_spot(rng, taken, 0.55, 9.0)
		if p != Vector3.INF:
			Deco.house(_vis, p, rng.randf() * TAU, rng)
	for k in trees:
		var p := _free_spot(rng, taken, 0.75, 3.5)
		if p != Vector3.INF:
			Deco.tree(_vis, p, rng)


func _free_spot(rng: RandomNumberGenerator, taken: Array[Vector3], max_r: float, gap: float) -> Vector3:
	for attempt in 12:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * max_r
		var p := _island_point(Vector2(cos(a), sin(a)) * r)
		var ok := true
		for q in taken:
			if q.distance_to(p) < gap:
				ok = false
				break
		if ok:
			taken.append(p)
			return p
	return Vector3.INF
