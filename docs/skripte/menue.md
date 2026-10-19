# Menü und Lobby

Vier Dateien: `game_state.gd` (Daten), `menu.gd` (Startmenü), `lobby.gd` (Netzwerk-Lobby),
`ui_style.gd` (gemeinsamer Look). Zusammen sind es rund 1000 Zeilen, aber wenig Logik: Das
meiste ist Oberflächenaufbau.

## `game_state.gd` { #game-state-gd }

`class_name GameState`, `extends RefCounted`, 125 Zeilen. Es wird **nie instanziiert**:
Alles sind `const`-Listen und `static var`s. Weil `static var`s einen **Szenenwechsel
überleben**, ist das der einfachste Weg, die Menü-Auswahl ins Rennen mitzunehmen.

```gdscript
static var level_path := ""
static var crew_choice := 0         # Index in CREW_OPTIONS
static var ai_level := 1            # 0 leicht, 1 mittel, 2 schwer
static var wind_choice := 0         # Index in WIND_OPTIONS
static var gust_choice := 0
static var fuel_choice := 0
static var net_mode := ""           # "" lokal, "host" oder "client"
static var net_cfg := {}            # Konfiguration, die der Host verteilt
static var my_peer := 1
```

### Auswahllisten

Jede Einstellung ist eine Liste von **Name + Wert(en)**, der Menüknopf blättert mit
`wrapi(index + d, 0, liste.size())` hindurch:

```gdscript
const WIND_OPTIONS := [["Wie im Level", 0.0], ["Leicht (3 Bft)", 4.2],
                       ["Mittel (4 Bft)", 6.5], ["Frisch (5 Bft)", 9.0]]
const GUST_OPTIONS := [["Wie im Level", -1.0, -1.0], ["Ruhig", 0.25, 8.0],
                       ["Normal", 0.9, 17.0], ["Böig & drehend", 1.4, 28.0]]
const CREW_OPTIONS := [["2 Spieler", 2, 0], ["1 Spieler gegen 1 Computer", 1, 1],
                       ["1 Spieler gegen 3 Computer", 1, 3], ["2 Spieler gegen 2 Computer", 2, 2],
                       ["Zuschauen: 4 Computer", 0, 4]]      # [Name, Menschen, Computer]
const FUEL_OPTIONS := [["Wie im Level", -1.0], ["Kein Motor", 0.0], ["Wenig (4 l)", 4.0],
                       ["Halber Tank (10 l)", 10.0], ["Voller Tank (20 l)", 20.0]]
```

**Beispiel:** Eine neue Windstufe „Sturm (7 Bft)“ ist **eine Zeile** in `WIND_OPTIONS`:
`["Sturm (7 Bft)", 14.0]`. Das Menü zeigt sie sofort an.

### Wichtige Funktionen

| Funktion | Aufgabe |
|---|---|
| `slots()` | Boote dieser Runde als Liste von Dictionaries `{peer, local, name, color, bot, ai}`. Lokal aus `CREW_OPTIONS`, im Netzwerk aus `net_cfg["slots"]` |
| `bot_slot(i, level, color)` | ein Computer-Boot („Fiete (KI)“ …) |
| `apply_net_config(cfg, my_id, mode)` | übernimmt die vom Host verteilte Konfiguration |
| `start_fuel(level)` | Startfüllung: Menüwahl oder `level.fuel_liters` |
| `list_levels()` | alle `.tscn` in `res://levels/` (auch im exportierten Spiel, dort `.remap` entfernt) |
| `current_level_path()` | gewählte Bahn oder die erste |
| `apply_wind(level, wind)` | Level-Wind **und** Menüüberschreibung in das `WindField`; im Netzwerk die Seeds |

!!! note "Warum `.remap`?"
    Im exportierten Spiel werden Szenen zu `…tscn.remap`-Dateien. `list_levels()` schneidet das
    Suffix ab, sonst fände das Menü im Export keine Bahnen.

## `menu.gd` { #menu-gd }

`extends Control`, 460 Zeilen, Szene `scenes/menu.tscn`.

### `_ready()`

1. `Sfx.ensure(...)` (Musik beginnt), Controller melden (`_on_joy`).
2. **Alle Level einlesen**: `_read_level(path)` instanziiert jede Bahn **kurz** (unsichtbar im
   Baum), rechnet die Tiefen in 160×160, daraus ein Vorschaubild, und liest Marken, Startlinie,
   Wind, Treibstoff, Tankstellen, Warngebiete. Das Ergebnis liegt in `_info[path]`.
3. `_build_ui()` baut linke Spalte (Bahnknöpfe, Auswahl für Besetzung, Stärke, Wind, Böen,
   Treibstoff, „Leinen los!“, „Mehrspieler“) und die rechte Vorschau.

### Auswahlknöpfe

Jeder Knopf mit „◀ Wert ▶“ ruft eine Funktion wie `_cycle_wind(d)` auf, die den Index in
`GameState` ändert und `_update_labels()` aufruft. `_update_labels` schreibt **alle**
Beschriftungen neu (Besetzung, Stärke, Wind, …) und die Zeile mit den Kerndaten der Bahn
(„Bahnlänge 0,66 sm · 3 Tonnen · Wind aus 225°, 12 kn · Tank 6 l, 1 Tankstelle“).

### Vorschau (`_draw_preview`)

Zeichnet auf einem `Control` das Kartenbild und darüber:

* die Kurslinie (gestrichelt, magenta), die Startlinie, die Tonnen mit Nummern,
* **Warngebiete** (magenta Kreise mit Beschriftung) und **Tankstellen** (rote „F“-Punkte),
* den Windpfeil und den Titel der Bahn.

Die Tonnen wippen leicht (`sin(_t * 2.0 + i)`), `_process` ruft dafür `queue_redraw()`.

### Starten

```gdscript
func _start() -> void:
    GameState.net_mode = ""
    GameState.level_path = _levels[_selected]
    Sfx.play("go", -6.0)
    get_tree().change_scene_to_file(GAME_SCENE)       # lädt scenes/main.tscn
```

Es gibt keine Parameterübergabe: `main.gd` liest `GameState`. Der Controller-Startknopf und
`Esc` (Beenden) sind in `_unhandled_input`.

## `lobby.gd` { #lobby-gd }

`extends Control`, 355 Zeilen, Szene `scenes/lobby.tscn`. Links: Name, Spieleranzahl an
diesem Rechner, „Spiel eröffnen“, **gefundene Spiele** im LAN, „Direkt verbinden“ (IP). Rechts:
die Regatta, in der man gerade ist (Mitsegler, Bahn und Wetter, Start).

Die Lobby **besitzt keine Netzwerklogik**. Sie ruft `Net.host()`, `Net.join(addr)`,
`Net.set_setting(key, value)`, `Net.start_race()` und hört auf die Signale:

```gdscript
Net.status.connect(_on_status)              # Textmeldung
Net.lobby_changed.connect(_refresh)         # Mitsegler oder Einstellungen haben sich geändert
Net.games_changed.connect(_refresh_games)   # LAN-Liste hat sich geändert
```

Nur der **Host** sieht aktive Einstellungsknöpfe (`_setting_button`), Clients sehen die Werte
nur. Alle Änderungen gehen über `Net.set_setting`, das sie an alle verteilt. Protokoll:
[Netzwerk](netzwerk.md).

## `ui_style.gd` { #ui-style-gd }

`class_name UIStyle`, nur `static`-Funktionen und Farbkonstanten (`PAPER`, `INK`, `MAGENTA`,
`BLUE`). Es kapselt den Seekartenlook, damit Menü und Lobby gleich aussehen:

| Funktion | Ergebnis |
|---|---|
| `box(bg, border, w)` | `StyleBoxFlat` mit Rand und Innenabstand |
| `make_theme()` | ein `Theme` für Knöpfe, Beschriftungen und Textfelder (Normal, Hover, Gedrückt, Fokus magenta) |
| `style_primary(button)` | magenta Hauptknopf („Leinen los!“) |
| `heading(text)` | blaue Überschrift in kursiver Serifenschrift |
| `draw_paper(canvas_item, size)` | Papier mit Kartennetz und Rahmen mit Minuten-Skala |

`theme = UIStyle.make_theme()` an die Wurzel des Menüs gesetzt gilt für **alle Kinder**. Das
ist Godots Weg, die Oberfläche einheitlich zu gestalten, ohne jedem Knopf einzeln eine Farbe zu geben.

## Beispiel: Einen neuen Menüeintrag ergänzen

Neue Einstellung „Gegenwind-Start“ (Schalter an/aus):

1. `game_state.gd`: `static var upwind_start := true`.
2. `menu.gd`: einen Knopf im `_build_ui()` anlegen und beim Drücken
   `GameState.upwind_start = not GameState.upwind_start; _update_labels()`.
3. `main.gd`: beim Erzeugen der Boote `if GameState.upwind_start:` den Kurs hoch am Wind
   setzen (sonst Richtung Startlinie).
4. Im Netzwerkfall muss der Host den Wert in `Net.settings`/`start_race()` mitschicken (siehe
   [Netzwerk](netzwerk.md#einstellungen-und-rennstart)).
