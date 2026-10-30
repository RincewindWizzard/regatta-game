class_name Tutorial
extends Node
## Segelschule: geführte Übungen für einen Spieler. Die Aufgaben werden nacheinander gestellt:
## Kurse zum Wind (Am Wind, Halber Wind, Raumschots, Vorwind), Vollkreis, Achten um zwei
## Regattatonnen, Aufschießer an der Tonne, Mann über Bord.
##
## Die Logik ist eine Zustandsmaschine über Bootszustand und Wind (kein Rennablauf). `step(delta)`
## wertet den aktuellen Zustand aus; die HUD (`_draw_tutorial`) liest Aufgabe, Fortschritt, Hinweis.

signal task_done(index: int)
signal finished

const HOLD_TIME := 6.0            ## so lange muss ein Kurs zum Wind gehalten werden
const MIN_SPEED := 1.2            ## Mindestfahrt (m/s) bei den Kursübungen
const CIRCLE_DEG := 340.0         ## Drehung für einen Vollkreis
const EIGHT_RADIUS := 45.0        ## Umkreis um die Tonne, in dem die Drehung zählt
const EIGHT_WINDOW := 120.0       ## Sekunden bis zur zweiten Tonne
const STOP_RADIUS := 8.0          ## Aufschießer: so nah an die Tonne
const STOP_SPEED := 0.5           ## ... und so langsam
const STOP_ARM_DIST := 25.0       ## erst nach einem Anlauf aus dieser Entfernung zählt das Stehenbleiben
const MOB_RADIUS := 6.0
const MOB_SPEED := 0.8
const MOB_DROP_BEHIND := 15.0

## Windeinfallswinkel-Bereiche (Grad, 0 = genau gegen den Wind)
const RANGES := {"am_wind": [40.0, 55.0], "halb": [80.0, 100.0], "raum": [120.0, 145.0], "vorwind": [165.0, 180.0]}

const TASKS := [
	{"id": "am_wind", "titel": "Am Wind", "text": "Segle am Wind: Etwa 45° zum Wind, Segel dicht. Halte den Kurs."},
	{"id": "halb", "titel": "Halber Wind", "text": "Segle Halben Wind: Der Wind kommt quer von der Seite (90°). Schot etwas fieren."},
	{"id": "raum", "titel": "Raumschots", "text": "Segle Raumschots: Der Wind kommt schräg von hinten (etwa 135°). Schot weit fieren."},
	{"id": "vorwind", "titel": "Vorwind", "text": "Segle Vorwind: Der Wind kommt direkt von hinten. Schot ganz fieren."},
	{"id": "kreis", "titel": "Vollkreis", "text": "Segle einen Vollkreis: Dreh das Boot einmal ganz herum, immer in dieselbe Richtung."},
	{"id": "acht", "titel": "Achten", "text": "Segle eine Acht: Umrunde die linke Tonne nach links, dann die rechte Tonne nach rechts."},
	{"id": "aufschiesser", "titel": "Aufschießer", "text": "Lauf die gelbe Tonne an, schieße in den Wind auf und bleib höchstens 8 m neben ihr stehen."},
	{"id": "mob", "titel": "Mann über Bord", "text": "Segle auf Halbwindkurs. Gleich fällt jemand über Bord – wende zurück und stoppe neben ihm."},
]

var main: Node
var boat: Boat
var wind: WindField
var level: Level

var index := 0                    ## laufende Aufgabe
var progress := 0.0               ## 0..1 (Haltedauer, Drehung ...)
var hint := ""                    ## kurzer Hinweis bei Fehlversuchen
var done := false
var done_time := 0.0
var flash := 1.0                  ## Einblend-Zeit des Anleitungstextes (1 → 0)
var mob_pos := Vector2.INF        ## Person im Wasser (INF = noch nicht abgesetzt)
var mob_dist := 0.0
var mob_bearing := 0.0            ## relativ zum Bug in Grad (+ = rechts)

var _prev_heading := 0.0
var _turn_acc := 0.0              ## aufsummierte Kursänderung (+ = nach links)
var _turn_peak := 0.0
var _eight_stage := 0             ## 0 linke Tonne, 1 rechte Tonne
var _eight_timer := 0.0
var _armed := false
var _mob_timer := 0.0
var _mob_node: Node3D
var _warn_cd := 0.0


func setup(p_main: Node, p_level: Level, p_boat: Boat, p_wind: WindField) -> void:
	main = p_main
	level = p_level
	boat = p_boat
	wind = p_wind
	_prev_heading = boat.heading
	_enter_task()


func current() -> Dictionary:
	return TASKS[mini(index, TASKS.size() - 1)]


func _physics_process(delta: float) -> void:
	step(delta)


## Wertet einen Physikschritt aus (auch von Tests direkt aufrufbar)
func step(delta: float) -> void:
	flash = maxf(0.0, flash - delta * 0.8)
	_warn_cd = maxf(0.0, _warn_cd - delta)
	if done or boat == null or boat.out:
		return
	match String(current()["id"]):
		"am_wind", "halb", "raum", "vorwind":
			_hold_course(delta)
		"kreis":
			_circle(delta)
		"acht":
			_eight(delta)
		"aufschiesser":
			_luff_stop(delta)
		"mob":
			_man_overboard(delta)
	_prev_heading = boat.heading
	if is_instance_valid(_mob_node):
		_mob_node.position = Vector3(mob_pos.x, 0.0, mob_pos.y)


# ---------------------------------------------------------------- Aufgaben

## Windeinfallswinkel in Grad (0 = genau gegen den Wind, 180 = Vorwind)
func true_wind_angle() -> float:
	var tw := wind.get_wind(boat.pos2d(), boat)
	if tw.length() < 0.01:
		return 0.0
	var from := -tw.normalized()
	var fwd := Vector2(sin(boat.heading), cos(boat.heading))
	return rad_to_deg(acos(clampf(from.dot(fwd), -1.0, 1.0)))


func _hold_course(delta: float) -> void:
	var r: Array = RANGES[String(current()["id"])]
	var a := true_wind_angle()
	var fast := boat.speed() >= MIN_SPEED
	if fast and a >= float(r[0]) and a <= float(r[1]):
		progress += delta / HOLD_TIME
		hint = ""
	else:
		progress = maxf(0.0, progress - delta * 3.0 / HOLD_TIME)
		if not fast:
			hint = "Mehr Fahrt! Trimm die Schot und halte den Kurs."
		elif a < float(r[0]):
			hint = "Zu hoch am Wind (%d°): etwas abfallen." % roundi(a)
		else:
			hint = "Zu weit abgefallen (%d°): etwas anluven." % roundi(a)
	if progress >= 1.0:
		_complete()


## Kursänderung aufsummieren (+ = nach links); bei Richtungswechsel von vorn beginnen
func _accumulate_turn() -> void:
	if boat.speed() < 0.8:
		return
	var dh := angle_difference(_prev_heading, boat.heading)
	_turn_acc += dh
	if absf(_turn_acc) > absf(_turn_peak):
		_turn_peak = _turn_acc
	elif absf(_turn_acc) < absf(_turn_peak) - 0.6:     # Drehrichtung gewechselt
		_turn_acc = dh
		_turn_peak = dh


func _circle(_delta: float) -> void:
	_accumulate_turn()
	progress = clampf(absf(_turn_acc) / deg_to_rad(CIRCLE_DEG), 0.0, 1.0)
	hint = ""
	if boat.speed() < 0.8:
		hint = "Du brauchst Fahrt für den Kreis."
	if progress >= 1.0:
		_complete()


func _eight(delta: float) -> void:
	var mark := _mark("Acht_A" if _eight_stage == 0 else "Acht_B")
	if mark == null:
		return
	var dist := boat.pos2d().distance_to(mark.pos2d())
	if _eight_stage == 1:
		_eight_timer -= delta
		if _eight_timer <= 0.0:
			_eight_stage = 0
			_reset_turn()
			hint = "Zu lange gebraucht – beginne wieder an der linken Tonne."
			return
	if dist > EIGHT_RADIUS:
		if _turn_acc != 0.0:
			hint = "Näher an die Tonne (%d m)! Die Drehung zählt nur im Umkreis von %d m." % [roundi(dist), roundi(EIGHT_RADIUS)]
		else:
			hint = "Fahr zur %s Tonne." % ("linken" if _eight_stage == 0 else "rechten")
		_reset_turn()
		progress = 0.0
		return
	_accumulate_turn()
	var want_left := _eight_stage == 0
	var dir_ok := (_turn_acc > 0.0) == want_left or absf(_turn_acc) < 0.05
	progress = clampf(absf(_turn_acc) / deg_to_rad(CIRCLE_DEG), 0.0, 1.0) if dir_ok else 0.0
	hint = "" if dir_ok else "Andere Drehrichtung: um die %s Tonne nach %s." % [("linke" if want_left else "rechte"), ("links" if want_left else "rechts")]
	if dir_ok and progress >= 1.0:
		if _eight_stage == 0:
			_eight_stage = 1
			_eight_timer = EIGHT_WINDOW
			_reset_turn()
			progress = 0.0
			hint = "Gut! Jetzt die rechte Tonne nach rechts umrunden."
			Sfx.play("bell", -8.0, 1.2)
		else:
			_complete()


func _luff_stop(_delta: float) -> void:
	var mark := _mark("Uebungstonne")
	if mark == null:
		return
	var dist := boat.pos2d().distance_to(mark.pos2d())
	var speed := boat.speed()
	if not _armed:
		hint = "Lauf die Tonne mit Fahrt an (aus mehr als %d m)." % roundi(STOP_ARM_DIST)
		if speed >= 1.5 and dist > STOP_ARM_DIST:
			_armed = true
			hint = ""
		progress = 0.0
		return
	progress = clampf(1.0 - (dist - STOP_RADIUS) / 60.0, 0.0, 1.0)
	if dist <= STOP_RADIUS and speed < STOP_SPEED and true_wind_angle() <= 45.0:
		_complete()
	elif speed < STOP_SPEED and dist > STOP_RADIUS:
		hint = "Zu weit weg (%d m): bis auf %d m an die Tonne heranschießen." % [roundi(dist), roundi(STOP_RADIUS)]
	elif dist <= STOP_RADIUS and speed >= 1.0:
		hint = "Fiere die Schot und drehe in den Wind, um zu stoppen."
	else:
		hint = ""


func _man_overboard(delta: float) -> void:
	if mob_pos == Vector2.INF:
		var a := true_wind_angle()
		if boat.speed() >= 2.0 and a >= 70.0 and a <= 110.0:
			_mob_timer += delta
			hint = ""
		else:
			_mob_timer = maxf(0.0, _mob_timer - delta)
			hint = "Segle mit Fahrt auf Halbwindkurs (Wind quer von der Seite)."
		if _mob_timer >= 2.0:
			_drop_mob()
		return
	mob_dist = boat.pos2d().distance_to(mob_pos)
	var to := mob_pos - boat.pos2d()
	mob_bearing = rad_to_deg(angle_difference(boat.heading, atan2(to.x, to.y)))   # + = links des Buges
	mob_bearing = -mob_bearing                                                      # + = rechts
	progress = clampf(1.0 - (mob_dist - MOB_RADIUS) / 100.0, 0.0, 1.0)
	var speed := boat.speed()
	if mob_dist <= MOB_RADIUS and speed < MOB_SPEED:
		_complete()
	elif mob_dist <= MOB_RADIUS and speed >= MOB_SPEED:
		if _warn_cd <= 0.0:
			boat.show_message("Zu schnell – nochmal anlaufen!", 2.5)
			_warn_cd = 4.0
		hint = "Zu schnell! Schieße auf und stoppe neben der Person."
	elif mob_dist > 200.0:
		hint = "Du entfernst dich von der Person – wende!"
	else:
		hint = ""


func _drop_mob() -> void:
	var fwd := Vector2(sin(boat.heading), cos(boat.heading))
	mob_pos = boat.pos2d() - fwd * MOB_DROP_BEHIND
	mob_dist = MOB_DROP_BEHIND
	_mob_node = _make_mob_marker()
	level.add_child(_mob_node)
	_mob_node.position = Vector3(mob_pos.x, 0.0, mob_pos.y)
	boat.show_message("Mann über Bord!", 4.0)
	Sfx.play("ship_horn", -4.0, 1.3)
	flash = 1.0
	hint = ""
	progress = 0.0


func _make_mob_marker() -> Node3D:
	var root := Node3D.new()
	root.name = "MannUeberBord"
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.45
	tm.outer_radius = 0.9
	tm.rings = 16
	tm.ring_segments = 8
	ring.mesh = tm
	ring.material_override = _mat(Color(0.95, 0.35, 0.08))
	ring.position.y = 0.15
	root.add_child(ring)
	var head := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.28
	sm.height = 0.56
	head.mesh = sm
	head.material_override = _mat(Color(0.95, 0.8, 0.65))
	head.position.y = 0.2
	root.add_child(head)
	var light := MeshInstance3D.new()
	var lm := SphereMesh.new()
	lm.radius = 0.18
	lm.height = 0.36
	light.mesh = lm
	var lmat := _mat(Color(1.0, 0.2, 0.1))
	lmat.emission_enabled = true
	lmat.emission = Color(1.0, 0.25, 0.1)
	lmat.emission_energy_multiplier = 3.0
	light.material_override = lmat
	light.position = Vector3(0.0, 1.3, 0.0)
	root.add_child(light)
	var pole := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.03
	cm.bottom_radius = 0.03
	cm.height = 1.2
	pole.mesh = cm
	pole.material_override = _mat(Color(0.2, 0.2, 0.22))
	pole.position.y = 0.7
	root.add_child(pole)
	var tag := Label3D.new()
	tag.text = "Person im Wasser"
	tag.font = SeaChart.font(true)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.font_size = 48
	tag.outline_size = 10
	tag.outline_modulate = Color(1, 1, 1, 0.9)
	tag.modulate = Color(0.8, 0.15, 0.05)
	tag.pixel_size = 0.03
	tag.position = Vector3(0.0, 4.0, 0.0)
	root.add_child(tag)
	ModelStyle.outline(root)
	return root


# ---------------------------------------------------------------- Ablauf

func _complete() -> void:
	task_done.emit(index)
	Sfx.play("bell", -4.0, 1.0)
	boat.show_message("%s geschafft!" % String(current()["titel"]), 2.5)
	index += 1
	if index >= TASKS.size():
		done = true
		done_time = float(main.race_time) if main else 0.0
		hint = ""
		progress = 1.0
		Sfx.play("finish", -2.0)
		boat.show_message("Segelschule bestanden!", 6.0)
		finished.emit()
		return
	_enter_task()


func _enter_task() -> void:
	progress = 0.0
	hint = ""
	flash = 1.0
	_reset_turn()
	_eight_stage = 0
	_eight_timer = 0.0
	_armed = false
	_mob_timer = 0.0
	_prev_heading = boat.heading


func _reset_turn() -> void:
	_turn_acc = 0.0
	_turn_peak = 0.0
	_prev_heading = boat.heading


func _mark(node_name: String) -> CourseMark:
	return level.get_node_or_null(node_name) as CourseMark


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.6
	return m
