extends SceneTree
## Bild der Seekarte mit einer Bézier-Insel, Hafenbecken und grobem Raster (Shader mit scharfer Kante).
## Aufruf: xvfb-run ... godot --path . --script res://tests/land_shape_shots.gd -- <ausgabe.png>
var _f := 0
var _cam: Camera3D

func _initialize() -> void:
	var l := Level.new()
	l.coast_east = false
	l.coast_west = false
	l.depth_cell = 8.0
	root.add_child(l)
	var land := LandShape.new()
	var c := Curve3D.new()
	c.add_point(Vector3(0, 0, -60), Vector3(-50, 0, 10), Vector3(40, 0, -20))
	c.add_point(Vector3(70, 0, 10), Vector3(10, 0, -40), Vector3(-10, 0, 40))
	c.add_point(Vector3(10, 0, 70), Vector3(40, 0, 10), Vector3(-30, 0, 0))
	c.add_point(Vector3(-60, 0, 20), Vector3(10, 0, 35), Vector3(-5, 0, -30))
	c.add_point(Vector3(-20, 0, -10))
	land.curve = c
	l.add_child(land)
	var hb := LandShape.new()
	hb.kind = LandShape.Kind.WASSER
	var hc := Curve3D.new()
	for v in [Vector2(-10, -10), Vector2(25, -10), Vector2(25, 15), Vector2(-10, 15)]:
		hc.add_point(Vector3(v.x, 0, v.y))
	hb.curve = hc
	l.add_child(hb)
	l.apply_area()
	var res := SeaChart.game_res()
	SeaChart.set_depth_grid(l.compute_depth(res), res)
	var chart := SeaChart.new()
	chart.soundings = false
	root.add_child(chart)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = 220.0
	root.add_child(_cam)
	_cam.position = Vector3(0, 300, 0)
	_cam.rotation_degrees = Vector3(-90, 0, 0)
	_cam.current = true
	root.size = Vector2i(900, 900)


func _process(_d: float) -> bool:
	_f += 1
	if _f == 6:
		var img := root.get_texture().get_image()
		img.save_png(OS.get_cmdline_user_args()[0])
		print("gespeichert")
		quit()
	return false
