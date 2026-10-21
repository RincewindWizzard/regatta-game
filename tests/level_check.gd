extends SceneTree
## Prüft alle Level: Startplätze, Startlinie und Bahnmarken müssen in tiefem Wasser
## und im Regattagebiet liegen.
## Aufruf: godot --headless --path . --script res://tests/level_check.gd

var _frame := 0
var _levels: Array[Level] = []


func _initialize() -> void:
	for p in GameState.list_levels():
		var l: Level = load(p).instantiate()
		root.add_child(l)
		_levels.append(l)


func _process(_d: float) -> bool:
	_frame += 1
	if _frame < 3:
		return false
	var all_ok := true
	for l in _levels:
		SeaChart.set_depth_grid(l.compute_depth(256), 256)
		var area := l.race_area()
		var problems: Array[String] = []
		var line := l.start_line()
		var pts := {"Linienmitte": line.center2d()}
		for i in 4:
			pts["Startplatz %d" % (i + 1)] = line.start_position(i)
		var fin := l.finish_line()
		if fin:
			pts["Ziellinie"] = fin.center2d()
			pts["Ziel-Anlaufpunkt"] = fin.center2d() + fin.normal2d() * 30.0
		for m in l.marks():
			pts[m.mark_name] = m.pos2d()
		for k in pts:
			var p: Vector2 = pts[k]
			var d := SeaChart.depth_at(p)
			if d < 2.5:
				problems.append("%s zu flach (%.1f m)" % [k, d])
			if not area.has_point(p):
				problems.append("%s außerhalb des Gebiets" % k)
		# Tankstellen: Liegeplatz im Wasser, Stegwurzel an Land
		for d in l.fuel_docks():
			var bd := SeaChart.depth_at(d.berth())
			if bd < 2.0:
				problems.append("%s: Liegeplatz zu flach (%.1f m)" % [d.name, bd])
			if not area.has_point(d.berth()):
				problems.append("%s: Liegeplatz außerhalb des Regattagebiets (%s, Gebiet %s)" % [d.name, d.berth(), area])
			if SeaChart.depth_at(d.pos2d()) > 0.5:
				problems.append("%s: Stegwurzel nicht an Land (%.1f m)" % [d.name, SeaChart.depth_at(d.pos2d())])
		# Linienenden sollten befahrbar sein
		for s in [-1.0, 1.0]:
			var e: Vector2 = line.center2d() + line.tangent2d() * line.half_width * s * 0.8
			if SeaChart.depth_at(e) < 1.5:
				problems.append("Startlinie endet im Flachen")
		var status := "OK" if problems.is_empty() else "PROBLEME: " + "; ".join(problems)
		all_ok = all_ok and problems.is_empty()
		print("%-22s Gebiet %4dx%4d m, %d Tonnen, %d Hindernisse, %d Strömungen, %d Tankstellen, %.0f l -> %s" % [l.level_name, area.size.x, area.size.y, l.marks().size(), l.obstacles().size(), l.current_sources().size(), l.fuel_docks().size(), l.fuel_liters, status])
	print("ALLE OK" if all_ok else "FEHLER")
	return true
