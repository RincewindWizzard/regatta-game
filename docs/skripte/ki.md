# Computergegner (`ai_input.gd`)

Datei: `scripts/ai_input.gd`, `class_name AIInput`, `extends PlayerInput`, rund 480 Zeilen.

Die KI ist **kein Cheater**: Sie erbt von `PlayerInput`, füllt also nur `steer`,
`sheet_rate` und die Gas-Felder. Sie nutzt dieselbe Physik wie ein Mensch und darf keine
Boot-Variable direkt verändern.

## Überblick: Der Entscheidungszyklus

```
 jeder Physikschritt (update):
    Timer, Manöversperre
    alle _think_every Sekunden:  _think()   ← die eigentliche Entscheidung (teuer)
    _trim(delta)                 ← Schot auf optimal nachführen (billig)
    _steer(delta)                ← mit der Pinne auf den Wunschkurs drehen
    _apply_throttle()            ← Gas nach Plan
```

`_think()` läuft nur alle 0,2 bis 0,7 s (je nach Stärke), `_steer`/`_trim` jeden Schritt.
Das ist auch menschlich: Man überlegt nicht 60× pro Sekunde.

## Stärken

Die drei Stufen sind nur **Parameter**:

| Parameter | Leicht | Mittel | Schwer | Bedeutung |
|---|---|---|---|---|
| `_think_every` | 0,7 s | 0,45 s | 0,2 s | Reaktionszeit |
| `_trim_error` | 0,20 | 0,15 | 0,02 | Zufallsfehler beim Trimmen |
| `_heading_noise` | 0,16 | 0,10 | 0,015 | Ungenauigkeit im Kurs (rad) |
| `_look` | 55 m | 80 m | 120 m | wie weit voraus Gefahren gesehen werden |
| `_maneuver_cost` | 0,28 | 0,18 | 0,16 | Abneigung gegen Wenden |
| `_min_gap` | 12 s | 10 s | 9 s | Mindestzeit zwischen Manövern |
| `_use_local_wind` | nein | ja | ja | liest örtliche Winddreher |
| `_use_gusts` | nein | nein | ja | steuert in Böen hinein |
| `_motor_use`, `_motor_reserve` | 0 / 50 % | 0,6 / 30 % | 1,0 / 12 % | Motornutzung, Tankreserve |

## Schritt 1: Das Ziel bestimmen

`_target_point(p)` liefert, wohin das Boot gerade will: die nächste **Tonne**, oder bei
Start/Ziel einen Punkt 30 m **hinter** der Startlinie (zum Anlauf) bzw. **vor** der Linie. Dabei
bleibt der Punkt auf der Linie innerhalb 55 % der Halbbreite.

## Schritt 2: Der Weg (A\* um Hindernisse)

Gerade zur Tonne zu segeln würde in Inseln enden. Deshalb plant die KI über die Karte:

```gdscript
const NAV_CELL := 8.0
_nav = AStarGrid2D.new()
_nav.region = Rect2i(0, 0, ceil(area.size.x / 8), ceil(area.size.y / 8))
_nav.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
for y in …: for x in …:
    var c := _cell_center(Vector2i(x, y))
    if not _safe(c, 6.0):  _nav.set_point_solid(Vector2i(x, y), true)       # gesperrt
    elif not _safe(c, 14.0): _nav.set_point_weight_scale(Vector2i(x, y), 3.0)   # teuer
```

`AStarGrid2D` ist Godots fertiger A\*-Algorithmus auf einem Raster. Eine Zelle ist **gesperrt**,
wenn die Wassertiefe an ihr oder an vier Nachbarpunkten (6 m entfernt) unter 1,6 m liegt, wenn
ein fester Punkt (`fixed_points`: Tonnen, Wracks, Stege) oder ein **Gefahrengebiet**
(`avoid`: Minen, Polizei, Sirenen) zu nah ist. Zellen in Küstennähe sind dreimal so teuer, damit der
Weg Abstand hält. Das Raster wird **einmal pro Level** gebaut (`static var _nav`) und von allen
Computerbooten geteilt.

`_waypoint(p, goal)`: Ist die Luftlinie frei (`_clear_line`), geht es direkt zum Ziel.
Sonst wird (alle 2,5 s oder bei neuem Ziel) ein Weg berechnet und der **am weitesten
sichtbare** Wegpunkt (höchstens 250 m voraus) angesteuert.

## Schritt 3: Kurse bewerten

Das Herzstück von `_think()`: 40 mögliche Kurse (alle 9°) plus der direkte Kurs und der
aktuelle Kurs, jeder bekommt einen **Punktwert**:

```gdscript
for h in candidates:
    var dir := Vector2(sin(h), cos(h))
    var twa := absf(_twa(h, from_dir))                       # wahrer Windwinkel auf diesem Kurs
    var spd := _polar(twa)                                   # Tabelle POLAR: relative Geschwindigkeit
    if _use_gusts: spd *= clamp(wind.get_wind(p + dir * 45, boat).length() / base_speed, 0.8, 1.25)
    var through_water := maxf(spd * v_sail, motor_v) + 0.3 * minf(spd * v_sail, motor_v)
    var ground := dir * through_water + cur                  # + Strömung
    var score := ground.dot(to_unit) / v_sail                # VMG: Fortschritt zum Ziel
    if _side(h, from_dir) != cur_side and twa > deg_to_rad(15.0):
        score -= switch_cost * (1.0 if motor == 0 else 0.3)  # Wenden kostet Zeit
    score += 0.04 * cos(angle_difference(h, _want_heading))  # gegen Zappeln
    score -= _hazard(p, dir, dist)                           # Land/Untiefe/Tonne voraus
```

| Term | Bedeutung |
|---|---|
| `ground.dot(to_unit)` | **VMG** (Velocity Made Good): Geschwindigkeit in Richtung Ziel. Kurse knapp am Wind sind langsam, Kurse seitlich schnell. Das Maximum ist automatisch der beste **Kreuzkurs**. |
| `switch_cost` | Wer die Windseite wechseln müsste (Wende/Halse), wird „bestraft“; so wendet die KI nicht dauernd. Nah am Ziel kostet es weniger (`× 0,4`). |
| `_hazard(...)` | strafft Kurse, die in Gefahr führen (Land, Untiefe, Tonne, Gebietsgrenze, Gefahrenkreis) |
| `0,04 · cos(Differenz)` | kleiner Bonus für den bisherigen Wunschkurs: Hysterese |

Der beste Kurs wird `_want_heading` (plus Zufallsrauschen `_heading_noise`).

`POLAR` ist die Tabelle der Bootsgeschwindigkeit je Windwinkel, **aus `tests/polar_test.gd`
gemessen**:

```gdscript
const POLAR := [[0, 0.0], [30, 0.0], [38, 0.15], [45, 0.43], [52, 0.65], [60, 0.86],
    [75, 0.97], [90, 1.0], [110, 0.8], [130, 0.62], [150, 0.52], [170, 0.44], [180, 0.41]]
```

`_polar(twa)` interpoliert linear zwischen den Zeilen.

### `_hazard(p, dir, dist_target)`

Läuft einen **Streifen in Bootsbreite** (Mitte und ±5 m) entlang `dir` bis `_look` Meter ab
(Schritte von 5 bzw. 8 m) und sucht, was **zu nah** ist:

```gdscript
hit = not area.has_point(q)                       # außerhalb des Regattagebiets
for o in [Vector2.ZERO, side, -side]:
    if SeaChart.depth_at(q + o) < 1.4: hit = true # Untiefe
for fp in fixed_points:  if dist < radius + 7.0   # Tonne, Wrack
for z in avoid:          if dist < radius + 8.0   # Gefahrengebiet
if hit:
    var k := 1.0 - d / (look + 4.0)
    return 3.0 * k * k                            # nah = sehr teuer, fern = billig
```

Die **quadratische Gewichtung** `k²` heißt: Ein Hindernis in 10 m ist dramatisch, eines in 80 m
nur ein leichtes Ärgernis. Wie beim echten Kreuzen, wo man **erst kurz vor dem Ufer wendet**.

## Schritt 4: Ausführen

### Steuern

```gdscript
func _steer(_delta: float) -> void:
    var diff := angle_difference(boat.heading, _want_heading)
    steer = clampf(-diff * 2.2, -1.0, 1.0)         # P-Regler (Proportional)
```

Ein einfacher **P-Regler**: je größer die Abweichung, desto mehr Pinne, maximal 1. Das Boot
dreht durch den Wind, wenn der Wunschkurs auf der anderen Seite liegt. Es gibt keine
Wendetaste, auch nicht für die KI.

### Trimmen

```gdscript
var target := clampf(boat.optimal_sheet() + _trim_offset, 0.0, 1.0)
sheet_rate = clampf((target - boat.sheet) * 8.0, -1.0, 1.0)
```

`optimal_sheet()` ist die Schot, bei der die Segel optimal stehen (derselbe grüne Strich wie im
HUD). `_trim_offset` (neu gewürfelt alle 2 bis 5 s, `±_trim_error`) macht schwächere Gegner
ungenau.

### Gas

`_plan_throttle(p, to_unit, dist, from_dir)`:

* **Notlage:** steckt das Boot im Wind (`speed < 0,5` und `in_irons`) länger als 2 s → Gas 2.
* sonst nur, wenn `_motor_use > 0` und noch Sprit über `_motor_reserve` ist:
    * Ziel (fast) gegen den Wind (`twa_target < 55°`) und weiter als 50 m → Gas 2 bis 4
      (Schwer: Vollgas bei mehr als 40 % Tank),
    * Gegenstrom (> 0,6 m/s) und weit → Gas 2.

`_apply_throttle()` vergleicht `boat.throttle` mit `_want_throttle` und löst genau einen
Gas-Impuls aus (`gas_up_pressed`/`gas_down_pressed`) pro Schritt.

### Tanken

Ist der Tank unter 20 % (und der Motor erlaubt), sucht `_think()` eine Tankstelle, die
**ungefähr auf dem Weg** liegt (`detour < 50 + 40·motor_use` m). Am Liegeplatz (unter 9 m):
Gas 0, in den Wind drehen, Schoten los (`sheet_rate = 1`), damit das Boot steht. Danach
(über 92 % voll, oder nach dem Tanken über 50 % und stehend) weiter.

## Schritt 5: Festgefahren? Notlauf

`_check_progress` merkt sich den kleinsten Abstand zum Ziel. Kommt das Boot **30 s** nicht
mindestens 15 m näher (z. B. Sackgasse hinter einer Insel), segelt es **12 s** lang einen
**Ausweichkurs** (±70° bis 110° quer zum Wind) und versucht es dann neu.

## Besonderheiten

* `update()` macht **nichts**, wenn das Boot abgeschleppt wird, ausgeschieden ist oder
  festgehalten wird (Polizei, Sirenen).
* Im Ziel (`finished`): Gas aus, Schoten los, treiben lassen.
* `avoid` (Gefahrengebiete) kommt von `Level.danger_circles()`; `main.gd` setzt es nach dem
  Erzeugen der KI.

## Testen

```bash
# alle vier Stärken auf einer Bahn gegeneinander (läuft ohne Fenster in einigen Minuten)
godot --headless --fixed-fps 60 --path . --script res://tests/ai_race.gd -- res://levels/06_schaerengarten.tscn mix
```

Ausgabe je Boot: Zeit, **Grundberührungen**, Schlepper-Einsätze, Motorzeit, Tankstopps,
Haltezustände, Kollisionen. Alle Bahnen und Stärken auf einmal: `sh tests/ai_compare.sh`. Siehe
[Werkzeuge und Tests](werkzeuge.md).

## Übung

Baue eine **vierte Stufe „Anfänger“**: In `AIInput` das `enum Level` und die Liste `NAMES`
um einen Eintrag erweitern und im `match level:` von `_init` die Werte `_think_every = 1.2`,
`_trim_error = 0.3`, `_heading_noise = 0.3`, `_look = 40.0` setzen. Das Menü (`menu.gd`) zeigt
`AIInput.NAMES` automatisch an; `GameState.ai_level` hält die Auswahl. Prüfe, dass das Boot
sichtbar schlechter segelt (`tests/ai_race.gd`).
