# Schlepper (`tug.gd`)

Datei: `scripts/tug.gd`, `class_name Tug`, `extends Node3D`, 310 Zeilen. Der Schlepper holt
**festgefahrene** Boote ab. Er ist ein kleines Beispiel für eine **Zustandsmaschine**.

## Wann kommt er?

`main.gd` ruft in `_call_tugs()` für jedes Boot, das seit mehr als `STUCK_WAIT = 4 s`
festsitzt (`stuck_time`, siehe [Das Boot](boot.md)), `Tug.spawn_for(boat)` und hängt ihn in
den Baum. Pro Boot gibt es höchstens einen (`boat.tug`).

## Zustände

```
 APPROACH ──► HOOK ──► TOW ──► RELEASE ──► LEAVE ──► (queue_free)
 anfahren     Leine    ziehen   loswerfen   abdampfen
              übergeben
```

```gdscript
enum State { APPROACH, HOOK, TOW, RELEASE, LEAVE }
var state := State.APPROACH

match state:
    State.APPROACH:
        # Ziel: ein Punkt eine Leinenlänge vor dem Boot, auf der tiefen Seite
        ...
        if dist < 3.0:
            state = State.HOOK; timer = HOOK_TIME; boat.start_tow(self)
    State.HOOK:   ... timer -= delta; _drag_boat(delta); if timer <= 0.0: state = State.TOW
    State.TOW:    ... zieht zum tow_target; bei tiefem Wasser: RELEASE
    State.RELEASE: ... boat.end_tow(); state = State.LEAVE
    State.LEAVE:  ... nach 25 s queue_free()
```

Das `match` über ein `enum` ist **das** Muster für Zustandsmaschinen in GDScript: Jeder Zustand
hat seinen Block, Übergänge sind Zuweisungen an `state`.

## Startpunkt: `spawn_for`

```gdscript
static func spawn_for(b: Boat) -> Tug:
    var deep := SeaChart.find_deep_water(bp, SAFE_DEPTH + 1.0)     # nächstes tiefes Wasser
    var dir := (deep - bp).normalized()
    ...  # bis 12 Richtungen durchprobieren (abwechselnd links/rechts), die frei sind
    for k in 12:
        var cand := bp + dir.rotated(k * 0.5 * (1 if k % 2 == 0 else -1)) * SPAWN_DIST   # 55 m
        if SeaChart.depth_at(cand) > SAFE_DEPTH and SeaChart.path_clear(cand, bp): ...
    tug.tow_target = deep + dir * 12.0              # dorthin wird geschleppt
```

Der Schlepper erscheint 55 m vom Boot entfernt, **im Wasser** und mit freier Linie, und zieht es
zum nächsten Punkt mit mindestens 2 m Wasser. Die Hilfsfunktionen `find_deep_water` und
`path_clear` stehen in [`sea_chart.gd`](seekarte.md).

## Boot ziehen: `_drag_boat`

Der Schlepper bewegt das Boot **nicht** per Physik, sondern setzt es direkt
(`boat.tow_to(pos, heading, delta)`): Es hängt an einer 17 m langen Leine (`ROPE`) hinter dem
Heck. Zieht die Leine, wird die Position auf Leinenlänge begrenzt, der Kurs dreht sich
(max. 1,2 rad/s) in Zugrichtung. Das Boot hat in dieser Zeit `towed = true`: Seine eigene
Physik ist aus ([Das Boot, Schritt 4](boot.md#der-physikschritt-in-reihenfolge)).

## Die Leine

`_rope` ist ein dünner `CylinderMesh`, `top_level = true`. In `_update_rope` wird er jedes
Bild zwischen Schlepphaken und Bug des Bootes aufgespannt: die Basis (`Basis(x, y * len, z)`)
streckt den Zylinder auf die Länge zwischen den Punkten.

## Netzwerk

Auf dem Client ist der Schlepper ein **Puppet** (`puppet = true`): Er rechnet nichts, sondern
zieht Position und Kurs weich an die Werte aus dem Schnappschuss
(`net_pack`/`net_unpack`, 6 Zahlen: Boot-Index, x, z, Kurs, Zustand, Tempo).
`main.gd` legt Puppen an und entfernt sie, wenn der Host sie nicht mehr meldet.

## Konstanten

| Konstante | Wert | |
|---|---|---|
| `APPROACH_SPEED` | 2,6 m/s | gemächlich (≈ 5 kn), mit Absicht nicht zu schnell |
| `TOW_SPEED` | 2,0 m/s | |
| `LEAVE_SPEED` | 3,0 m/s | |
| `ROPE` | 17 m | Leinenlänge |
| `SPAWN_DIST` | 55 m | Abstand beim Auftauchen |
| `HOOK_TIME` | 2 s | Leine übergeben |
| `SAFE_DEPTH` | 2 m | gilt als „tief genug“ |

## Test

`tests/tug_test.gd` setzt ein Boot auf die Untiefe „Mittelgrund“ und gibt aus, wie sich
`stuck`, `towed` und `tug.state` entwickeln, bis es befreit ist.
