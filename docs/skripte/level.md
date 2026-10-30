# Level und Bausteine

Eine **Bahn** ist eine normale Godot-Szene, deren Wurzel das Skript `level.gd` trägt und
deren Kinder **Bausteine** sind: Startlinie, Tonnen, Inseln, Untiefen, Seezeichen, Molen,
Leuchttürme, Strömungen, Flüsse, Tankstellen, Tiere und Gefahrengebiete. Alles liegt in
`scripts/level/`, alle Skripte sind `@tool` (laufen auch im Editor).

## Das Konzept: Bausteine mit „Vertrag“

Das Level kennt seine Kinder nicht dem Typ nach, sondern fragt nach **Fähigkeiten**
(Methoden). Wer eine Methode hat, nimmt teil:

| Methode | Wer sie hat | Wer fragt |
|---|---|---|
| `depth_profile(p)` + `reach()` | `ShoalArea`, `Mole`, `Lighthouse` | `Level.compute_depth` macht den Seegrund flacher |
| `poly()` (nur `LandShape`) | `LandShape` | `Level.land_polys()`: exakte Umrisse über dem Raster |
| `carves()` + `carve_grid(grid, res)` | `ShoalArea` (See), `RiverChannel` | `Level.compute_depth` gräbt Wasser aus |
| `current_at(p)` + `prepare_current()` | `CurrentArea`, `RiverChannel` | `Currents.at(p)` |
| `collision_points()` | `FuelDock`, `SeaLife` (Wrack) | `Level.collision_points()` |
| `update_boat(boat, delta)` | `RestrictedArea`, `SirenIsland`, `ShippingLane` | `main.gd` (jeden Physikschritt) |
| `danger_circle()` | `RestrictedArea`, `SirenIsland` | `Level.danger_circles()` für die KI |
| `prune_trees()` | `RiverChannel` | `Level.prepare_for_game()` |

Dieses Muster heißt **Duck Typing** („wenn es quakt wie eine Ente …“) und macht das Projekt
erweiterbar: Ein neuer Baustein mit `update_boat` wird automatisch aufgerufen, ohne dass
`main.gd` ihn kennen müsste.

## `level.gd` { #level-gd }

`class_name Level`, `extends Node3D`, 480 Zeilen. Es hat vier Bereiche.

### 1. Export-Variablen (Inspector)

```gdscript
@export var level_name := "Neue Bahn"
@export_multiline var description := ""
@export_group("Wind")
@export_range(0, 359, 1, "degrees") var wind_from_deg := 0.0    # aus welcher Richtung
@export_range(2.0, 12.0, 0.5, "suffix:m/s") var wind_speed := 6.0
@export_range(0, 40, 1, "degrees") var wind_shift_deg := 17.0   # Winddreher
@export_range(0.0, 1.5, 0.05) var gusts := 0.9                  # Böigkeit
@export_group("Motor")
@export_range(0.0, 20.0, 0.5, "suffix:l") var fuel_liters := 6.0
@export_group("Regattagebiet")
@export_range(80.0, 450.0, 5.0, "suffix:m") var area_margin := 200.0
@export_group("Seegrund")
@export_range(3.0, 40.0, 0.5, "suffix:m") var base_depth := 14.0
@export_range(0.0, 20.0, 0.5, "suffix:m") var depth_variation := 9.0
@export var seabed_seed := 4711
@export var inland := false          # Binnenrevier: alles Land, Flüsse/Seen graben Wasser
@export_file("*.png") var depth_image := ""   # Seegrund aus einem Bild (z. B. echte Seekarte)
@export_group("Karte")
@export_range(300.0, 3000.0, 10.0, "suffix:m") var map_size := Vector2(1280, 1280)   # Länge × Breite
@export var map_origin := Vector2(-640, -840)       # Ecke links oben (x, z)
@export_group("Tiefenbild")
@export_range(-30.0, 10.0, 0.1, "suffix:m") var depth_image_black := -8.0   # Tiefe bei Schwarz
@export_range(-30.0, 40.0, 0.1, "suffix:m") var depth_image_white := 17.5   # Tiefe bei Weiß
@export var depth_image_invert := false
@export_range(0.0, 8.0, 0.1, "suffix:m") var depth_image_warp := 2.0        # Versatz der Abtastung
@export_range(0.0, 1.0, 0.05, "suffix:m") var depth_image_noise := 0.15     # Tiefenrauschen
@export_group("Seegrund")
@export var coast_east := true
@export var coast_west := true
@export_storage var depth_paint_png := PackedByteArray()   # gemalter Seegrund
```

**`depth_cell`** stellt die Zellgröße des Tiefenrasters im Spiel ein (2–10 m, 0 = automatisch ≈ 2,9 m).
Größere Zellen sparen Rechenzeit bei großen Karten; Land aus `LandShape` bleibt dabei exakt.

**`map_size`** legt Länge × Breite der Karte fest (300–3000 m, Standard 1280 × 1280 m,
`map_origin` ist die Ecke links oben). Das Tiefenraster ist rechteckig, die Zellen bleiben
ca. 2,9 m groß; `SeaChart.set_area` wird vor jeder Berechnung mit der Fläche des Levels gesetzt.

**`depth_image`** ersetzt den zufälligen Grund durch ein PNG, das **auf die ganze Karte
gestreckt** wird (egal wie groß das Bild ist). Die Helligkeit (Mittel aus R, G, B, 0–1) wird
linear auf die Tiefe abgebildet: `Tiefe = black + (white − black) · Helligkeit`, mit
`depth_image_invert` umgekehrt. Der Standard (−8 m … 17,5 m) entspricht dem alten
Format `−8 + 0,1·v`. Grenzen: **Land** ab Tiefe < −0,8 m, **flach** unter 1 m (Tiefgang).

Damit keine Pixel- oder Kachelkanten an den Tiefenlinien entstehen, wird nicht linear
abgetastet, sondern **bikubisch** (Catmull-Rom) in Weltmetern; zusätzlich verschiebt ein
Rauschen (`depth_image_warp`, FastNoiseLite, Seed aus `seabed_seed`) die Abtastposition und
`depth_image_noise` addiert feines Tiefenrauschen. Beides ist deterministisch, Rauschen 0
liefert eine glatte Karte. Der Aufbau kostet Zeit: die Standardkarte ca. 1,5 s, eine Karte von 3000 × 3000 m (1 Mio. Zellen) ca. 7 s.
Ein 8-Bit-Bild hat nur 256 Stufen; bei sehr flachen Verläufen
über große Karten sieht man das Rauschen dann als feines Körnchen, nicht als Treppe. Das Bild wird
als Rohdatei gelesen (`FileAccess.get_file_as_bytes` + `Image.load_png_from_buffer`), damit es auch
im exportierten Spiel funktioniert (der Export-Filter nimmt `levels/data/*.png` mit). Erzeugt wird
es mit `tools/chart_to_depth.py` aus einer Seekarte (Land/Wasser nach Farbe, Abstand zur Küste →
Tiefe, Wasserwege verbreitert); die Kieler Förde nutzt das. Untiefen, Inseln, Molen, Landzungen
(kleine lange `ShoalArea`-Inseln) und Leuchttürme liegen darüber.

`@export_storage` speichert den Wert in der Szene, zeigt ihn aber nicht im Inspector (ein
PNG-Bild als Bytes wäre dort unlesbar).

### 2. Bahn auslesen

Das Level sucht seine Kinder nach **Typ** (`is`):

```gdscript
func start_line() -> StartLine:
    for c in get_children():
        if c is StartLine and not c.finish_only: return c
    return null

func finish_line() -> StartLine:        # eigene Ziellinie (Strecke von A nach B) oder null
    for c in get_children():
        if c is StartLine and c.finish_only: return c
    return null

func marks() -> Array[CourseMark]       # Reihenfolge im Szenenbaum = Rundungsreihenfolge!
func shoals() -> Array[ShoalArea]
func fuel_docks() -> Array
```

Und nach **Fähigkeit** (`has_method`): `obstacles()`, `carvers()`, `current_sources()`,
`hazards()`, `danger_circles()`, `danger_zones()`.

| Funktion | Ergebnis |
|---|---|
| `collision_points()` | feste Punkte `[Position, Radius]`: Seezeichen (2,6 m), Marken (1,5 m), Tankstegpfähle, Wrackabschnitte |
| `race_area()` | das Regattagebiet: Bahnumriss plus `area_margin`, geschnitten mit der Karte |
| `course_bounds(margin)` | Rechteck um Start, Startplätze und alle Marken |
| `map_bounds(margin)` | wie oben, zusätzlich Warngebiete und Tankstellen (für Vorschau und Minikarte) |
| `prepare_for_game()` | berechnet das Tiefenraster in voller Auflösung und setzt es global; ruft `prune_trees()` |

### 3. Das Tiefenmodell: `compute_depth(res)`

Das ist die wichtigste Funktion des Levels. Sie liefert ein `PackedFloat32Array` mit
`res × res` Tiefen. In vier Schichten:

```
 Basis        Rauschen: base_depth ± depth_variation, oder im Binnenrevier "Land"
   │  + gemalter Seegrund (depth_paint_png, 128 = unverändert, ±0,15 m je Stufe)
   ▼
 Küsten       Ost/West-Rand, unregelmäßig durch Rauschen, flacht zum Rand ab
   ▼
 Graben       Flüsse und Seen: grid = max(grid, Tiefe)   → Wasser entsteht im Land
   ▼
 Hindernisse  Inseln, Untiefen, Molen, Leuchtturmklippen: grid = min(grid, Profil)  → flacher
```

Zusätzlich gilt das **Schichtenmodell**: Das Raster (Basis, Pinsel, Küsten, Tiefenbild) ist nur
die **Grundlage** für Stellen ohne genauere Angaben. Was spezifischer ist, hat Vorrang:

 * Untiefen, Inseln, Molen: im eigenen **Kern** (Profil flacher als der Tiefgang) gilt die Form
   selbst, solange die Grundlage dort Wasser ist (`grid = Profil`, z. B. eine Untiefe „0,3 m“ über
   einem Grund von 0,1 m); Rasterland bleibt, sonst „flacher gewinnt“.
 * **Landformen** (`LandShape`, nächster Abschnitt) bestimmen die Landgrenze exakt und ersetzen
   die Grundlage in ihrem Gebiet; sie kommen als letzte Schicht.

Der Kern der Hindernis-Schicht (vereinfacht):

```gdscript
for s in obstacles():
    var reach: float = s.reach()                 # so weit wirkt der Baustein
    for j in range(j0, j1 + 1):                  # nur Zellen im Umkreis, nicht das ganze Raster!
        for i in range(i0, i1 + 1):
            var p := amin + Vector2(i + 0.5, j + 0.5) * step
            grid[j * res + i] = minf(grid[j * res + i], s.depth_profile(p + warp))
```

Danach, als **Schicht 5**, werden die `LandShape`-Umrisse in Szenenreihenfolge angewendet
(`lp.apply(p, d)` je Zelle im Gebiet der Form) und an `SeaChart.set_land(polys)` übergeben, damit
`depth_at` die Kante auch zwischen den Rasterpunkten exakt trifft.

**Warum `min`?** Eine Untiefe macht den Grund nur flacher, nie tiefer; zwei überlappende
Inseln ergeben das Flachere von beiden. Bei Flüssen ist es umgekehrt (`max`).

!!! note "Der Warp"
    `ShoalArea` bekommt vor dem Profil einen kleinen Versatz aus Rauschen (`warp`, ±7 m),
    damit die Küstenlinien unregelmäßig wie auf echten Karten aussehen statt rund.

!!! tip "Zwei Auflösungen"
    Im **Spiel** wird mit `SeaChart.RES` (448 Zellen je Kante der Standardkarte; bei anderen Kartengrößen entsprechend `game_res()`) gerechnet, in der **Menü-Vorschau** mit 160 und
    im **Editor** mit 256 (`PREVIEW_RES`), damit das Verschieben flüssig bleibt.

### 4. Seegrund malen

`paint(p, radius, brush, strength)` verändert das Malbild (`Image`, 256×256, `FORMAT_L8`):
Pixelwert 128 heißt „unverändert“, kleiner heißt flacher, größer tiefer. Der Pinsel hat einen
weichen Rand (`smoothstep`). Das Editor-Plugin ruft `begin_stroke()`, `paint()`, `end_stroke()`
auf und nutzt die zurückgegebenen Bytes für Undo/Redo.
→ [Level-Editor-Plugin](editor.md).

## `land_shape.gd` und `land_poly.gd` { #land-shape-gd }

`LandShape` ist ein **`Path3D`**: der Umriss einer Landmasse oder Wasserfläche als geschlossene
Kurve mit Bézier-Griffen (Pfad-Werkzeug des Godot-Editors, Draufsicht Num 7; Punkte ohne Griffe sind
Ecken; der Umriss schließt sich vom letzten zum ersten Punkt). Die Kurve wird in Strecken zerlegt
(`LandPoly.flatten`, Abweichung < 0,04 m) und in einem `LandPoly` gehalten (reine Daten und Rechenregeln,
ohne Szenenbezug, deshalb sicher in `SeaChart` statisch haltbar).

```gdscript
@export var kind := Kind.LAND                 # LAND oder WASSER
@export_range(0.05, 1.0) var shore_slope := 0.22   # m Tiefe je m Abstand vom Ufer
@export_range(10, 300) var zone := 60.0       # Gebietsbreite um das Land, in der die Form die Grundlage ersetzt
@export_range(1.5, 30.0) var water_depth := 8.0    # größte Tiefe einer Wasserform
```

`LandPoly.apply(p, d)` liefert die Tiefe nach der Form; `signed_water(p)` ist der Abstand zur Kante
(positiv auf der Wasserseite):

| Art | innen | außen |
|---|---|---|
| Land | Land (−0,8 m − 0,5 m je m, höchstens −6,8 m), ersetzt die Grundlage | −0,8 m + `shore_slope` · Abstand, im Gebiet `zone` ersetzt, am Rand über 15 m zur Grundlage überblendet |
| Wasser | Wasser (−0,8 m + `shore_slope` · Abstand bis `water_depth`), ersetzt die Grundlage | unverändert |

Die Uferlinie (−0,8 m) liegt damit **exakt** auf dem Umriss, unabhängig von der Rasterzelle.
Mehrere Formen wirken in **Szenenreihenfolge**; ein Wasser-Polygon über einem Land-Polygon ergibt ein
Hafenbecken. LandShapes dürfen auch in einem Gruppen-`Node3D` unter dem Level liegen.

!!! note "Grobes Raster neben dem Becken"
    Das grobe Raster verwischt die Kante eines Wasserbeckens im Land über eine Zelle. Deshalb merkt sich
    jede Wasserform das Raster **vor** ihrer Anwendung (`prepare`, `base_depth`) und nutzt es für die
    Landseite direkt neben dem Becken. Die Streifenbreite `band` wächst mit der Zellgröße.

## `start_line.gd` { #start-line-gd }

Start- und Ziellinie, entlang der lokalen X-Achse, Startrichtung lokal −Z (Pfeil).

```gdscript
func normal2d() -> Vector2      # Startrichtung in der Wasserebene
func tangent2d() -> Vector2     # Richtung der Linie
func signed_dist(p) -> float    # > 0 vor der Linie, < 0 dahinter
func within(p) -> bool          # innerhalb der Linienbreite?
func start_position(i) -> Vector2   # Startplatz i: 30 m hinter der Linie, seitlich versetzt
```

`signed_dist` ist ein **Skalarprodukt**: `(p - center).dot(normal)`. Ein Boot hat die Linie
überquert, wenn das Vorzeichen von `a = signed_dist(alt)` zu `b = signed_dist(neu)` wechselt
und `within(neu)` stimmt (siehe `course.gd`). Das Ziel ist normalerweise **dieselbe Linie** in
Gegenrichtung. Für eine **Strecke von A nach B** (z. B. die Kieler Förde) gibt es eine zweite
`StartLine` mit `finish_only = true`: Sie ist nur das Ziel und wird **in Pfeilrichtung**
überquert; `Level.finish_line()` liefert sie, `Course` trägt sie als `"line"` im letzten Ziel ein
(jedes Linienziel hat seine eigene Linie), und die Beschriftung lautet dann „START“ bzw. „ZIEL“.

Gezeichnet wird eine gestrichelte Linie mit zwei Tonnen an den Enden, ein magenta Pfeil und
die Beschriftung „START / ZIEL“, alles mit `SeaChart.add_line` & Co.

## `course_mark.gd` { #course-mark-gd }

Gelbe Sondertonne (INT 1, Kreuz oben). Wichtige Konstanten:

```gdscript
const MARK_RADIUS := 20.0     # in diesen Kreis muss man fahren, um zu runden
const YELLOW := Color(0.98, 0.82, 0.1)
```

Das Boot wippt (`_process`: Sinus auf `position.y`, `rotation.x/z`). Im Editor beschriftet die
Marke sich mit ihrer Nummer: `order_number()` = Position in `Level.marks()`. Wird sie im
Szenenbaum verschoben (`NOTIFICATION_MOVED_IN_PARENT`), bauen sich **alle** Marken neu.

## `shoal_area.gd` { #shoal-area-gd }

Der vielseitigste Baustein. `enum Kind { UNTIEFE, INSEL, SEE }`. Form ist ein Kreis mit
`radius`; durch **Skalieren und Drehen des Nodes** wird daraus eine Ellipse (das Profil wird
in lokale Koordinaten zurückgerechnet: `_inv * Vector3(p.x, 0, p.y)`).

```gdscript
func depth_profile(p: Vector2) -> float:
    var l := _inv * Vector3(p.x, 0, p.y)
    var k := Vector2(l.x, l.z).length() / radius          # 0 = Mitte, 1 = Rand
    if kind == Kind.INSEL:
        return SeaChart.LAND + (k - 1.0) * radius * 0.22   # Ufer bei k=1, Böschung 1:4,5
    return center_depth + k * k * (SeaChart.DRAFT - center_depth)   # Untiefe: Parabel
```

* **Untiefe:** in der Mitte `center_depth` (0,3 m), am Rand genau 1 m (Tiefgang), dazwischen eine
  Parabel.
* **Insel:** Am Rand liegt die Uferlinie (`LAND`), nach innen wird es Land, nach außen fällt
  die Böschung um 1 m je 4,5 m ab.
* **See:** im Binnenrevier; `carves()` ist `true`, `carve_grid` gräbt Wasser.

Dekoration von Inseln (`_build_island_deco`): Uferfelsen als `MultiMesh` (`Deco.rocks`), Häuser
und Bäume an freien Plätzen (`_free_spot` versucht 12× eine Position mit Mindestabstand).
Der Zufall ist über `rng.seed` aus Radius, Baumzahl, Hauszahl und Namen **fest**, damit jeder
Rechner dieselbe Insel zeichnet.

!!! note "Warum `_vis` mit `top_level`?"
    Die Symbole und Beschriftungen hängen an einem Hilfsnode `_vis`, der `top_level = true` ist:
    Er erbt Drehung und Skalierung der Insel **nicht**. Sonst wäre die Schrift verzerrt, wenn man
    die Insel zur Ellipse streckt.

## `sea_mark.gd` { #sea-mark-gd }

Seezeichen nach IALA-Region A. `enum Kind { NORD, OST, SUED, WEST, EINZELGEFAHR, ROT, GRUEN,
ANSTEUERUNG }`. Eine Tabelle `SPECS` beschreibt jede Art (Farbbänder von unten nach oben,
Toppzeichen, Kartenkürzel, Feuer, Form). `_rebuild()` schichtet daraus Zylinder und Kegel.
Boote prallen ab (`RADIUS = 2.6`; `Level.collision_points()` sammelt die Punkte).

## `mole.gd` { #mole-gd }

Felsmole entlang der lokalen X-Achse von −Länge/2 bis +Länge/2. `depth_profile` berechnet den
Abstand zu diesem **Liniensegment** (`clampf` auf die Länge, dann `Vector2.length()`), zieht die
halbe Breite ab und liefert innerhalb Land (`LAND − 2`), außerhalb einen steilen Steinfuß
(+1,6 m Tiefe je Meter Abstand). `enum HeadLight { KEINES, ROT, GRUEN, WEISS }` setzt ein
Molenfeuer an den Kopf; `light_text()` liefert die Kennung für die Karte.

## `lighthouse.gd` { #lighthouse-gd }

Leuchtturm auf Felsklippe, `enum Style` für vier Farbschemata, drehender Lichtkegel
(`Deco.beam`) in `_process`. Die Klippe wirkt über `depth_profile` wie eine kleine Insel mit
parabelförmigem Profil: `4 · (k² − 1) + LAND`, mit `k` = Abstand zur Mitte geteilt durch
`rock_radius`.

## `chart_rose.gd` { #chart-rose-gd }

Nur Dekoration: ruft `SeaChart.build_compass_rose(_vis, radius)`.

## `fuel_dock.gd` { #fuel-dock-gd }

Tankstelle: Holzsteg vom Ufer ins Wasser (lokal −Z), Zapfsäule, Kassenhäuschen, Schild.

```gdscript
const ZONE := 13.0                       # Radius des Liegeplatzes
func berth() -> Vector2                  # Liegeplatz am Stegkopf (lokal (-7, 0, -length+4))
func collision_points() -> Array         # Pfähle alle 3 m, Radius 1,8: der Steg ist fest
```

`main.gd` ruft `boat.refuel(delta)`, solange ein Boot näher als `ZONE` am `berth()` liegt.
Im Editor setzt man die **Wurzel** (lokaler Ursprung) an Land, der Pfeil zeigt ins Wasser.

!!! warning "Platzierung testen"
    `tests/level_check.gd` prüft: Stegwurzel an Land (`depth_at(root) ≤ 0,5`) und Liegeplatz in
    mindestens 2 m Wasser. Wer die Tankstelle zu nah ans Ufer setzt, bekommt Grundberührungen
    beim Anlegen.

## `deco.gd` { #deco-gd }

Hilfsklasse (`RefCounted`, `@tool`) für Landschaft im Spielzeugstil, alle Funktionen `static`:

| Funktion | Ergebnis |
|---|---|
| `rocks(parent, items, seed)` | viele Felsbrocken als **ein** `MultiMesh` (ein Zeichenaufruf) |
| `tree(parent, pos, rng)` | Baum: Kiefer (zwei Kegel) oder Laubbaum (Kugel) |
| `house(parent, pos, rot, rng)` | Häuschen mit Satteldach und Tür |
| `tower(parent, bands, height, radius, lamp)` | Turm aus Farbbändern, Galerie, Laterne |
| `beam(parent, y, length, color)` | additiv gemischter, drehbarer Lichtfächer |

## Beispiel: Ein Mini-Level von Hand bauen

So legt man ein Level **im Code** an (genau das macht `tools/make_levels.gd`):

```gdscript
var l := Level.new()
l.name = "Level"
l.level_name = "Testbahn"
l.wind_from_deg = 0.0                       # Nordwind

var line := StartLine.new()
line.name = "StartZiel"
line.half_width = 40.0
l.add_child(line)

var m := CourseMark.new()
m.name = "Luvtonne"
m.mark_name = "Luvtonne"
m.position = Vector3(0, 0, -300)            # 300 m nach Norden
l.add_child(m)

var bank := ShoalArea.new()
bank.name = "Sandbank"
bank.area_name = "Sandbank"
bank.radius = 30.0
bank.position = Vector3(60, 0, -150)
l.add_child(bank)

# als Szene speichern
for c in l.get_children():
    c.owner = l                              # sonst wird das Kind nicht mitgespeichert!
var ps := PackedScene.new()
ps.pack(l)
ResourceSaver.save(ps, "res://levels/99_test.tscn")
```

Danach erscheint „Testbahn“ automatisch im Menü (`GameState.list_levels()` liest den Ordner).
Mehr in [Eigene Bahnen bauen](../referenz/bahnen-bauen.md).
