extends SceneTree
## Erzeugt bzw. ergänzt die mitgelieferten Beispiel-Level in levels/.
## Normalerweise baut man Level im Editor; dieses Skript dient als Startpunkt.
## Vorhandene Level werden nur ergänzt (fehlende Nodes), eigene Änderungen bleiben.
## Aufruf: godot --headless --path . --script res://tools/make_levels.gd

func _initialize() -> void:
	_augment("res://levels/01_mittelgrund.tscn", _extras_mittelgrund)
	_augment("res://levels/02_kurzer_up_and_down.tscn", _extras_up_and_down)
	_augment("res://levels/03_rund_um_moewenhoern.tscn", _extras_moewenhoern)
	_save(_hafen(), "res://levels/04_hafenausfahrt.tscn")
	_save(_fahrwasser(), "res://levels/05_lotsenrinne.tscn")
	_save(_schaeren(), "res://levels/06_schaerengarten.tscn")
	_augment("res://levels/04_hafenausfahrt.tscn", _extras_hafen)
	_augment("res://levels/05_lotsenrinne.tscn", _extras_rinne)
	_augment("res://levels/06_schaerengarten.tscn", _extras_schaeren)
	_save(_fluss(), "res://levels/07_flussregatta.tscn")
	_augment("res://levels/07_flussregatta.tscn", _extras_fluss)
	_save(_kiel(), "res://levels/08_kieler_foerde.tscn")
	quit()


# ---------------------------------------------------------------- Speichern

func _save(level: Level, path: String) -> void:
	for c in level.get_children():
		c.owner = level
	var ps := PackedScene.new()
	ps.pack(level)
	print("gespeichert ", path, " -> ", ResourceSaver.save(ps, path))
	level.free()


func _augment(path: String, extras: Callable) -> void:
	if not ResourceLoader.exists(path):
		return
	var level: Level = load(path).instantiate()
	extras.call(level)
	_save(level, path)


func _has(l: Level, node_name: String) -> bool:
	return l.has_node(NodePath(node_name))


# ---------------------------------------------------------------- Bausteine

func _level(name: String, desc: String) -> Level:
	var l := Level.new()
	l.name = "Level"
	l.level_name = name
	l.description = desc
	return l


func _line(l: Level, p: Vector2, rot_deg := 0.0, hw := 45.0, finish := false) -> void:
	var s := StartLine.new()
	s.name = "Ziellinie" if finish else "StartZiel"
	s.finish_only = finish
	s.half_width = hw
	s.position = Vector3(p.x, 0, p.y)
	s.rotation.y = deg_to_rad(rot_deg)
	l.add_child(s)


func _mark(l: Level, node_name: String, mark_name: String, p: Vector2, light: String) -> void:
	var m := CourseMark.new()
	m.name = node_name
	m.mark_name = mark_name
	m.light = light
	m.position = Vector3(p.x, 0, p.y)
	l.add_child(m)


func _shoal(l: Level, area_name: String, p: Vector2, r: float, sx := 1.0, sz := 1.0, rot := 0.0, rock := true) -> void:
	var s := ShoalArea.new()
	s.name = area_name.replace(" ", "").replace("ö", "oe").replace("ü", "ue").replace("ä", "ae")
	s.area_name = area_name
	s.radius = r
	s.rock_symbol = rock
	s.position = Vector3(p.x, 0, p.y)
	s.scale = Vector3(sx, 1, sz)
	s.rotation.y = deg_to_rad(rot)
	l.add_child(s)


func _island(l: Level, area_name: String, p: Vector2, r: float, light := "", sx := 1.0, sz := 1.0, trees := 0, houses := 0, rot := 0.0) -> void:
	var s := ShoalArea.new()
	s.name = area_name.replace(" ", "").replace("ö", "oe").replace("ü", "ue").replace("ä", "ae")
	s.kind = ShoalArea.Kind.INSEL
	s.area_name = area_name
	s.radius = r
	s.rock_symbol = false
	s.lighthouse = light != ""
	if light != "":
		s.light_characteristic = light
	s.trees = trees
	s.houses = houses
	s.position = Vector3(p.x, 0, p.y)
	s.scale = Vector3(sx, 1, sz)
	s.rotation.y = deg_to_rad(rot)
	l.add_child(s)


func _sea(l: Level, node_name: String, kind: SeaMark.Kind, p: Vector2, label := "") -> void:
	if _has(l, node_name):
		return
	var m := SeaMark.new()
	m.name = node_name
	m.kind = kind
	m.mark_label = label
	m.position = Vector3(p.x, 0, p.y)
	l.add_child(m)


func _mole(l: Level, node_name: String, center: Vector2, length: float, rot_deg: float, light: Mole.HeadLight, width := 9.0, label := "") -> void:
	if _has(l, node_name):
		return
	var m := Mole.new()
	m.name = node_name
	m.mole_name = label
	m.length = length
	m.width = width
	m.head_light = light
	m.position = Vector3(center.x, 0, center.y)
	m.rotation.y = deg_to_rad(rot_deg)
	l.add_child(m)


func _tower(l: Level, node_name: String, p: Vector2, tower_name: String, style: Lighthouse.Style, ch: String, h := 20.0, beam := true) -> void:
	if _has(l, node_name):
		return
	var t := Lighthouse.new()
	t.rotating_beam = beam
	t.name = node_name
	t.tower_name = tower_name
	t.style = style
	t.characteristic = ch
	t.tower_height = h
	t.position = Vector3(p.x, 0, p.y)
	l.add_child(t)


func _rose(l: Level, p: Vector2, r: float, node_name := "Kompassrose") -> void:
	if _has(l, node_name):
		return
	var c := ChartRose.new()
	c.name = node_name
	c.radius = r
	c.position = Vector3(p.x, 0, p.y)
	l.add_child(c)


## Strömung; rot_deg: 0 = fließt nach Norden, 90 = Westen, 180 = Süden, -90 = Osten
func _current(l: Level, node_name: String, p: Vector2, rot_deg: float, speed_kn: float, length: float, width: float, tide := 0.0) -> void:
	if _has(l, node_name):
		return
	var c := CurrentArea.new()
	c.name = node_name
	c.speed_kn = speed_kn
	c.length = length
	c.width = width
	c.tide_period = tide
	c.position = Vector3(p.x, 0, p.y)
	c.rotation.y = deg_to_rad(rot_deg)
	l.add_child(c)


## Tankstelle: Wurzel an Land bei root, Steg zeigt in Richtung dir (ins Wasser)
func _dock(l: Level, node_name: String, root: Vector2, dir: Vector2, length := 26.0, title := "Tankstelle") -> void:
	if _has(l, node_name):
		return
	var d := FuelDock.new()
	d.name = node_name
	d.length = length
	d.dock_name = title
	d.position = Vector3(root.x, 0, root.y)
	var n := dir.normalized()
	d.rotation.y = atan2(-n.x, -n.y)
	l.add_child(d)


## Tiere und Wracks (SeaLife): count Tiere im Umkreis range_m
func _life(l: Level, node_name: String, kind: SeaLife.Kind, p: Vector2, count := 3, range_m := 40.0, rot_deg := 0.0, label := "") -> void:
	if _has(l, node_name):
		return
	var s := SeaLife.new()
	s.name = node_name
	s.kind = kind
	s.count = count
	s.range_m = range_m
	s.label = label
	s.position = Vector3(p.x, 0, p.y)
	s.rotation.y = deg_to_rad(rot_deg)
	l.add_child(s)


## Sperrgebiet: Minenfeld oder Polizei
func _restricted(l: Level, node_name: String, kind: RestrictedArea.Kind, p: Vector2, r: float, name_text := "", mines := 14) -> void:
	if _has(l, node_name):
		return
	var a := RestrictedArea.new()
	a.name = node_name
	a.kind = kind
	a.radius = r
	a.area_name = name_text
	a.mine_count = mines
	a.position = Vector3(p.x, 0, p.y)
	l.add_child(a)


## Schifffahrtsweg: Berufsschiffe fahren ab p in Richtung dir (Weltachse), length Meter lang
func _shipping(l: Level, node_name: String, p: Vector2, dir: Vector2, length: float, interval := 140.0, phase_out := 60.0, phase_back := -40.0, offset := 22.0, bend_at := 0.0, bend_deg := 0.0) -> void:
	if _has(l, node_name):
		return
	var s := ShippingLane.new()
	s.bend_at = bend_at
	s.bend_deg = bend_deg
	s.name = node_name
	s.length = length
	s.interval = interval
	s.phase_out = phase_out
	s.phase_back = phase_back
	s.lane_offset = offset
	s.position = Vector3(p.x, 0, p.y)
	var n := dir.normalized()
	s.rotation.y = atan2(-n.x, -n.y)        # lokal −Z soll in Richtung dir zeigen
	l.add_child(s)


## Sirenen-Insel: Gesang hält Boote bis song_range vom Ufer fest
func _siren(l: Level, node_name: String, p: Vector2, r: float, song_range := 60.0, trees := 6) -> void:
	if _has(l, node_name):
		return
	var s := SirenIsland.new()
	s.name = node_name
	s.area_name = "Sirenenfelsen"
	s.radius = r
	s.song_range = song_range
	s.rock_symbol = false
	s.trees = trees
	s.position = Vector3(p.x, 0, p.y)
	l.add_child(s)


# ---------------------------------------------------------------- Ergänzungen bestehender Level

func _extras_mittelgrund(l: Level) -> void:
	var isle := l.get_node_or_null("Moewenhoern") as ShoalArea
	if isle and isle.trees == 0:
		isle.trees = 30
		isle.houses = 2
	_sea(l, "Mittelgrund_W", SeaMark.Kind.WEST, Vector2(-108, -250))
	_sea(l, "Mittelgrund_O", SeaMark.Kind.OST, Vector2(-14, -250))
	_sea(l, "KleinerSand_Gefahr", SeaMark.Kind.EINZELGEFAHR, Vector2(10, -300))
	_sea(l, "HohePlate_N", SeaMark.Kind.NORD, Vector2(80, -285))
	_sea(l, "Steingrund_S", SeaMark.Kind.SUED, Vector2(-100, -112))
	_sea(l, "Bullenbank_W", SeaMark.Kind.WEST, Vector2(95, -110))
	_sea(l, "Tonnengrund_S", SeaMark.Kind.SUED, Vector2(110, -326))
	_sea(l, "SchwarzerGrund_O", SeaMark.Kind.OST, Vector2(-112, -320))
	_sea(l, "Ansteuerung", SeaMark.Kind.ANSTEUERUNG, Vector2(0, 95), "Mittelgrund")
	_mole(l, "Westmole", Vector2(-215, 70), 150.0, 0.0, Mole.HeadLight.GRUEN)
	_tower(l, "Leuchtturm", Vector2(-275, -110), "Rotsand", Lighthouse.Style.ROT_WEISS, "Oc(2)WRG.9s 22m 14M")
	# Gezeitenstrom zwischen Mittelgrund und Hohe Plate, kehrt alle 4 Minuten um
	_current(l, "Plattenstrom", Vector2(12, -245), -90.0, 1.4, 120.0, 90.0, 480.0)
	_dock(l, "Tankstelle", Vector2(222, -262), Vector2(-1, 0), 30.0, "Tankstelle Möwenhörn")
	_life(l, "Tuemmler", SeaLife.Kind.TUEMMLER, Vector2(100, -470), 3, 40.0)
	_life(l, "Wal", SeaLife.Kind.WAL, Vector2(-280, -440), 1, 50.0)
	_life(l, "Moewen", SeaLife.Kind.MOEWEN, Vector2(255, -270), 7, 45.0)
	_life(l, "Seehunde", SeaLife.Kind.SEEHUNDE, Vector2(80, -230), 4, 8.0)
	_life(l, "Wrack", SeaLife.Kind.WRACK, Vector2(140, 40), 1, 20.0, 35.0)


func _extras_up_and_down(l: Level) -> void:
	_sea(l, "Westbank_O", SeaMark.Kind.OST, Vector2(-62, -160))
	_sea(l, "Westbank_W", SeaMark.Kind.WEST, Vector2(-178, -160))
	_sea(l, "Ostplate_W", SeaMark.Kind.WEST, Vector2(78, -200))
	_sea(l, "Ansteuerung", SeaMark.Kind.ANSTEUERUNG, Vector2(0, 90))
	_tower(l, "Leuchtturm", Vector2(200, -330), "Hoher Weg", Lighthouse.Style.SCHWARZ_WEISS, "Fl(3)W.12s 18m 12M", 18.0)
	_life(l, "Moewen", SeaLife.Kind.MOEWEN, Vector2(150, -100), 6, 40.0)
	_life(l, "Tuemmler", SeaLife.Kind.TUEMMLER, Vector2(-150, -330), 3, 35.0)
	_life(l, "Seehunde", SeaLife.Kind.SEEHUNDE, Vector2(-120, -160), 3, 8.0)


func _extras_moewenhoern(l: Level) -> void:
	var isle := l.get_node_or_null("Moewenhoern") as ShoalArea
	if isle and isle.trees == 0:
		isle.trees = 40
		isle.houses = 4
	_sea(l, "Nordriff_N", SeaMark.Kind.NORD, Vector2(60, -364))
	_sea(l, "Seehundsbank_O", SeaMark.Kind.OST, Vector2(228, -200))
	_sea(l, "Westgrund_W", SeaMark.Kind.WEST, Vector2(-145, -180))
	_sea(l, "KleinePlate_Gefahr", SeaMark.Kind.EINZELGEFAHR, Vector2(-10, -110))
	_mole(l, "Inselmole", Vector2(95, -150), 60.0, -90.0, Mole.HeadLight.GRUEN, 8.0)
	_current(l, "Seehundsstrom", Vector2(162, -230), 0.0, 1.6, 160.0, 40.0)
	_dock(l, "Tankstelle", Vector2(6, -228), Vector2(-1, 0), 28.0)
	_life(l, "Moewen", SeaLife.Kind.MOEWEN, Vector2(80, -230), 9, 55.0)
	_life(l, "Seehunde", SeaLife.Kind.SEEHUNDE, Vector2(190, -200), 5, 10.0)
	_life(l, "Wal", SeaLife.Kind.WAL, Vector2(-250, -100), 1, 55.0)
	_life(l, "Tuemmler", SeaLife.Kind.TUEMMLER, Vector2(330, -120), 3, 40.0)
	_life(l, "Wrack", SeaLife.Kind.WRACK, Vector2(330, -440), 1, 20.0, -20.0)
	_restricted(l, "Minenfeld", RestrictedArea.Kind.MINEN, Vector2(330, -60), 50.0, "Minenfeld (Altlast)", 12)


func _extras_hafen(l: Level) -> void:
	_current(l, "Hafenstrom", Vector2(0, 30), 0.0, 1.0, 150.0, 150.0, 360.0)
	_dock(l, "Tankstelle", Vector2(70, 138), Vector2(0, -1), 24.0, "Hafentankstelle")
	_life(l, "Moewen", SeaLife.Kind.MOEWEN, Vector2(0, 150), 8, 60.0)
	_life(l, "Tuemmler", SeaLife.Kind.TUEMMLER, Vector2(200, -330), 3, 40.0)
	_life(l, "Wrack", SeaLife.Kind.WRACK, Vector2(-190, -250), 1, 20.0, 70.0)
	_restricted(l, "Sperrgebiet", RestrictedArea.Kind.POLIZEI, Vector2(-200, -60), 50.0, "Sperrgebiet Marine")


func _extras_rinne(l: Level) -> void:
	_current(l, "Ebbstrom", Vector2(0, -270), 180.0, 1.2, 440.0, 80.0, 600.0)
	_dock(l, "Tankstelle", Vector2(-404, -400), Vector2(1, 0), 46.0, "Vogelsand")
	_shipping(l, "Berufsschifffahrt", Vector2(0, 190), Vector2(0, -1), 930.0)
	_life(l, "Wrack", SeaLife.Kind.WRACK, Vector2(-150, -300), 1, 20.0, 15.0)
	_life(l, "Seehunde", SeaLife.Kind.SEEHUNDE, Vector2(130, -270), 5, 12.0)
	_life(l, "Moewen", SeaLife.Kind.MOEWEN, Vector2(300, -280), 7, 50.0)
	_life(l, "Tuemmler", SeaLife.Kind.TUEMMLER, Vector2(-300, -430), 3, 40.0)


func _extras_schaeren(l: Level) -> void:
	_current(l, "Sundstrom", Vector2(-100, 160), 45.0, 1.8, 120.0, 45.0)
	_current(l, "Holmstrom", Vector2(10, 165), -60.0, 1.2, 90.0, 40.0)
	_dock(l, "Tankstelle", Vector2(-150, 88), Vector2(0, -1), 40.0, "Granholm Bränsle")
	_siren(l, "Sireneninsel", Vector2(-150, 385), 20.0, 25.0, 5)
	_life(l, "Moewen", SeaLife.Kind.MOEWEN, Vector2(-150, 120), 8, 55.0)
	_life(l, "Tuemmler", SeaLife.Kind.TUEMMLER, Vector2(100, 300), 3, 40.0)
	_life(l, "Seehunde", SeaLife.Kind.SEEHUNDE, Vector2(-170, 315), 4, 6.0)
	_life(l, "Wrack", SeaLife.Kind.WRACK, Vector2(-390, 230), 1, 20.0, 80.0)


func _extras_fluss(l: Level) -> void:
	_life(l, "Moewen", SeaLife.Kind.MOEWEN, Vector2(-40, -300), 7, 70.0)
	_life(l, "Moewen_Insel", SeaLife.Kind.MOEWEN, Vector2(70, -330), 5, 40.0)
	_life(l, "Seehunde", SeaLife.Kind.SEEHUNDE, Vector2(-110, -390), 3, 6.0)
	_life(l, "Wrack", SeaLife.Kind.WRACK, Vector2(-100, -460), 1, 20.0, 40.0)
	_restricted(l, "Schutzgebiet", RestrictedArea.Kind.POLIZEI, Vector2(95, -430), 35.0, "Vogelschutzgebiet")


# ---------------------------------------------------------------- Neue Level

func _hafen() -> Level:
	var l := _level("Hafenausfahrt",
		"Start im Hafen zwischen den Molen, raus aufs Wasser bei Westwind und zurück durch die enge Einfahrt. Rot und Grün an den Molenköpfen weisen den Weg.")
	l.wind_from_deg = 270.0
	l.wind_speed = 6.0
	l.wind_shift_deg = 15.0
	l.gusts = 0.8
	l.seabed_seed = 2207
	l.area_margin = 170.0
	# Festland im Süden mit Kai und Häusern
	_island(l, "Festland", Vector2(0, 430), 300.0, "", 1.6, 1.0, 0, 0)
	_island(l, "Hafenkai", Vector2(0, 180), 75.0, "", 2.2, 0.7, 14, 10)
	# Hafenmolen: West grün, Ost rot (IALA A beim Einlaufen)
	_mole(l, "Westmole", Vector2(-95, 45), 130.0, 90.0, Mole.HeadLight.GRUEN, 10.0)
	_mole(l, "Ostmole", Vector2(95, 45), 130.0, 90.0, Mole.HeadLight.ROT, 10.0)
	_line(l, Vector2(0, 60), 0.0, 40.0)
	_mark(l, "Tonne1", "Tonne 1", Vector2(-80, -280), "Fl.Y.2s")
	_mark(l, "Tonne2", "Tonne 2", Vector2(170, -210), "Fl(2)Y.6s")
	_mark(l, "Tonne3", "Tonne 3", Vector2(-30, -95), "Fl(3)Y.10s")
	_shoal(l, "Sandbank", Vector2(60, -160), 26, 1.5, 0.8)
	_sea(l, "Sandbank_N", SeaMark.Kind.NORD, Vector2(60, -196))
	_sea(l, "Sandbank_S", SeaMark.Kind.SUED, Vector2(60, -124))
	_shoal(l, "Kleiner Stein", Vector2(-160, -170), 10)
	_sea(l, "Stein_Gefahr", SeaMark.Kind.EINZELGEFAHR, Vector2(-160, -170))
	_sea(l, "Ansteuerung", SeaMark.Kind.ANSTEUERUNG, Vector2(0, -40), "Hafen")
	_tower(l, "Leuchtturm", Vector2(230, -40), "Hafenfeuer", Lighthouse.Style.ROT_WEISS, "Oc.WRG.6s 15m 10M", 16.0)
	_rose(l, Vector2(-230, -330), 32)
	return l


func _fahrwasser() -> Level:
	var l := _level("Lotsenrinne",
		"Gegen den Wind durch ein enges, betonntes Fahrwasser zwischen zwei Sandbänken – rot an Backbord, grün an Steuerbord. Wer die Tonnen schneidet, sitzt fest.")
	l.wind_from_deg = 345.0
	l.wind_speed = 6.5
	l.wind_shift_deg = 12.0
	l.gusts = 0.8
	l.base_depth = 12.0
	l.depth_variation = 5.0
	l.seabed_seed = 515
	l.area_margin = 160.0
	_line(l, Vector2.ZERO, 0.0, 45.0)
	_shoal(l, "Westerbank", Vector2(-130, -270), 70, 1.0, 3.2, 0.0, false)
	_shoal(l, "Osterbank", Vector2(130, -270), 70, 1.0, 3.2, 0.0, false)
	for k in 5:
		var z := -80.0 - k * 85.0
		_sea(l, "Rot%d" % (k + 1), SeaMark.Kind.ROT, Vector2(-42, z), str(2 * k + 2))
		_sea(l, "Gruen%d" % (k + 1), SeaMark.Kind.GRUEN, Vector2(42, z), str(2 * k + 1))
	_sea(l, "Westerbank_N", SeaMark.Kind.NORD, Vector2(-130, -520))
	_sea(l, "Osterbank_N", SeaMark.Kind.NORD, Vector2(130, -520))
	_sea(l, "Westerbank_S", SeaMark.Kind.SUED, Vector2(-130, -20))
	_sea(l, "Osterbank_S", SeaMark.Kind.SUED, Vector2(130, -20))
	_mark(l, "Wendetonne", "Wendetonne", Vector2(0, -580), "Fl.Y.2s")
	_mark(l, "Westtonne", "Westtonne", Vector2(-240, -470), "Fl(2)Y.6s")
	_tower(l, "Oberfeuer", Vector2(250, -620), "Oberfeuer", Lighthouse.Style.SCHWARZ_WEISS, "Iso.W.4s 30m 16M", 24.0)
	_island(l, "Vogelsand", Vector2(300, -280), 45, "", 1.0, 1.6, 18, 0)
	_rose(l, Vector2(-250, -120), 34)
	return l


func _schaeren() -> Level:
	var l := _level("Schärengarten",
		"Zwischen bewaldeten Schären hindurch, mit Leuchttürmen, Klippen und böigem Südwestwind. Kurze Schläge, viel Taktik.")
	l.wind_from_deg = 225.0
	l.wind_speed = 6.0
	l.wind_shift_deg = 25.0
	l.gusts = 1.2
	l.seabed_seed = 3141
	l.coast_east = false
	l.area_margin = 150.0
	_line(l, Vector2.ZERO, 135.0, 40.0)
	_mark(l, "Kliptonne", "Kliptonne", Vector2(-300, 250), "Fl.Y.2s")
	_mark(l, "Holmtonne", "Holmtonne", Vector2(-80, 330), "Fl(2)Y.6s")
	_mark(l, "Sundtonne", "Sundtonne", Vector2(-260, 60), "Fl(3)Y.10s")
	_island(l, "Granholm", Vector2(-150, 120), 40, "Fl.W.5s 12m 8M", 1.2, 1.0, 22, 1)
	_island(l, "Tallskär", Vector2(-220, 225), 28, "", 1.0, 1.3, 12, 0, 30.0)
	_island(l, "Björkö", Vector2(-50, 200), 36, "", 1.4, 1.0, 20, 3)
	_island(l, "Lillskär", Vector2(-310, 150), 22, "", 1.0, 1.0, 8, 0)
	_island(l, "Ekholm", Vector2(70, 130), 30, "", 1.0, 1.4, 16, 1, -20.0)
	_shoal(l, "Klippe", Vector2(-170, 315), 10)
	_sea(l, "Klippe_Gefahr", SeaMark.Kind.EINZELGEFAHR, Vector2(-170, 315))
	_shoal(l, "Unterwasserstein", Vector2(-40, 85), 8)
	_sea(l, "Stein_Gefahr", SeaMark.Kind.EINZELGEFAHR, Vector2(-40, 85))
	_sea(l, "Granholm_S", SeaMark.Kind.SUED, Vector2(-150, 178))
	_tower(l, "Leuchtturm", Vector2(-390, 320), "Ytterfyr", Lighthouse.Style.GRUEN_WEISS, "LFl.W.10s 20m 12M", 18.0)
	_rose(l, Vector2(120, -60), 30)
	return l



func _fluss() -> Level:
	var l := _level("Flussregatta",
		"Binnenrevier: Vom Kleinen See flussaufwärts gegen die Strömung in den Großen See, dort zwei Tonnen runden und mit dem Strom zurück. In der Engstelle fließt der Fluss am schnellsten. Zwei Tankstellen.")
	l.inland = true
	l.wind_from_deg = 200.0
	l.wind_speed = 5.5
	l.wind_shift_deg = 22.0
	l.gusts = 1.0
	l.seabed_seed = 777
	l.area_margin = 110.0
	l.fuel_liters = 6.0
	# Seen
	var gross := ShoalArea.new()
	gross.name = "GrosserSee"
	gross.kind = ShoalArea.Kind.SEE
	gross.area_name = "Großer See"
	gross.radius = 190.0
	gross.see_depth = 9.0
	gross.rock_symbol = false
	gross.position = Vector3(0, 0, -340)
	gross.scale = Vector3(1.35, 1, 0.85)
	l.add_child(gross)
	var klein := ShoalArea.new()
	klein.name = "KleinerSee"
	klein.kind = ShoalArea.Kind.SEE
	klein.area_name = "Kleiner See"
	klein.radius = 115.0
	klein.see_depth = 6.0
	klein.rock_symbol = false
	klein.position = Vector3(40, 0, 315)
	klein.scale = Vector3(1.25, 1, 1.0)
	l.add_child(klein)
	# Fluss vom Großen in den Kleinen See (fließt nach Süden)
	var r := RiverChannel.new()
	r.name = "Muehlenfluss"
	r.river_name = "Mühlenfluss"
	r.width = 100.0
	r.depth = 6.0
	r.flow_kn = 1.1
	r.bank_trees = 70
	var wc := Curve.new()
	wc.add_point(Vector2(0.0, 1.2))
	wc.add_point(Vector2(0.45, 0.78))
	wc.add_point(Vector2(0.6, 0.78))
	wc.add_point(Vector2(1.0, 1.2))
	r.width_curve = wc
	var c := Curve3D.new()
	c.add_point(Vector3(0, 0, -200), Vector3.ZERO, Vector3(0, 0, 50))
	c.add_point(Vector3(-80, 0, -80), Vector3(20, 0, -45), Vector3(-20, 0, 45))
	c.add_point(Vector3(50, 0, 40), Vector3(-55, 0, -40), Vector3(55, 0, 40))
	c.add_point(Vector3(-20, 0, 150), Vector3(30, 0, -40), Vector3(-30, 0, 40))
	c.add_point(Vector3(30, 0, 225), Vector3(-25, 0, -30), Vector3.ZERO)
	r.curve = c
	l.add_child(r)
	# Inseln und Untiefen im Großen See
	_island(l, "Möweninsel", Vector2(70, -330), 34, "", 1.3, 0.9, 14, 0)
	_shoal(l, "Krautgrund", Vector2(-110, -390), 26)
	_sea(l, "Krautgrund_N", SeaMark.Kind.NORD, Vector2(-110, -432))
	_sea(l, "Krautgrund_S", SeaMark.Kind.SUED, Vector2(-110, -348))
	# Fahrwassertonnen am Fluss (Betonnungsrichtung flussaufwärts: rot an Backbord)
	var baked_len := c.get_baked_length()
	var k := 0
	for t in [0.18, 0.42, 0.62, 0.85]:
		var a := c.sample_baked(t * baked_len)
		var b := c.sample_baked(minf(t * baked_len + 4.0, baked_len))
		var flow := Vector2(b.x - a.x, b.z - a.z).normalized()
		var up := -flow
		var left := Vector2(up.y, -up.x)
		var half := r.width * wc.sample(t) * 0.5
		var p := Vector2(a.x, a.z)
		k += 1
		_sea(l, "Rot%d" % k, SeaMark.Kind.ROT, p + left * half * 0.62, str(2 * k))
		_sea(l, "Gruen%d" % k, SeaMark.Kind.GRUEN, p - left * half * 0.62, str(2 * k - 1))
	# Flusstankstelle am Ostufer, zwischen zwei Tonnenpaaren
	var ta := c.sample_baked(0.27 * baked_len)
	var tb := c.sample_baked(0.27 * baked_len + 4.0)
	var tflow := Vector2(tb.x - ta.x, tb.z - ta.z).normalized()
	var east := Vector2(-tflow.y, tflow.x)
	var thalf := r.width * wc.sample(0.27) * 0.5
	_dock(l, "Flusstankstelle", Vector2(ta.x, ta.z) + east * (thalf + 14.0), -east, 26.0, "Flusstankstelle")
	_dock(l, "Seetankstelle", Vector2(-150, -470), Vector2(0.4, 1.0), 48.0, "Marina")
	# Bahn
	_line(l, Vector2(40, 330), 0.0, 40.0)
	_mark(l, "Seetonne1", "Seetonne Nord", Vector2(30, -400), "Fl.Y.2s")
	_mark(l, "Seetonne2", "Seetonne West", Vector2(-160, -290), "Fl(2)Y.6s")
	_rose(l, Vector2(200, -180), 30)
	return l


## Kieler Förde (nicht maßstabsgetreu): Die Fördeachse läuft von der Südspitze Hörn nach Nordnordost
## (um etwa 20° nach rechts geneigt), schmal am Hörn, breit bei Düsternbrook/Wik, eng an der
## Friedrichsorter Enge, weit offen zur Kieler Bucht. Land entsteht aus Ketten großer Kreise.
const KIEL_C0 := Vector2(-200, 340)      ## Achse bei s = 0 (Hörn)
const KIEL_C1 := Vector2(200, -780)      ## Achse bei s = 1 (Mündung)
const KIEL_W := [[0.0, 170.0], [0.08, 330.0], [0.2, 560.0], [0.38, 620.0], [0.5, 540.0], [0.57, 330.0],
	[0.62, 250.0], [0.68, 330.0], [0.8, 600.0], [1.0, 760.0]]


func _kc(s: float) -> Vector2:
	return KIEL_C0.lerp(KIEL_C1, s)


func _kd() -> Vector2:
	return (KIEL_C1 - KIEL_C0).normalized()


func _kn() -> Vector2:
	var d := _kd()
	return Vector2(-d.y, d.x)                ## zeigt nach Osten


func _kw(s: float) -> float:
	for i in KIEL_W.size() - 1:
		var a: Array = KIEL_W[i]
		var b: Array = KIEL_W[i + 1]
		if s <= float(b[0]):
			return lerpf(float(a[1]), float(b[1]), (s - float(a[0])) / (float(b[0]) - float(a[0])))
	return float(KIEL_W[KIEL_W.size() - 1][1])


## Punkt bei Achsenanteil s und Querabstand o (Meter, Osten positiv)
func _kp(s: float, o: float) -> Vector2:
	return _kc(s) + _kn() * o


## Drehwinkel (Grad), damit der lokale -Z-Pfeil in Richtung v zeigt
func _arrow_deg(v: Vector2) -> float:
	return rad_to_deg(atan2(-v.x, -v.y))


func _kiel() -> Level:
	var l := _level("Kieler Förde",
		"Von der Schwentinemündung die Förde hinauf, bei knackigem Westwind: Ostseekai am Hörn, Düsternbrook, Tirpitzmole, NOK-Schleuse Holtenau, durch die Friedrichsorter Enge mit Leuchtturm (gegenüber das U-Boot-Ehrenmal) bis zum Olympiahafen Schilksee – mit Berufsschifffahrt in der Fahrrinne.")
	l.wind_from_deg = 270.0
	l.wind_speed = 10.5
	l.wind_shift_deg = 12.0
	l.gusts = 1.3
	l.base_depth = 12.0
	l.depth_variation = 4.0
	l.seabed_seed = 2412
	l.fuel_liters = 8.0
	l.area_margin = 110.0
	l.coast_east = false
	l.coast_west = false
	var d := _kd()
	var n := _kn()
	# Südspitze Hörn schließt die Förde
	_island(l, "Hörn", _kc(0.0) - d * 215.0, 250.0, "", 1.0, 1.0, 6, 24)
	# Westufer (Kette von Kreisen); Namen von Süd nach Nord
	var west := ["Kiel Hbf – Hörn West", "Düsternbrook", "Düsternbrook Nord", "Wik", "Marine-Arsenal Wik", "Holtenau", "Friedrichsort", "Falkenstein", "Schilksee", "Bülk"]
	var wi := 0
	var s := 0.05
	while s <= 1.02:
		var o := -(_kw(s) * 0.5 + 170.0)
		_island(l, west[mini(wi, west.size() - 1)], _kp(s, o), 190.0, "", 1.0, 1.0, 14, 8)
		wi += 1
		s += 0.125
	# Ostufer: Lücke für die Schwentine zwischen Wellingdorf (Süd) und Neumühlen (Nord)
	_island(l, "Wellingdorf", _kp(0.04, _kw(0.04) * 0.5 + 95.0), 105.0, "", 1.0, 1.0, 6, 8)
	_island(l, "Neumühlen", _kp(0.30, _kw(0.30) * 0.5 + 95.0), 105.0, "", 1.0, 1.0, 6, 8)
	_island(l, "Schwentine-Hinterland", _kp(0.17, _kw(0.17) * 0.5 + 480.0), 300.0, "", 1.0, 1.0, 10, 6)
	var east := ["Dietrichsdorf", "Dietrichsdorf Nord", "Möltenort", "Heikendorf", "Heikendorf Nord", "Laboe", "Laboe Nord"]
	var ei := 0
	s = 0.40
	while s <= 1.02:
		var o2 := _kw(s) * 0.5 + 170.0
		_island(l, east[mini(ei, east.size() - 1)], _kp(s, o2), 190.0, "", 1.0, 1.0, 14, 6)
		ei += 1
		s += 0.1
	# Start in der Schwentine (Pfeil nach Westen, hoch am Wind), Ziel vor dem Olympiahafen Schilksee
	var sg := _kp(0.17, _kw(0.17) * 0.5 - 25.0)
	_line(l, sg, _arrow_deg(-n), 40.0)
	var fin := _kp(0.93, -_kw(0.93) * 0.5 + 150.0)
	_line(l, fin, _arrow_deg(-n), 22.0, true)
	# Wahrzeichen
	_tower(l, "Leuchtturm_Friedrichsort", _kp(0.62, -_kw(0.62) * 0.5 - 20.0), "Leuchtturm Friedrichsort", Lighthouse.Style.ROT_WEISS, "Fl(2)WR.12s 20m 14M", 22.0)
	_tower(l, "UBoot_Ehrenmal", _kp(0.62, _kw(0.62) * 0.5 + 35.0), "U-Boot-Ehrenmal Möltenort", Lighthouse.Style.DENKMAL, "", 14.0, false)
	_tower(l, "Laboe_Ehrenmal", _kp(0.90, _kw(0.90) * 0.5 + 15.0), "Marine-Ehrenmal Laboe", Lighthouse.Style.EHRENMAL, "", 40.0, false)
	var mrot := rad_to_deg(atan2(-n.y, n.x))        # lokale X-Achse zeigt nach Osten (Molen ragen ins Wasser)
	_mole(l, "Ostseekai", _kp(0.04, -_kw(0.04) * 0.5 + 20.0), 70.0, mrot, Mole.HeadLight.KEINES, 12.0, "Kreuzfahrtterminal Ostseekai")
	var dn := _kp(0.30, -_kw(0.30) * 0.5 + 25.0)
	_mole(l, "Duesternbrook_N", dn - d * 30.0, 60.0, mrot, Mole.HeadLight.ROT, 8.0, "Düsternbrooker Hafen")
	_mole(l, "Duesternbrook_S", dn + d * 30.0, 60.0, mrot, Mole.HeadLight.GRUEN, 8.0)
	_mole(l, "Tirpitzmole", _kp(0.44, -_kw(0.44) * 0.5 + 40.0), 100.0, mrot, Mole.HeadLight.WEISS, 10.0, "Tirpitzmole")
	var nk := _kp(0.54, -_kw(0.54) * 0.5 + 30.0)
	_mole(l, "NOK_Nord", nk - d * 28.0, 70.0, mrot, Mole.HeadLight.ROT, 9.0, "NOK – Schleuse Holtenau")
	_mole(l, "NOK_Sued", nk + d * 28.0, 70.0, mrot, Mole.HeadLight.GRUEN, 9.0)
	var oh := _kp(0.93, -_kw(0.93) * 0.5 + 60.0)
	_mole(l, "Olympiahafen_N", oh - d * 35.0, 80.0, mrot, Mole.HeadLight.ROT, 9.0, "Olympiahafen Schilksee")
	_mole(l, "Olympiahafen_S", oh + d * 35.0, 80.0, mrot, Mole.HeadLight.GRUEN, 9.0)
	_dock(l, "Anleger_Duesternbrook", _kp(0.22, -_kw(0.22) * 0.5 + 5.0), n, 80.0, "Hafen Düsternbrook")
	_dock(l, "Anleger_Falkenstein", _kp(0.80, -_kw(0.80) * 0.5 + 5.0), n, 105.0, "Falkenstein Anleger")
	# Bahnmarken
	_mark(l, "Ostseekai_Tonne", "Ostseekai", _kp(0.07, -20.0), "Fl.Y.2s")
	_mark(l, "Duesternbrook_Tonne", "Düsternbrook", _kp(0.28, -_kw(0.28) * 0.5 + 130.0), "Fl(2)Y.6s")
	_mark(l, "Tirpitz_Tonne", "Tirpitzmole", _kp(0.44, -_kw(0.44) * 0.5 + 150.0), "Fl(3)Y.10s")
	_mark(l, "NOK_Tonne", "NOK Holtenau", _kp(0.54, -_kw(0.54) * 0.5 + 130.0), "Fl.Y.2s")
	_mark(l, "Enge_Tonne", "Friedrichsorter Enge", _kp(0.62, -60.0), "Fl(2)Y.6s")
	_mark(l, "Falkenstein_Tonne", "Falkenstein", _kp(0.78, -_kw(0.78) * 0.5 + 150.0), "Fl(3)Y.10s")
	# Berufsschifffahrt, Sperrgebiet, Tiere
	# Berufsschifffahrt zwischen Nord-Ostsee-Kanal (Schleuse Holtenau) und Ostsee: aus der Kanalmündung
	# am Westufer quer über die Förde in die Enge, dann geradeaus nach Norden
	var s0 := _kp(0.545, -_kw(0.545) * 0.5 + 40.0) - n * 60.0
	var s1 := _kp(0.62, 0.0)
	var f := (s1 - s0).normalized()
	var turn := rad_to_deg(acos(clampf(f.dot(d), -1.0, 1.0))) * signf(d.dot(Vector2(-f.y, f.x)))
	var leg := s0.distance_to(s1)
	_shipping(l, "Berufsschifffahrt", s0, f, leg + 620.0, 150.0, 70.0, -30.0, 22.0, leg, turn)
	_restricted(l, "Marine_Sperrgebiet", RestrictedArea.Kind.POLIZEI, _kp(0.47, -_kw(0.47) * 0.5 + 90.0), 40.0, "Marine-Sperrgebiet")
	_life(l, "Moewen", SeaLife.Kind.MOEWEN, _kp(0.04, 0.0), 8, 50.0)
	_life(l, "Tuemmler", SeaLife.Kind.TUEMMLER, _kp(0.9, 60.0), 3, 40.0)
	_life(l, "Seehunde", SeaLife.Kind.SEEHUNDE, _kp(0.3, _kw(0.3) * 0.5 - 40.0), 4, 15.0)
	_rose(l, _kp(0.35, 130.0), 34)
	return l
