class_name GameState
extends RefCounted
## Einstellungen, die vom Startmenü ins Rennen übergeben werden.

const LEVEL_DIR := "res://levels/"

## Windstärken: Name, m/s (0 = wie im Level festgelegt)
const WIND_OPTIONS := [
	["Wie im Level", 0.0],
	["Leicht (3 Bft)", 4.2],
	["Mittel (4 Bft)", 6.5],
	["Frisch (5 Bft)", 9.0],
]
## Böigkeit: Name, Böenstärke, Winddreher in Grad (-1 = wie im Level)
const GUST_OPTIONS := [
	["Wie im Level", -1.0, -1.0],
	["Ruhig", 0.25, 8.0],
	["Normal", 0.9, 17.0],
	["Böig & drehend", 1.4, 28.0],
]

static var level_path := ""
## Besetzung im lokalen Spiel: [Name, Menschen, Computer]
const CREW_OPTIONS := [
	["2 Spieler", 2, 0],
	["1 Spieler gegen 1 Computer", 1, 1],
	["1 Spieler gegen 3 Computer", 1, 3],
	["2 Spieler gegen 2 Computer", 2, 2],
	["Zuschauen: 4 Computer", 0, 4],
]
const BOT_NAMES := ["Fiete", "Greta", "Ole", "Smutje"]
## Treibstoff: [Name, Liter] (-1 = wie im Level, 0 = kein Motor)
const FUEL_OPTIONS := [
	["Wie im Level", -1.0],
	["Kein Motor", 0.0],
	["Wenig (4 l)", 4.0],
	["Halber Tank (10 l)", 10.0],
	["Voller Tank (20 l)", 20.0],
]
static var fuel_choice := 0
static var crew_choice := 0
static var ai_level := 1          ## 0 leicht, 1 mittel, 2 schwer
static var wind_choice := 0
static var gust_choice := 0

## Netzwerk: "" = lokal, "host" oder "client"
static var net_mode := ""
static var net_cfg := {}
static var my_peer := 1
## Meldung, die Menü/Lobby nach einem Abbruch anzeigen
static var status_message := ""
static var player_name := "Skipper"


## Boote dieses Rennens: [{peer, local, name, color}]
static func slots() -> Array:
	if net_mode == "":
		var crew: Array = CREW_OPTIONS[crew_choice]
		var out: Array = []
		for i in int(crew[1]):
			out.append({"peer": 1, "local": i, "name": "Spieler %d" % (i + 1), "color": out.size()})
		for i in int(crew[2]):
			out.append(bot_slot(i, ai_level, out.size()))
		return out
	return net_cfg["slots"]


static func bot_slot(i: int, lvl: int, color: int) -> Dictionary:
	return {"peer": 1, "local": -1, "bot": true, "ai": lvl, "name": BOT_NAMES[i % BOT_NAMES.size()] + " (KI)", "color": color}


static func apply_net_config(cfg: Dictionary, my_id: int, mode: String) -> void:
	net_cfg = cfg
	my_peer = my_id
	net_mode = mode
	level_path = cfg["level"]
	wind_choice = int(cfg["wind"])
	gust_choice = int(cfg["gust"])
	fuel_choice = int(cfg.get("fuel", 0))


## Startfüllung des Tanks in Litern (0 = kein Motor)
static func start_fuel(level: Level) -> float:
	var f: float = FUEL_OPTIONS[fuel_choice][1]
	return level.fuel_liters if f < 0.0 else f


## Alle Level-Szenen im Ordner levels/ (auch im exportierten Spiel)
static func list_levels() -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(LEVEL_DIR)
	if dir == null:
		return out
	for f in dir.get_files():
		f = f.trim_suffix(".remap")
		if f.ends_with(".tscn") and not out.has(LEVEL_DIR + f):
			out.append(LEVEL_DIR + f)
	out.sort()
	return out


static func current_level_path() -> String:
	if level_path == "":
		var all := list_levels()
		if all.size() > 0:
			level_path = all[0]
	return level_path


## Wind des Levels mit den Menü-Einstellungen überschreiben
static func apply_wind(level: Level, wind: WindField) -> void:
	if net_mode != "":
		wind.gust_seed = int(net_cfg["gust_seed"])
		wind.dir_seed = int(net_cfg["dir_seed"])
	wind.base_dir = deg_to_rad(level.wind_from_deg)
	wind.base_speed = level.wind_speed
	wind.shift_amplitude = deg_to_rad(level.wind_shift_deg)
	wind.gust_strength = level.gusts
	var w: Array = WIND_OPTIONS[wind_choice]
	if w[1] > 0.0:
		wind.base_speed = w[1]
	var g: Array = GUST_OPTIONS[gust_choice]
	if g[1] >= 0.0:
		wind.gust_strength = g[1]
		wind.shift_amplitude = deg_to_rad(g[2])
