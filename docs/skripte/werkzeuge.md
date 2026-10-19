# Werkzeuge und Tests

## Die Tests { #die-tests }

Godot-Skripte, die von `SceneTree` erben, ersetzen die Hauptschleife. So läuft ein Test **ohne
Fenster** (`--headless`) und gibt Ergebnisse auf der Konsole aus. Das Grundmuster:

```gdscript
extends SceneTree

func _initialize() -> void:            # einmal beim Start: Spielobjekte aufbauen
    GameState.level_path = "res://levels/01_mittelgrund.tscn"
    root.add_child(load("res://scenes/main.tscn").instantiate())

func _physics_process(delta: float) -> bool:     # jeder Schritt; true = beenden
    ...
    return t > 30.0
```

`_process` bzw. `_physics_process` dürfen hier einen `bool` zurückgeben: `true` beendet das
Programm.

!!! warning "Dummy-Renderer"
    Im headless-Modus gibt Godot viele Zeilen wie `ERROR: Parameter "m" is null` aus
    (Mesh-Aufrufe an den Dummy-Renderer). Das ist **harmlos**. Filtere mit
    `grep -v "mesh_get_surface\|Parameter"`.

### Headless-Tests (ohne Grafik)

| Test | Prüft | Aufruf |
|---|---|---|
| `tests/level_check.gd` | Alle Bahnen: Startplätze, Linie, Marken in tiefem Wasser und im Gebiet; Tankstellen: Wurzel an Land, Liegeplatz im Wasser | `godot --headless --path . --script res://tests/level_check.gd` |
| `tests/polar_test.gd` | **Segelphysik:** Geschwindigkeit je Kurs, Wende, Motor, Verbrauch, Anlasser | `… polar_test.gd` |
| `tests/hazard_test.gd` | Mine, Polizei, Sirenen, Kollision, Wendeschub | `godot --headless --fixed-fps 60 --path . --script res://tests/hazard_test.gd -- mine` |
| `tests/tug_test.gd` | Schlepper befreit ein festgefahrenes Boot | `… tug_test.gd` |
| `tests/area_test.gd` | Regattagebiet: Boot wird zurückgedrängt, höchstens 30 m hinaus | `… area_test.gd` |
| `tests/paint_test.gd` | Seegrund-Pinsel wirkt auf die Tiefenberechnung | `… paint_test.gd` |
| `tests/tree_test.gd` | Flussregatta: keine Uferbäume im Wasser | `… tree_test.gd` |
| `tests/wind_perf.gd` | Dauer eines vollen Windfeld-Durchlaufs (Leistungstest) | `… wind_perf.gd` |
| `tests/net_test.gd` | Netzwerk: Host und Client in zwei Prozessen | siehe [Netzwerk](netzwerk.md) |
| `tests/ai_race.gd` | Rennen mit Computerbooten, Statistik | siehe [Computergegner](ki.md) |
| `tests/level_dump.gd` | Listet Bausteine mit Position und Tiefe (Hilfe beim Platzieren) | `… level_dump.gd` |

`--fixed-fps 60` lässt die Physik **schneller als in Echtzeit** laufen (so viele Schritte wie
möglich, ohne auf das Fenster zu warten). Das macht lange KI-Rennen in Minuten statt Stunden
möglich.

### Beispiel: `hazard_test.gd`

Das Muster für Szenario-Tests: **Spielzustand direkt setzen, dann warten, was passiert.**

```gdscript
"mine":
    var area: RestrictedArea = _main.level.get_node("Minenfeld")
    var m: Vector2 = area.pos2d() + area._mine_pos[0]
    _place(b, m + Vector2(-20, 0), PI / 2, 3.0)         # Boot 20 m vor eine Mine, Kurs Ost
...
if b.out:
    print("OK: Boot explodiert nach %.1f s" % e)
    return _finish(true)
if e > 15.0:
    return _finish(false)                                # Zeitüberschreitung = Fehler
```

### Tests mit Grafik (Screenshots)

Mit einem Display (oder `xvfb-run` auf dem Server) rendert Godot Bilder:

```bash
xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
    --resolution 1280x720 --script res://tests/feature_shots.gd -- /tmp/bilder
```

| Skript | Bilder |
|---|---|
| `screenshot.gd` | gemeinsame Kamera, Splitscreen, Schlepper |
| `level_shots.gd` | Übersichten von Bahnen aus freier Kamera |
| `feature_shots.gd` | Tiere, Wrack, Minenfeld, Polizei, Sirenen, Segel-Overlay, Explosion |
| `menu_shot.gd` | Menü und Rennstart |
| `showroom.gd`, `closeup.gd`, `ai_shot.gd` | Nahaufnahmen von Modellen, Orten, KI-Rennen |

Der Trick dahinter: Die Kamera des `SplitCameraManager` wird per Skript auf einen Punkt
gesetzt, dann `root.get_texture().get_image().save_png(pfad)`. Man sieht damit, **ohne zu
spielen**, ob ein neuer Baustein richtig aussieht.

## `tools/make_levels.gd` { #tools-make-levels-gd }

Erzeugt oder ergänzt die Beispielbahnen. Aufruf:

```bash
godot --headless --path . --script res://tools/make_levels.gd
```

* `_save(level, path)`: setzt bei allen Kindern `owner = level` und speichert per
  `PackedScene.pack` + `ResourceSaver.save`.
* `_augment(path, extras)`: lädt eine **vorhandene** Szene und ruft `extras` auf. Alle
  Hilfsfunktionen (`_mark`, `_island`, `_dock`, `_life`, …) prüfen mit `_has(l, name)`, ob es
  den Node schon gibt, und überspringen ihn dann. Das Skript ist deshalb **idempotent**:
  Mehrfach ausführen ändert nichts, eigene Änderungen im Editor bleiben erhalten.
* Die Bahnen 4 bis 7 werden mit `_save(_hafen(), …)` etc. **von Grund auf** aus dem Code
  erzeugt, die Bahnen 1 bis 3 nur ergänzt.

!!! note "Bahn im Code oder im Editor?"
    Der Editor ist bequemer für neue Bahnen. Das Skript ist dann nützlich, wenn man
    **viele Bahnen systematisch ändern** will (z. B. überall Tiere einsetzen) oder wenn man eine
    Szene reproduzierbar erzeugen will. Nach dem Ausführen ändern sich die zufälligen
    Resource-IDs in den `.tscn`-Dateien: Das ist normal und harmlos.

## `tools/make_audio.py`

Siehe [Klang](klang.md#tools-make-audio-py).

## Modelle aus Blender { #modelle-aus-blender }

| Skript | Aufgabe |
|---|---|
| `tools/export_dehler.py` | zerlegt das Blender-Modell „Dehler 31“ in vier `.glb`: Rumpf, Großsegel mit Baum, Fock, Pinne mit Ruder. Der Drehpunkt (`ORIGIN`) ist der Root-Knochen des Rigs. |
| `tools/build_tug.py` | baut den stilisierten Schlepper aus Primitiven und exportiert `models/tug.glb` |

Beide laufen **in Blender** (`blender --background --python tools/build_tug.py -- models/tug.glb`).
Wichtig ist die **Koordinatenumrechnung**: Blender hat Z oben und Bug +X, Godot Y oben und
Bug +Z. Die Skripte drehen beim Export so, dass in Godot der Bug nach `+z` zeigt und Backbord
`+x` ist, genau wie `boat.gd` es erwartet.

**Alternative ohne Blender:** `boat.gd` und `tug.gd` haben Ersatzmodelle aus Boxen.

## Zwei Godot-Versionen testen

Der Code ist mit Godot **4.3 und 4.7** getestet. Ein `godot --headless --path . --import`
liest das Projekt ein, danach laufen alle obigen Tests unverändert.
