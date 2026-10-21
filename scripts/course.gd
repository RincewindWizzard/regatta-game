class_name Course
extends Node
## Bahnlogik: liest Start-/Ziellinie und Tonnen aus dem Level und verfolgt,
## welches Boot welches Ziel erreicht hat. Die Optik zeichnen die Level-Nodes selbst.

signal target_reached(boat: Boat, target_index: int, label: String)
signal boat_finished(boat: Boat)

const MARK_RADIUS := CourseMark.MARK_RADIUS

var level: Level
var line: StartLine
var finish_line: StartLine     ## eigene Ziellinie oder die Startlinie
## Regattagebiet: draußen wird man zurückgedrängt
var area := Rect2(-640, -840, 1280, 1280)
## Reihenfolge: Startlinie, Tonnen ..., Ziel
var targets: Array[Dictionary] = []


func setup(p_level: Level) -> void:
	level = p_level
	line = level.start_line()
	area = level.race_area()
	targets.clear()
	var own_finish := level.finish_line()
	finish_line = own_finish if own_finish else line
	targets.append({"type": "line", "name": "Startlinie", "pos": line.center2d(), "dir": 1, "line": line})
	for m in level.marks():
		targets.append({"type": "mark", "name": m.mark_name, "pos": m.pos2d()})
	# eigene Ziellinie: in Pfeilrichtung überqueren; sonst die Startlinie rückwärts
	targets.append({"type": "line", "name": "Ziel", "pos": finish_line.center2d(), "dir": 1 if own_finish else -1, "line": finish_line})


func target_pos(i: int) -> Vector2:
	var t: Dictionary = targets[clampi(i, 0, targets.size() - 1)]
	return t["pos"]


func target_name(i: int) -> String:
	if i >= targets.size():
		return "Ziel"
	return targets[i]["name"]


## Fortschritt fürs Ranking: erreichte Ziele zählen viel, dann Distanz zum nächsten.
func progress(boat: Boat) -> float:
	if boat.finished:
		return 1.0e9 - boat.finish_time
	if boat.out:
		return -1.0e9 + boat.next_target * 100000.0
	return boat.next_target * 100000.0 - boat.pos2d().distance_to(target_pos(boat.next_target))


## Ungefähre Bahnlänge (für die Menüanzeige)
static func course_length(lvl: Level) -> float:
	var sl := lvl.start_line()
	if sl == null:
		return 0.0
	var pts: Array[Vector2] = [sl.center2d()]
	for m in lvl.marks():
		pts.append(m.pos2d())
	var fl := lvl.finish_line()
	pts.append(fl.center2d() if fl else sl.center2d())
	var total := 0.0
	for i in pts.size() - 1:
		total += pts[i].distance_to(pts[i + 1])
	return total


func update_progress(boat: Boat, prev: Vector2, cur: Vector2) -> void:
	if boat.finished or boat.next_target >= targets.size():
		return
	var idx := boat.next_target
	var t: Dictionary = targets[idx]
	var reached := false
	if t["type"] == "mark":
		reached = cur.distance_to(t["pos"]) < MARK_RADIUS
	else:
		var tl: StartLine = t.get("line", line)
		var a := tl.signed_dist(prev)
		var b := tl.signed_dist(cur)
		var crossed := (a < 0.0 and b >= 0.0) if int(t["dir"]) > 0 else (a > 0.0 and b <= 0.0)
		reached = crossed and tl.within(cur)
	if not reached:
		return
	boat.next_target += 1
	if boat.next_target >= targets.size():
		boat.finished = true
		boat_finished.emit(boat)
	else:
		target_reached.emit(boat, idx, t["name"])
