extends Node
## Baut ein Rennen auf und steuert den Ablauf:
## (Warten auf Mitsegler) -> Countdown -> Rennen -> erster im Ziel gewinnt -> Neustart.
## Ruft Schlepper für festgefahrene Boote.
##
## Lokal: 2 Boote an einem Rechner. Netzwerk: bis zu 4 Boote; der Host rechnet,
## Clients zeigen nur an (siehe scripts/net/net.gd).
##
## Tasten: F5 = Rennen neu starten (Host/lokal), Esc = zurück ins Menü bzw. in die Lobby

const COLORS := [Color(0.85, 0.18, 0.15), Color(0.15, 0.4, 0.85), Color(0.12, 0.6, 0.3), Color(0.95, 0.55, 0.1)]
const MENU_SCENE := "res://scenes/menu.tscn"
const STUCK_WAIT := 4.0                 # so lange festsitzen, bis der Schlepper gerufen wird
const WAIT_TIMEOUT := 20.0              # Host wartet höchstens so lange auf langsame Clients
const STATES := ["waiting", "countdown", "racing", "finished"]
const SNAPSHOT_HZ := 20.0
const LOBBY_SCENE := "res://scenes/lobby.tscn"

var level: Level
var wind: WindField
var chart: SeaChart
var course: Course
var boats: Array[Boat] = []
var local_boats: Array[Boat] = []
var cams: SplitCameraManager
var hud: RaceHud

var net := ""              # "" lokal, "host", "client"
var state := "countdown"   # waiting | countdown | racing | finished
var countdown := 4.0
var race_time := 0.0
var go_flash := 0.0
var winner: Boat = null

var _last_beep := 99
var _wind_snd: AudioStreamPlayer
var _wait_time := 0.0
var _snap_timer := 0.0
var _local_inputs: Array = []      # Client: [{slot, input, tack, jibe, start}]
var _tug_puppets := {}             # Client: Boot-Index -> Tug
var _fixed_points: Array = []      # Tonnen: [Position, Radius]
var _docks: Array = []             # Tankstellen
var _hazards: Array = []           # Minenfelder, Polizeigebiete, Sirenen-Inseln
var _kvr := Kvr.new()              # Vorfahrtsregeln als Einblendung
var _kvr_timer := 0.0


func _ready() -> void:
	randomize()
	Sfx.ensure(get_tree())
	if OS.get_cmdline_user_args().has("--debug"):
		Boat.debug_mode = true
	net = GameState.net_mode
	_build_environment()

	level = load(GameState.current_level_path()).instantiate()
	add_child(level)
	level.prepare_for_game()

	wind = WindField.new()
	GameState.apply_wind(level, wind)
	add_child(wind)
	chart = SeaChart.new()
	add_child(chart)
	course = Course.new()
	add_child(course)
	course.setup(level)
	_fixed_points = level.collision_points()
	_docks = level.fuel_docks()
	_hazards = level.hazards()
	ShippingLane.clock = 0.0
	ShippingLane.running = false
	Currents.set_sources(level.current_sources())
	course.target_reached.connect(_on_target_reached)
	course.boat_finished.connect(_on_boat_finished)

	var bounds := level.course_bounds(60.0)
	var visuals := WindVisuals.new()
	visuals.wind = wind
	visuals.chart = chart
	visuals.area = bounds
	add_child(visuals)

	# Start: hinter der Linie, hoch am Wind
	var line := level.start_line()
	var from := Vector2(sin(wind.base_dir), -cos(wind.base_dir))
	var close_hauled := from.rotated(deg_to_rad(45.0))
	if close_hauled.dot(line.normal2d()) < 0.0:
		close_hauled = from.rotated(deg_to_rad(-45.0))

	var slots := GameState.slots()
	for i in slots.size():
		var slot: Dictionary = slots[i]
		var b := Boat.new()
		b.player_index = i
		b.player_name = slot["name"]
		b.color = COLORS[int(slot["color"]) % COLORS.size()]
		b.wind = wind
		b.course = course
		b.heading = atan2(close_hauled.x, close_hauled.y)
		var sp: Vector2 = line.start_position(i)
		b.position = Vector3(sp.x, 0.0, sp.y)
		b.fuel = GameState.start_fuel(level)
		b.has_engine = b.fuel > 0.0
		var is_bot: bool = slot.get("bot", false)
		var mine := int(slot["peer"]) == GameState.my_peer and not is_bot
		b.local_human = mine
		if is_bot and net != "client":
			var ai := AIInput.new(b, wind, course, int(slot.get("ai", 1)), _fixed_points)
			ai.avoid = level.danger_circles()
			ai.lanes = level.shipping_lanes()
			ai.docks = _docks
			b.input = ai
		elif net == "client":
			b.puppet = true
			if mine:
				_local_inputs.append({"slot": i, "input": PlayerInput.new(int(slot["local"])), "tack": 0, "jibe": 0, "start": 0})
		elif mine:
			b.input = PlayerInput.new(int(slot["local"]))
		elif not is_bot:
			b.input = NetInput.new()
		if mine:
			local_boats.append(b)
		add_child(b)
		boats.append(b)
		wind.boats.append(b)

	cams = SplitCameraManager.new()
	add_child(cams)
	cams.setup(local_boats if local_boats.size() > 0 else boats.slice(0, 2))

	var layer := CanvasLayer.new()
	add_child(layer)
	hud = RaceHud.new()
	hud.main = self
	hud.boats = boats
	hud.local_boats = local_boats
	hud.wind = wind
	hud.course = course
	hud.cams = cams
	hud.map_rect = level.map_bounds(70.0)
	layer.add_child(hud)

	_wind_snd = Sfx.make_loop_player("wind_loop")
	add_child(_wind_snd)

	if net != "":
		Net.game = self
		state = "waiting"
		if net == "client":
			Net.notify_loaded()


func _physics_process(delta: float) -> void:
	_wind_snd.volume_db = linear_to_db(clampf(wind.base_speed / 10.0, 0.1, 0.8) * 0.6) + Sfx.LOOP_DB
	if net == "client":
		_send_local_inputs()
		return

	match state:
		"waiting":
			_wait_time += delta
			if Net.all_loaded() or _wait_time > WAIT_TIMEOUT:
				state = "countdown"
		"countdown":
			countdown -= delta
			var sec := ceili(countdown)
			if sec < _last_beep and sec >= 1 and sec <= 3:
				Sfx.play("beep", -6.0)
			_last_beep = sec
			if countdown <= 0.0:
				state = "racing"
				go_flash = 1.2
				Sfx.play("go", -3.0)
				for b in boats:
					b.controls_enabled = true
		"racing", "finished":
			race_time += delta
	go_flash = maxf(0.0, go_flash - delta)
	ShippingLane.clock = race_time
	ShippingLane.running = state == "racing" or state == "finished"
	if state == "racing" or state == "finished":
		for h in _hazards:
			for b in boats:
				h.update_boat(b, delta)
		if state == "racing" and winner == null and boats.all(func(b: Boat): return b.out):
			state = "finished"
	_kvr_timer -= delta
	if _kvr_timer <= 0.0 and state == "racing":
		_kvr_timer = 0.25
		_kvr.update(boats, wind, race_time)
	_resolve_collisions(delta)
	_call_tugs()
	for dock in _docks:
		for b in boats:
			if b.out:
				continue
			if b.pos2d().distance_to(dock.berth()) < FuelDock.ZONE:
				b.refuel(delta)
			elif b.refueling and b.pos2d().distance_to(dock.berth()) < FuelDock.ZONE + 10.0:
				b.refueling = false
	if net == "host":
		_snap_timer -= delta
		if _snap_timer <= 0.0:
			_snap_timer = 1.0 / SNAPSHOT_HZ
			Net.send_snapshot(_make_snapshot())
	if state == "finished":
		for b in boats:
			if b.input and b.input.start_pressed:
				restart()
				return


func _call_tugs() -> void:
	for b in boats:
		if b.tug == null and not b.towed and not b.out and b.stuck_time > STUCK_WAIT:
			var tug := Tug.spawn_for(b)
			b.tug = tug
			add_child(tug)
			b.show_message("Schlepper ist unterwegs", 3.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_F5:
				if net != "client":
					restart()
			KEY_T:
				Boat.trim_overlay = not Boat.trim_overlay
			KEY_F9:
				if net != "client":
					Boat.debug_mode = not Boat.debug_mode
					for b in local_boats:
						b.show_message("Debug-Modus an: Turbo-Motor, Tank voll" if Boat.debug_mode else "Debug-Modus aus", 3.0)
			KEY_ESCAPE:
				_leave()


func restart() -> void:
	if net == "host":
		Net.start_race()
	elif net == "":
		get_tree().reload_current_scene()


func _leave() -> void:
	match net:
		"host":
			Net.return_to_lobby()
		"client":
			Net.leave()
			get_tree().change_scene_to_file(LOBBY_SCENE)
		_:
			get_tree().change_scene_to_file(MENU_SCENE)


func rank_of(boat: Boat) -> int:
	var my := course.progress(boat)
	var rank := 1
	for b in boats:
		if b != boat and course.progress(b) > my:
			rank += 1
	return rank


func _on_target_reached(boat: Boat, index: int, label: String) -> void:
	if index == 0:
		boat.show_message("Gut gestartet!")
	else:
		boat.show_message(label + " gerundet")
		Sfx.play("bell", -4.0)


func _on_boat_finished(boat: Boat) -> void:
	boat.finish_time = race_time
	boat.show_message("Im Ziel!", 4.0)
	Sfx.play("finish", -2.0 if winner == null else -8.0)
	if winner == null:
		winner = boat
		state = "finished"


func _resolve_collisions(delta: float) -> void:
	for i in boats.size():
		for j in range(i + 1, boats.size()):
			var a := boats[i]
			var b := boats[j]
			if a.towed or b.towed or a.out or b.out:
				continue
			var d := b.pos2d() - a.pos2d()
			var dist := d.length()
			var min_d := Boat.BOAT_RADIUS * 2.0
			if dist >= min_d or dist < 0.001:
				continue
			var n := d / dist
			var push := (min_d - dist) * 0.5
			a.position -= Vector3(n.x, 0, n.y) * push
			b.position += Vector3(n.x, 0, n.y) * push
			var rel := (b.vel - a.vel).dot(n)
			if rel < 0.0:
				# Nachteil für beide; stärker für den, der mit mehr Fahrt aufgefahren ist
				var a_in := a.vel.dot(n)
				var b_in := -b.vel.dot(n)
				a.vel += n * rel * 0.6
				b.vel -= n * rel * 0.6
				if rel < -1.0:
					Sfx.play("crunch", -10.0, 1.6)
				a.collide(-rel, a_in >= b_in)
				b.collide(-rel, b_in > a_in)
			# Aneinanderliegen bremst beide
			a.scrape(delta)
			b.scrape(delta)
	# Tonnen sind fest: Boote prallen ab
	for b in boats:
		if b.towed or b.out:
			continue
		for fp in _fixed_points:
			var c: Vector2 = fp[0]
			var min_d: float = fp[1] + Boat.BOAT_RADIUS
			var d := b.pos2d() - c
			var dist := d.length()
			if dist >= min_d or dist < 0.001:
				continue
			var n := d / dist
			b.position += Vector3(n.x, 0, n.y) * (min_d - dist)
			var vn := b.vel.dot(n)
			if vn < 0.0:
				b.vel -= n * vn * 1.4
				if vn < -1.0:
					Sfx.play("crunch", -12.0, 2.0)


# ---------------------------------------------------------------- Netzwerk

## Host: Eingaben eines Clients für seine Boote
func apply_remote_inputs(peer: int, data: Array) -> void:
	var slots := GameState.slots()
	for entry in data:
		var e: Array = entry
		var idx := int(e[0])
		if idx < 0 or idx >= boats.size() or int(slots[idx]["peer"]) != peer:
			continue
		var inp := boats[idx].input as NetInput
		if inp:
			inp.set_remote(e[1], e[2], int(e[3]), int(e[4]), int(e[5]))


## Host: Mitsegler hat die Verbindung verloren
func on_peer_left(peer: int) -> void:
	var slots := GameState.slots()
	for i in boats.size():
		if int(slots[i]["peer"]) == peer:
			var inp := boats[i].input as NetInput
			if inp:
				inp.clear()
			boats[i].show_message("Verbindung verloren", 6.0)


## Client: eigene Eingaben lesen und zum Host schicken
func _send_local_inputs() -> void:
	if _local_inputs.is_empty():
		return
	var data: Array = []
	for li in _local_inputs:
		var inp: PlayerInput = li["input"]
		inp.update()
		if inp.gas_up_pressed:
			li["tack"] += 1
		if inp.gas_down_pressed:
			li["jibe"] += 1
		if inp.start_pressed:
			li["start"] += 1
		data.append([li["slot"], inp.steer, inp.sheet_rate, li["tack"], li["jibe"], li["start"]])
	Net.send_inputs(data)


func _make_snapshot() -> PackedFloat32Array:
	var tugs: Array[Tug] = []
	for c in get_children():
		if c is Tug and c.boat != null and not c.is_queued_for_deletion():
			tugs.append(c)
	var d := PackedFloat32Array([float(STATES.find(state)), countdown, race_time, go_flash, wind.time,
		float(winner.player_index if winner else -1), float(boats.size()), float(tugs.size())])
	for b in boats:
		b.net_pack(d)
	for t in tugs:
		t.net_pack(d)
	return d


## Client: Zustand vom Host übernehmen
func apply_snapshot(d: PackedFloat32Array) -> void:
	if d.size() < 8:
		return
	var new_state: String = STATES[clampi(int(d[0]), 0, STATES.size() - 1)]
	if new_state == "racing" and state == "countdown":
		for b in boats:
			b.controls_enabled = true
	state = new_state
	countdown = d[1]
	race_time = d[2]
	ShippingLane.clock = race_time
	ShippingLane.running = new_state == "racing" or new_state == "finished"
	go_flash = d[3]
	if absf(wind.time - d[4]) > 0.25:
		wind.time = d[4]
	var w := int(d[5])
	winner = boats[w] if w >= 0 and w < boats.size() else null
	var nb := mini(int(d[6]), boats.size())
	var nt := int(d[7])
	var o := 8
	for i in nb:
		boats[i].net_unpack(d, o)
		o += Boat.NET_FIELDS
	# Schlepper: anlegen, bewegen, entfernen
	var seen := {}
	for k in nt:
		if o + 6 > d.size():
			break
		var bi := int(d[o])
		seen[bi] = true
		if bi >= 0 and bi < boats.size():
			var t: Tug = _tug_puppets.get(bi)
			if t == null or not is_instance_valid(t):
				t = Tug.new()
				t.puppet = true
				t.boat = boats[bi]
				t.position = Vector3(d[o + 1], 0, d[o + 2])
				t.heading = d[o + 3]
				add_child(t)
				_tug_puppets[bi] = t
				boats[bi].tug = t
			t.net_unpack(d, o)
			# Anzeige "Schlepper kommt" nur, solange er noch hilft
			boats[bi].tug = t if t.state < Tug.State.RELEASE else null
		o += 6
	for bi in _tug_puppets.keys():
		if not seen.has(bi):
			var t: Tug = _tug_puppets[bi]
			if is_instance_valid(t):
				t.queue_free()
			_tug_puppets.erase(bi)
			if bi < boats.size():
				boats[bi].tug = null


## Client: Meldungen vom Host
func on_net_event(kind: String, args: Array) -> void:
	match kind:
		"kvr":
			var k := int(args[0])
			if k >= 0 and k < boats.size():
				boats[k].show_kvr(args[1], args[2], int(args[3]), false)
		"msg":
			var i := int(args[0])
			if i >= 0 and i < boats.size():
				boats[i].show_message(args[1], args[2], false)


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.99, 0.99, 0.97)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.3
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-62.0, -35.0, 0.0)
	sun.light_energy = 0.8
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.35
	sun.directional_shadow_max_distance = 250.0
	add_child(sun)
