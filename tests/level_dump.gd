extends SceneTree
## Listet alle Bausteine der Level mit Position (Hilfe beim Platzieren von Dekoration).
## Aufruf: godot --headless --path . --script res://tests/level_dump.gd

var _levels: Array[Level] = []
var _frame := 0


func _initialize() -> void:
	for p in GameState.list_levels():
		var l: Level = load(p).instantiate()
		root.add_child(l)
		_levels.append(l)


func _process(_d: float) -> bool:
	_frame += 1
	if _frame < 3:
		return false
	for l in _levels:
		SeaChart.set_depth_grid(l.compute_depth(256), 256)
		var a := l.race_area()
		print("== %s  Gebiet x %d..%d  z %d..%d  Wind aus %d°" % [l.level_name, a.position.x, a.end.x, a.position.y, a.end.y, l.wind_from_deg])
		for c in l.get_children():
			if c is Node3D:
				var extra := ""
				if c is ShoalArea:
					extra = " r=%d kind=%d" % [c.radius, c.kind]
				print("  %-22s %-14s (%4d, %4d)%s  tiefe %.1f" % [c.name, (c.get_script().get_global_name() if c.get_script() else "Node3D"), c.global_position.x, c.global_position.z, extra, SeaChart.depth_at(Vector2(c.global_position.x, c.global_position.z))])
	return true
