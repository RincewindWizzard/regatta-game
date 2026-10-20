# Alle Skripte im Überblick

Jedes Skript des Projekts mit einem Satz zur Aufgabe und dem Kapitel, das es genau erklärt.
„Zeilen“ sind ungefähre Größen, damit man den Aufwand einschätzen kann.

## Kern: Rennen, Boot, Welt

| Skript | Zeilen | Aufgabe | Kapitel |
|---|---|---|---|
| `scripts/main.gd` | 450 | Dirigent eines Rennens: baut alles auf, Countdown, Kollisionen, Schlepper, Tanken, Gefahren, Netzwerk-Schnappschüsse | [Rennablauf](rennen.md#main-gd) |
| `scripts/boat.gd` | 950 | Segelphysik, Motor, Grund, Wendeschub, Kollisionsfolgen, Haltezustände, Overlay, Optik, Klang | [Das Boot](boot.md) |
| `scripts/course.gd` | 85 | Bahnlogik: Startlinie, Marken, Ziel, Rang | [Rennablauf](rennen.md#course-gd) |
| `scripts/game_state.gd` | 125 | Menü-Auswahl und Wetterstufen als `static var`s, Bootliste | [Menü und Lobby](menue.md#game-state-gd) |
| `scripts/sea_chart.gd` | 420 | Tiefenraster, Karten-Shader, Zeichenhilfen | [Seekarte und Tiefen](seekarte.md) |
| `scripts/wind_field.gd` | 125 | Wind, Böen, Dreher, Windschatten von Booten und Land | [Wind und Strömung](wind.md#wind-field-gd) |
| `scripts/wind_visuals.gd` | 110 | Windstriche (MultiMesh), Böen-Textur | [Wind und Strömung](wind.md#wind-visuals-gd) |
| `scripts/currents.gd` | 30 | Summe aller Strömungen an einem Punkt | [Wind und Strömung](wind.md#currents-gd) |
| `scripts/kvr.gd` | 230 | Vorfahrtsregeln (KVR) als Einblendung bei Annäherung zweier Boote | [Rennablauf](rennen.md#kvr-gd) |
| `scripts/boat_track.gd` | 55 | Gestrichelte Kielwasserlinie hinter dem Boot | [Das Boot](boot.md#boat-track-gd) |
| `scripts/tug.gd` | 310 | Schlepper (Zustandsmaschine) | [Schlepper](schlepper.md) |

## Eingabe und Computergegner

| Skript | Aufgabe | Kapitel |
|---|---|---|
| `scripts/player_input.gd` | Tastatur und Controller → `steer`, `sheet_rate`, Gas, Start | [Eingabe](eingabe.md) |
| `scripts/ai_input.gd` | Computergegner (erbt von `PlayerInput`) | [Computergegner](ki.md) |
| `scripts/net/net_input.gd` | Eingaben eines fernen Spielers beim Host | [Netzwerk](netzwerk.md#net-input-gd) |

## Oberfläche

| Skript | Aufgabe | Kapitel |
|---|---|---|
| `scripts/hud.gd` | Anzeige im Rennen (Rahmen, Windrose, Minikarte, Panels) | [Kamera und Anzeige](kamera-hud.md#hud-gd) |
| `scripts/split_camera.gd` | Eine oder zwei Kameras, dynamischer Splitscreen | [Kamera und Anzeige](kamera-hud.md#split-camera-gd) |
| `scripts/menu.gd` | Startmenü mit Kartenvorschau | [Menü und Lobby](menue.md#menu-gd) |
| `scripts/lobby.gd` | Mehrspieler-Lobby | [Menü und Lobby](menue.md#lobby-gd) |
| `scripts/ui_style.gd` | Seekarten-Look für Menü und Lobby | [Menü und Lobby](menue.md#ui-style-gd) |
| `scripts/fullscreen.gd` | Autoload: `F11` / `Alt+Enter` | [Kamera und Anzeige](kamera-hud.md#fullscreen-gd) |

## Level-Bausteine (`scripts/level/`)

| Skript | Baustein | Kapitel |
|---|---|---|
| `level.gd` | Wurzel einer Bahn, Tiefenmodell, Seegrund malen | [Level und Bausteine](level.md#level-gd) |
| `start_line.gd` | Start- und Ziellinie | [Level](level.md#start-line-gd) |
| `course_mark.gd` | Bahnmarke (gelbe Tonne) | [Level](level.md#course-mark-gd) |
| `shoal_area.gd` | Untiefe, Insel, See | [Level](level.md#shoal-area-gd) |
| `sea_mark.gd` | Seezeichen (Kardinal-, Lateral-, Gefahrentonnen) | [Level](level.md#sea-mark-gd) |
| `mole.gd` | Felsmole | [Level](level.md#mole-gd) |
| `lighthouse.gd` | Leuchtturm | [Level](level.md#lighthouse-gd) |
| `chart_rose.gd` | Kompassrose | [Level](level.md#chart-rose-gd) |
| `current_area.gd` | Strömung im Rechteck | [Wind und Strömung](wind.md#current-area-gd) |
| `river_channel.gd` | Fluss (`Path3D`) | [Wind und Strömung](wind.md#river-channel-gd) |
| `fuel_dock.gd` | Tankstelle | [Level](level.md#fuel-dock-gd) |
| `deco.gd` | Bäume, Häuser, Felsen, Türme | [Level](level.md#deco-gd) |
| `sea_life.gd` | Tümmler, Wal, Möwen, Seehunde, Wrack | [Gefahren, Tiere, Effekte](gefahren.md#sea-life-gd) |
| `restricted_area.gd` | Minenfeld, Polizei-Sperrgebiet | [Gefahren](gefahren.md#restricted-area-gd) |
| `shipping_lane.gd` | Schifffahrtsweg mit Berufsschiffen | [Gefahren](gefahren.md#shipping-lane-gd) |
| `siren_island.gd` | Sirenen-Insel | [Gefahren](gefahren.md#siren-island-gd) |
| `hazard_visuals.gd` | Polizeiboot, Mine, Noten | [Gefahren](gefahren.md#hazard-visuals-gd) |

## Hilfen

| Skript | Aufgabe | Kapitel |
|---|---|---|
| `scripts/model_style.gd` | Tusche-Kontur, Umfärben, Schatten aus | [Gefahren, Tiere, Effekte](gefahren.md#model-style-gd) |
| `scripts/fx.gd` | Explosion, Wellenring | [Gefahren](gefahren.md#fx-gd) |
| `scripts/sfx.gd` | Soundeffekte, Schleifen, Musik | [Klang](klang.md) |
| `scripts/net/net.gd` | Autoload: Netzwerk | [Netzwerk](netzwerk.md) |

## Editor und Werkzeuge

| Datei | Aufgabe | Kapitel |
|---|---|---|
| `addons/regatta_editor/plugin.gd` | Seegrund-Pinsel, „+ Baustein“ | [Level-Editor-Plugin](editor.md) |
| `tools/make_levels.gd` | erzeugt/ergänzt die Beispielbahnen | [Werkzeuge und Tests](werkzeuge.md#tools-make-levels-gd) |
| `tools/make_audio.py` | erzeugt alle Klänge | [Klang](klang.md#tools-make-audio-py) |
| `tools/export_dehler.py`, `tools/build_tug.py` | Blender-Skripte für die Modelle | [Werkzeuge und Tests](werkzeuge.md#modelle-aus-blender) |
| `tests/*.gd` | Headless-Tests und Screenshot-Skripte | [Werkzeuge und Tests](werkzeuge.md#die-tests) |

!!! tip "Lesereihenfolge für Nachbauer"
    1. [Seekarte und Tiefen](seekarte.md) – die Grundlage von allem.
    2. [Das Boot](boot.md) – das Herz des Spiels.
    3. [Wind und Strömung](wind.md), dann [Level und Bausteine](level.md).
    4. [Rennablauf](rennen.md), [Eingabe](eingabe.md), [Computergegner](ki.md).
    5. Der Rest nach Interesse.
