# Seekarte und Tiefen (`sea_chart.gd`)

Datei: `scripts/sea_chart.gd`, `class_name SeaChart`, `extends Node3D`, `@tool`.
Etwa 420 Zeilen. Es hat **drei Aufgaben**:

1. Das **Tiefenraster** halten und abfragen (`static`): die Spiellogik.
2. Die **Karte zeichnen**: ein Shader auf einer großen Fläche.
3. **Zeichenhilfen** (Linien, Ringe, Beschriftungen) für alle Level-Bausteine.

## Das Tiefenraster

```gdscript
const AREA_MIN := Vector2(-640, -840)   # Ecke links oben (x, z) in Metern
const AREA_SIZE := 1280.0               # Kantenlänge der Karte
const RES := 448                        # Zellen pro Kante (Zelle ≈ 2,86 m)
const DRAFT := 1.0      # Tiefgang: flacher = Grundberührung
const HARD := 0.55      # flacher = festgefahren
const LAND := -0.8      # tiefer als das = festes Land

static var _depth := PackedFloat32Array()   # RES*RES Tiefen in m, Zeile = z, Spalte = x
static var _res := 0
```

Alle Welten liegen innerhalb dieser einen Karte von 1,28 km Kantenlänge. Jedes Level
berechnet seine Tiefen selbst (`Level.compute_depth`, siehe [Level](level.md#level-gd)) und
übergibt sie hier:

```gdscript
static func set_depth_grid(grid: PackedFloat32Array, res: int) -> void
```

### Die Tiefenzonen

| Tiefe `d` | Bedeutung | Farbe auf der Karte |
|---|---|---|
| `d < -0.8` (`LAND`) | festes Land | gelblich |
| `-0.8 … 0` | trockenfallend (Watt) | grün |
| `0 … 1,0` | flach: Grundberührung (`DRAFT`) | kräftig blau |
| `1 … 2` | flach, aber befahrbar | kräftig blau |
| `2 … 5` | | hellblau |
| `5 … 10` | | blassblau |
| `> 10` | tiefes Wasser | fast weiß |

Dieselben Grenzwerte stehen **zweimal**: in `depth_color()` (für Menü und Minikarte, CPU)
und im Shader (für die große Karte, GPU). Ändert man sie, muss man beide anfassen.

### `depth_at(p)`: bilineare Abfrage

```gdscript
static func depth_at(p: Vector2) -> float:
    var f := (p - AREA_MIN) / AREA_SIZE * _res - Vector2(0.5, 0.5)   # Rasterkoordinate
    if f.x < 0.0 or f.y < 0.0 or f.x >= _res - 1 or f.y >= _res - 1:
        return 20.0                                                   # außerhalb: tief
    var i := int(f.x)
    var j := int(f.y)
    var fx := f.x - i                  # Nachkommaanteil = Mischfaktor
    var fy := f.y - j
    var a := lerpf(_depth[j * _res + i], _depth[j * _res + i + 1], fx)
    var b := lerpf(_depth[(j + 1) * _res + i], _depth[(j + 1) * _res + i + 1], fx)
    return lerpf(a, b, fy)
```

**Warum `- Vector2(0.5, 0.5)`?** Eine Zelle repräsentiert ihre *Mitte*. Position `p` liegt
zwischen den Mittelpunkten von vier Zellen; zieht man 0,5 ab, wird `i` die linke obere dieser vier.

**Beispiel:** Wer fragt alles `depth_at`?

| Aufrufer | Wofür |
|---|---|
| `boat.gd` | Grundberührung, Land, Gebietsgrenze |
| `wind_field.gd` | Landschatten (Strahl gegen den Wind) |
| `tug.gd` | Startpunkt im tiefen Wasser suchen |
| `ai_input.gd` | Wegplanung (A\*-Raster) und Gefahrenstrahl |
| `river_channel.gd` | Uferbäume auf Land setzen |

### Weitere statische Helfer

| Funktion | Zweck |
|---|---|
| `find_deep_water(from, min_depth, max_radius)` | Spiralförmig nach dem nächsten Punkt mit genug Wasser suchen (Schlepper) |
| `path_clear(a, b)` | Ist die Strecke frei von Land? (alle 4 m geprüft) |
| `make_map_image(min, max, w, h)` | Kleines Farbbild für Minikarte und Menü-Vorschau |
| `depth_color(d)` | Papierfarbe zur Tiefe |

## Der Kartenshader

`CHART_SHADER` (ein langer String am Dateiende) ist ein Godot-Shader (`shader_type spatial;
render_mode unshaded;`, also unbeleuchtet wie Papier). Das Tiefenraster wird als
Float-Textur (`Image.FORMAT_RF`) in die Grafikkarte geladen:

```gdscript
var img := Image.create_from_data(_res, _res, false, Image.FORMAT_RF, _depth.to_byte_array())
_depth_tex = ImageTexture.create_from_image(img)
material.set_shader_parameter("depth_tex", _depth_tex)
```

Im Shader (`fragment()`) passiert pro Bildpunkt:

1. Weltposition `wpos.xz` → Textur-Koordinate `uv`, Tiefe `d = texture(depth_tex, uv).r`.
2. Farbe nach Tiefenstufe (`if (d < 10.0) col = c_d10; …`).
3. **Kartennetz** alle 100 m (nur über Land) mit `fract`.
4. **Böen** als Riffel-Schraffur quer zum Wind, gesteuert von `gust_tex`.
5. **Tiefenlinien** bei 2, 5, 10 und 20 m, Küstenlinie bei 0 und −0,8 m. Die Funktion
   `iso(d, level, width)` zeichnet eine Linie genau dort, wo `d` den Wert `level` kreuzt –
   mit `fwidth(d)` sorgt sie für konstante Linienbreite in Pixeln.

!!! note "Warum ein Shader?"
    Die Alternative wäre, für jede Zelle ein Rechteck zu zeichnen. Der Shader malt dagegen
    scharfe, bildschirmgenaue Linien auf **eine** Fläche von 4000×4000 m (`PlaneMesh`), ist
    nur ein einziger Zeichenaufruf und bleibt bei jedem Zoom sauber.

### Weitere Parameter des Shaders

| Uniform | Setzt | Zweck |
|---|---|---|
| `depth_tex`, `area_min`, `area_size` | `refresh()` | Tiefenraster |
| `gust_tex`, `gust_min`, `gust_size` | `set_gust_texture()` | Böenfeld vom `WindVisuals` |
| `wind_blow` | `set_wind()` | Richtung der Riffel |
| `paint_delta`, `use_paint_delta` | `set_paint_delta()` | Live-Vorschau beim Malen im Editor |

## Lotungen (Tiefenzahlen)

`_build_soundings()` streut im Abstand von 38 m (mit etwas Zufall, fester `seed`) kleine
`Label3D`s auf die Karte: ganze Meter groß, Dezimale tiefgestellt. Das gibt den typischen
Seekartenlook.

## Hilfsfunktionen zum Zeichnen

Alle Level-Bausteine bauen ihre Symbole mit diesen `static`-Funktionen. Beispiel: Eine
gestrichelte Kreislinie in Magenta.

```gdscript
var st := SurfaceTool.new()
st.begin(Mesh.PRIMITIVE_TRIANGLES)
SeaChart.add_ring(st, Vector2.ZERO, 20.0, 0.35, 0.08, 72, true)   # Mitte, Radius, Breite, Höhe, Segmente, gestrichelt
parent.add_child(SeaChart.mesh_from(st, SeaChart.MAGENTA))
```

| Funktion | Beschreibung |
|---|---|
| `add_line(st, a, b, width, y)` | ein Rechteck als zwei Dreiecke von `a` nach `b` |
| `add_ring(st, c, r, width, y, segments, dashed)` | Kreis aus Liniensegmenten |
| `add_triangle(st, a, b, c, y)` | gefülltes Dreieck |
| `ink_material(color)` | unbeleuchtetes, doppelseitiges Material (mit Alpha, wenn nötig) |
| `mesh_from(st, color)` | `SurfaceTool` → fertige `MeshInstance3D` ohne Schatten |
| `flat_label(text, size, color, italic, bold)` | flach auf dem Wasser liegendes `Label3D` (Oberkante nach Norden) |
| `font(italic, bold)` | Serifenschrift per `SystemFont` mit Rückfallkette |
| `build_compass_rose(parent, r)` | Kompassrose mit Skala und Stern |
| `build_lighthouse(parent, characteristic)` | Turm aus vier Zylindern, Lampe, Lichtfächer |

Die Höhen `y` (0,065 bis 0,1) sind winzig verschieden, damit sich übereinanderliegende
Symbole nicht gegenseitig flackern lassen (**Z-Fighting**).

## Nachbau-Tipp

Beginne mit `depth_at` und einem einfachen `StandardMaterial3D` mit Textur
([Fahrplan, Etappe 2](../nachbauen/fahrplan.md#etappe-2-die-seekarte-als-tiefenraster)). Den
Shader fügst du erst später hinzu: Er ist reine Optik, die Spiellogik funktioniert ohne ihn.
