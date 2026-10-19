class_name SplitCameraManager
extends Control
## Dynamischer Splitscreen:
## Sind die Boote nah beieinander, zeigt EINE Kamera beide (zoomt passend raus).
## Werden sie zu weit getrennt, teilt sich das Bild vertikal (links/rechts) mit
## weichem Übergang. Wer beim Teilen weiter links ist, bekommt die linke Hälfte.

const PITCH := deg_to_rad(68.0)    ## Neigung der Kamera (90° = senkrecht von oben)
const FOV := 50.0
const SPLIT_ON := 125.0            ## Kameraabstand, ab dem geteilt wird
const SPLIT_OFF := 95.0            ## ... unter dem wieder zusammengeführt wird (Hysterese)
const SPLIT_DIST := 58.0           ## Kameraabstand im geteilten Modus
const MIN_DIST := 48.0
const MARGIN := 40.0
const TRANSITION_SPEED := 1.8

var boats: Array = []
var order := [0, 1]                ## welches Boot links / rechts
var split_t := 0.0                 ## 0 = gemeinsam, 1 = geteilt

var _containers: Array[SubViewportContainer] = []
var _viewports: Array[SubViewport] = []
var _cameras: Array[Camera3D] = []
var _divider: ColorRect
var _split_wanted := false
var _merged_dist := 80.0
var _focus: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]


func setup(p_boats: Array) -> void:
	boats = p_boats
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 2:
		var c := SubViewportContainer.new()
		c.stretch = true
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(c)
		var vp := SubViewport.new()
		vp.msaa_3d = Viewport.MSAA_4X
		vp.audio_listener_enable_3d = i == 0
		c.add_child(vp)
		var cam := Camera3D.new()
		cam.fov = FOV
		cam.far = 3000.0
		vp.add_child(cam)
		cam.current = true
		_containers.append(c)
		_viewports.append(vp)
		_cameras.append(cam)
	_divider = ColorRect.new()
	_divider.color = Color(0.05, 0.08, 0.12)
	_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_divider)
	if boats.size() >= 2:
		_focus = [_midpoint(), boats[0].pos2d(), boats[1].pos2d()]
	elif boats.size() == 1:
		_focus = [boats[0].pos2d(), boats[0].pos2d(), boats[0].pos2d()]


func _midpoint() -> Vector2:
	return (boats[0].pos2d() + boats[1].pos2d()) * 0.5


## Kameraabstand, bei dem beide Boote ins volle Bild passen
func _needed_dist(aspect: float) -> float:
	var d: Vector2 = (boats[0].pos2d() - boats[1].pos2d()).abs()
	var k := 2.0 * tan(deg_to_rad(FOV * 0.5))
	return maxf(MIN_DIST, maxf((d.x + MARGIN) / (k * aspect), (d.y + MARGIN) / k))


func _process(delta: float) -> void:
	if boats.size() == 1:
		_single_view(delta)
		return
	if boats.size() < 2:
		return
	var vs := get_viewport_rect().size
	var need := _needed_dist(vs.x / vs.y)

	if not _split_wanted and need > SPLIT_ON:
		_split_wanted = true
		order = [0, 1] if boats[0].position.x <= boats[1].position.x else [1, 0]
	elif _split_wanted and need < SPLIT_OFF:
		_split_wanted = false

	split_t = move_toward(split_t, 1.0 if _split_wanted else 0.0, delta * TRANSITION_SPEED)
	var t := smoothstep(0.0, 1.0, split_t)
	_merged_dist = lerpf(_merged_dist, minf(need, SPLIT_ON), 1.0 - exp(-3.0 * delta))

	# Layout
	var left_w := roundf(lerpf(vs.x, vs.x * 0.5, t))
	_containers[0].position = Vector2.ZERO
	_containers[0].size = Vector2(left_w, vs.y)
	var right_visible := vs.x - left_w >= 2.0
	_containers[1].visible = right_visible
	_viewports[1].render_target_update_mode = SubViewport.UPDATE_ALWAYS if right_visible else SubViewport.UPDATE_DISABLED
	if right_visible:
		_containers[1].position = Vector2(left_w, 0)
		_containers[1].size = Vector2(vs.x - left_w, vs.y)
	_divider.visible = right_visible
	_divider.position = Vector2(left_w - 2.0, 0)
	_divider.size = Vector2(4.0, vs.y)

	# Kameraziele (mit etwas Vorausschau in Fahrtrichtung, weich nachgeführt)
	var left: Boat = boats[order[0]]
	var right: Boat = boats[order[1]]
	var smooth := 1.0 - exp(-4.0 * delta)
	_focus[0] = _focus[0].lerp(_midpoint(), smooth)
	_focus[1] = _focus[1].lerp(left.pos2d() + left.vel * 2.0, smooth)
	_focus[2] = _focus[2].lerp(right.pos2d() + right.vel * 2.0, smooth)

	_place(_cameras[0], _focus[0].lerp(_focus[1], t), lerpf(_merged_dist, SPLIT_DIST, t))
	_place(_cameras[1], _focus[2], SPLIT_DIST)


## Nur ein eigenes Boot (Netzwerk): eine Kamera, Vollbild
func _single_view(delta: float) -> void:
	var vs := get_viewport_rect().size
	_containers[0].position = Vector2.ZERO
	_containers[0].size = vs
	_containers[1].visible = false
	_viewports[1].render_target_update_mode = SubViewport.UPDATE_DISABLED
	_divider.visible = false
	var b: Boat = boats[0]
	_focus[0] = _focus[0].lerp(b.pos2d() + b.vel * 2.5, 1.0 - exp(-4.0 * delta))
	_place(_cameras[0], _focus[0], SPLIT_DIST * 1.15)


func _place(cam: Camera3D, target: Vector2, dist: float) -> void:
	var tgt := Vector3(target.x, 0.0, target.y)
	cam.position = tgt + Vector3(0.0, sin(PITCH) * dist, cos(PITCH) * dist)
	cam.look_at(tgt, Vector3.UP)
