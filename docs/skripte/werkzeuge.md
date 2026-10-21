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
| `tests/depth_png.gd` | schreibt die Tiefenkarte eines Levels als PNG (Marken gelb, Start rot, Ziel grün, Tankstellen orange): schnelle Kontrolle beim Bauen eines Levels |
| `tests/perf_test.gd` | misst die CPU-Zeit je Bild mit vier Computerbooten (`-- res://levels/05_lotsenrinne.tscn`) |
| `tests/hazard_test.gd` | Mine, Polizei, Sirenen, Berufsschiff (`schiff`), Kollision, Polizei rammen (`rammen`), Wendeschub, KVR, Debug | `godot --headless --fixed-fps 60 --path . --script res://tests/hazard_test.gd -- mine` |
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

### Tests mit Grafik (Screenshots) { #screenshots }

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
| `map_shots.gd` | **die ganze Karte jeder Bahn** senkrecht von oben (orthogonale Kamera), auf das Regattagebiet zugeschnitten; speist [Die Karten](../spielen/karten.md) |
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
| `tools/chart_to_depth.py` | wandelt eine Seekarte (Bild) in den Seegrund eines Levels um (Land/Wasser nach Farbe, nur zu schmale Wasserwege verbreitert, Küstenabstand → Tiefe); Parameter in `tools/kiel_chart.json`, Ergebnis `levels/data/kiel_foerde_tiefe.png` |
| `tools/build_ships.py` | baut die drei Berufsschiffe (Loft-Rumpf, Aufbauten, Ladung, Schaumstreifen) und schreibt `models/ship_*.glb` sowie die Rumpfkontur `models/ship_hulls.json` |

Die Skripte laufen **in Blender** (`blender --background --python tools/build_tug.py -- models/tug.glb`, `blender --background --python tools/build_ships.py -- models`). Ohne Blender-Installation geht es auch mit dem Python-Modul: `pip install bpy` und dann `python tools/build_ships.py models`.
Wichtig ist die **Koordinatenumrechnung**: Blender hat Z oben und Bug +X, Godot Y oben und
Bug +Z. Die Skripte drehen beim Export so, dass in Godot der Bug nach `+z` zeigt und Backbord
`+x` ist, genau wie `boat.gd` es erwartet.

**Alternative ohne Blender:** `boat.gd` und `tug.gd` haben Ersatzmodelle aus Boxen.

## Build und Release { #build-und-release }

Zwei GitHub-Actions-Workflows in `.github/workflows/` bauen und veröffentlichen das Projekt:

| Datei | Aufgabe |
|---|---|
| `docs.yml` | baut die Dokumentation mit MkDocs und veröffentlicht sie auf GitHub Pages; holt dabei die Dateien des neuesten Releases nach `/downloads` |
| `release.yml` | exportiert das Spiel für Windows, Linux und macOS, legt ein GitHub Release an und stößt `docs.yml` an |

**`release.yml` im Detail.** Ausgelöst wird er von Hand (*Actions → Spiel bauen und
veröffentlichen → Run workflow*, mit Versionsnummer wie `v1.2.0`) oder durch das Pushen eines
Tags `v*`. Der Job `export` lädt Godot **4.7.2** und die passenden Export-Vorlagen (zusammen
gecacht, die Version steht in `GODOT_VERSION`), importiert das Projekt, führt `level_check.gd`
aus und exportiert mit den Presets aus `export_presets.cfg` die drei Plattformen. Daraus werden
`Regatta-windows.zip`, `Regatta-linux.zip` und `Regatta-macos.zip`. Der Job `release` hängt sie
an ein GitHub Release (Namen **ohne** Versionsnummer, damit der Link
`…/releases/latest/download/Regatta-windows.zip` immer funktioniert). Der Job `docs` startet
danach `docs.yml` auf dem Hauptzweig; so liegen die Downloads auch auf der Seite
[Download](../spielen/download.md).

Einmalig im Repository einzustellen: *Settings → Actions → General → Workflow permissions →
Read and write permissions*, und *Settings → Pages → Source → GitHub Actions*.

**Export-Presets.** `export_presets.cfg` enthält drei Presets: Windows (x86_64, Programm und Daten
in einer `.exe`), Linux (x86_64, eine Datei) und macOS (universal, nicht signiert, als Zip mit
`.app`). `exclude_filter` hält Dokumentation, Tests und Werkzeuge aus dem Spiel heraus.

## Zwei Godot-Versionen testen

Entwickelt und getestet wird mit Godot **4.7.2** (das Projekt ist auf 4.7 eingestellt); der Code läuft auch noch mit 4.3. Ein `godot --headless --path . --import`
liest das Projekt ein, danach laufen alle obigen Tests unverändert.
