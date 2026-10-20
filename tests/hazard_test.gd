extends SceneTree
## Headless-Test der Gefahrengebiete, Kollisionsfolgen und des Wendeschubs.
## Aufruf: godot --headless --fixed-fps 60 --path . --script res://tests/hazard_test.gd -- <mine|polizei|sirene|kollision|wende>

var _main: Node
var _t := 0.0
var _scenario := ""
var _phase := 0
var _t0 := 0.0
var _ok := false
var _ship_pos := Vector2.ZERO


func _level_for(s: String) -> String:
	match s:
		"mine":
			return "res://levels/03_rund_um_moewenhoern.tscn"
		"polizei":
			return "res://levels/04_hafenausfahrt.tscn"
		"sirene":
			return "res://levels/06_schaerengarten.tscn"
		"schiff":
			return "res://levels/05_lotsenrinne.tscn"
	return "res://levels/01_mittelgrund.tscn"


func _initialize() -> void:
	_scenario = OS.get_cmdline_user_args()[0]
	GameState.net_mode = ""
	GameState.level_path = _level_for(_scenario)
	GameState.crew_choice = 0          # zwei Spieler, nichts wird gesteuert
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)


func _place(b: Boat, p: Vector2, heading: float, speed: float) -> void:
	b.position = Vector3(p.x, 0, p.y)
	b.heading = heading
	b.vel = Vector2(sin(heading), cos(heading)) * speed


func _physics_process(delta: float) -> bool:
	if _main.boats.is_empty():
		return false
	_t += delta
	var b: Boat = _main.boats[0]
	var b2: Boat = _main.boats[1]
	if _phase == 0:
		_main.countdown = 0.0
		_main.state = "racing"
		for x in _main.boats:
			x.controls_enabled = true
		_phase = 1
		_t0 = _t
		# das zweite Boot weit weg parken
		_place(b2, Vector2(0, 150), 0.0, 0.0)
		match _scenario:
			"mine":
				var area: RestrictedArea = _main.level.get_node("Minenfeld")
				var m: Vector2 = area.pos2d() + area._mine_pos[0]
				print("Mine bei ", m)
				_place(b, m + Vector2(-20, 0), PI / 2, 3.0)
			"polizei":
				var area: RestrictedArea = _main.level.get_node("Sperrgebiet")
				_place(b, area.pos2d(), PI / 2, 2.0)
			"sirene":
				var isle: SirenIsland = _main.level.get_node("Sireneninsel")
				_place(b, isle.pos2d() + Vector2(0, -isle.capture_radius() - 8.0), 0.0, 3.0)
				print("Fangradius ", isle.capture_radius())
			"schiff":
				var lane: ShippingLane = _main.level.shipping_lanes()[0]
				_main.race_time = 150.0                      # main.gd gibt diese Rennzeit an die Schiffe weiter
				var ships := lane.ships_at(_main.race_time)
				var sh: Dictionary = ships[0]
				print("Schiffe: ", ships.size(), ", erstes ", sh["name"], " bei ", sh["pos"])
				# Boot direkt vor den Bug setzen, das Schiff fährt hinein
				_place(b, sh["pos"] + sh["dir"] * (sh["half"] + 6.0), 0.0, 0.0)
				_ship_pos = sh["pos"]
			"debug":
				Boat.debug_mode = true
				_place(b, Vector2(100, 100), PI, 0.0)       # freie Fahrt nach Norden
				b.fuel = 0.0
				b.has_engine = false
				b.sheet = 1.0
			"kvr":
				# Gegenkurs: A (Kurs Ost) hat bei Nordwind den Wind von Backbord, B (Kurs West) von Steuerbord
				_place(b, Vector2(-30, 0), PI / 2, 3.0)
				_place(b2, Vector2(30, 0), -PI / 2, 3.0)
			"kollision":
				_place(b, Vector2(0, -30), 0.0, 0.0)
				_place(b2, Vector2(0, -34), 0.0, 0.0)
				b.vel = Vector2(0, -3.0)
				b2.vel = Vector2(0, 3.0)
				b.position = Vector3(0, 0, -30)
				b2.position = Vector3(0, 0, -34)
			"wende":
				_place(b, Vector2(0, -60), 0.0, 3.2)
		return false
	var e := _t - _t0
	match _scenario:
		"mine":
			if b.out:
				print("OK: Boot explodiert nach %.1f s, out=%s" % [e, b.out])
				return _finish(true)
			if e > 15.0:
				return _finish(false)
		"polizei":
			if b.hold_kind == 1 and _phase == 1:
				print("Polizei greift zu nach %.1f s, hold_time %.1f" % [e, b.hold_time])
				_phase = 2
				_t0 = _t
			if _phase == 2 and b.hold_kind == 3 and _phase != 3:
				_phase = 3
				print("Kontrolle nach %.1f s, Abschleppen beginnt" % (_t - _t0))
			if _phase >= 2 and b.hold_kind == 0 and _t - _t0 > 1.0:
				var zone: RestrictedArea = _main.level.get_node("Sperrgebiet")
				var dist := b.pos2d().distance_to(zone.pos2d()) if zone else 0.0
				print("OK: nach %.1f s frei, %.0f m von der Mitte (Radius %.0f), Schonfrist %.1f s" % [_t - _t0, dist, zone.radius if zone else 0.0, b.immune_time])
				return _finish(_phase == 3 and zone != null and dist > zone.radius and b.immune_time > 20.0)
			if e > 90.0:
				return _finish(false)
		"sirene":
			if b.hold_kind == 2 and _phase == 1:
				print("Sirenengesang packt das Boot nach %.1f s" % e)
				_phase = 2
				_t0 = _t
			if _phase == 2 and b.hold_kind == 0:
				print("OK: Gesang nach %.1f s vorbei, Fahrt %.2f" % [_t - _t0, b.speed()])
				return _finish(true)
			if e > 30.0:
				return _finish(false)
		"debug":
			if e < 0.5:
				b._set_throttle(4)
			if e > 12.0:
				print("Debug: Tempo %.1f m/s (%.0f kn), Tank %.1f l, Motor %s" % [b.speed(), b.speed() * 1.944, b.fuel, b.engine])
				Boat.debug_mode = false
				return _finish(b.speed() > 10.0 and b.fuel >= Boat.TANK - 0.01)
		"kvr":
			_place(b, b.pos2d(), PI / 2, 3.0)
			_place(b2, b2.pos2d(), -PI / 2, 3.0)
			if b.kvr_time > 0.0 and b2.kvr_time > 0.0:
				print("A: %s | %s (Art %d)" % [b.kvr_title, b.kvr_sub, b.kvr_kind])
				print("B: %s | %s (Art %d)" % [b2.kvr_title, b2.kvr_sub, b2.kvr_kind])
				return _finish(b.kvr_kind == 2 and b2.kvr_kind == 1 and b2.kvr_title.contains("Baum links"))
			if e > 6.0:
				return _finish(false)
		"schiff":
			if b.out:
				var lane: ShippingLane = _main.level.shipping_lanes()[0]
				var dmin := INF
				for sh in lane.ships_at(_main.race_time):
					dmin = minf(dmin, ShippingLane.hull_distance(sh, b.pos2d()))
				print("OK: Zusammenstoß nach %.1f s, ausgeschieden, Abstand zum Rumpf %.1f m, Meldung: %s" % [e, dmin, b.message])
				return _finish(dmin > 0.0)
			if e > 8.0:
				return _finish(false)
		"kollision":
			if b.penalty > 0.0 and b2.penalty > 0.0:
				print("OK: Kollision, Strafe %.1f s / %.1f s, Fahrt %.2f / %.2f, Meldung: %s" % [b.penalty, b2.penalty, b.speed(), b2.speed(), b.message])
				var cases := [b.hold_case, b2.hold_case]
				print("Polizei: hold_kind %d/%d, Fall %s, Dauer %.0f/%.0f s" % [b.hold_kind, b2.hold_kind, cases, b.hold_total, b2.hold_total])
				return _finish(b.hold_kind == 1 and b2.hold_kind == 1 and cases.has(1) and cases.has(2) and absf(b.hold_total - b2.hold_total) > 5.0)
			if e > 5.0:
				return _finish(false)
		"wende":
			var from: float = _main.wind.dir_at(b.pos2d())
			var up: float = PI - from      # Kurs genau gegen den Wind
			if _phase == 1:
				# Kurs hoch am Wind auf einer Seite, dann auf die andere
				b.heading = wrapf(up + 0.8, -PI, PI)
				b.vel = Vector2(sin(b.heading), cos(b.heading)) * 3.2
				if e > 1.0:
					_phase = 2
			elif _phase == 2:
				b.heading = wrapf(up - 0.8, -PI, PI)
				b.vel = Vector2(sin(b.heading), cos(b.heading)) * 3.2
				if b.boost > 0.0:
					print("OK: Wende mit Schub, boost %.2f, Meldung: %s" % [b.boost, b.message])
					return _finish(true)
				if e > 4.0:
					print("Meldung: ", b.message)
					return _finish(false)
	return false


func _finish(ok: bool) -> bool:
	print("ERGEBNIS: ", "BESTANDEN" if ok else "FEHLGESCHLAGEN", " (", _scenario, ")")
	return true
