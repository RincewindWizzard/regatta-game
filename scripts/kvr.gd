class_name Kvr
extends RefCounted
## Kollisionsverhütungsregeln (KVR) als lehrreiche Einblendung: Nähern sich zwei Boote, sagt das
## Spiel jedem, wer ausweichen muss und wer Wegerecht hat, mit der passenden Regel
## ("Baum links, bringt's!"). Das hat keine Folgen für das Rennen, es erklärt nur.
##
## Erkannt wird eine Annäherung mit dem CPA (Closest Point of Approach): Wenn die Boote auf
## ihrem jetzigen Kurs in den nächsten Sekunden dicht aneinander vorbeikämen, gilt die Regel:
##   Regel 18  Maschine weicht Segler aus
##   Regel 13  Überholer hält sich frei
##   Regel 12  Segler: Wind von Backbord weicht aus (Baum links, bringt's); gleiche Seite: Luv weicht Lee
##   Regel 14  zwei Maschinen auf Gegenkurs: beide nach Steuerbord
##   Regel 15  zwei Maschinen kreuzen: wer den anderen an Steuerbord hat, weicht aus

const RANGE := 70.0            ## so nah müssen sich die Boote kommen
const TCPA_MAX := 14.0         ## in so vielen Sekunden würden sie am dichtesten sein ...
const CPA_MAX := 22.0          ## ... und sich dabei bis auf so viele Meter nähern
const PAUSE := 14.0            ## Sekunden Pause, bis dasselbe Paar wieder eine Meldung bekommt

enum Kind { INFO, VORFAHRT, AUSWEICHEN }

var _last := {}                ## "i:j" -> Zeitpunkt der letzten Meldung


## Alle Bootspaare prüfen. Nur Boote von Menschen bekommen Meldungen (Computer lesen keine).
func update(boats: Array, wind: WindField, time: float) -> void:
	for i in boats.size():
		for j in range(i + 1, boats.size()):
			var a: Boat = boats[i]
			var b: Boat = boats[j]
			if a.out or b.out or a.towed or b.towed or a.finished or b.finished:
				continue
			if a.hold_kind != 0 or b.hold_kind != 0:
				continue
			var a_human := a.input != null and not (a.input is AIInput)
			var b_human := b.input != null and not (b.input is AIInput)
			if not a_human and not b_human:
				continue
			var key := "%d:%d" % [i, j]
			if time - float(_last.get(key, -1000.0)) < PAUSE:
				continue
			if not approaching(a, b):
				continue
			var r := assess(a, b, WindField.dir_to_blow(wind.dir_at(a.pos2d())))
			if r.is_empty():
				continue
			_last[key] = time
			if a_human:
				a.show_kvr(r["a_title"], r["a_sub"], r["a_kind"])
			if b_human:
				b.show_kvr(r["b_title"], r["b_sub"], r["b_kind"])


## Kommen sich die Boote auf dem jetzigen Kurs gefährlich nah? (CPA/TCPA)
static func approaching(a: Boat, b: Boat) -> bool:
	var r := b.pos2d() - a.pos2d()
	if r.length() > RANGE:
		return false
	var v := b.vel - a.vel
	var v2 := v.length_squared()
	if v2 < 0.25:                                   # fast gleiche Fahrt: keine Annäherung
		return false
	var tcpa := -r.dot(v) / v2
	if tcpa <= 0.0 or tcpa > TCPA_MAX:
		return false
	return (r + v * tcpa).length() < CPA_MAX


## Welche Regel gilt? Leeres Dictionary, wenn keine Aussage möglich ist.
static func assess(a: Boat, b: Boat, blow: Vector2) -> Dictionary:
	var a_sail := not a.engine_running()
	var b_sail := not b.engine_running()
	# Regel 18: Maschinenfahrzeug weicht Segler aus
	if a_sail != b_sail:
		return _result(18, "KVR 18 – Maschine weicht Segler aus", "Du fährst mit Motor: Ausweichen!",
			"Segel vor Motor: Kurs und Fahrt halten", not a_sail)
	# Regel 13: Überholen (auf Segel wie auf Motor)
	var over := _overtaking(a, b)
	if over != 0:
		return _result(13, "KVR 13 – Überholer hält Abstand", "Du überholst: Ausweichen!",
			"Du wirst überholt: Kurs halten", over == 1)
	if a_sail and b_sail:
		# Regel 12: beide unter Segel
		var a_port := _wind_from_port(a, blow)
		var b_port := _wind_from_port(b, blow)
		if absf(a.awa) < 0.12 or absf(b.awa) < 0.12:
			return {}                                   # im Wind stehend: keine Aussage
		if a_port != b_port:
			# Wind von Backbord weicht aus; Wind von Steuerbord ("Baum links") hat Wegerecht
			return _result(12, "KVR 12 – Backbordbug weicht aus", "Wind von Backbord: Ausweichen!",
				"Wind von Steuerbord: Du hast Wegerecht", a_port, "KVR 12 – Baum links, bringt's!")
		# gleiche Seite: das Luvboot weicht dem Leeboot aus
		var a_is_lee := (a.pos2d() - b.pos2d()).dot(blow) > 0.0
		return _result(12, "KVR 12 – Luv gibt Lee Raum", "Du bist das Luvboot: Ausweichen!",
			"Du bist das Leeboot: Du hast Wegerecht", not a_is_lee)
	# zwei Maschinenfahrzeuge
	var ha := Vector2(sin(a.heading), cos(a.heading))
	var hb := Vector2(sin(b.heading), cos(b.heading))
	if ha.dot(hb) < -0.98:
		return {"a_title": "KVR 14 – Gegenkurs", "a_sub": "Beide nach Steuerbord ausweichen", "a_kind": Kind.INFO,
			"b_title": "KVR 14 – Gegenkurs", "b_sub": "Beide nach Steuerbord ausweichen", "b_kind": Kind.INFO}
	# Regel 15: wer den anderen an Steuerbord hat, weicht aus
	return _result(15, "KVR 15 – Kurs kreuzt", "Der andere ist an Steuerbord: Ausweichen!",
		"Der andere muss ausweichen: Kurs halten", _on_starboard(a, b))


## give_a = true: Boot a weicht aus, sonst Boot b
## Der Titel nennt die Regel; stand_title darf von give_title abweichen (z. B. der Merkspruch)
static func _result(_rule: int, title: String, give_text: String, stand_text: String, give_a: bool, stand_title := "") -> Dictionary:
	var st := stand_title if stand_title != "" else title
	return {
		"a_title": title if give_a else st, "a_sub": give_text if give_a else stand_text,
		"a_kind": Kind.AUSWEICHEN if give_a else Kind.VORFAHRT,
		"b_title": st if give_a else title, "b_sub": stand_text if give_a else give_text,
		"b_kind": Kind.VORFAHRT if give_a else Kind.AUSWEICHEN,
	}


## Kommt der wahre Wind von Backbord (links)? Dann segelt das Boot auf Backbordbug.
static func _wind_from_port(b: Boat, blow: Vector2) -> bool:
	var port := Vector2(cos(b.heading), -sin(b.heading))
	return (-blow).dot(port) > 0.0


## Liegt das andere Boot rechts voraus (0° bis 112,5° an Steuerbord)?
static func _on_starboard(me: Boat, other: Boat) -> bool:
	var d := other.pos2d() - me.pos2d()
	var fwd := Vector2(sin(me.heading), cos(me.heading))
	var port := Vector2(cos(me.heading), -sin(me.heading))
	var ahead := d.dot(fwd)
	var side := d.dot(port)                       # + = links, - = rechts
	return side < 0.0 and ahead > -d.length() * 0.38


## 1 = a überholt b, 2 = b überholt a, 0 = kein Überholen (Sektor 135° nach achtern, schneller)
static func _overtaking(a: Boat, b: Boat) -> int:
	if _overtakes(a, b):
		return 1
	if _overtakes(b, a):
		return 2
	return 0


static func _overtakes(o: Boat, t: Boat) -> bool:
	var d := o.pos2d() - t.pos2d()
	var back := -Vector2(sin(t.heading), cos(t.heading))
	if d.length() < 0.5 or d.normalized().dot(back) < cos(deg_to_rad(67.5)):
		return false                              # nicht im Sektor hinter dem Boot
	return o.vel.length() > t.vel.length() + 0.3
