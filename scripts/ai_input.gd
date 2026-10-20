class_name AIInput
extends PlayerInput
## Computergegner. Segelt über dieselben Eingaben wie ein Mensch (Pinne, Schot,
## Wende-/Halse-Taste), hat also keine Vorteile bei der Physik.
##
## Ablauf alle paar Zehntelsekunden:
##  1. Zielpunkt bestimmen (Startlinie überqueren, Tonne anfahren, Ziel überqueren)
##  2. ~40 mögliche Kurse bewerten: Fahrt zum Ziel (VMG nach Polardiagramm),
##     Strafe für Untiefen/Land/Tonnen/Gebietsgrenze voraus (Strahl über die Seekarte),
##     Strafe für Wenden/Halsen (damit sie nicht hin und her zappelt)
##  3. Mit der Pinne auf den Kurs steuern (Wenden/Halsen = durch den Wind steuern)
##     und die Schot auf optimal trimmen
##  4. Strömung wird eingerechnet (Fahrt über Grund), der Motor nach Stärke genutzt,
##     bei knappem Tank wird eine nahe Tankstelle angelaufen
## Hängt sie fest (kein Fortschritt), segelt sie eine Weile einen Ausweichkurs.
##
## Wegplanung: Über die Seekarte liegt ein Raster (AStarGrid2D, 8 m Zellen), flaches
## Wasser und Tonnen sind gesperrt. Daraus wird ein Weg um Inseln und Sandbänke
## berechnet; angesteuert wird jeweils der am weitesten sichtbare Wegpunkt.

enum Level { LEICHT, MITTEL, SCHWER }

const NAMES := ["Leicht", "Mittel", "Schwer"]
## Bootsgeschwindigkeit je wahrem Windwinkel (Grad -> relativ), aus tests/polar_test.gd
const POLAR := [[0, 0.0], [30, 0.0], [38, 0.15], [45, 0.43], [52, 0.65], [60, 0.86], [75, 0.97],
	[90, 1.0], [110, 0.8], [130, 0.62], [150, 0.52], [170, 0.44], [180, 0.41]]

var boat: Boat
var wind: WindField
var course: Course
var fixed_points: Array = []
var level := Level.MITTEL

# Stärke-Parameter
var _think_every := 0.35
var _trim_error := 0.08
var _heading_noise := 0.06
var _look := 95.0
var _maneuver_cost := 0.14
var _use_local_wind := true
var _use_gusts := false

var _think_timer := 0.0
var _want_heading := 0.0
var _trim_offset := 0.0
var _trim_drift_timer := 0.0
var _since_maneuver := 99.0
var _min_gap := 8.0           # Mindestzeit zwischen Manövern (außer bei Gefahr)
var _progress_dist := INF
var _progress_timer := 0.0
var _detour_time := 0.0
var _detour_heading := 0.0
var _rng := RandomNumberGenerator.new()
var _last_side := 0
var docks: Array = []          # Tankstellen des Levels
var avoid: Array = []          # Gefahrengebiete [Mitte, Radius]: Minen, Polizei, Sirenen
var lanes: Array = []          # Schifffahrtswege (ShippingLane) mit Berufsschiffen
var _ship_preds: Array = []    # Schiffspositionen jetzt und in 4, 8, 12 s: [[Schiffe], …]
var _motor_use := 0.0          # 0 = nie, 1 = gern
var _motor_reserve := 1.0      # Tankanteil, der für Notfälle bleibt
var _want_throttle := 0
var _refuel_dock: Node = null
var _stall_time := 0.0
var _path := PackedVector2Array()
var _path_goal := Vector2.INF
var _path_timer := 0.0

# gemeinsames Navigationsraster aller Computerboote (pro Level einmal)
const NAV_CELL := 8.0
const NAV_SAFE_DEPTH := 1.6   ## Tiefgang 1 m + Reserve
static var _nav: AStarGrid2D
static var _nav_key := ""
static var _nav_origin := Vector2.ZERO


func _init(p_boat: Boat, p_wind: WindField, p_course: Course, p_level: int, p_fixed: Array) -> void:
	super(0)
	boat = p_boat
	wind = p_wind
	course = p_course
	level = p_level
	fixed_points = p_fixed
	_rng.randomize()
	match level:
		Level.LEICHT:
			_think_every = 0.7
			_trim_error = 0.2
			_heading_noise = 0.16
			_look = 55.0
			_maneuver_cost = 0.28
			_min_gap = 12.0
			_use_local_wind = false
			_motor_use = 0.0
			_motor_reserve = 0.5
		Level.MITTEL:
			_think_every = 0.45
			_trim_error = 0.15
			_heading_noise = 0.1
			_look = 80.0
			_maneuver_cost = 0.18
			_min_gap = 10.0
			_motor_use = 0.6
			_motor_reserve = 0.3
		Level.SCHWER:
			_think_every = 0.2
			_trim_error = 0.02
			_heading_noise = 0.015
			_look = 120.0
			_maneuver_cost = 0.16
			_min_gap = 9.0
			_use_gusts = true
			_motor_use = 1.0
			_motor_reserve = 0.12
	_think_timer = _rng.randf() * _think_every
	_want_heading = boat.heading


func update() -> void:
	gas_up_pressed = false
	gas_down_pressed = false
	start_pressed = false
	if boat == null or boat.towed or boat.out or boat.hold_kind != 0:
		steer = 0.0
		sheet_rate = 0.0
		_want_throttle = 0
		return
	if boat.finished:
		# im Ziel: Motor aus, Schoten los und austreiben lassen
		steer = 0.0
		sheet_rate = 1.0
		_want_throttle = 0
		_apply_throttle()
		return
	var delta := 1.0 / Engine.physics_ticks_per_second
	_since_maneuver += delta
	var side := _side(boat.heading, _wind_from(boat.pos2d()))
	if side != _last_side:
		_since_maneuver = 0.0
		_last_side = side
	_think_timer -= delta
	if _think_timer <= 0.0:
		_think_timer = _think_every
		_think()
	_trim(delta)
	_steer(delta)
	_apply_throttle()


# ---------------------------------------------------------------- Entscheiden

func _think() -> void:
	var p := boat.pos2d()
	_ship_preds.clear()
	if not lanes.is_empty():
		for dt in [0.0, 4.0, 8.0, 12.0]:
			var ships: Array = []
			for l in lanes:
				ships.append_array(l.ships_at(ShippingLane.clock + dt))
			_ship_preds.append(ships)
	var goal := _target_point(p)
	# Tank fast leer und eine Tankstelle in der Nähe? Dann dorthin.
	if _refuel_dock == null and boat.has_engine and _motor_use > 0.0 and boat.fuel_fraction() < 0.2:
		for d in docks:
			# nur, wenn die Tankstelle ungefähr auf dem Weg liegt
			var b: Vector2 = d.berth()
			var detour: float = p.distance_to(b) + b.distance_to(goal) - p.distance_to(goal)
			if p.distance_to(b) < 160.0 + 60.0 * _motor_use and detour < 50.0 + 40.0 * _motor_use:
				_refuel_dock = d
				break
	if _refuel_dock:
		if boat.fuel_fraction() > 0.92 or (not boat.refueling and boat.fuel_fraction() > 0.5 and boat.speed() < 0.3):
			_refuel_dock = null
		else:
			goal = _refuel_dock.berth()
			if p.distance_to(goal) < 9.0:
				# angekommen: Motor aus, in den Wind drehen und Schoten los
				_want_throttle = 0
				_want_heading = atan2(_wind_from(p).x, _wind_from(p).y)
				return
	var target := _waypoint(p, goal)
	_check_progress(p, goal)
	if _detour_time > 0.0:
		_want_heading = _detour_heading
		return
	var from_dir := _wind_from(p)
	var cur_side := _side(boat.heading, from_dir)
	var to_t := target - p
	var dist := to_t.length()
	var to_unit := to_t / maxf(dist, 0.01)
	var best := -INF
	var best_h := boat.heading
	# Gefahr auf dem jetzigen Kurs? Dann darf sofort gewendet werden
	var cur_hazard := _hazard(p, Vector2(sin(boat.heading), cos(boat.heading)), dist)
	var switch_cost := _maneuver_cost * (1.0 if dist > 60.0 else 0.4)
	if _since_maneuver < _min_gap and cur_hazard < 0.4:
		switch_cost += 0.6
	# Motor einplanen? (Stärke, Tankinhalt, Reserve)
	var motor := _plan_throttle(p, to_unit, dist, from_dir)
	var motor_v := 3.0 * float(motor) / Boat.THROTTLE_MAX
	var v_sail := 0.45 * maxf(wind.base_speed, 1.0)
	var cur := Currents.at(p)
	var candidates: Array[float] = []
	for k in 40:
		candidates.append(-PI + TAU * k / 40.0)
	candidates.append(atan2(to_unit.x, to_unit.y))
	candidates.append(boat.heading)
	for h in candidates:
		var dir := Vector2(sin(h), cos(h))
		var twa := absf(_twa(h, from_dir))
		var spd := _polar(twa)
		if _use_gusts:
			var ahead := p + dir * 45.0
			spd *= clampf(wind.get_wind(ahead, boat).length() / maxf(wind.base_speed, 0.1), 0.8, 1.25)
		# Fahrt über Grund: Segel + Motor + Strom, bezogen auf normale Segelfahrt
		var through_water := maxf(spd * v_sail, motor_v) + 0.3 * minf(spd * v_sail, motor_v)
		var ground := dir * through_water + cur
		var score := ground.dot(to_unit) / v_sail
		# Seite zum Wind wechseln kostet Zeit (mit Motor kaum)
		if _side(h, from_dir) != cur_side and twa > deg_to_rad(15.0):
			score -= switch_cost * (1.0 if motor == 0 else 0.3)
		# leichte Vorliebe für den aktuellen Wunschkurs (gegen Zappeln)
		score += 0.04 * cos(angle_difference(h, _want_heading))
		score -= _hazard(p, dir, dist)
		if score > best:
			best = score
			best_h = h
	_want_heading = best_h + _rng.randf_range(-1.0, 1.0) * _heading_noise
	_want_throttle = motor


## Wie viel Gas? Hängt von Stärke, Tank, Kurs zum Ziel und Notlagen ab.
func _plan_throttle(p: Vector2, to_unit: Vector2, dist: float, from_dir: Vector2) -> int:
	if not boat.has_engine or boat.fuel <= 0.05:
		return 0
	# Notlage: im Wind steckengeblieben oder zu langsam beim Wenden
	if boat.speed() < 0.5 and boat.in_irons:
		_stall_time += _think_every
	else:
		_stall_time = 0.0
	if _stall_time > 2.0:
		return 2
	if _motor_use <= 0.0:
		return 0
	var frac := boat.fuel_fraction()
	if frac <= _motor_reserve:
		return 0
	# lohnt sich: Ziel liegt (fast) gegen den Wind und ist noch weit
	var twa_target := absf(from_dir.angle_to(to_unit))
	var upwind := twa_target < deg_to_rad(55.0)
	if upwind and dist > 50.0:
		return 4 if _motor_use >= 1.0 and frac > 0.4 else (3 if _motor_use >= 1.0 else 2)
	# Gegenstrom
	var cur := Currents.at(p)
	if cur.dot(to_unit) < -0.6 and dist > 40.0:
		return 2
	return 0


func _apply_throttle() -> void:
	if boat.throttle < _want_throttle:
		gas_up_pressed = true
	elif boat.throttle > _want_throttle:
		gas_down_pressed = true


## Wohin soll das Boot gerade?
func _target_point(p: Vector2) -> Vector2:
	var idx := boat.next_target
	if idx >= course.targets.size():
		return p
	var t: Dictionary = course.targets[idx]
	if t["type"] == "mark":
		return t["pos"]
	var line := course.line
	var n := line.normal2d()
	var tan := line.tangent2d()
	var lat := clampf((p - line.center2d()).dot(tan), -line.half_width * 0.55, line.half_width * 0.55)
	var on_line := line.center2d() + tan * lat
	var sd := line.signed_dist(p)
	if int(t["dir"]) > 0:   # Start: von hinten nach vorn
		return line.center2d() - n * 30.0 if sd > 0.0 else on_line + n * 30.0
	# Ziel: von vorn nach hinten
	return line.center2d() + n * 30.0 if sd < 0.0 else on_line - n * 30.0


# ---------------------------------------------------------------- Wegplanung

func _ensure_nav() -> void:
	var key := "%s|%s" % [course.level.get_instance_id(), course.area]
	if _nav and _nav_key == key:
		return
	_nav_key = key
	var area := course.area
	_nav_origin = area.position
	_nav = AStarGrid2D.new()
	_nav.region = Rect2i(0, 0, int(ceil(area.size.x / NAV_CELL)), int(ceil(area.size.y / NAV_CELL)))
	_nav.cell_size = Vector2.ONE
	_nav.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_nav.default_compute_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
	_nav.default_estimate_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
	_nav.update()
	for y in _nav.region.size.y:
		for x in _nav.region.size.x:
			var c := _cell_center(Vector2i(x, y))
			if not _safe(c, 6.0):
				_nav.set_point_solid(Vector2i(x, y), true)
				continue
			# Kosten: nahe am Flachen etwas teurer, damit der Weg Abstand hält
			if not _safe(c, 14.0):
				_nav.set_point_weight_scale(Vector2i(x, y), 3.0)


func _safe(c: Vector2, margin: float) -> bool:
	for o in [Vector2.ZERO, Vector2(margin, 0), Vector2(-margin, 0), Vector2(0, margin), Vector2(0, -margin)]:
		if SeaChart.depth_at(c + o) < NAV_SAFE_DEPTH:
			return false
	for fp in fixed_points:
		var fc: Vector2 = fp[0]
		if fc.distance_to(c) < float(fp[1]) + margin:
			return false
	for z in avoid:
		var zc: Vector2 = z[0]
		if zc.distance_to(c) < float(z[1]) + margin + 4.0:
			return false
	return true


func _cell_of(p: Vector2) -> Vector2i:
	var q := (p - _nav_origin) / NAV_CELL
	return Vector2i(clampi(int(q.x), 0, _nav.region.size.x - 1), clampi(int(q.y), 0, _nav.region.size.y - 1))


func _cell_center(c: Vector2i) -> Vector2:
	return _nav_origin + (Vector2(c) + Vector2(0.5, 0.5)) * NAV_CELL


func _nearest_free(c: Vector2i) -> Vector2i:
	if not _nav.is_point_solid(c):
		return c
	for r in range(1, 12):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if absi(dx) != r and absi(dy) != r:
					continue
				var n := c + Vector2i(dx, dy)
				if _nav.region.has_point(n) and not _nav.is_point_solid(n):
					return n
	return c


## Nächster anzusteuernder Punkt auf dem geplanten Weg zum Ziel
func _waypoint(p: Vector2, goal: Vector2) -> Vector2:
	_ensure_nav()
	if _clear_line(p, goal):
		_path = PackedVector2Array()
		return goal
	_path_timer -= _think_every
	if _path.is_empty() or _path_goal.distance_to(goal) > 5.0 or _path_timer <= 0.0:
		_path_timer = 2.5
		_path_goal = goal
		var from := _nearest_free(_cell_of(p))
		var to := _nearest_free(_cell_of(goal))
		var cells := _nav.get_id_path(from, to)
		_path = PackedVector2Array()
		for c in cells:
			_path.append(_cell_center(c))
		if _path.is_empty():
			return goal
		_path[_path.size() - 1] = goal
	# weitesten sichtbaren Wegpunkt suchen (höchstens 250 m voraus)
	var best := _path[0]
	for i in _path.size():
		var w := _path[i]
		if w.distance_to(p) > 250.0:
			break
		if _clear_line(p, w):
			best = w
	return best


func _clear_line(a: Vector2, b: Vector2) -> bool:
	var dist := a.distance_to(b)
	var n := int(dist / 6.0) + 1
	var dir := (b - a) / maxf(dist, 0.01)
	var side := Vector2(-dir.y, dir.x) * 4.0
	for k in range(1, n + 1):
		var q := a.lerp(b, float(k) / n)
		if SeaChart.depth_at(q) < NAV_SAFE_DEPTH or SeaChart.depth_at(q + side) < 1.4 or SeaChart.depth_at(q - side) < 1.4:
			return false
		for fp in fixed_points:
			var fc: Vector2 = fp[0]
			if fc.distance_to(q) < float(fp[1]) + 5.0 and fc.distance_to(b) > 22.0:
				return false
		for z in avoid:
			var zc: Vector2 = z[0]
			if zc.distance_to(q) < float(z[1]) + 6.0:
				return false
	return true


## Strafe für Gefahren in Kursrichtung (geprüft wird ein Streifen in Bootsbreite).
## Weit entfernte Hindernisse kosten wenig, nahe sehr viel – wie beim echten Kreuzen,
## wo man erst kurz vor dem Ufer wendet.
func _hazard(p: Vector2, dir: Vector2, dist_target: float) -> float:
	var look := minf(_look, dist_target + 25.0)
	var area := course.area.grow(-12.0)
	var side := Vector2(-dir.y, dir.x) * 5.0
	var d := 4.0
	while d <= look:
		var q := p + dir * d
		var hit := not area.has_point(q)
		if not hit:
			for o in [Vector2.ZERO, side, -side]:
				if SeaChart.depth_at(q + o) < 1.4:
					hit = true
					break
		if not hit:
			for fp in fixed_points:
				var c: Vector2 = fp[0]
				if c.distance_to(q) < float(fp[1]) + 7.0:
					hit = true
					break
		if not hit:
			for z in avoid:
				var zc: Vector2 = z[0]
				if zc.distance_to(q) < float(z[1]) + 8.0:
					hit = true
					break
		if not hit and not _ship_preds.is_empty():
			# Berufsschiffe: wo das Boot in d/4 Sekunden ankommt, darf kein Schiff sein
			var ships: Array = _ship_preds[mini(int(d / 16.0), _ship_preds.size() - 1)]
			for sh in ships:
				if ShippingLane.hull_distance(sh, q) < Boat.BOAT_RADIUS + 14.0:
					hit = true
					break
		if hit:
			var k := 1.0 - d / (look + 4.0)
			return 3.0 * k * k
		d += 5.0 if d < 30.0 else 8.0
	return 0.0


## Kommt das Boot nicht voran (z. B. Bucht hinter einer Insel), Ausweichkurs fahren
func _check_progress(p: Vector2, target: Vector2) -> void:
	_detour_time -= _think_every
	var dist := p.distance_to(target)
	if dist < _progress_dist - 15.0:
		_progress_dist = dist
		_progress_timer = 0.0
	else:
		_progress_timer += _think_every
	if _progress_timer > 30.0 and _detour_time <= 0.0:
		_progress_timer = 0.0
		_progress_dist = INF
		var from_dir := _wind_from(p)
		var side := 1.0 if _rng.randf() < 0.5 else -1.0
		_detour_heading = atan2(-from_dir.x, -from_dir.y) + side * deg_to_rad(_rng.randf_range(70.0, 110.0))
		_detour_time = 12.0


# ---------------------------------------------------------------- Ausführen

func _steer(_delta: float) -> void:
	var diff := angle_difference(boat.heading, _want_heading)
	steer = clampf(-diff * 2.2, -1.0, 1.0)


func _trim(delta: float) -> void:
	if _refuel_dock and boat.pos2d().distance_to(_refuel_dock.berth()) < 12.0:
		sheet_rate = 1.0   # an der Tankstelle: Segel auf, damit das Boot steht
		return
	_trim_drift_timer -= delta
	if _trim_drift_timer <= 0.0:
		_trim_drift_timer = _rng.randf_range(2.0, 5.0)
		_trim_offset = _rng.randf_range(-1.0, 1.0) * _trim_error
	var target := clampf(boat.optimal_sheet() + _trim_offset, 0.0, 1.0)
	sheet_rate = clampf((target - boat.sheet) * 8.0, -1.0, 1.0)


# ---------------------------------------------------------------- Hilfen

func _wind_from(p: Vector2) -> Vector2:
	var d := wind.dir_at(p) if _use_local_wind else wind.base_dir
	return -WindField.dir_to_blow(d)


## Wahrer Windwinkel zum Kurs h; + = Wind von Backbord
func _twa(h: float, from_dir: Vector2) -> float:
	var fwd := Vector2(sin(h), cos(h))
	var port := Vector2(cos(h), -sin(h))
	return atan2(from_dir.dot(port), from_dir.dot(fwd))


func _side(h: float, from_dir: Vector2) -> int:
	return 1 if _twa(h, from_dir) >= 0.0 else -1


func _polar(twa: float) -> float:
	var deg := rad_to_deg(twa)
	for i in POLAR.size() - 1:
		var a: Array = POLAR[i]
		var b: Array = POLAR[i + 1]
		if deg <= b[0]:
			return lerpf(a[1], b[1], (deg - a[0]) / float(b[0] - a[0]))
	return POLAR[POLAR.size() - 1][1]
