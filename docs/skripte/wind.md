# Wind und Strömung

Drei Dinge schieben ein Boot: der **Wind** (treibt die Segel), die **Strömung** (versetzt
das ganze Boot) und der **Windschatten** (nimmt Wind weg). Dieses Kapitel erklärt alle
Skripte dazu.

## `wind_field.gd` { #wind-field-gd }

`class_name WindField`, `extends Node`. Eine einzige Instanz pro Rennen (von `main.gd`
erzeugt). Sie beantwortet: **Welcher Wind weht an Position `p` zur Zeit `t`?**

### Zutaten

```
 wahrer Wind(p, t) = Richtung(p, t) × Stärke(p, t) × Schatten(p)

 Richtung  = base_dir  + großer langsamer Dreher (sin, Periode 80 s)
                       + kleiner schneller Dreher (sin, Periode 31 s)
                       + örtliches Rauschen (±0,35 rad)
 Stärke    = max(1,5; base_speed × (1 + Böe(p, t) × gust_strength × 0,5))
 Böe       = Rauschen, das mit dem Wind über die Bahn wandert, -1 (Flaute) … +1 (Böe)
 Schatten  = Land- und Bootsschatten (siehe unten)
```

| Export | Standard | Bedeutung |
|---|---|---|
| `base_dir` | 0 | Richtung, **aus der** der Wind kommt (Radiant) |
| `base_speed` | 6 | m/s (≈ 12 kn) |
| `shift_amplitude` | 0,30 | Winddreher (rad ≈ 17°) |
| `gust_strength` | 0,9 | 0 = keine Böen |
| `shadow_length`, `shadow_strength` | 50 m, 0,5 | Bootschatten |
| `land_shadow_length`, `land_shadow_strength` | 170 m, 0,88 | Landschatten |

### Böen und Rauschen

```gdscript
func gust_at(p: Vector2) -> float:
    var q := _drift_pos(p)       # Böenfeld wandert mit dem Wind über die Karte
    return clampf(_gust_noise.get_noise_3d(q.x, q.y, time * 0.5) * 1.6, -1.0, 1.0)
```

`get_noise_3d(x, y, z)` mit `z = Zeit` lässt das 2D-Rauschfeld sich verändern. Die
Verschiebung `p - blow_dir() * time * base_speed * 0.5` lässt das Muster mit halber
Windgeschwindigkeit wandern. Das ist, was man auf dem Wasser als „die Böe kommt auf mich zu“
sieht.

Die **Seeds** (`gust_seed`, `dir_seed`) sind im Netzwerk vom Host vorgegeben, damit alle Rechner
dieselben Böen sehen (`GameState.apply_wind`).

### Windschatten von Booten

```gdscript
func shadow_factor(p: Vector2, bd: Vector2, exclude: Node = null) -> float:
    var f := _land_shadow(p, bd)                    # 1. Land
    for b in boats:                                 # 2. andere Boote
        if b == exclude: continue
        var rel: Vector2 = p - b.pos2d()
        var along := rel.dot(bd)                    # wie weit hinter dem Boot (Lee)?
        if along < 1.0 or along > shadow_length: continue
        var lat := absf(rel.cross(bd))              # seitlicher Abstand zur Windachse
        var width := 3.0 + along * 0.2              # der Schatten wird mit Abstand breiter
        if lat >= width: continue
        f *= 1.0 - shadow_strength * (1.0 - along / shadow_length) * (1.0 - lat / width)
    return f
```

`rel.dot(bd)` ist die Strecke **in Windrichtung**, `rel.cross(bd)` der Abstand **quer**
dazu (2D-Kreuzprodukt = Skalar). Ein Boot im Kegel bis 50 m hinter einem anderen verliert
bis zu 50 % Wind.

### Windschatten von Land

```gdscript
func _land_shadow(p: Vector2, bd: Vector2) -> float:
    var side := Vector2(-bd.y, bd.x)
    var total := 0.0
    for off in [-14.0, 0.0, 14.0]:                       # drei Strahlen nebeneinander
        var origin: Vector2 = p + side * off
        var hit := land_shadow_length
        var d := 6.0
        while d < land_shadow_length:                    # gegen den Wind laufen
            if SeaChart.depth_at(origin - bd * d) < SeaChart.LAND:   # Land getroffen
                hit = d
                break
            d += 10.0
        total += land_shadow_strength * pow(1.0 - hit / land_shadow_length, 0.7)
    return 1.0 - total / 3.0
```

Es werden drei Strahlen gegen den Wind geschickt (mittig und 14 m seitlich). Trifft ein
Strahl nach `hit` Metern Land, verliert der Wind `strength × (1 − hit/170)^0,7` – direkt im
Lee fast alles, 170 m dahinter nichts. Der Mittelwert der drei Strahlen macht den Schatten
**weich** statt scharfkantig.

!!! warning "Das ist teuer: nicht alles auf einmal!"
    Ein Aufruf macht bis zu 3 × 17 Kartenabfragen. Die Windstriche (etwa 900 Stück) werden
    deshalb **portionsweise** in `WindVisuals._sample_chunk()` berechnet. In einem Test
    dauerte ein voller Durchlauf 40 ms, das gab Ruckler. Test: `tests/wind_perf.gd`.

### Weitere Methoden

| Methode | Zweck |
|---|---|
| `static dir_to_blow(dir)` | Richtung **aus der** → Vektor **in die** der Wind weht: `Vector2(-sin(dir), cos(dir))` |
| `blow_dir()` | dasselbe für die aktuelle Grundrichtung |
| `dir_at(p)` | örtliche Richtung |
| `get_wind(p, exclude)` | Vektor in m/s (Länge = Stärke) mit Schatten |

!!! note "Warum `exclude`?"
    Ein Boot soll nicht im Schatten **seines eigenen** Rumpfes segeln. `boat.gd` ruft deshalb
    `wind.get_wind(p, self)`.

## `wind_visuals.gd` { #wind-visuals-gd }

Macht den Wind **sichtbar**: kurze dunkle Striche im Raster (16 m), die in Windrichtung
wandern, länger und kräftiger bei mehr Wind. Ein Strich ist kein Node, sondern eine **Instanz
eines `MultiMesh`**: Mehrere Tausend Instanzen kosten nur einen Zeichenaufruf.

```gdscript
_mm = MultiMesh.new()
_mm.transform_format = MultiMesh.TRANSFORM_3D
_mm.use_colors = true                          # pro Instanz eine Farbe (Alpha = Sichtbarkeit)
_mm.mesh = streak                              # ein flacher Quader 0,16 × 1 m
_mm.instance_count = _cells.size()
...
_mm.set_instance_transform(k, Transform3D(basis, Vector3(p.x, 0.1, p.y)))
_mm.set_instance_color(k, Color(0.12, 0.22, 0.38, a))
```

Jeder Strich hat eine Phase und läuft von `-0,5` bis `+0,5` Zellenbreite durch, wobei die
Transparenz `sin(cyc × π)` ein sanftes Ein- und Ausblenden ergibt. Wo der Landschatten den Wind
wegnimmt, wird `spd` klein und der Strich verschwindet: So **sieht** man den Windschatten.

Zusätzlich schreibt `_update_gusts()` alle 0,3 s ein 128×128-Bild der Böenstärke
(`Image.FORMAT_R8`) und übergibt es dem Karten-Shader (`SeaChart.set_gust_texture`).

## `currents.gd` { #currents-gd }

Eine winzige Klasse (30 Zeilen) mit `static var _sources`. Das Level meldet beim Start alle
Nodes mit `current_at(p)`; `Currents.at(p)` addiert ihre Beiträge:

```gdscript
static func at(p: Vector2) -> Vector2:
    var c := Vector2.ZERO
    for s in _sources:
        c += s.current_at(p)
    return c
```

Aufrufer: `boat.gd` (`current = Currents.at(p)`), `ai_input.gd` (plant mit Strom). Das **Boot** addiert den Strom zur Geschwindigkeit über Grund:
`ground = vel + current`.

## `current_area.gd` { #current-area-gd }

Strömung in einem Rechteck, `speed_kn`, `length`, `width`, optional `tide_period` (Gezeiten:
kehrt periodisch um). `current_at(p)` rechnet `p` in lokale Koordinaten und blendet zu den
Rändern aus:

```gdscript
var ax := absf(l.x) / (width * 0.5)
var az := absf(l.z) / (length * 0.5)
if ax >= 1.0 or az >= 1.0: return Vector2.ZERO
var f := (1.0 - smoothstep(0.55, 1.0, ax)) * (1.0 - smoothstep(0.65, 1.0, az))
return _dir * speed_kn / 1.944 * f * _tide()        # _tide() = sin(t·2π/Periode) oder 1
```

Die Richtung ist **lokal −Z** des Nodes: man dreht den Baustein im Editor, bis der Pfeil stimmt.
Zeichnen: Pfeile mit „x kn“ in `_rebuild()`, bewegte Schlieren (`MultiMesh`) in `_process`.

## `river_channel.gd` { #river-channel-gd }

`extends Path3D`: Die Flusskurve zeichnet man im Editor mit Godots Pfad-Werkzeug (Punkte
setzen und ziehen). Das Skript macht daraus:

1. `prepare_current()`: `curve.get_baked_points()` → Mittellinie `_pts` (alle ≥ 4 m), Lauflänge
   `_cum`, Breite je Punkt `_w` (aus `width` und optionaler `width_curve`).
2. `carve_grid(grid, res)`: gräbt Wasser ins Land (nur Zellen in der Nähe, Segment für
   Segment): `grid = max(grid, depth × (1 − k⁴) + LAND × smoothstep(0.9, 1.15, k))`.
3. `current_at(p)`: Strömung entlang der Kurve:

```gdscript
var n := _nearest(p)                        # [Abstand zur Mittellinie, Segment, Anteil]
var w := lerpf(_w[i], _w[i + 1], n[2])      # Breite an dieser Stelle
var k: float = n[0] / (w * 0.5)             # 0 = Flussmitte, 1 = Ufer
if k >= 1.0: return Vector2.ZERO
return dir * flow_kn / 1.944 * (width / w) * (1.0 - k * k) * 1.3
```

* **`width / w`**: Kontinuität. Wird der Fluss schmaler (`w` klein), fließt er schneller.
* **`(1 − k²)`**: in der Mitte schneller als am Ufer.

4. `_rebuild()`: Uferbäume und Strompfeile; `prune_trees()` setzt die Bäume beim Rennstart
   auf **Land** (läuft von der Flussmitte nach außen, bis die Tiefenkarte Land zeigt; ohne Land
   in 220 m wird der Baum entfernt).

!!! note "Warum `prune_trees` erst beim Rennstart?"
    Beim Aufbau der Szene (`_ready`) gibt es das Tiefenraster noch nicht: `Level.prepare_for_game()`
    berechnet es erst danach. Also verschiebt man die Bäume im Nachhinein.

## Beispiel: Strömung nachbauen

Ein Baustein, der alle Boote in einem Kreis nach Osten schiebt, in 15 Zeilen:

```gdscript
class_name EastWind
extends Node3D
@export var radius := 60.0
@export var speed_kn := 2.0

func current_at(p: Vector2) -> Vector2:
    var d := p.distance_to(Vector2(global_position.x, global_position.z))
    if d >= radius:
        return Vector2.ZERO
    var f := 1.0 - smoothstep(0.5, 1.0, d / radius)     # weich zum Rand hin
    return Vector2(1, 0) * speed_kn / 1.944 * f

func prepare_current() -> void:
    pass                                                # nichts vorzubereiten
```

Setzt man ihn in ein Level, findet ihn `Level.current_sources()` (er hat `current_at`) und
`Currents.set_sources` ruft `prepare_current()` auf. Mehr braucht das Spiel nicht.
