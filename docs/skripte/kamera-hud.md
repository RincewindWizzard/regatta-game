# Kamera und Anzeige

## `split_camera.gd`: Splitscreen { #split-camera-gd }

`class_name SplitCameraManager`, `extends Control`, 133 Zeilen. Es zeigt **ein oder zwei**
Boote mit einer oder zwei Kameras und teilt den Bildschirm **dynamisch**:

* Sind die Boote nah beieinander, zeigt **eine** Kamera beide und zoomt passend heraus.
* Entfernen sie sich zu weit voneinander, teilt sich das Bild **vertikal** (links/rechts) mit
  weichem Übergang. Wer beim Teilen weiter links ist, bekommt die linke Hälfte.

### Aufbau

Für zwei Ansichten braucht man in Godot **zwei Viewports**: `SubViewport`s mit je einer
`Camera3D`, dargestellt in `SubViewportContainer`s:

```
 SplitCameraManager (Control, füllt den Bildschirm)
 ├─ SubViewportContainer 0 ── SubViewport 0 ── Camera3D 0      (linke/volle Hälfte)
 ├─ SubViewportContainer 1 ── SubViewport 1 ── Camera3D 1      (rechte Hälfte)
 └─ ColorRect (Trennlinie)
```

Beide `SubViewport`s teilen sich dieselbe 3D-Welt (`world_3d` des Hauptfensters), sehen also
dasselbe Spiel von verschiedenen Kameras. `audio_listener_enable_3d` ist nur für den ersten
an.

### Die Rechnung

```gdscript
const PITCH := deg_to_rad(68.0)    # Neigung (90° = senkrecht von oben)
const FOV := 50.0
const SPLIT_ON := 125.0            # ab diesem nötigen Abstand wird geteilt
const SPLIT_OFF := 95.0            # unter diesem wieder zusammengeführt (Hysterese!)
const SPLIT_DIST := 58.0           # Kameraabstand im geteilten Modus
```

1. `_needed_dist(aspect)`: Wie weit müsste die Kamera weg, damit **beide** Boote ins Bild
   passen? Aus dem Öffnungswinkel: `k = 2 · tan(FOV/2)`, Bildbreite in Metern = `dist · k · aspect`.
2. **Hysterese:** Geteilt wird ab 125, zusammengeführt erst unter 95. Ohne diese Lücke würde das
   Bild bei 110 m flackernd hin und her springen. Dieselbe Idee wie bei einem Thermostat.
3. `split_t` bewegt sich mit `move_toward` von 0 nach 1 (Geschwindigkeit 1,8/s); `smoothstep`
   macht den Übergang weich. Aus `split_t` ergibt sich die Breite der linken Hälfte:
   `lerpf(bildschirmbreite, bildschirmbreite/2, t)`.
4. **Vorausschau:** Die Kamera zielt auf `pos + vel * 2` (zwei Sekunden voraus), damit man mehr
   von dem sieht, wohin man fährt. `lerp` mit `1 − exp(−4·dt)` glättet die Bewegung.
5. `_place(cam, target, dist)`: Position `target + (0, sin(PITCH)·dist, cos(PITCH)·dist)`,
   dann `look_at(target)`. Die Kamera schwebt hinter (+z, also im Süden) und über dem Ziel.

Bei **einem** Boot (`boats.size() == 1`, z. B. Client im Netzwerk) gibt es nur
`_single_view`: Vollbild, Abstand `SPLIT_DIST × 1,15`.

### Beispiel: Kamera hoch und flach

Setzt man `PITCH` auf `deg_to_rad(90.0)`, blickt die Kamera **senkrecht von oben**; bei `45°`
sieht man Segel und Masten von der Seite. Der Standardwert 68° ist der Kompromiss zwischen
Kartenlook und lesbarem Boot.

## `hud.gd`: Anzeige im Rennen { #hud-gd }

`class_name RaceHud`, `extends Control`, 365 Zeilen. Das HUD hat **keine Kind-Nodes**: Alles
wird in `_draw()` mit Zeichenbefehlen gemalt. `_process` ruft nur `queue_redraw()`.

```gdscript
func _draw() -> void:
    var vs := get_viewport_rect().size
    _draw_frame(vs)                                # Kartenrahmen mit Minuten-Skala
    _draw_wind(Vector2(vs.x * 0.5, 66.0))          # Windrose
    _draw_minimap(Rect2(vs.x * 0.5 - 70.0, 138.0, 140.0, 135.0))
    ...                                            # Spielerpanels links/rechts unten
    _draw_time(...)                                # Rennuhr
    _draw_leaderboard(...)                         # bei Netzwerk oder mehr als 2 Booten
    _draw_center(vs)                               # Countdown, "LOS!", Sieger
```

### Die Teile

| Funktion | Zeigt |
|---|---|
| `_draw_frame` | weißer Rahmen mit abwechselnd schwarzen Abschnitten (Gradeinteilung) |
| `_draw_wind` | Windrose mit Pfeil (zeigt, wohin der Wind weht), Fiederung (je 5 kn eine), Text „Wind 236° 12 kn“, Meldung „Winddreher rechts/links“ |
| `_draw_minimap` | Kartenbild, Startlinie, Tonnen, **Warngebiete, Tankstellen, Schifffahrtswege mit den Schiffen (live)**, Boote mit Kurs, Zielstrich |
| `_draw_panel(boat, pos)` | Name und Platz, Geschwindigkeit in kn, nächste Tonne und Abstand, Schot-Balken, Gas, Tankuhr, Tiefe/Strom, Warnzeile |
| `_draw_sheet_bar` | Balken der Schot; **grüner Strich = optimal**; Text „zu dicht/zu offen/killt/optimal“ |
| `_draw_engine` | vier Kästchen Gas und Motorzustand |
| `_draw_fuel_gauge` | Tankuhr mit Zeiger, roter Reserve, „E“ und „F“ |
| `_draw_leaderboard` | Rangliste mit Fortschritt („2/3“), Zielzeit, „raus“ |
| `_draw_center` | `waiting`, `countdown`, `racing`, `finished` |

### Die Warnzeile

Die **wichtigste** Meldung gewinnt: Die Warnzeile unten im Panel wird mit einer langen
`if/elif`-Kette gewählt, in dieser Priorität:

```
abgeschleppt › ausgeschieden › Polizei › Sirenen › Schlepper kommt › festgefahren ›
außerhalb des Gebiets › Tanken › Grundberührung › Meldung › im Wind › Windschatten › Böe
```

**Beispiel:** Eine neue Warnung „Gegenstrom!“ ergänzt man mit einer weiteren `elif`-Zeile an
der passenden Stelle:

```gdscript
elif b.current.dot(Vector2(sin(b.heading), cos(b.heading))) < -0.6:
    warn = "Gegenstrom!"
    warn_col = Color(0.15, 0.3, 0.55)
```

### Hilfsfunktionen

`_text`, `_text_centered` und `_big` zeichnen Schrift mit weißem Rand („Halo“), damit sie auf
jeder Karte lesbar bleibt (`draw_string_outline` vor `draw_string`). `_fmt_time(t)` macht
`m:ss.d`.

### Wo die Daten herkommen

Das HUD liest nur: `boat.sheet`, `boat.optimal_sheet()`, `boat.main_status`, `boat.fuel`,
`boat.message`, `boat.hold_kind`, `boat.out` …, `course.targets`, `main.state`,
`main.race_time`, `main.rank_of(b)`. Es **ändert nie etwas**.

## `fullscreen.gd` { #fullscreen-gd }

Ein Autoload (`Fullscreen` in `project.godot`) mit 20 Zeilen:

```gdscript
func _input(event: InputEvent) -> void:
    if not (event is InputEventKey and event.pressed and not event.echo): return
    var alt_enter: bool = event.alt_pressed and event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]
    if event.physical_keycode == KEY_F11 or alt_enter:
        toggle()
        get_viewport().set_input_as_handled()

static func toggle() -> void:
    var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
    DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
```

`process_mode = PROCESS_MODE_ALWAYS` hält ihn aktiv. Weil als Autoload in jeder Szene, geht
`F11` im Menü, in der Lobby und im Rennen. Die Oberfläche passt sich der neuen Fenstergröße an,
weil sie in Pixeln aus `get_viewport_rect().size` zeichnet.

## Minikarte und Vorschau

Beide zeichnen dasselbe Kartenbild (`SeaChart.make_map_image`) und legen Symbole obendrauf. Der
Kartenausschnitt `Level.map_bounds(margin)` umschließt die Bahn **und** alle Warngebiete und
Tankstellen, damit nichts abgeschnitten wird. Die Menü-Vorschau (`menu.gd`) rechnet das Bild
**einmal beim Start** pro Level (240×180 Pixel) und speichert es in `_info[path]["tex"]`.
