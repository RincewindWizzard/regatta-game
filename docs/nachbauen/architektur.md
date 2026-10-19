# Architektur im Überblick

Dieses Kapitel zeigt das Gesamtbild. Die Details jedes Skripts stehen im Abschnitt
[Die Skripte erklärt](../skripte/index.md).

## Die drei Szenen und der Spielfluss

```
        ┌──────────────┐   „Leinen los!“    ┌──────────────┐
        │  menu.tscn   │ ─────────────────► │  main.tscn   │
        │  menu.gd     │ ◄───── Esc ─────── │  main.gd     │
        └──────┬───────┘                    └──────▲───────┘
               │ „Mehrspieler“                     │ Host startet Rennen
               ▼                                   │ (RPC an alle)
        ┌──────────────┐ ─────────────────────────┘
        │ lobby.tscn   │
        │ lobby.gd     │
        └──────────────┘

   Autoload „Net“ (net.gd) lebt in allen drei Szenen weiter.
   `GameState` (static vars) trägt die Auswahl von einer Szene in die nächste.
```

| Szene | Skript | Aufgabe |
|---|---|---|
| `scenes/menu.tscn` | `scripts/menu.gd` | Bahn, Besetzung, Wetter wählen; Kartenvorschau |
| `scenes/lobby.tscn` | `scripts/lobby.gd` | Netzwerk: Spiel eröffnen, beitreten, Mitsegler, Einstellungen |
| `scenes/main.tscn` | `scripts/main.gd` | ein Rennen: baut alles auf und steuert den Ablauf |

## Was in `main.gd` zur Laufzeit entsteht

`main.gd` ist der **Dirigent**. Beim Start (`_ready`) erzeugt es nacheinander diese Objekte:

```
Main
├─ Level            ← aus der gewählten Bahn-Szene geladen (Tonnen, Inseln, Strömungen, …)
├─ WindField        ← Wind, Böen, Windschatten (Boote und Land)
├─ SeaChart         ← die Karte als Shader + Tiefenraster
├─ Course           ← Bahnlogik: wer hat welche Tonne gerundet
├─ WindVisuals      ← Windstriche, Böen-Schraffur
├─ Boat × 1–4       ← Boote (Mensch, Computer oder fernes Boot)
│    └─ BoatTrack, Audio-Player, Modell, Overlay …
├─ SplitCameraManager ← eine oder zwei Kameras
├─ CanvasLayer → RaceHud ← Anzeige
├─ Tug (bei Bedarf) ← Schlepper
└─ Audio: Windrauschen, Musik (Sfx)
```

Danach läuft die **Zustandsmaschine** des Rennens:

```
waiting ──► countdown ──► racing ──► finished
(Netzwerk:                (Boote      (erstes Boot im Ziel
 auf Mitsegler warten)     fahren)     bzw. alle ausgeschieden)
```

## Datenfluss pro Physikschritt (60× pro Sekunde)

```
 PlayerInput / AIInput / NetInput
          │  steer, sheet_rate, gas_up_pressed, gas_down_pressed
          ▼
      Boat._physics_process ──────────────────────────────┐
          │ liest: WindField.get_wind(), Currents.at(),   │
          │        SeaChart.depth_at()                    │
          │ schreibt: Position, Geschwindigkeit, Krängung │
          ▼                                               │
   Course.update_progress(boat, alt, neu)                 │
          │  Signale: target_reached / boat_finished      │
          ▼                                               │
      main.gd  ◄── Hazards.update_boat() (Minen, Polizei, Sirenen)
          │    ◄── _resolve_collisions() (Boot↔Boot, Tonnen)
          │    ◄── _call_tugs(), Tanken
          ▼
   Net.send_snapshot() (nur Host im Netzwerk, 20 Hz)
```

Die **Optik** (Segel schwenken, Boot kippen, Töne, Kamera, HUD) hängt an `_process` und liest
nur den Zustand, den die Physik hinterlassen hat.

## Die wichtigsten Datenstrukturen

| Was | Wo | Inhalt |
|---|---|---|
| Tiefenraster | `SeaChart._depth` (static) | 448×448 Kommazahlen: Wassertiefe in Metern, negativ = Land |
| Strömungsquellen | `Currents._sources` (static) | Liste von Nodes mit `current_at(p)` |
| Menü-Auswahl | `GameState` (static vars) | Bahn, Besetzung, Windstufe, KI-Stärke, Treibstoff |
| Boote einer Runde | `GameState.slots()` | Liste von Dictionaries `{peer, local, name, color, bot, ai}` |
| Bahn | `Course.targets` | Startlinie, Marken …, Ziel als Dictionaries `{type, name, pos}` |
| Snapshot | `PackedFloat32Array` | Zustand aller Boote, 30 Zahlen je Boot |

## Schichtenmodell

```
 Oberfläche   menu.gd · lobby.gd · hud.gd · ui_style.gd · split_camera.gd
 ───────────────────────────────────────────────────────────────────────
 Ablauf       main.gd · course.gd · game_state.gd · net/net.gd
 ───────────────────────────────────────────────────────────────────────
 Simulation   boat.gd · wind_field.gd · currents.gd · tug.gd · ai_input.gd
              player_input.gd · net/net_input.gd
 ───────────────────────────────────────────────────────────────────────
 Welt         level/*.gd (Bausteine) · sea_chart.gd (Tiefen + Karte)
 ───────────────────────────────────────────────────────────────────────
 Hilfen       model_style.gd · fx.gd · sfx.gd · level/deco.gd · boat_track.gd
```

Faustregel: **Eine Schicht kennt nur Schichten unter sich.** Das `Boat` weiß nichts vom HUD;
das HUD liest dagegen `Boat`-Variablen (`sheet`, `fuel`, `message`). Ausnahmen sind die
Schnittstellen `Boat.show_message()` und `Sfx.play()`, die bewusst von überall aufrufbar sind.

## Warum diese Architektur?

* **Die Karte ist die Spiellogik.** Ein einziges Tiefenraster beantwortet: Wo ist Land? Wo
  läuft man auf Grund? Wo kann der Schlepper starten? Wo schattet Land den Wind ab? Wohin
  kann die KI planen? Dasselbe Raster färbt die Karte im Shader ein.
* **Level sind Daten.** Eine Bahn ist eine Szene aus Bausteinen, die sich selbst zeichnen und
  der Spiellogik über kleine Methoden Auskunft geben (`depth_profile`, `current_at`,
  `collision_points`, `update_boat`). Neue Bausteine fügen sich ein, ohne `main.gd` zu ändern:
  [Level und Bausteine](../skripte/level.md).
* **Host-autoritativ im Netz.** Nur der Host simuliert. Clients schicken Eingaben und zeigen
  Schnappschüsse. So gibt es keine Abweichungen: [Netzwerk](../skripte/netzwerk.md).
* **KI = Eingabegerät.** Der Computergegner erbt von `PlayerInput` und füllt dieselben
  Felder wie ein Mensch. Das Boot merkt keinen Unterschied: [Computergegner](../skripte/ki.md).

## Ordnerstruktur

```
regatta-game/
├── project.godot          Projekteinstellungen, Autoloads
├── scenes/                menu.tscn, lobby.tscn, main.tscn (je nur ein Wurzel-Node)
├── scripts/
│   ├── main.gd boat.gd course.gd wind_field.gd currents.gd game_state.gd
│   ├── ai_input.gd player_input.gd hud.gd split_camera.gd sea_chart.gd
│   ├── menu.gd lobby.gd ui_style.gd sfx.gd fx.gd tug.gd boat_track.gd
│   ├── model_style.gd wind_visuals.gd fullscreen.gd
│   ├── level/             Bausteine der Bahnen (@tool-Skripte)
│   └── net/               net.gd (Autoload), net_input.gd
├── levels/                7 Bahnen als Szenen
├── models/                Segelboot (4 Teile) und Schlepper als .glb
├── audio/                 .ogg-Dateien (erzeugt von tools/make_audio.py)
├── addons/regatta_editor/ Editor-Plugin: Seegrund-Pinsel, „+ Baustein“
├── tools/                 Audio, Modell-Export (Blender), Level-Generator
├── tests/                 Headless-Tests und Screenshot-Skripte
└── docs/                  diese Dokumentation (MkDocs)
```

Weiter: [Projekt aufsetzen](projekt.md) oder direkt zum
[Fahrplan zum Nachbau](fahrplan.md).
