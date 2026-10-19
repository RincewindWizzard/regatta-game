class_name NetInput
extends PlayerInput
## Eingaben eines Bootes, das an einem anderen Rechner gesteuert wird (nur beim Host).
## Tasten-Ereignisse kommen als Zähler, damit verlorene Pakete keinen Gasschritt verschlucken.

var _up_count := 0
var _down_count := 0
var _start_count := 0
var _up_seen := 0
var _down_seen := 0
var _start_seen := 0


func _init() -> void:
	super(0)


func set_remote(p_steer: float, p_sheet: float, up_c: int, down_c: int, start_c: int) -> void:
	steer = clampf(p_steer, -1.0, 1.0)
	sheet_rate = clampf(p_sheet, -1.0, 1.0)
	_up_count = up_c
	_down_count = down_c
	_start_count = start_c


func clear() -> void:
	steer = 0.0
	sheet_rate = 0.0


func update() -> void:
	gas_up_pressed = _up_count > _up_seen
	gas_down_pressed = _down_count > _down_seen
	start_pressed = _start_count > _start_seen
	_up_seen = _up_count
	_down_seen = _down_count
	_start_seen = _start_count
