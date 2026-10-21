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


## Kieler Förde nach der Seekarte „Kieler Förde“ (Nautic Publications S2, 1 : 40 000): Küste und
## Wassertiefe stammen aus tools/chart_to_depth.py (levels/data/kiel_foerde_tiefe.png), die
## Wahrzeichen sitzen an den Kartenpunkten (Bildpunkt der Seekarte -> Spielmeter, siehe _chart).
## Die Karte ist etwa 1 : 11 gestaucht, Wasserwege sind um 28 m verbreitert.
const KIEL_X0 := 500.0       ## Bildpunkt der Weltecke (-640, -840)
const KIEL_Y0 := 2923.0
const KIEL_K := 0.30         ## Spielmeter je Kartenpixel
var _kd_img: Image


func _chart(px: float, py: float) -> Vector2:
	return Vector2(-640.0 + (px - KIEL_X0) * KIEL_K, -840.0 + (py - KIEL_Y0) * KIEL_K)


func _kdepth(p: Vector2) -> float:
	if _kd_img == null:
		_kd_img = Image.load_from_file("res://levels/data/kiel_foerde_tiefe.png")
	var i := clampi(int((p.x + 640.0) / 2.0), 0, 639)
	var j := clampi(int((p.y + 840.0) / 2.0), 0, 639)
	return -8.0 + _kd_img.get_pixel(i, j).r * 255.0 * 0.1


## nächster Wasserpunkt mit möglichst min_d Meter Tiefe (sonst mit weniger, bis 2,6 m)
func _kwater(p: Vector2, min_d := 7.0, rad := 140.0) -> Vector2:
	for want in [min_d, minf(min_d, 6.0), 4.0, 2.6]:
		var best := p
		var bd := INF
		var r := -rad
		while r <= rad:
			var c := -rad
			while c <= rad:
				var q := p + Vector2(c, r)
				var dd := q.distance_to(p)
				if dd < bd and _kdepth(q) >= want:
					bd = dd
					best = q
				c += 4.0
			r += 4.0
		if bd < INF:
			return best
	return p


## nächster Küstenpunkt (Land, Tiefe unter -0,8) zu p
func _kshore(p: Vector2, rad := 150.0) -> Vector2:
	var best := p
	var bd := INF
	var r := -rad
	while r <= rad:
		var c := -rad
		while c <= rad:
			var q := p + Vector2(c, r)
			var dd := q.distance_to(p)
			if dd < bd and _kdepth(q) < -0.8:
				bd = dd
				best = q
			c += 2.0
		r += 2.0
	return best


## Richtung vom Ufer ins Wasser: zum nächsten tiefen Wasser (Tiefe >= 6 m)
func _kout(shore: Vector2) -> Vector2:
	var deep := _kwater(shore, 6.0, 120.0)
	var v := deep - shore
	if v.length() > 1.0:
		return v.normalized()
	var g := Vector2(_kdepth(shore + Vector2(8, 0)) - _kdepth(shore - Vector2(8, 0)), _kdepth(shore + Vector2(0, 8)) - _kdepth(shore - Vector2(0, 8)))
	return g.normalized() if g.length() > 0.01 else Vector2(1, 0)


## Drehwinkel (Grad), damit der lokale -Z-Pfeil in Richtung v zeigt
func _arrow_deg(v: Vector2) -> float:
	return rad_to_deg(atan2(-v.x, -v.y))


## Winkel (Grad), damit die lokale +X-Achse (Mole, Steg) in Richtung v zeigt
func _x_deg(v: Vector2) -> float:
	return rad_to_deg(atan2(-v.y, v.x))


## Mole am Ufer in der Nähe von Kartenpunkt p, ragt ins Wasser; liefert Uferpunkt und Richtung
func _shore_mole(l: Level, node: String, p: Vector2, length: float, light: Mole.HeadLight, width: float, label := "", side := 0.0) -> Array:
	var sh := _kshore(p)
	var out := _kout(sh)
	var tang := Vector2(-out.y, out.x)
	var root := sh + tang * side - out * 5.0
	_mole(l, node, root + out * length * 0.5, length, _x_deg(out), light, width, label)
	return [sh, out]


## Landzunge vom Ufer bis zum Kartenpunkt p (die Küste ist verbreitert, deshalb fehlt sonst die Spitze):
## schmale Insel zwischen Uferpunkt und p; liefert den Kartenpunkt für das Bauwerk.
func _peninsula(l: Level, node: String, p: Vector2, width := 15.0) -> Vector2:
	var sh := _kshore(p, 200.0)
	var d := p.distance_to(sh)
	if d > 10.0:
		var u := (p - sh).normalized()
		var isl := ShoalArea.new()
		isl.name = node
		isl.kind = ShoalArea.Kind.INSEL
		isl.area_name = ""
		isl.radius = width
		isl.rock_symbol = false
		isl.position = Vector3((sh.x + p.x) * 0.5 - u.x * 10.0, 0, (sh.y + p.y) * 0.5 - u.y * 10.0)
		isl.scale = Vector3(1, 1, (d * 0.5 + 24.0) / width)
		isl.rotation.y = atan2(u.x, u.y)
		l.add_child(isl)
	return p


func _kiel() -> Level:
	var l := _level("Kieler Förde",
		"Nach der Seekarte: Von der Schwentinemündung die Förde hinauf, bei knackigem Westwind – Ostseekai am Hörn, Düsternbrook, Tirpitzmole, NOK-Schleuse Holtenau, durch die Friedrichsorter Enge mit Leuchtturm und U-Boot-Ehrenmal, am Marine-Ehrenmal Laboe vorbei bis zum Olympiahafen Schilksee. Berufsschiffe fahren zwischen Kanal und Ostsee.")
	l.wind_from_deg = 270.0
	l.wind_speed = 10.5
	l.wind_shift_deg = 12.0
	l.gusts = 1.3
	l.seabed_seed = 2412
	l.fuel_liters = 8.0
	l.area_margin = 110.0
	l.coast_east = false
	l.coast_west = false
	l.depth_image = "res://levels/data/kiel_foerde_tiefe.png"
	# Start in der Schwentinemündung (Pfeil nach Westen in die Förde), Ziel vor dem Olympiahafen Schilksee
	var mouth := _chart(1762, 6140)
	_line(l, mouth + Vector2(-16, 0), 90.0, 22.0)
	var fin_sh := _kshore(_chart(2026, 3323))
	var fin_out := _kout(fin_sh)
	var fin := fin_sh + fin_out * 55.0
	_line(l, fin, _arrow_deg(-fin_out), 24.0, true)
	var ft := Vector2(-fin_out.y, fin_out.x)
	_mole(l, "Olympiahafen_N", fin_sh - fin_out * 5.0 + ft * 36.0 + fin_out * 40.0, 80.0, _x_deg(fin_out), Mole.HeadLight.ROT, 8.0, "Olympiahafen Schilksee")
	_mole(l, "Olympiahafen_S", fin_sh - fin_out * 5.0 - ft * 36.0 + fin_out * 40.0, 80.0, _x_deg(fin_out), Mole.HeadLight.GRUEN, 8.0)
	# Wahrzeichen
	var lh := _peninsula(l, "Landzunge_Friedrichsort", _chart(2167, 4157))
	_tower(l, "Leuchtturm_Friedrichsort", lh, "Leuchtturm Friedrichsort", Lighthouse.Style.ROT_WEISS, "Dir.Iso.WRG.4s 32m 7M", 22.0)
	var ub := _peninsula(l, "Landzunge_Moeltenort", _chart(2193, 4550))
	_tower(l, "UBoot_Ehrenmal", ub, "U-Boot-Ehrenmal Möltenort", Lighthouse.Style.DENKMAL, "", 14.0, false)
	var lb := _kshore(_chart(2907, 3436))
	_tower(l, "Laboe_Ehrenmal", lb - _kout(lb) * 8.0, "Marine-Ehrenmal Laboe (72 m)", Lighthouse.Style.EHRENMAL, "", 40.0, false)
	_shore_mole(l, "Ostseekai", _chart(1100, 6380), 60.0, Mole.HeadLight.KEINES, 12.0, "Kreuzfahrtterminal Ostseekai")
	_shore_mole(l, "Duesternbrook_N", _chart(1342, 5860), 55.0, Mole.HeadLight.ROT, 7.0, "Düsternbrooker Hafen", 26.0)
	_shore_mole(l, "Duesternbrook_S", _chart(1342, 5860), 55.0, Mole.HeadLight.GRUEN, 7.0, "", -26.0)
	_shore_mole(l, "Tirpitzmole", _chart(1320, 5420), 70.0, Mole.HeadLight.WEISS, 9.0, "Tirpitzmole")
	var nok := _kshore(_chart(1350, 5065))
	var nok_out := _kout(nok)
	var nok_t := Vector2(-nok_out.y, nok_out.x)
	_mole(l, "NOK_Nord", nok - nok_out * 5.0 + nok_t * 24.0 + nok_out * 30.0, 60.0, _x_deg(nok_out), Mole.HeadLight.ROT, 8.0, "NOK – Schleuse Holtenau")
	_mole(l, "NOK_Sued", nok - nok_out * 5.0 - nok_t * 24.0 + nok_out * 30.0, 60.0, _x_deg(nok_out), Mole.HeadLight.GRUEN, 8.0)
	var dd := _kshore(_chart(1342, 5740))
	_dock(l, "Anleger_Duesternbrook", dd - _kout(dd) * 6.0, _kout(dd), 64.0, "Hafen Düsternbrook")
	var fd := _kshore(_chart(2055, 3880))
	_dock(l, "Anleger_Falkenstein", fd - _kout(fd) * 6.0, _kout(fd), 44.0, "Falkenstein Anleger")
	# Bahnmarken
	_mark(l, "Duesternbrook_Tonne", "Düsternbrook", _kwater(_chart(1342, 5860), 9.0), "Fl(2)Y.6s")
	_mark(l, "Tirpitz_Tonne", "Tirpitzmole", _kwater(_chart(1440, 5380), 9.0), "Fl(3)Y.10s")
	_mark(l, "NOK_Tonne", "NOK Holtenau", _kwater(_chart(1570, 5080), 9.0), "Fl.Y.2s")
	_mark(l, "Enge_Tonne", "Friedrichsorter Enge", Vector2(-58, -480), "Fl(2)Y.6s")        # Fahrwasser östlich der Landzunge Friedrichsort
	_mark(l, "Laboe_Tonne", "Laboe", _kwater(_chart(2690, 3560), 9.0), "Fl(3)Y.10s")
	# Berufsschifffahrt zwischen Nord-Ostsee-Kanal (Schleuse Holtenau) und Ostsee: aus dem Kanal quer
	# über die Förde zur Enge, dann nach Norden. Die Schiffe sind kleiner als in der Lotsenrinne.
	var s0 := nok - nok_out * 90.0
	var s1 := Vector2(-58, -470)
	var s2 := _kwater(_chart(2480, 3000), 9.0)
	var f := (s1 - s0).normalized()
	var f2 := (s2 - s1).normalized()
	var turn := rad_to_deg(acos(clampf(f.dot(f2), -1.0, 1.0))) * signf(f2.dot(Vector2(-f.y, f.x)))
	var leg := s0.distance_to(s1)
	_shipping(l, "Berufsschifffahrt", s0, f, leg + s1.distance_to(s2), 210.0, 70.0, -60.0, 14.0, leg, turn)
	var lane := l.get_node("Berufsschifffahrt") as ShippingLane
	lane.ship_length = 55.0
	lane.beam = 11.0
	_restricted(l, "Marine_Sperrgebiet", RestrictedArea.Kind.POLIZEI, _kwater(_chart(1500, 6420), 9.0), 28.0, "Marine-Sperrgebiet")
	_life(l, "Moewen", SeaLife.Kind.MOEWEN, _kwater(_chart(1250, 6450), 9.0), 8, 40.0)
	_life(l, "Tuemmler", SeaLife.Kind.TUEMMLER, _kwater(_chart(2300, 3150), 9.0), 3, 40.0)
	_life(l, "Seehunde", SeaLife.Kind.SEEHUNDE, _kwater(_chart(2600, 3350), 5.0), 4, 15.0)
	_rose(l, _chart(3300, 3500), 34)
	return l
