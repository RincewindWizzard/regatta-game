extends SceneTree
## Prüft die Aufgabenlogik der Segelschule ohne Grafik: Bootszustand wird direkt gesetzt, die Aufgabe
## wertet ihn aus. Positiv- und Negativfälle je Aufgabe.
## Aufruf: godot --headless --path . --script res://tests/tutorial_test.gd

var _main: Node
var _tut: Tutorial
var _boat: Boat
var _frames := 0
var _fails := 0


func _initialize() -> void:
	GameState.net_mode = ""
	GameState.level_path = "res://levels/09_segelschule.tscn"
	GameState.crew_choice = 2            # wird im Tutorial ignoriert
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)


func _check(name: String, ok: bool) -> void:
	print(("OK    " if ok else "FEHLER ") + name)
	if not ok:
		_fails += 1


## Boot setzen: Kurs h, Fahrt v (m/s), Position p
func _pose(h: float, v: float, p := Vector2(0, 0)) -> void:
	_boat.heading = h
	_boat.vel = Vector2(sin(h), cos(h)) * v
	_boat.position = Vector3(p.x, 0, p.y)


func _run(seconds: float, h: float, v: float, p := Vector2(0, 0)) -> void:
	for i in int(seconds * 60.0):
		_pose(h, v, p)
		_tut.step(1.0 / 60.0)


## Kurs mit Windeinfallswinkel a (Grad), Wind von Norden: Bug nach Norden = 0°
func _heading_for(a: float, left := true) -> float:
	var h := PI - deg_to_rad(a)
	return h if left else PI + deg_to_rad(a)


func _process(_d: float) -> bool:
	_frames += 1
	if _frames < 3:
		return false
	_tut = _main.tutorial
	_boat = _main.boats[0]
	_check("ein Boot, Tutorial aktiv", _main.boats.size() == 1 and _tut != null)
	_check("Rennlogik aus (Zustand racing, Kurs deaktiviert)", _main.state == "racing" and _main.course.disabled)
	_boat.set_physics_process(false)
	_tut.set_physics_process(false)
	_main.set_physics_process(false)

	# 1-4: Kurse zum Wind – Negativfälle, dann Positivfälle
	_run(8.0, _heading_for(48.0), 0.5)
	_check("Am Wind: zu langsam zählt nicht", _tut.index == 0)
	_run(8.0, _heading_for(70.0), 2.0)
	_check("Am Wind: falscher Winkel (70°) zählt nicht", _tut.index == 0)
	_run(6.5, _heading_for(48.0), 2.0)
	_check("Am Wind: 48° für 6 s -> Aufgabe gelöst", _tut.index == 1)
	_run(6.5, _heading_for(90.0, false), 2.0)
	_check("Halber Wind: 90° -> gelöst", _tut.index == 2)
	_run(6.5, _heading_for(135.0), 2.0)
	_check("Raumschots: 135° -> gelöst", _tut.index == 3)
	_run(6.5, _heading_for(175.0, false), 2.0)
	_check("Vorwind: 175° -> gelöst", _tut.index == 4)

	# 5: Vollkreis
	var h := 0.0
	for i in 150:                               # rund 200° Drehung -> noch nicht
		h += deg_to_rad(200.0) / 150.0
		_pose(h, 2.0)
		_tut.step(1.0 / 60.0)
	_check("Vollkreis: 200° zählt noch nicht", _tut.index == 4)
	for i in 120:                               # weitere 160° -> 360°
		h += deg_to_rad(160.0) / 120.0
		_pose(h, 2.0)
		_tut.step(1.0 / 60.0)
	_check("Vollkreis: 360° -> gelöst", _tut.index == 5)

	# 6: Achten um zwei Tonnen
	var a_pos: Vector2 = _main.level.get_node("Acht_A").pos2d()
	var b_pos: Vector2 = _main.level.get_node("Acht_B").pos2d()
	_far_circle(a_pos + Vector2(120, 0), 1.0)
	_check("Achten: Kreis weit weg von den Tonnen zählt nicht", _tut.index == 5)
	_circle_at(a_pos, 20.0, 1.0)               # linke Tonne nach links
	_check("Achten: linke Tonne umrundet, weiter mit der rechten", _tut.index == 5 and _tut.progress < 0.1)
	_circle_at(b_pos, 20.0, -1.0)              # rechte Tonne nach rechts
	_check("Achten: rechte Tonne in Gegenrichtung -> gelöst", _tut.index == 6)

	# 7: Aufschießer
	var buoy: Vector2 = _main.level.get_node("Uebungstonne").pos2d()
	_run(2.0, _heading_for(60.0), 0.1, buoy + Vector2(4, 0))
	_check("Aufschießer: Stehen ohne Anlauf zählt nicht", _tut.index == 6)
	_run(1.0, _heading_for(80.0), 2.5, buoy + Vector2(50, 0))
	_run(2.0, _heading_for(10.0), 0.2, buoy + Vector2(30, 0))
	_check("Aufschießer: zu weit weg (30 m) gestoppt zählt nicht", _tut.index == 6)
	_run(2.0, _heading_for(10.0), 0.2, buoy + Vector2(5, 0))
	_check("Aufschießer: neben der Tonne mit Anlauf gestoppt -> gelöst", _tut.index == 7)

	# 8: Mann über Bord
	_run(1.0, _heading_for(90.0), 3.0)
	_check("Mann über Bord: noch nichts abgesetzt", _tut.mob_pos == Vector2.INF)
	_run(2.5, _heading_for(90.0), 3.0)
	_check("Mann über Bord: Person abgesetzt", _tut.mob_pos != Vector2.INF)
	var mp: Vector2 = _tut.mob_pos
	_run(1.0, 0.0, 3.0, mp + Vector2(3, 0))
	_check("Mann über Bord: zu schnell vorbei zählt nicht", _tut.index == 7)
	_run(2.0, 0.0, 0.3, mp + Vector2(3, 0))
	_check("Mann über Bord: neben der Person gestoppt -> bestanden", _tut.done and _main.state == "finished")

	print("ERGEBNIS: ", "BESTANDEN" if _fails == 0 else "%d FEHLER" % _fails)
	quit(0 if _fails == 0 else 1)
	return true


## Kreis mit Radius r um c (dir +1 = nach links, -1 = nach rechts), 380°
func _circle_at(c: Vector2, r: float, dir: float) -> void:
	for i in 380:
		var t := deg_to_rad(float(i)) * dir
		# Position auf dem Kreis, Kurs tangential; Kurs ändert sich um dir * 1° je Schritt
		var p := c + Vector2(cos(t), -sin(t)) * r
		var hh := PI + deg_to_rad(float(i)) * dir + (PI * 0.5 if dir > 0.0 else -PI * 0.5)
		_pose(hh, 2.0, p)
		_tut.step(1.0 / 60.0)


func _far_circle(c: Vector2, dir: float) -> void:
	_circle_at(c, 40.0, dir)
