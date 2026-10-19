# Rennablauf (`main.gd`, `course.gd`)

## `main.gd`: Der Dirigent { #main-gd }

Datei: `scripts/main.gd`, `extends Node`, etwa 450 Zeilen. Szene: `scenes/main.tscn` (nur ein
`Node` mit diesem Skript). Das Skript **besitzt keine Spiellogik für Boote**, es verbindet die
Teile miteinander:

* **baut** das Rennen auf (`_ready`),
* **steuert** den Ablauf: Warten → Countdown → Rennen → Ziel (`_physics_process`),
* **löst** Boot↔Boot- und Boot↔Tonne-Kollisionen,
* **ruft** Schlepper, lässt tanken, wertet Gefahrengebiete aus,
* **synchronisiert** im Netzwerk (Schnappschüsse, Eingaben).

### Der Aufbau in `_ready()`

Die Reihenfolge ist wichtig. Hier der gekürzte echte Ablauf:

```gdscript
func _ready() -> void:
    randomize()
    Sfx.ensure(get_tree())                       # Klang bereitstellen
    net = GameState.net_mode                     # "", "host" oder "client"
    _build_environment()                         # Licht, Hintergrund

    level = load(GameState.current_level_path()).instantiate()
    add_child(level)                             # Kinder machen ihr _ready()
    level.prepare_for_game()                     # Tiefenraster berechnen und global setzen

    wind = WindField.new()
    GameState.apply_wind(level, wind)            # Wind des Levels + Menüwahl
    add_child(wind)
    chart = SeaChart.new();  add_child(chart)    # Karte erst NACH dem Tiefenraster
    course = Course.new();   add_child(course)
    course.setup(level)

    _fixed_points = level.collision_points()     # Tonnen, Wracks, Tankstege
    _docks = level.fuel_docks()
    _hazards = level.hazards()
    Currents.set_sources(level.current_sources())
    course.target_reached.connect(_on_target_reached)
    course.boat_finished.connect(_on_boat_finished)
    ...  # WindVisuals, Boote, Kameras, HUD, Windgeräusch
```

**Warum diese Reihenfolge?**

1. `SeaChart` und alle Baustein-`_ready()`s brauchen das Tiefenraster. Es entsteht in
   `level.prepare_for_game()`, also muss das Level **vor** `SeaChart` im Baum stehen.
2. `Course.setup()` liest `Level.marks()`. Deshalb nach dem Level.
3. Die Boote kommen **zuletzt**: Sie brauchen `wind`, `course`, `level`.

### Boote erzeugen

```gdscript
var slots := GameState.slots()                    # Liste von {peer, local, name, color, bot, ai}
for i in slots.size():
    var b := Boat.new()
    b.player_index = i
    b.color = COLORS[...]
    b.wind = wind; b.course = course
    b.heading = atan2(close_hauled.x, close_hauled.y)       # hoch am Wind
    b.position = ... line.start_position(i)                # Startplatz 30 m hinter der Linie
    b.fuel = GameState.start_fuel(level)
    b.has_engine = b.fuel > 0.0
    if is_bot and net != "client":
        b.input = AIInput.new(b, wind, course, ai_level, _fixed_points)   # Computer
    elif net == "client":
        b.puppet = true                                                    # nur anzeigen
    elif mine:
        b.input = PlayerInput.new(int(slot["local"]))                      # Mensch
    else:
        b.input = NetInput.new()                                           # Fremder Spieler
```

Die vier Fälle zeigen den Kern des Konzepts: **`Boat` bleibt immer gleich, nur `input`
wechselt.** Startrichtung: „hoch am Wind“ (45° zur Windrichtung, auf der Seite der Startlinie),
damit alle gleich losfahren können.

### Zustandsmaschine

`state` ist ein String: `"waiting"`, `"countdown"`, `"racing"`, `"finished"`.

```
 waiting   (nur Netzwerk) bis Net.all_loaded() oder 20 s Timeout
    ▼
 countdown 4 s, Pieptöne bei 3, 2, 1; Boote haben controls_enabled = false
    ▼  countdown <= 0:  Sfx "go", b.controls_enabled = true
 racing    race_time zählt; Hazards.update_boat; Kollisionen; Schlepper; Tanken
    ▼  _on_boat_finished (erstes Boot) oder alle Boote out
 finished  Rennen geht weiter, bis Start/Enter gedrückt wird → restart()
```

Ein Boot im Ziel setzt `finish_time`; das **erste** wird `winner`. Bei `finished` läuft die
Uhr weiter, damit auch die anderen noch ins Ziel kommen können.

### Kollisionen `_resolve_collisions(delta)`

**Boot ↔ Boot** (Kreise mit `BOAT_RADIUS = 3,6`):

```gdscript
var d := b.pos2d() - a.pos2d()
var dist := d.length()
var min_d := Boat.BOAT_RADIUS * 2.0
if dist >= min_d: continue                    # keine Überlappung
var n := d / dist                             # Normale von a nach b
var push := (min_d - dist) * 0.5
a.position -= Vector3(n.x, 0, n.y) * push     # beide je zur Hälfte auseinanderschieben
b.position += Vector3(n.x, 0, n.y) * push
var rel := (b.vel - a.vel).dot(n)             # Annäherungstempo (< 0 = nähern sich)
if rel < 0.0:
    var a_in := a.vel.dot(n); var b_in := -b.vel.dot(n)     # vor dem Impuls merken
    a.vel += n * rel * 0.6;  b.vel -= n * rel * 0.6         # Impuls (teilelastisch)
    a.collide(-rel, a_in >= b_in); b.collide(-rel, b_in > a_in)   # Nachteil
a.scrape(delta); b.scrape(delta)              # Dauerkontakt bremst
```

**Boot ↔ feste Punkte** (Tonnen, Stege, Wracks): gleiche Idee, aber nur das Boot wird
bewegt; die Geschwindigkeit entlang der Normalen wird mit Faktor 1,4 umgekehrt (Abprallen).
Boote mit `towed` oder `out` werden übersprungen.

### Weitere Aufgaben pro Physikschritt

| Aufgabe | Code |
|---|---|
| Gefahren auswerten | `for h in _hazards: for b in boats: h.update_boat(b, delta)` (nur `racing`/`finished`) |
| Alle ausgeschieden? | `boats.all(func(b): return b.out)` → `state = "finished"` ohne Sieger |
| Schlepper rufen | `_call_tugs()`: `stuck_time > 4 s` und kein Schlepper → `Tug.spawn_for(b)` |
| Tanken | Boot näher als `FuelDock.ZONE` am Liegeplatz → `b.refuel(delta)` |
| Snapshot senden | Host: alle 1/20 s `Net.send_snapshot(_make_snapshot())` |
| Neustart | Im Zustand `finished` und `input.start_pressed` → `restart()` |

### Tasten (`_unhandled_input`)

`F5` neu starten (Host/lokal), `T` Segel-Overlay, `Esc` zurück (`_leave()`: Host → Lobby für
alle, Client → Verbindung trennen, lokal → Menü).

### Rang `rank_of(boat)`

Zählt, wie viele Boote einen **höheren** `Course.progress` haben, +1.

### Netzwerk in `main.gd`

| Funktion | Rolle |
|---|---|
| `_make_snapshot()` | Host: Zustand, Zeit, Wind, Sieger, alle Boote, Schlepper → `PackedFloat32Array` |
| `apply_snapshot(d)` | Client: Zustand übernehmen, Schlepper-Puppen anlegen/entfernen |
| `apply_remote_inputs(peer, data)` | Host: Eingaben eines Clients in dessen `NetInput`s |
| `_send_local_inputs()` | Client: eigene Eingaben zum Host |
| `on_peer_left`, `on_net_event` | Verbindungsverlust, Meldungen |

Erklärung des Protokolls: [Netzwerk](netzwerk.md).

### Licht (`_build_environment`)

Weißer Hintergrund (`BG_COLOR`), ein `WorldEnvironment` mit linearem Tonemapping, eine
`DirectionalLight3D` (−62° Neigung, Schatten mit Reichweite 250 m und 35 % Deckkraft).

## `course.gd`: Die Bahnlogik { #course-gd }

`class_name Course`, `extends Node`, 85 Zeilen. Sie weiß, **welches Boot welches Ziel als
Nächstes hat** und meldet Erreichtes per Signal.

```gdscript
signal target_reached(boat: Boat, target_index: int, label: String)
signal boat_finished(boat: Boat)

var targets: Array[Dictionary] = []     # Reihenfolge: Startlinie, Marken …, Ziel
func setup(p_level: Level) -> void:
    targets.append({"type": "line", "name": "Startlinie", "pos": line.center2d(), "dir": 1})
    for m in level.marks():
        targets.append({"type": "mark", "name": m.mark_name, "pos": m.pos2d()})
    targets.append({"type": "line", "name": "Ziel", "pos": line.center2d(), "dir": -1})
```

`boat.next_target` ist der Index in dieser Liste: 0 = Startlinie, 1 … n = Marken,
n+1 = Ziel.

### `update_progress(boat, prev, cur)`

Wird vom Boot am Ende jedes Physikschritts mit alter und neuer Position gerufen:

```gdscript
if t["type"] == "mark":
    reached = cur.distance_to(t["pos"]) < MARK_RADIUS            # in den 20-m-Kreis gefahren
else:
    var a := line.signed_dist(prev)
    var b := line.signed_dist(cur)
    var crossed := (a < 0.0 and b >= 0.0) if int(t["dir"]) > 0 else (a > 0.0 and b <= 0.0)
    reached = crossed and line.within(cur)                       # Linie in der richtigen Richtung gekreuzt
```

Das Überqueren wird über das **Vorzeichen-Wechsel-Muster** erkannt (alter Punkt hinter, neuer
vor der Linie). Das ist robust, auch wenn ein Boot in einem Schritt mehrere Meter springt.

### `progress(boat)` für die Rangfolge

```gdscript
if boat.finished: return 1.0e9 - boat.finish_time          # Früher im Ziel = höherer Wert
if boat.out:      return -1.0e9 + boat.next_target * 100000.0   # Ausgeschiedene ganz hinten
return boat.next_target * 100000.0 - boat.pos2d().distance_to(target_pos(boat.next_target))
```

Erreichte Ziele zählen **sehr viel** (100 000 pro Ziel), innerhalb eines Ziels entscheidet der
Abstand. Es braucht keine Rundenzeit-Verfolgung.

### Weitere

`target_pos(i)`, `target_name(i)` (für das HUD) und `static course_length(level)` (Bahnlänge in
Metern für die Menüanzeige).
