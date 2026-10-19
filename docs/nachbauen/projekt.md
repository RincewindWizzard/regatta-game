# Projekt aufsetzen

## 1. Neues Projekt anlegen

1. Godot starten → **Neues Projekt** → Name `Regatta`, Renderer **Forward+**.
2. Ordner anlegen: `scenes/`, `scripts/`, `scripts/level/`, `scripts/net/`, `levels/`,
   `models/`, `audio/`, `tests/`.

## 2. `project.godot` verstehen

Die Datei ist Text (Format `.ini`) und kann auch von Hand bearbeitet werden. Der echte Inhalt:

```ini
config_version=5

[application]
config/name="Regatta"
run/main_scene="res://scenes/menu.tscn"      ; Startszene
config/features=PackedStringArray("4.3", "Forward Plus")

[autoload]
Net="*res://scripts/net/net.gd"
Fullscreen="*res://scripts/fullscreen.gd"

[display]
window/size/viewport_width=1600
window/size/viewport_height=900

[editor_plugins]
enabled=PackedStringArray("res://addons/regatta_editor/plugin.cfg")
```

| Abschnitt | Bedeutung |
|---|---|
| `run/main_scene` | Das Menü ist die erste Szene. |
| `[autoload]` | `Net` (Netzwerk) und `Fullscreen` (F11) laufen immer. Im Editor: *Projekt → Projekteinstellungen → Globals → Autoload*. |
| `[display]` | Fenstergröße 1600×900. Es ist **kein** Stretch-Modus gesetzt: Die Oberfläche passt sich der Fenstergröße an und zeichnet in Pixeln. |
| `[editor_plugins]` | Das Level-Editor-Plugin ist aktiv. |

## 3. Die drei Szenen anlegen

Jede Szene besteht aus **einem** Node mit angehängtem Skript:

| Szene | Wurzel-Node | Skript |
|---|---|---|
| `scenes/menu.tscn` | `Control` | `scripts/menu.gd` |
| `scenes/lobby.tscn` | `Control` | `scripts/lobby.gd` |
| `scenes/main.tscn` | `Node` | `scripts/main.gd` |

So sieht `main.tscn` als Text aus (der gesamte Inhalt):

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/main.gd" id="1"]

[node name="Main" type="Node"]
script = ExtResource("1")
```

## 4. Modelle und Audio

* `models/dehler31_hull.glb`, `_main.glb`, `_jib.glb`, `_tiller.glb` und `tug.glb` sind
  glTF-Modelle aus Blender (Export-Skripte in `tools/`). **Sie sind optional**: Fehlen sie,
  baut `boat.gd` ein einfaches Ersatzboot aus Boxen (`_build_simple`), und `tug.gd` einen
  Ersatz-Schlepper. Zum Nachbauen kann man also **ohne Modelle starten**.
* `audio/*.ogg` werden von `tools/make_audio.py` erzeugt (siehe [Klang](../skripte/klang.md)).
  Fehlt eine Datei, bleibt der Klang einfach stumm (`Sfx.stream()` gibt `null` zurück).

## 5. Eine Schriftart

`SeaChart.font()` sucht Serifenschriften im System (`Georgia`, `DejaVu Serif`, …) und fällt auf
die Standardschrift zurück. Es werden **keine Schriftdateien** mitgeliefert.

## 6. Versionskontrolle

Ein `.gitignore` mit dem Inhalt `.godot/` genügt (der Ordner enthält Importcache). Die
`.import`-Dateien neben Bildern und Audio gehören dagegen **in** Git.

## 7. Erster Test

Lege in `scripts/main.gd` nur dies an und starte mit `F6` (aktuelle Szene) – wenn „Hallo
Regatta“ in der Ausgabe erscheint, steht das Gerüst:

```gdscript
extends Node

func _ready() -> void:
    print("Hallo Regatta")
```

Weiter mit dem [Fahrplan zum Nachbau](fahrplan.md).
