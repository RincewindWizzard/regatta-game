class_name PlayerInput
extends RefCounted
## Liest die Eingaben EINES Spielers: Controller (nach Geräte-ID) plus Tastatur-Fallback.
##
## Controller:  Linker Stick = Pinne
##              RT / R = Schoten dicht, LT / L = Schoten fieren (alternativ rechter Stick hoch/runter)
##              A / Steuerkreuz hoch = Gas hoch, B / Steuerkreuz runter = Gas runter
##              Start = neues Rennen
## Tastatur P1: A/D Pinne, W/S Schoten, E Gas hoch, Q Gas runter, Leertaste Start
## Tastatur P2: J/L Pinne, I/K Schoten, O Gas hoch, U Gas runter, Enter Start
## Wenden und Halsen: einfach durch den Wind steuern.

const DEADZONE := 0.18
const KEYMAPS := [
	{"left": KEY_A, "right": KEY_D, "in": KEY_W, "out": KEY_S,
		"gas_up": KEY_E, "gas_down": KEY_Q, "start": KEY_SPACE},
	{"left": KEY_J, "right": KEY_L, "in": KEY_I, "out": KEY_K,
		"gas_up": KEY_O, "gas_down": KEY_U, "start": KEY_ENTER},
]

var player := 0
var device := -1
## Echte Pinnensteuerung: Pinne nach links = Boot dreht nach rechts.
var invert_tiller := false

var steer := 0.0          ## -1 = nach Backbord (links), +1 = nach Steuerbord (rechts)
var sheet_rate := 0.0     ## Schoten: -1 = dichtholen, +1 = fieren
var gas_up_pressed := false
var gas_down_pressed := false
var start_pressed := false

var _was := {"up": false, "down": false, "start": false}

## Geräte, die Linux/Treiber als "Joypad" melden, die aber keine Controller sind
## (Bewegungssensoren, Touchpads, Tastatur-Sondertasten …)
const IGNORE_NAMES := ["motion", "sensor", "touchpad", "accelerometer", "consumer control",
	"system control", "keyboard", "mouse", "pen", "wacom", "power button", "video bus"]
static var _mappings_loaded := false


## Alle echten Controller in fester Reihenfolge: bekannte Gamepads zuerst.
static func gamepads() -> Array[int]:
	_load_extra_mappings()
	var known: Array[int] = []
	var other: Array[int] = []
	for id in Input.get_connected_joypads():
		var n := Input.get_joy_name(id).to_lower()
		var skip := false
		for bad in IGNORE_NAMES:
			if bad in n:
				skip = true
				break
		if skip:
			continue
		if Input.is_joy_known(id):
			known.append(id)
		else:
			other.append(id)
	known.sort()
	other.sort()
	return known + other


## Optionale Zusatz-Belegungen im SDL-Format (gamecontrollerdb.txt) neben dem Spiel
## oder im Projektordner – für Controller, die Godot noch nicht kennt.
static func _load_extra_mappings() -> void:
	if _mappings_loaded:
		return
	_mappings_loaded = true
	for path in [OS.get_executable_path().get_base_dir().path_join("gamecontrollerdb.txt"),
			ProjectSettings.globalize_path("res://gamecontrollerdb.txt")]:
		if not FileAccess.file_exists(path):
			continue
		var f := FileAccess.open(path, FileAccess.READ)
		var n := 0
		while f and not f.eof_reached():
			var line := f.get_line().strip_edges()
			if line == "" or line.begins_with("#"):
				continue
			Input.add_joy_mapping(line, true)
			n += 1
		print("Controller-Belegungen geladen: %d aus %s" % [n, path])


## Kurzbeschreibung für das Menü
static func describe() -> String:
	var all := Input.get_connected_joypads()
	var pads := gamepads()
	if pads.is_empty():
		if all.is_empty():
			return "Kein Controller erkannt"
		return "Kein Controller erkannt (ignoriert: %s)" % ", ".join(all.map(func(i): return Input.get_joy_name(i)))
	var names: Array[String] = []
	for i in pads.size():
		var id := pads[i]
		var tag := "" if Input.is_joy_known(id) else " – unbekannte Belegung"
		names.append("Sp. %d: %s%s" % [i + 1, Input.get_joy_name(id), tag])
	return "Controller: " + "   ·   ".join(names)


func _init(p_player: int) -> void:
	player = p_player


func update() -> void:
	var joys := gamepads()
	device = joys[player] if player < joys.size() else -1

	var km: Dictionary = KEYMAPS[player % KEYMAPS.size()]
	var s := _axis(km["left"], km["right"])
	var r := _axis(km["in"], km["out"])
	var up := Input.is_physical_key_pressed(km["gas_up"])
	var down := Input.is_physical_key_pressed(km["gas_down"])
	var start := Input.is_physical_key_pressed(km["start"])

	if device >= 0:
		s += _dz(Input.get_joy_axis(device, JOY_AXIS_LEFT_X))
		# Rechts (R / ZR) = dicht, links (L / ZL) = fieren. Joy-Con und Pro Controller melden
		# die Schultertasten je nach Treiber als Bumper-Button, Trigger-Button oder Trigger-Achse.
		r -= maxf(Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT), _btn(JOY_BUTTON_RIGHT_SHOULDER))
		r += maxf(Input.get_joy_axis(device, JOY_AXIS_TRIGGER_LEFT), _btn(JOY_BUTTON_LEFT_SHOULDER))
		r += _dz(Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y))  # hoch = dicht
		up = up or Input.is_joy_button_pressed(device, JOY_BUTTON_A) or Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_UP)
		down = down or Input.is_joy_button_pressed(device, JOY_BUTTON_B) or Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_DOWN)
		start = start or Input.is_joy_button_pressed(device, JOY_BUTTON_START)

	steer = clampf(s, -1.0, 1.0) * (-1.0 if invert_tiller else 1.0)
	sheet_rate = clampf(r, -1.0, 1.0)
	gas_up_pressed = up and not _was["up"]
	gas_down_pressed = down and not _was["down"]
	start_pressed = start and not _was["start"]
	_was["up"] = up
	_was["down"] = down
	_was["start"] = start


func _btn(button: JoyButton) -> float:
	return 1.0 if Input.is_joy_button_pressed(device, button) else 0.0


func _axis(neg: Key, pos: Key) -> float:
	var v := 0.0
	if Input.is_physical_key_pressed(neg):
		v -= 1.0
	if Input.is_physical_key_pressed(pos):
		v += 1.0
	return v


func _dz(v: float) -> float:
	if absf(v) < DEADZONE:
		return 0.0
	return (v - signf(v) * DEADZONE) / (1.0 - DEADZONE)
