extends SceneTree
## Headless-Test: Boot auf eine Untiefe setzen und prüfen, ob der Schlepper es befreit.
## Aufruf: godot --headless --path . --script res://tests/tug_test.gd

var _main: Node
var _t := 0.0
var _last := ""
var _start := 0.0


func _initialize() -> void:
	Engine.time_scale = 8.0
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)


func _process(delta: float) -> bool:
	_t += delta
	var b = _main.boats[0]
	if _t < 0.5:
		return false
	if _start == 0.0:
		_main.countdown = 0.0
		b.position = Vector3(-60, 0, -250)   # mitten auf dem "Mittelgrund"
		b.vel = Vector2.ZERO
		_start = _t
	var s := "depth=%.1f stuck=%s towed=%s tug=%s" % [b.depth, b.stuck, b.towed, b.tug != null]
	if b.tug != null and is_instance_valid(b.tug):
		s += " tug_state=%d" % b.tug.state
	if s != _last:
		print("t=%5.1fs  %s" % [_t - _start, s])
		_last = s
	if _t - _start > 120.0 or (_t - _start > 10.0 and not b.towed and b.depth > 3.0 and b.tug == null):
		print("Ende: Boot bei (%.0f, %.0f), Tiefe %.1f m" % [b.position.x, b.position.z, b.depth])
		return true
	return false
