extends Node
## Netzwerk für LAN- und Internet-Rennen (Autoload "Net").
##
## Aufbau: Der Host rechnet die komplette Simulation (Boote, Wind, Bahn, Schlepper).
## Clients schicken nur ihre Steuereingaben und bekommen ~20x pro Sekunde einen
## Zustandsschnappschuss zurück, den sie weich interpolieren.
##
## Finden: Hosts rufen sich per UDP-Broadcast im LAN aus (Port DISCOVERY_PORT).
## Übers Internet verbindet man sich direkt per IP; dafür muss beim Host der
## GAME_PORT (UDP) im Router freigegeben sein.

signal lobby_changed
signal games_changed
signal status(text: String)

const VERSION := "regatta-1"
const GAME_PORT := 24850
const DISCOVERY_PORT := 24851
const MAX_BOATS := 4
const SNAPSHOT_HZ := 20.0
const LOBBY_SCENE := "res://scenes/lobby.tscn"
const GAME_SCENE := "res://scenes/main.tscn"
const MENU_SCENE := "res://scenes/menu.tscn"

enum Mode { OFFLINE, HOST, CLIENT }

var mode := Mode.OFFLINE
var my_name := "Skipper"
var local_players := 1
var players := {}            ## peer_id -> {"name": String, "count": int}
var settings := {"level": "", "wind": 0, "gust": 0, "bots": 0, "ai": 1, "fuel": 0}
var in_race := false
var found_games := {}        ## "ip:port" -> {name, boats, level, port, ip, seen}
var game: Node               ## laufendes Rennen (main.gd), falls vorhanden

var _loaded := {}
var _tx: PacketPeerUDP
var _rx: PacketPeerUDP
var _bcast_timer := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_lost)


func is_host() -> bool:
	return mode == Mode.HOST


func is_online() -> bool:
	return mode != Mode.OFFLINE


## Host während eines Rennens: Ereignisse an die Clients weitergeben
func is_host_racing() -> bool:
	return mode == Mode.HOST and in_race


func my_id() -> int:
	return multiplayer.get_unique_id() if is_online() else 1


## Boote der Menschen (ohne Computer)
func human_boats() -> int:
	var n := 0
	for p in players.values():
		n += int(p["count"])
	return n


## Alle Boote inklusive Computer
func boat_count() -> int:
	return mini(MAX_BOATS, human_boats() + int(settings.get("bots", 0)))


# ---------------------------------------------------------------- Verbinden

func host(port := GAME_PORT) -> Error:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, 8)
	if err != OK:
		status.emit("Spiel konnte nicht eröffnet werden (Port %d belegt?)" % port)
		return err
	multiplayer.multiplayer_peer = peer
	mode = Mode.HOST
	players = {1: {"name": my_name, "count": local_players}}
	settings = {"level": GameState.current_level_path(), "wind": GameState.wind_choice, "gust": GameState.gust_choice, "bots": 0, "ai": GameState.ai_level, "fuel": GameState.fuel_choice}
	_tx = PacketPeerUDP.new()
	_tx.set_broadcast_enabled(true)
	_tx.set_dest_address("255.255.255.255", DISCOVERY_PORT)
	lobby_changed.emit()
	status.emit("Spiel eröffnet – warte auf Mitsegler")
	return OK


## address: "192.168.1.20" oder "meinserver.de:24850"
func join(address: String) -> Error:
	leave()
	var host_addr := address.strip_edges()
	var port := GAME_PORT
	if host_addr.count(":") == 1:
		port = int(host_addr.get_slice(":", 1))
		host_addr = host_addr.get_slice(":", 0)
	if host_addr == "":
		status.emit("Bitte eine Adresse eingeben")
		return ERR_INVALID_PARAMETER
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(host_addr, port)
	if err != OK:
		status.emit("Verbindung nicht möglich")
		return err
	multiplayer.multiplayer_peer = peer
	mode = Mode.CLIENT
	status.emit("Verbinde mit %s:%d …" % [host_addr, port])
	return OK


func leave() -> void:
	if multiplayer.multiplayer_peer and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	mode = Mode.OFFLINE
	players.clear()
	in_race = false
	_tx = null
	GameState.net_mode = ""
	lobby_changed.emit()


func _on_connected() -> void:
	_register.rpc_id(1, my_name, local_players, VERSION)


func _on_connection_failed() -> void:
	leave()
	status.emit("Verbindung fehlgeschlagen – Adresse und Portfreigabe prüfen")


func _on_server_lost() -> void:
	var was_racing := in_race
	leave()
	GameState.status_message = "Verbindung zum Host verloren"
	status.emit(GameState.status_message)
	if was_racing:
		get_tree().change_scene_to_file(LOBBY_SCENE)


func _on_peer_connected(_id: int) -> void:
	pass  # Anmeldung kommt per _register


func _on_peer_disconnected(id: int) -> void:
	if mode != Mode.HOST:
		return
	if players.has(id):
		var who: String = players[id]["name"]
		players.erase(id)
		_send_lobby()
		status.emit("%s hat die Regatta verlassen" % who)
		if in_race and game and game.has_method("on_peer_left"):
			game.on_peer_left(id)


# ---------------------------------------------------------------- Lobby

@rpc("any_peer", "reliable")
func _register(player_name: String, count: int, version: String) -> void:
	if mode != Mode.HOST:
		return
	var id := multiplayer.get_remote_sender_id()
	if version != VERSION:
		_reject(id, "Andere Spielversion beim Host")
	elif in_race:
		_reject(id, "Das Rennen läuft bereits – bitte gleich nochmal versuchen")
	elif human_boats() + count > MAX_BOATS:
		_reject(id, "Regatta ist voll (höchstens %d Boote)" % MAX_BOATS)
	else:
		players[id] = {"name": player_name.left(14), "count": clampi(count, 1, 2)}
		settings["bots"] = mini(int(settings.get("bots", 0)), MAX_BOATS - human_boats())
		_send_lobby()
		status.emit("%s ist beigetreten" % player_name)


func _reject(id: int, reason: String) -> void:
	_rejected.rpc_id(id, reason)
	await get_tree().create_timer(0.5).timeout
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		multiplayer.multiplayer_peer.disconnect_peer(id)


@rpc("authority", "reliable")
func _rejected(reason: String) -> void:
	leave()
	status.emit(reason)


func _send_lobby() -> void:
	_lobby_state.rpc(players, settings)
	lobby_changed.emit()


@rpc("authority", "reliable")
func _lobby_state(p: Dictionary, s: Dictionary) -> void:
	players = p
	settings = s
	lobby_changed.emit()
	status.emit("In der Lobby – der Host startet das Rennen")


## Host ändert Bahn oder Wetter
func set_setting(key: String, value: Variant) -> void:
	if mode != Mode.HOST:
		return
	settings[key] = value
	_send_lobby()


## Spieleranzahl am eigenen Rechner (1 oder 2) ändern, auch in der Lobby
func set_local_players(n: int) -> void:
	local_players = n
	if mode == Mode.HOST:
		if human_boats() - int(players[1]["count"]) + n <= MAX_BOATS:
			players[1]["count"] = n
			settings["bots"] = mini(int(settings.get("bots", 0)), MAX_BOATS - human_boats())
			_send_lobby()
	elif mode == Mode.CLIENT and multiplayer.get_unique_id() != 0:
		_register.rpc_id(1, my_name, n, VERSION)


func local_ips() -> PackedStringArray:
	var out := PackedStringArray()
	for a in IP.get_local_addresses():
		if a.count(".") == 3 and not a.begins_with("127.") and not a.begins_with("169.254."):
			out.append(a)
	return out


# ---------------------------------------------------------------- LAN-Suche

func start_listening() -> void:
	if _rx:
		return
	_rx = PacketPeerUDP.new()
	if _rx.bind(DISCOVERY_PORT) != OK:
		_rx = null   # Port belegt (z. B. zweites Spiel auf demselben Rechner)


func stop_listening() -> void:
	if _rx:
		_rx.close()
	_rx = null
	found_games.clear()


func _process(delta: float) -> void:
	# Host ruft sich aus
	if _tx and mode == Mode.HOST:
		_bcast_timer -= delta
		if _bcast_timer <= 0.0:
			_bcast_timer = 1.0
			var info := {"game": VERSION, "name": my_name, "boats": human_boats(), "max": MAX_BOATS,
				"level": settings["level"], "port": GAME_PORT, "open": not in_race}
			_tx.put_packet(JSON.stringify(info).to_utf8_buffer())
	# Client lauscht
	if _rx:
		var changed := false
		while _rx.get_available_packet_count() > 0:
			var pkt := _rx.get_packet()
			var ip := _rx.get_packet_ip()
			var data: Variant = JSON.parse_string(pkt.get_string_from_utf8())
			if data is Dictionary and data.get("game", "") == VERSION:
				var key := "%s:%d" % [ip, int(data["port"])]
				data["ip"] = ip
				data["seen"] = Time.get_ticks_msec()
				changed = changed or not found_games.has(key)
				found_games[key] = data
		var now := Time.get_ticks_msec()
		for k in found_games.keys():
			if now - int(found_games[k]["seen"]) > 3500:
				found_games.erase(k)
				changed = true
		if changed:
			games_changed.emit()


# ---------------------------------------------------------------- Rennen

## Boote verteilen: Host zuerst, dann nach Beitritt; je Rechner 1–2 Boote
func build_slots() -> Array:
	var slots: Array = []
	var ids := players.keys()
	ids.sort()
	for id in ids:
		var p: Dictionary = players[id]
		for k in int(p["count"]):
			if slots.size() >= MAX_BOATS:
				break
			var n: String = p["name"]
			if int(p["count"]) > 1:
				n = "%s %d" % [n, k + 1]
			slots.append({"peer": int(id), "local": k, "name": n, "color": slots.size()})
	var bots := mini(int(settings.get("bots", 0)), MAX_BOATS - slots.size())
	for i in bots:
		slots.append(GameState.bot_slot(i, int(settings.get("ai", 1)), slots.size()))
	return slots


func start_race() -> void:
	if mode != Mode.HOST:
		return
	var cfg := {
		"slots": build_slots(),
		"level": settings["level"],
		"wind": settings["wind"],
		"gust": settings["gust"],
		"fuel": settings.get("fuel", 0),
		"gust_seed": randi(),
		"dir_seed": randi(),
	}
	_start_race.rpc(cfg)


@rpc("authority", "call_local", "reliable")
func _start_race(cfg: Dictionary) -> void:
	if not ResourceLoader.exists(cfg["level"]):
		status.emit("Diese Bahn fehlt auf deinem Rechner: %s" % cfg["level"])
		leave()
		return
	GameState.apply_net_config(cfg, multiplayer.get_unique_id(), "host" if mode == Mode.HOST else "client")
	_loaded.clear()
	in_race = true
	get_tree().change_scene_to_file(GAME_SCENE)


## Client meldet: Szene geladen
func notify_loaded() -> void:
	if mode == Mode.CLIENT:
		_client_loaded.rpc_id(1)


@rpc("any_peer", "reliable")
func _client_loaded() -> void:
	_loaded[multiplayer.get_remote_sender_id()] = true


func all_loaded() -> bool:
	for id in players.keys():
		if int(id) != 1 and not _loaded.has(int(id)):
			return false
	return true


## Host: alle zurück in die Lobby
func return_to_lobby() -> void:
	if mode == Mode.HOST:
		_to_lobby.rpc()


@rpc("authority", "call_local", "reliable")
func _to_lobby() -> void:
	in_race = false
	game = null
	get_tree().change_scene_to_file(LOBBY_SCENE)


# --- Eingaben (Client -> Host) ---

func send_inputs(data: Array) -> void:
	_inputs.rpc_id(1, data)


@rpc("any_peer", "unreliable_ordered")
func _inputs(data: Array) -> void:
	if mode == Mode.HOST and game and game.has_method("apply_remote_inputs"):
		game.apply_remote_inputs(multiplayer.get_remote_sender_id(), data)


# --- Zustand (Host -> Clients) ---

func send_snapshot(data: PackedFloat32Array) -> void:
	_snapshot.rpc(data)


@rpc("authority", "unreliable_ordered")
func _snapshot(data: PackedFloat32Array) -> void:
	if game and game.has_method("apply_snapshot"):
		game.apply_snapshot(data)


# --- Ereignisse (Host -> Clients): Meldungen, Sounds ---

func send_event(kind: String, args: Array) -> void:
	if mode == Mode.HOST and in_race:
		_event.rpc(kind, args)


@rpc("authority", "reliable")
func _event(kind: String, args: Array) -> void:
	match kind:
		"sfx":
			Sfx.play(args[0], args[1], args[2])
		_:
			if game and game.has_method("on_net_event"):
				game.on_net_event(kind, args)
