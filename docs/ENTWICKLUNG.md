# Regatta – Entwicklerdoku

Alles zum Bauen eigener Bahnen und zum Aufbau des Codes. Die Spielanleitung steht in der
[README](../README.md).

**Voraussetzung:** Godot 4.3 oder neuer. Projekt importieren (`project.godot`), F5 startet.

## Computergegner (Technik)

Die KI (`scripts/ai_input.gd`) segelt mit denselben Eingaben wie ein Mensch (Pinne, Schot,
Gas) und hat keine Physik-Vorteile. Sie plant ihren Weg über die Seekarte (Godots
`AStarGrid2D` um Untiefen, Inseln, Molen und Stege herum), bewertet mögliche Kurse nach dem
Polardiagramm inklusive Strömung, wendet durch Lenken, wirft auf langen Kreuzschlägen oder
gegen den Strom den Motor an (je nach Stärke) und fährt zum Tanken, wenn eine Tankstelle auf
dem Weg liegt. Vergleichstest aller Stufen auf allen Bahnen:
`sh tests/ai_compare.sh <godot> <ausgabeordner>`.

## Gefahrengebiete (Technik)

`RestrictedArea` und `SirenIsland` haben `update_boat(boat, delta)`, das `main.gd` jeden
Physikschritt für jedes Boot aufruft (nur Host bzw. lokal). Sie lösen `Boat.explode()`
(Seemine, Boot ist `out`) oder `Boat.start_hold(kind)` aus (1 Polizei, 2 Sirenen, Dauer in
`Boat.HOLD_TIMES`, danach `IMMUNE_TIME` Schonfrist). Beide Zustände laufen im Netzwerk-
Schnappschuss mit (`out`, `hold_kind`, `hold_time`); Polizeiboot und Noten zeichnet jedes
Boot selbst aus diesem Zustand. Die Computergegner bekommen die Gebiete über
`Level.danger_circles()` als Sperrzonen. Tests: `tests/hazard_test.gd`.

Der Windschatten von Land (`WindField._land_shadow`) tastet gegen den Wind über die
Seekarte (bis 170 m, bis 88 % Windverlust im direkten Lee).

## Mehrspieler (Technik)

Der Host rechnet die Physik, die anderen schicken nur ihre Eingaben und erhalten 20× pro
Sekunde den Zustand aller Boote (interpoliert). ENet auf UDP-Port 24850, LAN-Suche per
UDP-Broadcast auf Port 24851. Computerboote werden beim Host gerechnet.

## Eigene Bahnen bauen (Level-Editor)

Jede Bahn ist eine ganz normale Godot-Szene in `levels/`. Alles, was dort liegt, erscheint
automatisch im Startmenü. Das Plugin **Regatta Level-Editor** ist im Projekt bereits aktiv.

### Neue Bahn anlegen
1. Im Dateisystem eine vorhandene Bahn duplizieren (Rechtsklick → *Duplizieren…*) und
   umbenennen, z. B. `levels/04_meine_bahn.tscn`. (Oder: neue Szene, Wurzel-Node vom Typ
   **Level** wählen.)
2. Szene öffnen. Am besten von oben schauen: im 3D-Viewport **Num 7** (Draufsicht),
   Mausrad zoomt. Die Seekarte wird live im Editor gezeichnet.
3. Im Inspector des **Level**-Nodes: Name, Beschreibung, Wind (Richtung, Stärke, Dreher,
   Böen) und Grundeigenschaften des Seegrunds (Tiefe, Variation, Zufallswert, Küsten).

### Bausteine
Oben in der 3D-Werkzeugleiste gibt es **„+ Baustein“** (sichtbar, wenn das Level ausgewählt
ist). Eingefügte Bausteine landen in der Mitte der Ansicht. Verschieben/Drehen/Skalieren
mit den normalen Godot-Gizmos (W/E/R).

| Baustein | Bedeutung |
|---|---|
| **StartLine** | Start- und Ziellinie. Der Magenta-Pfeil zeigt die Startrichtung, das Ziel ist dieselbe Linie zurück. Breite im Inspector. Drehen erlaubt. |
| **CourseMark** | Tonne. Die **Reihenfolge im Szenenbaum** ist die Rundungsreihenfolge (im Editor als „1.“, „2.“ … beschriftet). Zum Umsortieren einfach im Baum ziehen. |
| **ShoalArea** | Untiefe oder Insel (Art im Inspector). Radius im Inspector; mit Skalieren in X/Z und Drehen werden Ellipsen daraus. Inseln können einen Leuchtturm haben. |
| **SeaMark** | Seezeichen: Kardinaltonne Nord/Ost/Süd/West, Einzelgefahr, Fahrwasser rot/grün, Ansteuerung. Boote prallen ab. |
| **Mole** | Felsmole (Länge, Breite) mit Molenfeuer rot/grün/weiß am Kopf. Für Boote Land. |
| **Lighthouse** | Leuchtturm auf Felsklippe mit drehendem Lichtkegel, verschiedene Farbschemata. |
| **ChartRose** | Kompassrose als Dekoration. |
| **CurrentArea** (Strömung) | Strömungsfeld: Stärke in kn, Länge/Breite, optional Gezeitenperiode (Strom kentert). Fließt in Pfeilrichtung (lokal −Z), mit Drehen ausrichten. |
| **RiverChannel** (Flusslauf) | Ein Godot-`Path3D`: Punkte mit dem Pfad-Werkzeug setzen/ziehen. Gräbt einen Fluss ins Land, Breite (+ `width_curve`), Tiefe, Fließgeschwindigkeit vom ersten zum letzten Punkt, Uferbäume, Name. Schmal = schneller. |
| **ShoalArea „See“** | gräbt einen See ins Land (für Binnenreviere). |
| **SeaLife** (Tiere, Wrack) | Dekoration: Tümmler (springen), Wal (bläst, taucht ab), Möwen, Seehunde. `count` Tiere im Umkreis `range_m`. Art **Wrack**: gestrandetes Schiff, für Boote fest (`solid`), die KI umfährt es. |
| **RestrictedArea** (Sperrgebiet) | Art **Minenfeld**: Boot, das eine Mine berührt, explodiert und scheidet aus. Art **Polizei**: Boote im Gebiet werden angehalten und durchsucht. Radius und Minenzahl im Inspector. |
| **SirenIsland** (Sirenen-Insel) | Insel (wie ShoalArea), deren Gesang Boote bis `song_range` vom Ufer festhält. |
| **FuelDock** (Tankstelle) | Steg mit Zapfsäule. Wurzel an Land setzen, Pfeil (lokal −Z) zeigt ins Wasser; der Liegeplatz liegt am Stegkopf. |

Inseln (ShoalArea, Art „Insel“) haben im Inspector unter *Insel-Ausstattung* Bäume, Häuser
und Uferfelsen. Tipp: Untiefe auswählen und **„+ Baustein → Kardinaltonnen um ausgewählte
Untiefe“** – dann stehen die vier Tonnen automatisch richtig. Die Grenze des Regattagebiets
stellst du am Level-Node unter *Regattagebiet → area_margin* ein, die Tankmenge unter
*Motor → fuel_liters*.

**Binnenrevier:** Am Level-Node *Seegrund → inland* einschalten – dann ist alles Land, und
Seen (ShoalArea „See“) und Flüsse (RiverChannel) graben das Wasser hinein. Beispiel:
`levels/07_flussregatta.tscn`.

### Seegrund malen
Level-Node auswählen → in der Werkzeugleiste **Seegrund:** einen Pinsel wählen und mit der
linken Maustaste über die Karte malen. Die Karte zeigt die Änderung sofort.

| Pinsel | Wirkung |
|---|---|
| Flacher / Tiefer | Seegrund anheben / absenken (für Rinnen, Bänke, Fahrwasser) |
| Land | stark anheben – wird zu Land mit Uferlinie |
| Glätten | Kanten weich machen |
| Radierer | gemalte Änderungen zurücknehmen |
| Aus | normale Auswahl, Pinsel inaktiv |

Größe und Stärke stellst du daneben ein. Jeder Strich lässt sich mit **Strg+Z** rückgängig
machen; „Gemalten Grund löschen“ setzt alles zurück. Die Malerei wird in der Szene gespeichert.

**Spiellogik = Karte:** Tiefgang 1 m. Was auf der Karte flacher ist, ist auch im Spiel Grund.

## Grafik

- Boote: Dehler 31 „Schruvtrekker“ (Blender-Modell, mit Claude erstellt); `tools/export_dehler.py` zerlegt sie in
  Rumpf, Großsegel+Baum, Fock und Pinne+Ruder (`models/dehler31_*.glb`). Rumpf in Spielerfarbe.
- Schlepper: stilisierter Hafenschlepper aus `tools/build_tug.py` (`models/tug.glb`).
- Alle Modelle haben eine dünne Tusche-Kontur (`model_style.gd`), passend zur Seekarte.

## Sound & Musik

Effekte und Soundtrack liegen als OGG in `audio/`, gerendert mit `tools/make_audio.py`
(numpy/scipy/soundfile). Der Soundtrack ist ein Renn-Shanty im 6/8-Takt (d-Moll, 96 bpm):
galoppierender Bass, Akkordeon, Tin Whistle, Bodhrán mit Wirbeln, Streicher-Tremolo im
B-Teil und leise Brandung. Jede Datei kann durch eine echte Aufnahme gleichen Namens ersetzt
werden. Lautstärken: `MUSIC_DB`, `SFX_DB`, `LOOP_DB` in `scripts/sfx.gd`.

## Aufbau

| Datei | Inhalt |
|---|---|
| `scenes/menu.tscn` + `scripts/menu.gd` | Startmenü mit Levelauswahl und Wettereinstellungen |
| `scenes/main.tscn` + `scripts/main.gd` | Rennen: lädt das Level, Countdown, Ablauf, Kollisionen, Schlepper; Host-/Client-Logik |
| `scenes/lobby.tscn` + `scripts/lobby.gd` | Mehrspieler-Lobby |
| `scripts/net/net.gd` | Netzwerk-Autoload: Host/Beitreten, LAN-Suche, Eingaben, Schnappschüsse |
| `scripts/net/net_input.gd` | Eingaben ferngesteuerter Boote beim Host |
| `scripts/ai_input.gd` | Computergegner: Wegplanung, Kurswahl, Wenden durch Lenken, Trimm, Motor, Tanken |
| `scripts/ui_style.gd` | gemeinsamer Seekarten-Look für Menü und Lobby |
| `scripts/level/*.gd` | Level-Bausteine (Level, StartLine, CourseMark, ShoalArea, SeaMark, Mole, Lighthouse, ChartRose, CurrentArea, RiverChannel, FuelDock, Deco) |
| `scripts/currents.gd` | Summe aller Strömungen an einem Punkt |
| `addons/regatta_editor/` | Editor-Plugin: Seegrund-Pinsel und „+ Baustein“ |
| `scripts/game_state.gd` | Menü-Auswahl, Windstufen, Levelliste |
| `scripts/boat.gd` | Segelphysik, Motor/Tank, Strömung, Wendeschub, Kollisionsstrafe, Haltezustände, Segel-Overlay, Grund, Optik, Klang |
| `scripts/fx.gd` | Effekte: Wellenring, Explosion |
| `scripts/sea_chart.gd` | Kartendarstellung (Shader, Lotungen) und Tiefenabfrage |
| `scripts/course.gd` | Bahnlogik (Start, Tonnen, Ziel) |
| `scripts/wind_field.gd` / `wind_visuals.gd` | Wind (Dreher, Böen, Windschatten) und seine Darstellung |
| `scripts/tug.gd` | Schlepper |
| `scripts/split_camera.gd` | gemeinsame Kamera ↔ vertikaler Splitscreen |
| `scripts/hud.gd` | Kartenrahmen, Windrose, Minikarte, Spielerpanels mit Schot, Gas und Tankuhr |
| `tools/` | Audio-Rendering, Modell-Export (Blender), Beispiel-Level erzeugen |
| `tests/` | Headless-Tests (Physik, Schlepper, Seegrund-Malen, Level-Prüfung, Regattagebiet, Netzwerk) und Screenshot-Skripte |
