extends SceneTree
## Boot hinter die Gebietsgrenze setzen: Es muss zurückgedrängt werden und darf
## höchstens 30 m hinaus.
var f := 0
var m: Node
func _initialize():
	Engine.time_scale = 4.0
	GameState.net_mode = ""
	GameState.level_path = "res://levels/02_kurzer_up_and_down.tscn"
	m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
func _process(_d):
	f += 1
	var b: Boat = m.boats[0]
	var a: Rect2 = m.course.area
	if f == 5:
		m.countdown = 0.0
	if f == 20:
		# 10 m vor die Ostgrenze, mit 4 m/s nach Osten
		b.position = Vector3(a.end.x - 10.0, 0, a.get_center().y)
		b.heading = PI / 2.0
		b.vel = Vector2(4.0, 0)
	if f > 20 and f % 60 == 0:
		print("t=%3d  x-Abstand zur Grenze %+.1f m  outside=%s  msg='%s'" % [f, b.position.x - a.end.x, b.outside, b.message])
	return f > 620
