# Level-Editor-Plugin (`addons/regatta_editor/`)

Ein **Editor-Plugin** erweitert den Godot-Editor selbst. Dieses hier fügt der 3D-Ansicht eine
Werkzeugleiste hinzu: einen **Seegrund-Pinsel** und das Menü **„+ Baustein“**. Es läuft nur
im Editor, nie im fertigen Spiel.

## Dateien

| Datei | Zweck |
|---|---|
| `addons/regatta_editor/plugin.cfg` | Beschreibung (Name, Skript `plugin.gd`, Version) |
| `addons/regatta_editor/plugin.gd` | das Plugin (`@tool`, `extends EditorPlugin`) |
| `addons/regatta_editor/icons/*.svg` | Symbole der Bausteine im Szenenbaum (`@icon("res://…")` in den Baustein-Skripten) |

Aktiviert wird es in `project.godot` unter `[editor_plugins]` (oder im Editor: *Projekt →
Projekteinstellungen → Plugins*).

!!! note "Eigene Icons"
    `@icon("res://addons/regatta_editor/icons/fuel.svg")` über `class_name` gibt dem Baustein ein
    eigenes Symbol im Szenenbaum und im Dialog „Node hinzufügen“. Ein 16×16-SVG genügt.

## Aufbau von `plugin.gd`

```gdscript
@tool
extends EditorPlugin

func _enter_tree() -> void:          # Plugin wird aktiviert: Oberfläche aufbauen
    _bar = HBoxContainer.new()
    ...
    add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, _bar)   # in die 3D-Werkzeugleiste
    _bar.hide()

func _exit_tree() -> void:           # deaktiviert: aufräumen
    remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, _bar)
    _bar.queue_free()

func _handles(object: Object) -> bool:   # für welche Auswahl will das Plugin zuständig sein?
    return object is Level or object is ShoalArea or object is SeaMark or ...

func _edit(object: Object) -> void:      # Auswahl hat sich geändert: Level merken
func _make_visible(visible: bool) -> void:   # Leiste zeigen/verbergen
```

Die Leiste erscheint also nur, wenn ein Level (oder ein Baustein davon) ausgewählt ist.

## Der Seegrund-Pinsel

Der Pinsel arbeitet auf dem **Malbild** des Levels (`depth_paint_png`, 256×256, Graustufen),
siehe [Level und Bausteine](level.md#level-gd).

### Eingaben abfangen

```gdscript
func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
    if _level == null or _brush == 0: return EditorPlugin.AFTER_GUI_INPUT_PASS   # Pinsel aus: Editor normal
    if event is InputEventMouseMotion:
        _update_cursor(camera, event.position)
        if _painting: _level.paint(Vector2(_cursor_world.x, _cursor_world.z), radius, _brush, strength)
        return AFTER_GUI_INPUT_STOP if _painting else AFTER_GUI_INPUT_PASS
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:  _painting = true;  _before = _level.depth_paint_png;  _level.begin_stroke() ...
        elif _painting:    _painting = false; var after := _level.end_stroke(); ... Undo eintragen
```

`AFTER_GUI_INPUT_STOP` heißt: Das Plugin hat das Ereignis verbraucht, der Editor soll nichts
damit tun (sonst würde ein Klick die Auswahl ändern); `PASS` reicht es durch.

### Mausstrahl auf die Wasserebene

```gdscript
func _update_cursor(camera: Camera3D, pos: Vector2) -> void:
    var o := camera.project_ray_origin(pos)      # Startpunkt des Strahls
    var d := camera.project_ray_normal(pos)      # Richtung
    var t := -o.y / d.y                          # Schnittpunkt mit der Ebene y = 0
    _cursor_world = o + d * t
```

Aus `o + d·t = (x, 0, z)` folgt `t = −o.y / d.y`. Mehr braucht man nicht, um eine Mausposition
auf eine Ebene zu übertragen.

### Undo/Redo

Jeder Pinselstrich ist **eine** Undo-Aktion:

```gdscript
var ur := get_undo_redo()
ur.create_action("Seegrund malen", UndoRedo.MERGE_DISABLE, _level)
ur.add_do_property(_level, "depth_paint_png", after)
ur.add_undo_property(_level, "depth_paint_png", _before)
ur.commit_action()
```

Merken muss man nur das Bild vor dem Strich (`_before`) und danach (`after`). `Strg+Z` setzt die
Eigenschaft zurück. Weil `depth_paint_png` ein `@export_storage` ist, wird es mit der Szene
gespeichert.

### Pinsel-Overlay

`_forward_3d_draw_over_viewport(overlay)` zeichnet den Pinselkreis: 48 Punkte um den Mauspunkt
auf der Ebene, per `camera.unproject_position` in Bildschirmkoordinaten gebracht,
`overlay.draw_polyline(...)`.

## „+ Baustein“

Ein `MenuButton` mit einem Popup. Jeder Eintrag hat eine **Zahl** (id), `_add_piece(id)` baut
dazu den Node:

```gdscript
pm.add_item("Bahnmarke (Tonne zum Runden)", 0)
...
func _add_piece(id: int) -> void:
    var node: Node3D
    match id:
        0:  var m := CourseMark.new(); m.name = "Tonne"; m.mark_name = "Tonne %d" % (lvl.marks().size() + 1); node = m
        33: node = FuelDock.new(); node.name = "Tankstelle"
        40, 41, 42, 43, 44:                                   # Tiere und Wracks
            var l := SeaLife.new(); l.kind = id - 40; ...
    # in die Mitte der Ansicht setzen:
    _update_cursor(_camera, vp * 0.5)
    ur.add_do_method(lvl, "add_child", node, true)
    ur.add_do_method(node, "set_owner", lvl)                  # sonst wird der Node nicht gespeichert!
    ur.add_do_property(node, "position", pos)
```

**`set_owner(lvl)` ist die wichtigste Zeile.** Ein Node ohne `owner` wird in der Szene nicht
mitgespeichert, er wäre beim nächsten Öffnen weg.

### Kardinaltonnen um eine Untiefe

`_cardinals_around_selection(lvl)`: Für jede ausgewählte Untiefe vier `SeaMark`s (Nord, Ost,
Süd, West) im Abstand `max(Ausdehnung) · 1,35 + 12 m`. Die Ausdehnung kommt aus den
Skalierungsfaktoren der Basis (`global_basis.x.length()`), die Namen werden `Untiefe_N`,
`_O`, `_S`, `_W`.

## Neuen Baustein ins Menü aufnehmen

1. Baustein-Skript schreiben (`@tool`, `class_name`, `_rebuild()`).
2. `plugin.gd`: `pm.add_item("Mein Baustein", 50)`.
3. In `_add_piece` ein `match`-Zweig `50:` mit `node = MeinBaustein.new()`.
4. In `_handles` den Typ ergänzen, damit die Leiste bei seiner Auswahl sichtbar bleibt.

Danach lässt sich der Baustein per Klick einfügen und mit den normalen Godot-Werkzeugen
(`W` verschieben, `E` drehen, `R` skalieren) platzieren.
