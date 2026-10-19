class_name Tug
extends Node3D
## Schlepper: kommt gemächlich zu einem festgefahrenen Boot, übergibt eine Leine,
## zieht es ins tiefe Wasser, wirft los und tuckert wieder davon.

signal finished_tow(tug: Tug)

const APPROACH_SPEED := 2.6   ## m/s (~5 kn) - bewusst nicht zu schnell
const TOW_SPEED := 2.0        ## m/s beim Schleppen
const LEAVE_SPEED := 3.0
const TURN_RATE := 0.9
const ROPE := 17.0
const SPAWN_DIST := 55.0
const HOOK_TIME := 2.0        ## Leine übergeben
const SAFE_DEPTH := 2.0

enum State { APPROACH, HOOK, TOW, RELEASE, LEAVE }

var state := State.APPROACH
var boat: Boat
var heading := 0.0
var speed := 0.0
var timer := 0.0
var tow_target := Vector2.ZERO

var _rope: MeshInstance3D
var _engine: AudioStreamPlayer
var _visual: Node3D
var _t := 0.0
## Netzwerk-Client: nur Anzeige, Bewegung kommt vom Host
var puppet := false
var _net_pos := Vector2.ZERO
var _net_heading := 0.0


## Startpunkt im tiefen Wasser suchen, möglichst ohne Land dazwischen
static func spawn_for(b: Boat) -> Tug:
	var bp := b.pos2d()
	var deep := SeaChart.find_deep_water(bp, SAFE_DEPTH + 1.0)
	var dir := (deep - bp).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2(0, 1)
	var spawn := bp + dir * SPAWN_DIST
	for k in 12:
		var cand := bp + dir.rotated(k * 0.5 * (1 if k % 2 == 0 else -1)) * SPAWN_DIST
		if SeaChart.depth_at(cand) > SAFE_DEPTH and SeaChart.path_clear(cand, bp):
			spawn = cand
			break
	var tug := Tug.new()
	tug.boat = b
	tug.tow_target = deep + dir * 12.0
	tug.position = Vector3(spawn.x, 0, spawn.y)
	var to_boat := bp - spawn
	tug.heading = atan2(to_boat.x, to_boat.y)
	return tug


func pos2d() -> Vector2:
	return Vector2(position.x, position.z)


func distance_to_boat() -> float:
	return pos2d().distance_to(boat.pos2d())


func _ready() -> void:
	_build_visuals()
	_engine = Sfx.make_loop_player("engine_loop")
	add_child(_engine)
	if not puppet:
		Sfx.play("tug_horn", -6.0)
	rotation.y = heading
	_net_pos = pos2d()
	_net_heading = heading


## Zustand für den Schnappschuss
func net_pack(out: PackedFloat32Array) -> void:
	out.append_array(PackedFloat32Array([float(boat.player_index), position.x, position.z, heading, float(state), speed]))


func net_unpack(d: PackedFloat32Array, o: int) -> void:
	_net_pos = Vector2(d[o + 1], d[o + 2])
	_net_heading = d[o + 3]
	state = int(d[o + 4]) as State
	speed = d[o + 5]


func _physics_process(delta: float) -> void:
	if boat == null:
		queue_free()
		return
	if puppet:
		var k := 1.0 - exp(-8.0 * delta)
		var p := pos2d().lerp(_net_pos, k)
		position.x = p.x
		position.z = p.y
		heading = wrapf(lerp_angle(heading, _net_heading, k), -PI, PI)
		rotation.y = heading
		_update_rope()
		return
	var p := pos2d()
	match state:
		State.APPROACH:
			# Ziel: Punkt eine Leinenlänge vor dem Boot, auf der tiefen Seite
			var away := (tow_target - boat.pos2d()).normalized()
			var goal := boat.pos2d() + away * ROPE
			var to_goal := goal - p
			var dist := to_goal.length()
			_steer_towards(to_goal, delta)
			speed = move_toward(speed, APPROACH_SPEED * clampf(dist / 15.0, 0.2, 1.0), delta * 1.0)
			_move(delta)
			if dist < 3.0:
				state = State.HOOK
				timer = HOOK_TIME
				speed = 0.0
				boat.start_tow(self)
				Sfx.play("tug_horn", -8.0, 1.1)
		State.HOOK:
			var away := (tow_target - p).normalized()
			_steer_towards(away, delta)
			timer -= delta
			_drag_boat(delta)
			if timer <= 0.0:
				state = State.TOW
		State.TOW:
			_steer_towards(tow_target - p, delta)
			speed = move_toward(speed, TOW_SPEED, delta * 0.6)
			_move(delta)
			_drag_boat(delta)
			var boat_deep := SeaChart.depth_at(boat.pos2d()) >= SAFE_DEPTH
			if (boat_deep and p.distance_to(tow_target) < 14.0) or p.distance_to(tow_target) < 3.0:
				state = State.RELEASE
				timer = 1.0
		State.RELEASE:
			timer -= delta
			speed = move_toward(speed, 0.5, delta)
			_move(delta)
			if timer <= 0.0:
				boat.end_tow()
				Sfx.play("tug_horn", -6.0, 1.2)
				state = State.LEAVE
				timer = 25.0
				finished_tow.emit(self)
		State.LEAVE:
			speed = move_toward(speed, LEAVE_SPEED, delta)
			_move(delta)
			timer -= delta
			if timer <= 0.0:
				queue_free()
	_update_rope()


func _steer_towards(dir: Vector2, delta: float) -> void:
	if dir.length() < 0.01:
		return
	var target := atan2(dir.x, dir.y)
	var diff := angle_difference(heading, target)
	heading = wrapf(heading + clampf(diff, -TURN_RATE * delta, TURN_RATE * delta), -PI, PI)


func _move(delta: float) -> void:
	var fwd := Vector2(sin(heading), cos(heading))
	var np := pos2d() + fwd * speed * delta
	position.x = np.x
	position.z = np.y
	rotation.y = heading


## Boot hängt an der Leine hinter dem Schlepper
func _drag_boat(delta: float) -> void:
	var stern := pos2d() - Vector2(sin(heading), cos(heading)) * 6.5
	var bp := boat.pos2d()
	var to_stern := stern - bp
	var d := to_stern.length()
	var np := bp
	if d > ROPE:
		np = stern - to_stern.normalized() * ROPE
	var bh := boat.heading
	if d > 0.5:
		var target := atan2(to_stern.x, to_stern.y)
		bh = wrapf(bh + clampf(angle_difference(bh, target), -1.2 * delta, 1.2 * delta), -PI, PI)
	boat.tow_to(np, bh, delta)


func _update_rope() -> void:
	var tied := state == State.HOOK or state == State.TOW or state == State.RELEASE
	_rope.visible = tied
	_engine.volume_db = linear_to_db(clampf(0.25 + speed / 3.0, 0.0, 0.75) * _audible()) + Sfx.LOOP_DB
	_engine.pitch_scale = 0.85 + speed * 0.12
	if not tied:
		return
	var a := global_position - global_basis.z * 4.2 + Vector3(0, 2.2, 0)   # Schlepphaken
	var bow := boat.global_position + Vector3(sin(boat.heading), 0, cos(boat.heading)) * 4.9 + Vector3(0, 1.3, 0)
	var len := a.distance_to(bow)
	var y := (bow - a).normalized()
	var x := y.cross(Vector3.UP).normalized()
	if x.length() < 0.1:
		x = Vector3.RIGHT
	_rope.global_transform = Transform3D(Basis(x, y * len, x.cross(y)), (a + bow) * 0.5)


## leiser, wenn der Schlepper weit weg ist
func _audible() -> float:
	return clampf(1.0 - (distance_to_boat() - 20.0) / 120.0, 0.05, 1.0)


func _process(delta: float) -> void:
	_t += delta
	_visual.position.y = sin(_t * 1.6) * 0.1
	_visual.rotation.x = sin(_t * 1.2) * 0.03


func _build_visuals() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	if ResourceLoader.exists("res://models/tug.glb"):
		var model: Node3D = load("res://models/tug.glb").instantiate()
		_visual.add_child(model)
		ModelStyle.outline(model)
	else:
		_build_simple()
	_build_label_and_rope()


func _build_simple() -> void:
	var black := StandardMaterial3D.new()
	black.albedo_color = Color(0.12, 0.12, 0.14)
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.7, 0.12, 0.1)
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.96, 0.96, 0.94)
	var yellow := StandardMaterial3D.new()
	yellow.albedo_color = Color(0.95, 0.75, 0.15)

	_box(Vector3(2.8, 1.0, 6.0), Vector3(0, 0.3, -0.3), black)
	_box(Vector3(2.9, 0.25, 6.1), Vector3(0, 0.0, -0.3), red)
	var bow := PrismMesh.new()
	bow.size = Vector3(2.8, 2.0, 1.0)
	var bmi := MeshInstance3D.new()
	bmi.mesh = bow
	bmi.material_override = black
	bmi.rotation = Vector3(PI / 2, 0, 0)
	bmi.position = Vector3(0, 0.3, 3.7)
	_visual.add_child(bmi)
	_box(Vector3(2.0, 1.6, 2.2), Vector3(0, 1.6, 0.8), white)      # Steuerhaus
	_box(Vector3(2.1, 0.2, 2.3), Vector3(0, 2.5, 0.8), red)        # Dach
	var stack := CylinderMesh.new()
	stack.top_radius = 0.35
	stack.bottom_radius = 0.4
	stack.height = 1.4
	var smi := MeshInstance3D.new()
	smi.mesh = stack
	smi.material_override = yellow
	smi.position = Vector3(0, 2.3, -0.9)
	_visual.add_child(smi)
	# Fender rundherum
	for k in 6:
		var f := SphereMesh.new()
		f.radius = 0.3
		f.height = 0.6
		var fmi := MeshInstance3D.new()
		fmi.mesh = f
		fmi.material_override = white
		fmi.position = Vector3(1.45 * (1 if k % 2 == 0 else -1), 0.5, -2.5 + (k / 2) * 2.2)
		_visual.add_child(fmi)



func _build_label_and_rope() -> void:
	var label := Label3D.new()
	label.text = "Schlepper"
	label.font = SeaChart.font(true)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 56
	label.outline_size = 10
	label.outline_modulate = Color(1, 1, 1, 0.9)
	label.modulate = Color(0.15, 0.15, 0.2)
	label.pixel_size = 0.025
	label.position.y = 11.0
	add_child(label)

	_rope = MeshInstance3D.new()
	var rope := CylinderMesh.new()
	rope.top_radius = 0.09
	rope.bottom_radius = 0.09
	rope.height = 1.0
	rope.radial_segments = 4
	_rope.mesh = rope
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(0.85, 0.7, 0.35)
	_rope.material_override = rm
	_rope.top_level = true
	_rope.visible = false
	add_child(_rope)


func _box(size: Vector3, pos: Vector3, mat: Material) -> void:
	var b := BoxMesh.new()
	b.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	_visual.add_child(mi)
