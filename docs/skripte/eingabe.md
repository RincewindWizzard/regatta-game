# Eingabe (`player_input.gd`, `net_input.gd`)

## Die Idee

Das Boot fragt nicht „Welche Taste ist gedrückt?“, sondern liest ein **Eingabeobjekt**
(`boat.input`) mit fünf Feldern. Jeder, der diese Felder füllt, kann ein Boot steuern.

| Feld | Typ | Bedeutung |
|---|---|---|
| `steer` | −1 … +1 | −1 = nach Backbord (links), +1 = Steuerbord (rechts) |
| `sheet_rate` | −1 … +1 | −1 = dichtholen, +1 = fieren (Geschwindigkeit, nicht Position) |
| `gas_up_pressed` | bool | genau **einen Schritt lang** wahr, wenn Gas hoch gedrückt wurde |
| `gas_down_pressed` | bool | dito für Gas runter |
| `start_pressed` | bool | Flanke für „nächstes Rennen“ |

```
 PlayerInput ──► Mensch (Tastatur, Controller)
 AIInput     ──► Computergegner (erbt von PlayerInput)
 NetInput    ──► Mensch an einem anderen Rechner (erbt von PlayerInput)
```

## `player_input.gd`

`class_name PlayerInput`, `extends RefCounted` (kein Node: wird vom Boot nur gelesen und
vom Boot **aktualisiert**: `input.update()` am Anfang jedes Physikschritts).

### Tastaturbelegung

```gdscript
const KEYMAPS := [
    {"left": KEY_A, "right": KEY_D, "in": KEY_W, "out": KEY_S,
     "gas_up": KEY_E, "gas_down": KEY_Q, "start": KEY_SPACE},
    {"left": KEY_J, "right": KEY_L, "in": KEY_I, "out": KEY_K,
     "gas_up": KEY_O, "gas_down": KEY_U, "start": KEY_ENTER},
]
```

`PlayerInput.new(0)` ist Spieler 1 (WASD), `PlayerInput.new(1)` Spieler 2 (IJKL). Der Parameter
ist die **Spielernummer** am Rechner (`player`).

### Controller zuordnen

Controller sind **nummeriert nach Geräte-ID**; die Zuordnung zu Spielern geschieht über die
Reihenfolge in `gamepads()`:

```gdscript
static func gamepads() -> Array[int]:
    var known: Array[int] = []        # bekannte Gamepads zuerst
    var other: Array[int] = []        # Geräte ohne SDL-Belegung danach
    for id in Input.get_connected_joypads():
        var n := Input.get_joy_name(id).to_lower()
        # Geräte, die Linux als "Joypad" meldet, die aber keine Controller sind, überspringen
        if IGNORE_NAMES.any(func(bad): return bad in n): continue
        ...
    return known + other
```

* **`IGNORE_NAMES`** (`motion`, `touchpad`, `keyboard`, `mouse` …) filtert Geräte aus, die
  Linux fälschlich als Joypad meldet (Bewegungssensoren, Touchpads).
* **`Input.is_joy_known(id)`** sagt, ob Godot eine Belegung für das Gerät hat. Unbekannte werden
  hinten einsortiert und im Menü mit „unbekannte Belegung“ markiert.
* **`_load_extra_mappings()`** liest optional `gamecontrollerdb.txt` (SDL-Format) neben dem
  Spiel und registriert die Zeilen mit `Input.add_joy_mapping(line, true)`.
* **`describe()`** liefert den Text für das Menü („Controller: Sp. 1: Pro Controller“).

### `update()`: Zeile für Zeile

```gdscript
func update() -> void:
    var joys := gamepads()
    device = joys[player] if player < joys.size() else -1       # mein Controller (oder keiner)

    var km: Dictionary = KEYMAPS[player % KEYMAPS.size()]
    var s := _axis(km["left"], km["right"])                      # Tastatur: -1, 0 oder +1
    var r := _axis(km["in"], km["out"])
    var up := Input.is_physical_key_pressed(km["gas_up"])
    ...
    if device >= 0:                                              # Controller dazuaddieren
        s += _dz(Input.get_joy_axis(device, JOY_AXIS_LEFT_X))
        r -= maxf(Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT), _btn(JOY_BUTTON_RIGHT_SHOULDER))
        r += maxf(Input.get_joy_axis(device, JOY_AXIS_TRIGGER_LEFT), _btn(JOY_BUTTON_LEFT_SHOULDER))
        r += _dz(Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y))
        up = up or Input.is_joy_button_pressed(device, JOY_BUTTON_A) or ...DPAD_UP
        ...
    steer = clampf(s, -1.0, 1.0) * (-1.0 if invert_tiller else 1.0)
    sheet_rate = clampf(r, -1.0, 1.0)
    gas_up_pressed = up and not _was["up"]                       # Flanke: nur beim ersten Schritt
    _was["up"] = up
```

**Mehrere Quellen addieren sich** (Tastatur *und* Controller), dann wird auf −1…+1
begrenzt. So funktioniert beides gleichzeitig.

**Flanken** (`_was`): `gas_up_pressed` ist nur im **ersten** Schritt wahr, in dem die Taste
gedrückt wird. Sonst würde jede Sekunde Tastendruck das Gas auf Vollgas schieben.

**Totzone** (`_dz`): Analogsticks zeigen nie genau 0. Unter `DEADZONE = 0,18` wird 0
gemeldet, darüber skaliert der Wert wieder auf 0…1:

```gdscript
func _dz(v: float) -> float:
    if absf(v) < DEADZONE: return 0.0
    return (v - signf(v) * DEADZONE) / (1.0 - DEADZONE)
```

### Joy-Con und Schultertasten

Beim Joy-Con (und teils beim Pro Controller) sind ZL/ZR **digitale Tasten**, die je nach
Treiber als Achse (`TRIGGER_*`), als Trigger-Button oder als Bumper (`*_SHOULDER`) ankommen.
Deshalb gilt jede dieser Varianten:

```gdscript
r -= maxf(Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT), _btn(JOY_BUTTON_RIGHT_SHOULDER))
```

`_btn(button)` macht aus einem Knopf `0.0` oder `1.0`. Ein einzelner Joy-Con genügt: Stick
lenkt, Schultertasten trimmen, Frontknöpfe geben Gas.

!!! tip "Eigener Controller klappt nicht?"
    Starte das Spiel aus der Konsole: `menu.gd` druckt beim Start Name, GUID und „bekannt:
    true/false“ jedes Geräts. Für unbekannte Geräte legt man eine Zeile aus der
    [SDL-Controller-Datenbank](https://github.com/mdqinc/SDL_GameControllerDB) in
    `gamecontrollerdb.txt`.

## `net_input.gd` { #net-input-gd }

`class_name NetInput`, `extends PlayerInput`, 37 Zeilen. Für Boote, deren Besitzer an einem
anderen Rechner sitzt (nur auf dem **Host**). Der Client schickt `steer`, `sheet_rate` und
**Zähler** für Gas-hoch, Gas-runter und Start. `update()` vergleicht Zähler mit dem zuletzt
gesehenen Wert:

```gdscript
func update() -> void:
    gas_up_pressed = _up_count > _up_seen
    _up_seen = _up_count
    ...
```

**Warum Zähler statt `bool`?** Eingaben gehen als „unreliable“ UDP-Pakete. Geht eines verloren,
wäre ein einzelner Tastendruck weg. Ein Zähler holt ihn beim nächsten Paket nach.

## Beispiel: Ein eigenes Eingabegerät

Ein Boot, das stur geradeaus segelt und immer optimal trimmt:

```gdscript
class_name AutoPilot
extends PlayerInput

var boat: Boat

func _init(p_boat: Boat) -> void:
    super(0)
    boat = p_boat

func update() -> void:
    steer = 0.0
    var target := boat.optimal_sheet()
    sheet_rate = clampf((target - boat.sheet) * 8.0, -1.0, 1.0)   # wie die KI-Trimmung
    gas_up_pressed = false
    gas_down_pressed = false
    start_pressed = false
```

`boat.input = AutoPilot.new(boat)` genügt. Das ist im Kern auch der Computergegner, nur
mit sehr viel mehr Entscheidungen: [Computergegner](ki.md).
