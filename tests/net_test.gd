extends SceneTree
## Netzwerktest mit zwei Prozessen auf einem Rechner:
##   godot --headless --path . --script res://tests/net_test.gd -- host
##   godot --headless --path . --script res://tests/net_test.gd -- client
## Der Client steuert sein Boot (Taste A + W simuliert); beide geben am Ende die
## Bootszustände aus, die übereinstimmen sollten.

var role := ""
var t := 0.0
var phase := 0
var pressed := false


var count := 1
var shot := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	role = args[0]
	if args.size() > 1:
		count = int(args[1])
	if args.size() > 2:
		shot = args[2]


func _key(code: Key, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = down
	Input.parse_input_event(e)


func _process(delta: float) -> bool:
	t += delta
	var net := root.get_node("Net")
	match phase:
		0:
			net.local_players = count
			if role == "host":
				net.my_name = "Hosti"
				net.host()
				phase = 1
			elif t > 1.0:
				net.my_name = "Gast"
				net.join("127.0.0.1")
				phase = 1
		1:
			if role == "client" and shot != "" and t > 4.0 and net.players.size() >= 2 and current_scene == null:
				# Lobby-Ansicht des Clients festhalten
				change_scene_to_file("res://scenes/lobby.tscn")
			if role == "client" and shot != "" and t > 6.0 and not has_meta("lobby_shot"):
				set_meta("lobby_shot", true)
				root.get_texture().get_image().save_png(shot.replace(".png", "_lobby.png"))
				print("[client] Lobby-Screenshot gespeichert")
			if role == "host" and net.players.size() >= 2 and not has_meta("bots_set"):
				set_meta("bots_set", true)
				net.set_setting("level", "res://levels/02_kurzer_up_and_down.tscn")
				net.set_setting("bots", net.MAX_BOATS - net.human_boats())
			if role == "host" and net.players.size() >= 2 and t > 9.0:
				print("[host] Lobby: ", net.players, "  Computer: ", net.settings["bots"])
				net.start_race()
				phase = 2
				t = 0.0
			elif role == "client" and net.in_race:
				print("[client] Rennen gestartet, Slots: ", GameState.slots())
				phase = 2
				t = 0.0
			elif t > 15.0:
				print("[%s] FEHLER: keine Verbindung" % role)
				return true
		2:
			var main = current_scene
			if main == null or not main.has_method("apply_snapshot"):
				return false
			if role == "client" and main.state == "racing" and not pressed:
				pressed = true
				print("[client] Rennen läuft – steuere: A (links) + W (dicht)")
				_key(KEY_A, true)
				_key(KEY_W, true)
			if role == "client" and pressed and t > 11.0:
				_key(KEY_A, false)
			if role == "client" and shot != "" and t > 24.5 and not has_meta("race_shot"):
				set_meta("race_shot", true)
				root.get_texture().get_image().save_png(shot)
				print("[client] Rennen-Screenshot gespeichert")
			if t > (13.0 if role == "client" else 16.0):
				for b in main.boats:
					print("[%s] %s pos=(%.1f, %.1f) hdg=%.0f° speed=%.1f kn sheet=%.2f state=%s" % [
						role, b.player_name, b.position.x, b.position.z, rad_to_deg(b.heading), b.speed() * 1.944, b.sheet, main.state])
				return true
	return false
