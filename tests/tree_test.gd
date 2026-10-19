extends SceneTree
## Prüft, dass in der Flussregatta alle Uferbäume auf Land stehen.
## Aufruf: godot --headless --path . --script res://tests/tree_test.gd

func _initialize() -> void:
	var lvl: Level = load("res://levels/07_flussregatta.tscn").instantiate()
	root.add_child(lvl)
	SeaChart.set_depth_grid(lvl.compute_depth(SeaChart.RES), SeaChart.RES)
	var river: RiverChannel = lvl.get_node("Muehlenfluss")
	river.prune_trees()
	var kept := 0
	var wet := 0
	for t in river._vis.get_children():
		if t.is_queued_for_deletion() or t.get_class() != "Node3D":
			continue
		kept += 1
		if SeaChart.depth_at(Vector2(t.position.x, t.position.z)) > SeaChart.LAND - 1.0:
			wet += 1
	print("Bäume übrig %d (von %d), davon im Wasser %d" % [kept, river.bank_trees, wet])
	quit()
