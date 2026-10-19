class_name Boat
extends Node3D
## Eine Jolle mit Großsegel und Fock und vereinfachter, nachvollziehbarer Segelphysik.
##
## Physik läuft in der Wasserebene (x, z). Das Boot zeigt mit lokal +Z nach vorn,
## lokal +X ist Backbord (links), -X Steuerbord (rechts).
##
## Modell:
##  1. Scheinbarer Wind = wahrer Wind - Bootsgeschwindigkeit
##  2. Jede Schot begrenzt, wie weit ihr Segel aufgehen darf. Der Wind drückt es bis
##     an diese Grenze (oder es killt, wenn die Schot zu lose ist).
##  3. Vortrieb ~ scheinbarer Wind² × Polarkurve × Trimm (68 % Groß, 32 % Fock) × Krängung
##     Vor dem Wind steht die Fock im Windschatten des Großsegels und bringt wenig.
##  4. Schwert dämpft Seitwärtsdrift, etwas Abdrift nach Lee bleibt.
##  5. Grund: im Randbereich gebremst, im Flachen festgefahren -> Schlepper kommt.
##  6. Strömung versetzt das Boot (Fahrt über Grund = Fahrt durchs Wasser + Strom).
##  7. Motor: Gasstufen 0–4. Gas geben lässt ihn an (Anlasser ~1 s), Gas auf 0 stellt
##     ihn ab. Verbrauch steigt mit dem Gas; Tank leer -> Motor aus. Getankt wird
##     an Tankstellen im Stillstand.

const DRIVE := 0.085          ## Vortriebsfaktor
const DRAG := 0.2             ## quadratischer Wasserwiderstand
const LATERAL_DAMP := 4.0     ## wie stark das Schwert Seitwärtsdrift verhindert
const TURN_RATE := 1.1        ## Drehrate in rad/s bei voller Fahrt
const NO_GO := 0.38           ## unterhalb dieses scheinbaren Windwinkels kein Vortrieb
const SHEET_SPEED := 0.7      ## wie schnell eine Schot geholt/gefiert wird (pro s)
const JIB_SHARE := 0.32       ## Anteil der Fock am Vortrieb
const BOAT_RADIUS := 3.6
const WORLD_LIMIT := 650.0
const MODEL_DIR := "res://models/"

const THROTTLE_MAX := 4
const ENGINE_THRUST := 1.9    ## Schub bei Vollgas (ergibt ~6 kn ohne Segel)
const START_TIME := 1.1       ## Anlasser
const TANK := 20.0            ## Tankinhalt in Litern
const FUEL_BURN := 0.2        ## Liter pro Sekunde bei Vollgas
const REFUEL_RATE := 2.2      ## Liter pro Sekunde an der Tankstelle

enum Motor { AUS, ANLASSER, LAEUFT }

var player_index := 0
var player_name := "Spieler 1"
var color := Color.RED
var wind: WindField
var course: Course
var input: PlayerInput

var heading := 0.0            ## rad, 0 = Bug zeigt nach +Z (Süden)
var vel := Vector2.ZERO       ## m/s in Weltkoordinaten (x, z)
var sheet := 0.35             ## Schoten: 0 = ganz dicht, 1 = ganz offen (Groß und Fock gemeinsam)
var jib_sheet := 0.35         ## Fockschot, folgt automatisch der Großschot
var heel := 0.0               ## Krängung (rad)
var controls_enabled := false
var maneuver_left := 0.0      ## (nicht mehr benutzt, Wenden geht übers Lenken)

# --- Motor ---
var throttle := 0
var engine := Motor.AUS
var fuel := 0.0
var has_engine := true
var refueling := false
var _start_timer := 0.0
var _twa_side := 0

# --- Strömung ---
var current := Vector2.ZERO   ## Strom am Boot (m/s)

# --- Grund & Schlepper ---
var depth := 20.0
var aground := false          ## Grundberührung (gebremst)
var stuck := false            ## festgefahren
var stuck_time := 0.0
var towed := false
var tug: Node = null

# --- Telemetrie (für HUD) ---
var awa := 0.0
var aws := 0.0
var tws := 0.0
var boom_abs := 0.0
var boom_opt := 0.0
var jib_abs := 0.0
var jib_opt := 0.0
var trim_eff := 0.0
var luffing := false
var jib_luffing := false
var in_shadow := false
var outside := false           ## außerhalb des Regattagebiets
var gust := 0.0
var main_status := ""
var jib_status := ""
var in_irons := false
var next_target := 0
var finished := false
var finish_time := 0.0
var message := ""
var message_time := 0.0

var _visual: Node3D
var _boom_pivot: Node3D
var _jib_pivot: Node3D
var _jib_axis := Vector3.UP
## Netzwerk-Client: Boot wird vom Host gesteuert, hier nur angezeigt
var puppet := false
var _net_pos := Vector2.ZERO
var _net_heading := 0.0
var _net_has := false
var _tiller_pivot: Node3D
var _rudder := 0.0
var _last_turn := 0.0
var _arrow: Node3D
var _t := 0.0
var _track: BoatTrack
var _snd_water: AudioStreamPlayer
var _snd_flap: AudioStreamPlayer
var _snd_engine: AudioStreamPlayer


func _ready() -> void:
	_t = randf() * 10.0
	_build_visuals()
	rotation.y = heading
	_track = BoatTrack.new()
	_track.color = color
	add_child(_track)
	_snd_water = Sfx.make_loop_player("water_loop")
	add_child(_snd_water)
	_snd_flap = Sfx.make_loop_player("flap_loop")
	_snd_flap.pitch_scale = 0.9 + player_index * 0.15
	add_child(_snd_flap)
	_snd_engine = Sfx.make_loop_player("outboard_loop")
	_snd_engine.pitch_scale = 0.95 + player_index * 0.06
	add_child(_snd_engine)


func pos2d() -> Vector2:
	return Vector2(position.x, position.z)


## Fahrt über Grund
func speed() -> float:
	return (vel + current).length()


func fuel_fraction() -> float:
	return fuel / TANK


func engine_running() -> bool:
	return engine == Motor.LAEUFT


func show_message(text: String, duration := 2.5, relay := true) -> void:
	message = text
	message_time = duration
	var net := get_node_or_null("/root/Net")
	if relay and net and net.is_host_racing():
		net.send_event("msg", [player_index, text, duration])


func optimal_sheet() -> float:
	return clampf((boom_opt - 0.06) / 1.44, 0.0, 1.0)


func optimal_jib_sheet() -> float:
	return clampf((jib_opt - 0.1) / 1.15, 0.0, 1.0)


# ---------------------------------------------------------------- Schlepper-Schnittstelle

func start_tow(p_tug: Node) -> void:
	tug = p_tug
	towed = true
	_set_throttle(0)
	show_message("Leine fest - wird abgeschleppt", 3.0)


## Wird vom Schlepper jeden Frame aufgerufen
func tow_to(p: Vector2, new_heading: float, delta: float) -> void:
	vel = (p - pos2d()) / maxf(delta, 0.001)
	position.x = p.x
	position.z = p.y
	heading = new_heading
	rotation.y = heading


func end_tow() -> void:
	towed = false
	tug = null
	stuck = false
	stuck_time = 0.0
	vel *= 0.5
	show_message("Leine los - weiter geht's!", 2.5)


# ---------------------------------------------------------------- Netzwerk

const NET_FIELDS := 27


## Zustand für den Schnappschuss des Hosts
func net_pack(out: PackedFloat32Array) -> void:
	out.append_array(PackedFloat32Array([
		position.x, position.z, heading, vel.x, vel.y, sheet, heel, awa, aws,
		boom_abs, boom_opt, jib_abs, float(luffing), float(jib_luffing), float(throttle),
		float(next_target), float(finished), finish_time, float(aground), float(stuck),
		float(towed), stuck_time, _last_turn, float(engine), fuel, float(refueling), float(has_engine)]))


## Client: Schnappschuss übernehmen
func net_unpack(d: PackedFloat32Array, o: int) -> void:
	_net_pos = Vector2(d[o], d[o + 1])
	_net_heading = d[o + 2]
	vel = Vector2(d[o + 3], d[o + 4])
	sheet = d[o + 5]
	heel = d[o + 6]
	awa = d[o + 7]
	aws = d[o + 8]
	boom_abs = d[o + 9]
	boom_opt = d[o + 10]
	jib_abs = d[o + 11]
	luffing = d[o + 12] > 0.5
	jib_luffing = d[o + 13] > 0.5
	throttle = int(d[o + 14])
	next_target = int(d[o + 15])
	finished = d[o + 16] > 0.5
	finish_time = d[o + 17]
	aground = d[o + 18] > 0.5
	stuck = d[o + 19] > 0.5
	towed = d[o + 20] > 0.5
	stuck_time = d[o + 21]
	_last_turn = d[o + 22]
	var new_engine := int(d[o + 23]) as Motor
	if new_engine == Motor.ANLASSER and engine != Motor.ANLASSER:
		Sfx.play_local("starter", -6.0)
	engine = new_engine
	fuel = d[o + 24]
	refueling = d[o + 25] > 0.5
	has_engine = d[o + 26] > 0.5
	if not _net_has:
		position.x = _net_pos.x
		position.z = _net_pos.y
		heading = _net_heading
		_net_has = true


func _puppet_step(delta: float) -> void:
	if message_time > 0.0:
		message_time -= delta
	if not _net_has:
		return
	current = Currents.at(pos2d())
	_net_pos += (vel + current) * delta         # zwischen Schnappschüssen weiterrechnen
	var k := 1.0 - exp(-10.0 * delta)
	var p := pos2d().lerp(_net_pos, k)
	if p.distance_to(_net_pos) > 30.0:          # z. B. nach dem Schleppen: springen
		p = _net_pos
	position.x = p.x
	position.z = p.y
	heading = wrapf(lerp_angle(heading, _net_heading, k), -PI, PI)
	rotation.y = heading
	depth = SeaChart.depth_at(p)
	gust = wind.gust_at(p)
	in_shadow = wind.shadow_factor(p, WindField.dir_to_blow(wind.dir_at(p)), self) < 0.9
	if course:
		outside = not course.area.has_point(p)
	var abs_awa := absf(awa)
	jib_opt = clampf(abs_awa * 0.5 - 0.05, 0.1, 1.2)
	in_irons = abs_awa < NO_GO + 0.05
	main_status = _status(luffing, boom_abs, boom_opt)
	jib_status = _status(jib_luffing, jib_abs, jib_opt)


# ---------------------------------------------------------------- Physik

func _physics_process(delta: float) -> void:
	if wind == null:
		return
	if puppet:
		_puppet_step(delta)
		return
	if input:
		input.update()
	if message_time > 0.0:
		message_time -= delta
	var p := pos2d()
	depth = SeaChart.depth_at(p)
	if towed:
		aground = false
		stuck = false
		_update_sails_for_display(p)
		return

	var tw := wind.get_wind(p, self)
	tws = tw.length()
	gust = wind.gust_at(p)
	in_shadow = wind.shadow_factor(p, WindField.dir_to_blow(wind.dir_at(p)), self) < 0.9
	current = Currents.at(p)

	# --- Eingabe & Steuern ---
	var steer := 0.0
	if controls_enabled and input:
		steer = input.steer
		sheet = clampf(sheet + input.sheet_rate * SHEET_SPEED * delta, 0.0, 1.0)
		if input.gas_up_pressed:
			_set_throttle(throttle + 1)
		elif input.gas_down_pressed:
			_set_throttle(throttle - 1)
	_update_engine(delta)

	var fwd := Vector2(sin(heading), cos(heading))
	var spd_fwd := vel.dot(fwd)
	var steer_eff := clampf(0.25 + absf(spd_fwd) / 3.0, 0.25, 1.0)
	if engine == Motor.LAEUFT:
		# Schraubenstrom am Ruder: mit Motor lässt sich auch langsam gut steuern
		steer_eff = maxf(steer_eff, 0.4 + 0.5 * float(throttle) / THROTTLE_MAX)
	var turn := -steer * TURN_RATE * steer_eff * delta
	if stuck:
		turn *= 0.3
	heading = wrapf(heading + turn, -PI, PI)
	_last_turn = turn / delta

	# --- Wind relativ zum Boot (Fahrt über Grund zählt) ---
	fwd = Vector2(sin(heading), cos(heading))
	var port := Vector2(cos(heading), -sin(heading))
	spd_fwd = vel.dot(fwd)
	var spd_lat := vel.dot(port)
	var app := tw - (vel + current)
	aws = app.length()
	var from := -app
	awa = atan2(from.dot(port), from.dot(fwd))
	var abs_awa := absf(awa)
	# Fock wird mit der Großschot gemeinsam geführt: gleicher Trimmzustand für beide Segel
	jib_sheet = clampf((lerpf(0.06, 1.5, sheet) + 0.05 - 0.1) / 1.15, 0.0, 1.0)

	# --- Segel & Trimm ---
	_trim_sails(abs_awa)
	var polar := smoothstep(NO_GO, 0.95, abs_awa) * (1.0 - 0.25 * smoothstep(2.0, PI, abs_awa))

	# --- Krängung: viel Wind + zu dichte Schoten = Schräglage = Speedverlust ---
	var over := maxf(0.0, boom_opt - boom_abs) * (1.0 - JIB_SHARE) + maxf(0.0, jib_opt - jib_abs) * JIB_SHARE
	var power := (0.0 if luffing else 1.0 - JIB_SHARE) + (0.0 if jib_luffing else JIB_SHARE)
	var heel_target := aws * aws * 0.008 * sin(abs_awa) * (1.0 + over * 3.0) * power
	heel = lerpf(heel, heel_target, 1.0 - exp(-3.0 * delta))
	var heel_pen := clampf(1.0 - maxf(0.0, heel - 0.42) * 2.5, 0.15, 1.0)

	# --- Kräfte ---
	var drive := DRIVE * aws * aws * polar * trim_eff * heel_pen
	if engine == Motor.LAEUFT:
		drive += ENGINE_THRUST * float(throttle) / THROTTLE_MAX
	_detect_maneuver(tw)
	var turn_drag := absf(turn / delta) * spd_fwd * 0.75
	spd_fwd += (drive - DRAG * spd_fwd * absf(spd_fwd) - turn_drag) * delta
	spd_lat *= exp(-LATERAL_DAMP * delta)
	spd_lat -= signf(awa) * heel * 0.4 * delta

	# --- Grund ---
	var was_aground := aground
	aground = depth < SeaChart.DRAFT
	stuck = depth < SeaChart.HARD
	if aground:
		var k := exp(-(2.0 if not stuck else 8.0) * delta)
		var cap := 0.8 if not stuck else 0.15
		spd_fwd = clampf(spd_fwd * k, -cap, cap)
		spd_lat *= k
		if not was_aground and speed() > 0.8:
			Sfx.play("crunch", linear_to_db(clampf(speed() / 3.0, 0.3, 1.0)))
			show_message("Grundberührung!", 1.5)
	if stuck and speed() < 0.3:
		stuck_time += delta
	elif not aground:
		stuck_time = 0.0

	vel = fwd * spd_fwd + port * spd_lat
	var ground := vel + (current if not stuck else Vector2.ZERO)
	var new_p := (p + ground * delta).clamp(Vector2(-WORLD_LIMIT, -WORLD_LIMIT), Vector2(WORLD_LIMIT, WORLD_LIMIT))
	# Regattagebiet: draußen sanft zurückdrängen, 30 m dahinter ist Schluss
	if course:
		var was_outside := outside
		outside = not course.area.has_point(new_p)
		if outside:
			var inside := new_p.clamp(course.area.position, course.area.end)
			var out_vec := new_p - inside
			var n := out_vec.normalized()
			var dist := out_vec.length()
			# erlaubte Fahrt nach außen schrumpft: nach 15 m geht es nicht weiter
			var allowed := maxf(0.0, 1.5 * (1.0 - dist / 15.0))
			var vn := vel.dot(n)
			if vn > allowed:
				vel -= n * (vn - allowed)
			if dist > 12.0:
				vel -= n * 0.6 * delta   # sanft zurückschieben
			var hard := course.area.grow(30.0)
			new_p = new_p.clamp(hard.position, hard.end)
			if not was_outside:
				show_message("Regattagebiet verlassen – umkehren!", 3.0)
	if SeaChart.depth_at(new_p) < SeaChart.LAND:
		# Gegen Land: stehen bleiben
		new_p = p
		vel = Vector2.ZERO
		stuck = true
	position.x = new_p.x
	position.z = new_p.y
	rotation.y = heading

	if course:
		course.update_progress(self, p, new_p)


func _trim_sails(abs_awa: float) -> void:
	# Großsegel
	var boom_max := lerpf(0.06, 1.5, sheet)
	var limit := maxf(abs_awa - 0.08, 0.0)
	boom_opt = clampf(abs_awa * 0.5 - 0.1, 0.06, 1.45)
	luffing = boom_max >= limit
	boom_abs = minf(boom_max, limit)
	var main_eff := exp(-pow((boom_abs - boom_opt) / 0.4, 2.0)) * (0.35 if luffing else 1.0)
	# Fock
	var jib_max := lerpf(0.1, 1.25, jib_sheet)
	var jlimit := maxf(abs_awa - 0.12, 0.0)
	jib_opt = clampf(abs_awa * 0.5 - 0.05, 0.1, 1.2)
	jib_luffing = jib_max >= jlimit
	jib_abs = minf(jib_max, jlimit)
	var blanket := 1.0 - 0.7 * smoothstep(2.2, 2.9, abs_awa)
	var jib_eff := exp(-pow((jib_abs - jib_opt) / 0.35, 2.0)) * (0.35 if jib_luffing else 1.0) * blanket
	trim_eff = (1.0 - JIB_SHARE) * main_eff + JIB_SHARE * jib_eff
	in_irons = abs_awa < NO_GO + 0.05
	main_status = _status(luffing, boom_abs, boom_opt)
	jib_status = _status(jib_luffing, jib_abs, jib_opt)


func _update_sails_for_display(p: Vector2) -> void:
	# beim Schleppen: Segel killen im Fahrtwind
	var tw := wind.get_wind(p, self)
	var app := tw - vel
	aws = app.length()
	var fwd := Vector2(sin(heading), cos(heading))
	var port := Vector2(cos(heading), -sin(heading))
	awa = atan2(-app.dot(port), -app.dot(fwd))
	_trim_sails(absf(awa))


func _status(luff: bool, actual: float, opt: float) -> String:
	if luff:
		return "killt"
	if actual < opt - 0.15:
		return "zu dicht"
	if actual > opt + 0.15:
		return "zu offen"
	return "optimal"


## Wende/Halse wird am Lenken erkannt: Wechselt der Wind die Bootsseite, ging der
## Bug (Wende) oder das Heck (Halse) durch den Wind.
func _detect_maneuver(tw: Vector2) -> void:
	var fwd := Vector2(sin(heading), cos(heading))
	var port := Vector2(cos(heading), -sin(heading))
	var from := -tw
	var twa := atan2(from.dot(port), from.dot(fwd))  # + = Wind von Backbord
	if absf(twa) < 0.12 or absf(twa) > PI - 0.12:
		return
	var side := 1 if twa > 0.0 else -1
	if _twa_side != 0 and side != _twa_side:
		var tack := absf(twa) < PI * 0.5
		show_message("Wende!" if tack else "Halse!", 1.2)
		Sfx.play("whoosh", -4.0, randf_range(0.9, 1.1))
	_twa_side = side


# ---------------------------------------------------------------- Motor

func _set_throttle(t: int) -> void:
	if not has_engine:
		if t > 0 and controls_enabled:
			show_message("Kein Motor an Bord", 1.5)
		throttle = 0
		return
	t = clampi(t, 0, THROTTLE_MAX)
	if t > 0 and fuel <= 0.01:
		show_message("Tank leer – zur Tankstelle segeln!", 2.5)
		t = 0
	if t > 0 and throttle == 0 and engine == Motor.AUS:
		engine = Motor.ANLASSER
		_start_timer = START_TIME
		Sfx.play("starter", -6.0, randf_range(0.95, 1.05))
	if t == 0 and engine != Motor.AUS:
		engine = Motor.AUS
	throttle = t


func _update_engine(delta: float) -> void:
	match engine:
		Motor.ANLASSER:
			_start_timer -= delta
			if _start_timer <= 0.0:
				engine = Motor.LAEUFT
		Motor.LAEUFT:
			fuel = maxf(0.0, fuel - FUEL_BURN * pow(float(throttle) / THROTTLE_MAX, 1.5) * delta)
			if fuel <= 0.0:
				engine = Motor.AUS
				throttle = 0
				show_message("Tank leer – Motor aus!", 3.0)
				Sfx.play("engine_stop", -6.0)


## Von der Tankstelle aufgerufen, solange das Boot dort liegt
func refuel(delta: float) -> void:
	if not has_engine or fuel >= TANK - 0.01:
		refueling = false
		return
	if speed() > 0.7 or engine != Motor.AUS:
		refueling = false
		return
	if not refueling:
		show_message("Tanken …", 2.0)
	refueling = true
	fuel = minf(TANK, fuel + REFUEL_RATE * delta)
	if fuel >= TANK - 0.01:
		refueling = false
		show_message("Tank voll!", 2.0)
		Sfx.play("bell", -10.0, 1.4)


# ---------------------------------------------------------------- Optik & Klang

func _process(delta: float) -> void:
	_t += delta
	var side := signf(awa) if absf(awa) > 0.01 else 1.0
	var gust_f := clampf(aws / 6.0, 0.3, 1.2)
	var flap := sin(_t * 22.0) * 0.08 * gust_f if luffing else 0.0
	var jflap := sin(_t * 27.0 + 1.0) * 0.1 * gust_f if jib_luffing else 0.0
	_boom_pivot.rotation.y = side * boom_abs + flap     # Baum geht nach Lee
	_jib_pivot.basis = Basis(_jib_axis, side * jib_abs + jflap)
	_visual.rotation.z = side * minf(heel, 0.7)         # Krängung nach Lee
	_visual.rotation.x = sin(_t * 1.7) * 0.03
	_visual.position.y = sin(_t * 1.3) * 0.08
	# Pinne: Boot dreht nach Steuerbord -> Pinne geht nach Backbord (+X)
	_rudder = lerpf(_rudder, clampf(-_last_turn / TURN_RATE, -1.0, 1.0) * 0.55, 1.0 - exp(-6.0 * delta))
	if _tiller_pivot:
		_tiller_pivot.rotation.y = _rudder
	if course and not finished:
		var d := course.target_pos(next_target) - pos2d()
		_arrow.visible = d.length() > 25.0
		_arrow.global_rotation = Vector3(0.0, atan2(d.x, d.y), 0.0)
	else:
		_arrow.visible = false
	_track.add_point(pos2d())

	# Klang: Wasserrauschen nach Tempo, Flattern wenn ein Segel killt
	var spd := speed()
	_snd_water.volume_db = linear_to_db(clampf(spd / 5.0, 0.0, 1.0) * 0.5 + 0.0001) + Sfx.LOOP_DB
	_snd_water.pitch_scale = 0.8 + clampf(spd / 6.0, 0.0, 0.6)
	var flap_amount := (0.6 if luffing else 0.0) + (0.4 if jib_luffing else 0.0)
	var flap_vol := flap_amount * clampf(aws / 7.0, 0.2, 1.0) * 0.35
	_snd_flap.volume_db = lerpf(_snd_flap.volume_db, linear_to_db(flap_vol + 0.0001) + Sfx.LOOP_DB, 1.0 - exp(-4.0 * delta))
	var eng_vol := (0.25 + 0.5 * float(throttle) / THROTTLE_MAX) if engine == Motor.LAEUFT else 0.0
	_snd_engine.volume_db = lerpf(_snd_engine.volume_db, linear_to_db(eng_vol + 0.0001) + Sfx.LOOP_DB, 1.0 - exp(-6.0 * delta))
	_snd_engine.pitch_scale = 0.8 + 0.12 * throttle


func _mat(c: Color, unshaded := false, double_sided := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if double_sided:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _add_mesh(mesh: Mesh, mat: Material, pos: Vector3, rot: Vector3, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


## Dünner Draht von a nach b (z. B. Vorstag)
func _add_wire(a: Vector3, b: Vector3, mat: Material, parent: Node3D) -> void:
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.025
	cyl.bottom_radius = 0.025
	cyl.height = a.distance_to(b)
	cyl.radial_segments = 4
	var mi := MeshInstance3D.new()
	mi.mesh = cyl
	mi.material_override = mat
	var y := (b - a).normalized()
	var x := y.cross(Vector3.FORWARD).normalized()
	if x.length() < 0.1:
		x = Vector3.RIGHT
	mi.basis = Basis(x, y, x.cross(y))
	mi.position = (a + b) * 0.5
	parent.add_child(mi)


func _triangle_mesh(a: Vector3, b: Vector3, c: Vector3) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in [a, b, c]:
		st.add_vertex(v)
	st.generate_normals()
	return st.commit()


func _build_visuals() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	var size := 3.0
	if _build_model():
		size = 7.0
	else:
		_build_simple()

	# Ring auf dem Wasser in Spielerfarbe
	var ring := TorusMesh.new()
	ring.inner_radius = size * 0.9
	ring.outer_radius = size
	ring.rings = 64
	ring.ring_segments = 6
	var ring_mi := _add_mesh(ring, _mat(Color(color, 0.6), true), Vector3(0, 0.05, 0.3), Vector3.ZERO, self)
	ring_mi.scale = Vector3(1, 0.05, 1)
	ring_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Pfeil zur nächsten Tonne
	_arrow = Node3D.new()
	_arrow.position.y = 0.3
	add_child(_arrow)
	var arrow := PrismMesh.new()
	arrow.size = Vector3(1.8, 2.0, 0.15)
	var arrow_mi := _add_mesh(arrow, _mat(Color(color, 0.85), true), Vector3(0, 0, size + 2.5), Vector3(PI / 2, 0, 0), _arrow)
	arrow_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var label := Label3D.new()
	label.text = player_name
	label.font = SeaChart.font(false, true)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 64
	label.outline_size = 10
	label.outline_modulate = Color(1, 1, 1, 0.9)
	label.pixel_size = 0.03
	label.modulate = color.darkened(0.1)
	label.position = Vector3(0, size * 2.1 + 2.0, 0)
	add_child(label)


## Dehler 31 aus res://models/ (aus der .blend exportiert). Drehpunkte = Knochen des Rigs.
func _build_model() -> bool:
	if not ResourceLoader.exists(MODEL_DIR + "dehler31_hull.glb"):
		return false
	var hull: Node3D = load(MODEL_DIR + "dehler31_hull.glb").instantiate()
	_visual.add_child(hull)
	ModelStyle.tint(hull, "Rumpf_Gelcoat", color.lightened(0.05))
	ModelStyle.outline(hull)

	_boom_pivot = Node3D.new()
	_boom_pivot.position = Vector3(0, 2.15, 1.6)          # Lümmelbeschlag
	_visual.add_child(_boom_pivot)
	var main: Node3D = load(MODEL_DIR + "dehler31_main.glb").instantiate()
	_boom_pivot.add_child(main)
	ModelStyle.outline(main)

	var tack := Vector3(0, 1.1524, 4.92)                  # Fockhals
	var head := Vector3(0, 11.9, 1.67)                    # Fockkopf am Vorstag
	_jib_axis = (head - tack).normalized()
	_jib_pivot = Node3D.new()
	_jib_pivot.position = tack
	_visual.add_child(_jib_pivot)
	var jib: Node3D = load(MODEL_DIR + "dehler31_jib.glb").instantiate()
	_jib_pivot.add_child(jib)
	ModelStyle.outline(jib)

	_tiller_pivot = Node3D.new()
	_tiller_pivot.position = Vector3(0, 0, -3.35)          # Ruderschaft
	_visual.add_child(_tiller_pivot)
	var tiller: Node3D = load(MODEL_DIR + "dehler31_tiller.glb").instantiate()
	_tiller_pivot.add_child(tiller)
	return true


## Einfaches Ersatzboot, falls die Modelle fehlen
func _build_simple() -> void:
	var hull_mat := _mat(color)
	var white := _mat(Color(0.95, 0.95, 0.92))
	var metal := _mat(Color(0.7, 0.7, 0.72))
	var sail_mat := _mat(Color(0.98, 0.98, 0.96), false, true)
	var hull := BoxMesh.new()
	hull.size = Vector3(1.6, 0.6, 3.4)
	_add_mesh(hull, hull_mat, Vector3(0, 0.15, -0.2), Vector3.ZERO, _visual)
	var bow := PrismMesh.new()
	bow.size = Vector3(1.6, 1.3, 0.6)
	_add_mesh(bow, hull_mat, Vector3(0, 0.15, 2.15), Vector3(PI / 2, 0, 0), _visual)
	var deck := BoxMesh.new()
	deck.size = Vector3(1.4, 0.05, 3.2)
	_add_mesh(deck, white, Vector3(0, 0.46, -0.2), Vector3.ZERO, _visual)
	var mast := CylinderMesh.new()
	mast.top_radius = 0.05
	mast.bottom_radius = 0.07
	mast.height = 6.5
	_add_mesh(mast, metal, Vector3(0, 3.6, 0.7), Vector3.ZERO, _visual)
	_boom_pivot = Node3D.new()
	_boom_pivot.position = Vector3(0, 0.95, 0.7)
	_visual.add_child(_boom_pivot)
	var boom := BoxMesh.new()
	boom.size = Vector3(0.09, 0.09, 3.0)
	_add_mesh(boom, metal, Vector3(0, 0, -1.5), Vector3.ZERO, _boom_pivot)
	var sail := PrismMesh.new()
	sail.size = Vector3(3.0, 5.6, 0.03)
	sail.left_to_right = 0.0
	_add_mesh(sail, sail_mat, Vector3(0, 2.85, -1.5), Vector3(0, PI / 2, 0), _boom_pivot)
	var tack := Vector3(0, 0.5, 2.6)
	var head := Vector3(0, 5.3, 0.78)
	_add_wire(tack, head, metal, _visual)
	_jib_axis = (head - tack).normalized()
	_jib_pivot = Node3D.new()
	_jib_pivot.position = tack
	_visual.add_child(_jib_pivot)
	var jib := MeshInstance3D.new()
	jib.mesh = _triangle_mesh(Vector3.ZERO, head - tack, Vector3(0, 0.4, -1.9))
	jib.material_override = sail_mat
	_jib_pivot.add_child(jib)
