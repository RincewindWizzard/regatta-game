@tool
class_name Fx
extends RefCounted
## Kurze Effekte aus einfachen Meshes: Wellenring, Explosion.


static func _unshaded(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


## Ring auf dem Wasser, der sich ausbreitet und verblasst (Spritzer, Druckwelle)
static func ripple(parent: Node3D, pos: Vector3, max_scale := 8.0, time := 1.2, col := Color(1, 1, 1, 0.8)) -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = 0.88
	ring.outer_radius = 1.0
	ring.rings = 32
	ring.ring_segments = 4
	var mi := MeshInstance3D.new()
	mi.mesh = ring
	var mat := _unshaded(col)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3(0.5, 0.04, 0.5)
	parent.add_child(mi)
	mi.global_position = Vector3(pos.x, 0.12, pos.z)
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(max_scale, 0.04, max_scale), time)
	tw.tween_property(mat, "albedo_color:a", 0.0, time)
	tw.chain().tween_callback(mi.queue_free)


## Feuerball, Rauch, Trümmer und Druckwelle
static func explosion(parent: Node, pos: Vector3) -> void:
	var root := Node3D.new()
	root.top_level = true
	parent.add_child(root)
	root.global_position = pos

	var fire := MeshInstance3D.new()
	var fm := SphereMesh.new()
	fm.radius = 1.0
	fm.height = 2.0
	fm.radial_segments = 12
	fm.rings = 6
	fire.mesh = fm
	var fire_mat := _unshaded(Color(1.0, 0.65, 0.12, 0.95))
	fire.material_override = fire_mat
	root.add_child(fire)
	var tw := root.create_tween()
	tw.set_parallel(true)
	tw.tween_property(fire, "scale", Vector3.ONE * 8.0, 0.55).from(Vector3.ONE * 1.5)
	tw.tween_property(fire_mat, "albedo_color", Color(0.9, 0.15, 0.05, 0.0), 0.7)

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for k in 6:
		var smoke := MeshInstance3D.new()
		smoke.mesh = fm
		var sm := _unshaded(Color(0.18, 0.18, 0.2, 0.75))
		smoke.material_override = sm
		smoke.position = Vector3(rng.randf_range(-3.0, 3.0), rng.randf_range(0.5, 2.0), rng.randf_range(-3.0, 3.0))
		smoke.scale = Vector3.ONE * 1.5
		root.add_child(smoke)
		var dur := rng.randf_range(2.2, 3.0)
		tw.tween_property(smoke, "position:y", smoke.position.y + rng.randf_range(7.0, 12.0), dur)
		tw.tween_property(smoke, "scale", Vector3.ONE * rng.randf_range(3.5, 5.5), dur)
		tw.tween_property(sm, "albedo_color:a", 0.0, dur).set_delay(dur * 0.4)

	var debris := CPUParticles3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.7, 0.35, 1.1)
	debris.mesh = box
	debris.material_override = _unshaded(Color(0.32, 0.22, 0.14, 1.0))
	debris.amount = 36
	debris.lifetime = 1.8
	debris.one_shot = true
	debris.explosiveness = 1.0
	debris.direction = Vector3.UP
	debris.spread = 75.0
	debris.initial_velocity_min = 8.0
	debris.initial_velocity_max = 17.0
	debris.gravity = Vector3(0, -22.0, 0)
	debris.angular_velocity_min = -400.0
	debris.angular_velocity_max = 400.0
	root.add_child(debris)
	debris.emitting = true

	ripple(root, pos, 16.0, 1.1, Color(1, 1, 1, 0.9))
	ripple(root, pos, 28.0, 1.8, Color(1, 0.8, 0.5, 0.6))
	root.get_tree().create_timer(3.4).timeout.connect(root.queue_free)
