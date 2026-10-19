extends Node
## Vollbild umschalten: F11 oder Alt+Enter, in jeder Szene.


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var alt_enter: bool = event.alt_pressed and event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]
	if event.physical_keycode == KEY_F11 or alt_enter:
		toggle()
		get_viewport().set_input_as_handled()


static func toggle() -> void:
	var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
