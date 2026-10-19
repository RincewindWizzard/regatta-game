# Godot-Grundlagen für dieses Projekt

Dieses Kapitel erklärt alle Godot-Begriffe, die in den Skripten vorkommen. Wer Godot schon
kennt, kann zur [Architektur](architektur.md) springen. Alles hier ist mit **Godot 4.3** und
neuer gültig.

!!! tip "Installieren"
    Godot gibt es als einzelne Datei unter <https://godotengine.org/download>. Es braucht keine
    Installation: entpacken, starten, **Importieren** → `project.godot` wählen → `F5` startet
    das Spiel. Auf der Kommandozeile heißt dasselbe `godot --path . `.

## 1. Nodes und Szenen

Alles in Godot ist ein **Node** (Knoten). Ein Node hat einen Namen, einen Typ (z. B.
`Node3D`, `Label`, `MeshInstance3D`), Eigenschaften und beliebig viele **Kinder**. Nodes
bilden einen **Baum**. Eine **Szene** (`.tscn`) ist ein gespeicherter Teilbaum, den man in
andere Szenen einsetzen kann.

```
Main (Node, Skript main.gd)
├── WorldEnvironment
├── DirectionalLight3D
├── Level (Node3D, Skript level.gd)        ← aus levels/01_mittelgrund.tscn
│   ├── StartZiel (Node3D, start_line.gd)
│   ├── Luvtonne (Node3D, course_mark.gd)
│   └── …
├── WindField, SeaChart, Course
├── Boat, Boat, Boat …
└── CanvasLayer → RaceHud
```

In diesem Projekt gibt es **nur drei kleine Szenen** (`menu.tscn`, `lobby.tscn`, `main.tscn`),
die jeweils nur einen Wurzel-Node mit einem Skript enthalten. Den Rest baut der Code zur
Laufzeit zusammen (`Node.new()`, `add_child(...)`). Das ist bewusst so: Der Code bleibt
lesbar, und es gibt kaum Szenen-Dateien, die man pflegen muss. Nur die **Level** sind richtige
Szenen, weil man sie im Editor bearbeiten will.

**Beispiel:** Ein Node im Code anlegen und in den Baum hängen.

```gdscript
var label := Label3D.new()      # Objekt erzeugen
label.text = "Hallo"            # Eigenschaft setzen
add_child(label)                # an den aktuellen Node hängen -> erscheint im Spiel
```

!!! warning "Erst `add_child`, dann Positionen lesen"
    Ein Node, der noch nicht im Baum hängt, hat keine globale Position
    (`global_position`) und kann keinen Tween starten. Viele Skripte hier prüfen deshalb
    `if not is_inside_tree(): return`.

## 2. Skripte, `extends` und `class_name`

Ein Skript (`.gd`) erweitert einen Node-Typ:

```gdscript
class_name Boat          # globaler Name: überall als Typ nutzbar
extends Node3D           # dieses Skript ist ein Node3D
```

* `extends X` – das Skript **ist** ein `X` und erbt alle Eigenschaften.
* `class_name Y` – registriert den Namen `Y` global. Dann kann man in jedem anderen Skript
  `Boat.new()`, `var b: Boat` oder `b is Boat` schreiben, ohne Dateien zu laden. Das ganze
  Projekt nutzt das: `Level`, `SeaChart`, `WindField`, `Course`, `Boat`, `PlayerInput` …
* Skripte ohne Node (`extends RefCounted`) sind reine Hilfsklassen, z. B. `Fx`, `Deco`,
  `ModelStyle`, `UIStyle`, `GameState`.

### Konstanten, Variablen, Typen

```gdscript
const DRAG := 0.2            # Konstante (Großbuchstaben)
var heading := 0.0           # Variable, Typ wird aus dem Wert abgeleitet (float)
var vel: Vector2 = Vector2.ZERO   # Typ ausdrücklich
var boats: Array[Boat] = []  # typisiertes Array
static var level_path := ""  # gehört der Klasse, nicht einem Objekt (GameState)
```

`:=` leitet den Typ ab. Geht das nicht (weil der Wert „Variant“ ist, z. B. aus einem
Dictionary), schreibt man den Typ hin: `var a: float = d["x"]`. Das ist die häufigste
Fehlermeldung beim Nachbauen („Cannot infer the type of …“).

### `static`-Funktionen

`static func` braucht kein Objekt: `SeaChart.depth_at(p)` fragt die Wassertiefe, ohne dass
man ein `SeaChart` besitzt. Der **globale Zustand** (das Tiefenraster) liegt dazu in
`static var`. Das macht die Tiefenabfrage für Boote, KI, Schlepper und Wind überall verfügbar.

## 3. Lebenszyklus: `_ready`, `_process`, `_physics_process`

| Funktion | Wann | Wofür |
|---|---|---|
| `_init()` | beim Erzeugen (`.new()`) | Werte setzen, noch **nicht** im Baum |
| `_ready()` | wenn der Node samt Kindern im Baum ist | Aufbau, Kinder erzeugen |
| `_process(delta)` | **jedes gezeichnete Bild** | Optik: Animationen, Kamera, HUD |
| `_physics_process(delta)` | **fest 60× pro Sekunde** | Simulation: Boot, Wind, Spiellogik |
| `_input(event)`, `_unhandled_input(event)` | bei Eingabeereignissen | Tasten wie F11, Esc |

`delta` ist die vergangene Zeit in Sekunden seit dem letzten Aufruf. **Alle Bewegungen mit
`delta` multiplizieren**, dann sind sie unabhängig von der Bildrate:

```gdscript
position.x += speed * delta      # speed in Metern pro Sekunde
```

!!! note "Merke: Simulation und Optik trennen"
    Die Boote rechnen in `_physics_process` (fester Takt, deshalb zwischen Rechnern und in
    Tests reproduzierbar). Dass sie hübsch kippen und flattern, passiert in `_process`
    (`boat.gd`). Das ist auch der Grund, warum ein Netzwerk-Client die Physik auslassen und
    nur `_process` laufen lassen kann.

## 4. Signale

Ein **Signal** ist ein Ereignis, auf das andere Nodes hören können. Der Sender weiß nichts von
den Empfängern.

```gdscript
# Sender (course.gd)
signal boat_finished(boat: Boat)
...
boat_finished.emit(boat)

# Empfänger (main.gd)
course.boat_finished.connect(_on_boat_finished)
func _on_boat_finished(boat: Boat) -> void: ...
```

Im Projekt: `Course.target_reached`, `Course.boat_finished`, `Net.lobby_changed`,
`Net.status`, `Tug.finished_tow`, `Input.joy_connection_changed`.

## 5. `@export`, Setter und `@tool`

`@export` macht eine Variable im **Inspector** (rechte Seitenleiste) editierbar und speichert
den Wert in der `.tscn`-Szene:

```gdscript
@export_range(15.0, 150.0, 1.0, "suffix:m") var half_width := 45.0:
    set(v):
        half_width = v
        _rebuild()         # bei jeder Änderung neu zeichnen
```

Der **Setter** (`set(v): …`) läuft bei jeder Zuweisung. Mit `@tool` am Dateianfang läuft das
Skript **auch im Editor**, dann sieht man Änderungen sofort in der 3D-Ansicht. Alle
Level-Bausteine (`scripts/level/*.gd`) sind `@tool`-Skripte: Tonne verschieben → die Karte
aktualisiert sich live.

!!! warning "Fallen bei `@tool`"
    * Der Code läuft auch im Editor, darf also nicht ohne Prüfung auf Spiel-Zustand zugreifen
      (`Engine.is_editor_hint()` unterscheidet).
    * Alle Klassen, die ein `@tool`-Skript aufruft (`Deco`, `ModelStyle`, `SeaChart`, `Fx`),
      müssen selbst `@tool` sein.
    * Setter werden schon beim Laden der Szene aufgerufen, **bevor** der Node im Baum hängt.
      Deshalb beginnt jedes `_rebuild()` mit `if not is_inside_tree(): return`.

## 6. Autoloads (Singletons)

Ein **Autoload** ist ein Node, den Godot beim Start automatisch in den Baum hängt und der
über alle Szenenwechsel bleibt. Er ist global unter seinem Namen erreichbar. Im Projekt:

```ini
; project.godot
[autoload]
Net="*res://scripts/net/net.gd"
Fullscreen="*res://scripts/fullscreen.gd"
```

`Net` (Netzwerk) wird überall als `Net.host()`, `Net.is_online()` … benutzt. Das Sternchen
bedeutet: als Node instanziieren. `Sfx` ist dagegen **kein** Autoload, sondern legt sich
selbst an (`Sfx.ensure(get_tree())`), damit es auch in headless Tests funktioniert.

## 7. Szenenwechsel und Daten zwischen Szenen

`get_tree().change_scene_to_file("res://scenes/main.tscn")` wirft die aktuelle Szene weg und
lädt eine neue. Alles, was erhalten bleiben soll, muss **außerhalb** liegen: in einem Autoload
oder in `static var`s. Dafür gibt es `GameState` (Menü-Auswahl) – siehe
[Menü und Lobby](../skripte/menue.md).

## 8. Eingabe

Statt der Input-Map des Editors liest `PlayerInput` die Tasten direkt:

```gdscript
Input.is_physical_key_pressed(KEY_A)                       # Tastatur
Input.get_joy_axis(device, JOY_AXIS_LEFT_X)                # Stick, -1..+1
Input.is_joy_button_pressed(device, JOY_BUTTON_A)          # Knopf
```

`physical_keycode` meint die **Position** der Taste (WASD funktioniert auch auf einer
französischen Tastatur). Mehr in [Eingabe](../skripte/eingabe.md).

## 9. Zeichnen ohne Szene

Godot hat zwei Wege, Dinge sichtbar zu machen, die dieses Projekt beide nutzt:

* **3D:** `MeshInstance3D` mit einem `Mesh` (z. B. `BoxMesh`, `SphereMesh`, `CylinderMesh`,
  selbst gebautes `ArrayMesh` per `SurfaceTool`) und einem Material.
* **2D / UI:** In einem `Control` überschreibt man `_draw()` und ruft `draw_rect`,
  `draw_circle`, `draw_string` … auf. Mit `queue_redraw()` fordert man ein neues Zeichnen an.
  Das komplette HUD (`hud.gd`) und das Menü sind so gezeichnet.

**Beispiel:** Ein Viereck auf dem Wasser mit `SurfaceTool` (aus `sea_chart.gd`, vereinfacht).

```gdscript
var st := SurfaceTool.new()
st.begin(Mesh.PRIMITIVE_TRIANGLES)
for p in [Vector3(0,0,0), Vector3(1,0,0), Vector3(1,0,1),    # 1. Dreieck
          Vector3(0,0,0), Vector3(1,0,1), Vector3(0,0,1)]:   # 2. Dreieck
    st.add_vertex(p)
var mi := MeshInstance3D.new()
mi.mesh = st.commit()
add_child(mi)
```

## 10. Koordinaten und Winkel in diesem Projekt

Das Spiel ist in der Wasserebene 2D, wird aber in 3D gezeichnet. Eine Position ist deshalb ein
`Vector2(x, z)` (`boat.pos2d()`), die Höhe `y` ist fast immer 0.

```
            Norden  (-z)
               ▲
   Westen (-x) │   Osten (+x)
          ◄────┼────►
               │
            Süden  (+z)
```

* **Wind:** `dir` ist die Richtung, **aus der** der Wind kommt, in Radiant. 0 = aus Norden,
  π/2 = aus Osten. Die Richtung, **in die** er weht, liefert `WindField.dir_to_blow(dir)`.
* **Boot:** `heading = 0` heißt Bug nach +z (Süden). Der Richtungsvektor ist
  `Vector2(sin(heading), cos(heading))`. Lokal +z ist vorn, +x ist Backbord (links).
* **Winkel:** Alle Winkel sind Radiant (`deg_to_rad`, `rad_to_deg`). `angle_difference(a, b)`
  liefert die kürzeste Drehung zwischen zwei Winkeln, `wrapf(w, -PI, PI)` hält einen Winkel im
  gültigen Bereich.
* **Einheiten:** Meter und Sekunden. Knoten umrechnen: 1 m/s = 1,944 kn. Seemeilen:
  1 sm = 1852 m.

## 11. Zufall und Reproduzierbarkeit

`RandomNumberGenerator` mit festem `seed` liefert immer dieselbe Folge. Das nutzt das Projekt
überall, wo **alle Rechner dasselbe sehen müssen**: Position der Minen
(`restricted_area.gd`), Inseldekoration (`shoal_area.gd`), Böenfeld im Netzwerk
(`wind_field.gd` bekommt `gust_seed` vom Host).

## 12. Headless-Tests

Godot kann ohne Fenster laufen: `godot --headless --path . --script res://tests/x.gd`. Ein
Skript, das `extends SceneTree` erweitert, ersetzt dann die Hauptschleife. So testet man
Physik, KI und Netzwerk automatisch, siehe [Werkzeuge und Tests](../skripte/werkzeuge.md).

## Weiter

→ [Architektur im Überblick](architektur.md)
