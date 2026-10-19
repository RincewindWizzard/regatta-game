extends SceneTree
## Headless-Test der Bootsphysik:
##  - Geschwindigkeit je Kurs zum Wind (optimal getrimmt)
##  - Wende nur durch Lenken
##  - Motor: Geschwindigkeit, Verbrauch, Anlasser
##  - Strömung versetzt das Boot
## Aufruf: godot --headless --path . --script res://tests/polar_test.gd

class FakeInput extends PlayerInput:
	func _init() -> void:
		super(0)
	func update() -> void:
		pass


var _root_node: Node
var _wind: WindField


func _initialize() -> void:
	_root_node = Node.new()
	root.add_child(_root_node)
	_wind = WindField.new()
	_wind.gust_strength = 0.0
	_wind.shift_amplitude = 0.0
	_root_node.add_child(_wind)
	_wind.set_physics_process(false)
	_wind.current_dir = 0.0

	print("Wind 6 m/s aus Norden (konstant). Kurs = Winkel zum wahren Wind.")
	for deg in [35, 45, 60, 90, 120, 150, 180]:
		var b := _boat(PI - deg_to_rad(deg))
		for i in 60 * 30:
			b.sheet = b.optimal_sheet()
			b._physics_process(1.0 / 60.0)
			b.heading = PI - deg_to_rad(deg)
		print("  %3d°: %4.1f kn  (VMG %5.1f kn)" % [deg, b.speed() * 1.944, b.speed() * cos(deg_to_rad(deg)) * 1.944])
		b.queue_free()

	# Wende durch Lenken: von 45° Backbordbug auf 45° Steuerbordbug
	var t := _boat(PI - deg_to_rad(45))
	for i in 60 * 20:
		t.sheet = t.optimal_sheet()
		t._physics_process(1.0 / 60.0)
		t.heading = PI - deg_to_rad(45)
	var v0 := t.speed()
	var frames := 0
	var target := PI + deg_to_rad(45)
	var vmin := v0
	while absf(angle_difference(t.heading, target)) > 0.05 and frames < 1200:
		t.input.steer = clampf(-angle_difference(t.heading, target) * 3.0, -1.0, 1.0)
		t.sheet = t.optimal_sheet()
		t._physics_process(1.0 / 60.0)
		vmin = minf(vmin, t.speed())
		frames += 1
	print("Wende durch Lenken: %.1f s, Fahrt %.1f kn -> min %.1f kn -> %.1f kn, Meldung '%s'" % [frames / 60.0, v0 * 1.944, vmin * 1.944, t.speed() * 1.944, t.message])
	t.input.steer = 0.0

	# Motor ohne Segel (Wind von vorn, Segel killen)
	_wind.base_speed = 0.5
	var m := _boat(0.0)
	m.fuel = 20.0
	m.input.gas_up_pressed = true
	for k in 4:
		m._physics_process(1.0 / 60.0)
	m.input.gas_up_pressed = false
	var start_engine := m.engine
	for i in 60 * 40:
		m._physics_process(1.0 / 60.0)
	print("Motor Vollgas (Stufe %d): %.1f kn, Verbrauch in 40 s: %.1f l, Anlasser-Zustand am Anfang: %s" % [m.throttle, m.speed() * 1.944, 20.0 - m.fuel, Boat.Motor.keys()[start_engine]])
	m.input.gas_down_pressed = true
	for k in 4:
		m._physics_process(1.0 / 60.0)
	print("Gas auf 0 -> Motor %s" % Boat.Motor.keys()[m.engine])

	# Strömung: Boot ohne Fahrt treibt mit
	var area := CurrentArea.new()
	area.speed_kn = 2.0
	area.length = 400.0
	area.width = 400.0
	_root_node.add_child(area)
	Currents.set_sources([area])
	_wind.base_speed = 0.01
	var d := _boat(PI)
	d.sheet = 1.0
	var p0 := d.pos2d()
	for i in 60 * 20:
		d._physics_process(1.0 / 60.0)
	print("Strömung 2,0 kn nach Norden: Boot treibt in 20 s %.0f m (%.1f kn über Grund)" % [p0.distance_to(d.pos2d()), d.speed() * 1.944])
	Currents.clear()
	quit()


func _boat(h: float) -> Boat:
	var b := Boat.new()
	b.wind = _wind
	b.input = FakeInput.new()
	b.controls_enabled = true
	_root_node.add_child(b)
	b.set_physics_process(false)
	b.set_process(false)
	b.heading = h
	return b
