## Why

Land entsteht heute nur aus dem Tiefenraster (Zellen ≈ 2,9 m), aus Kreis-Inseln, Molen und dem
Zufallsrauschen der Küste. Für manche Level – nachgebaute Reviere, Häfen, enge Fahrwasser – müssen die
Umrisse der Landmassen **exakt** stimmen. Das Raster kann das nicht: Kanten sind unscharf, Ecken
rund, und eine feinere Auflösung für die ganze Karte wäre zu teuer. Die Wassertiefe dagegen braucht
keine hohe Auflösung.

## What Changes

- Neuer Level-Baustein **`LandShape`**: ein Polygon aus Eckpunkten, im Editor als Kind-Knoten
  (`Marker3D`) frei verschiebbar, einfügbar und löschbar. Art **Land** (festes Land) oder **Wasser**
  (gräbt Wasser aus, z. B. Hafenbecken, See im Binnenrevier). Mehrere Formen pro Level, auch mit Löchern
  (Wasser-Form über Land-Form).
- Der Umriss ist **exakt**: Boote, KI, Wind-Abschattung und Zeichnung der Seekarte prüfen die
  Kante gegen das Polygon, nicht gegen das Raster. Landkante = Uferlinie (Tiefe −0,8 m), von dort
  fällt der Grund mit festem Gefälle ab wie bei Inseln.
- Die Seekarte zeichnet die Uferlinie scharf über eine fein aufgelöste Land-Distanztextur
  (nur im Bereich der Formen), die Tiefenfarben bleiben auf dem groben Raster.
- Neue Level-Option **`depth_cell`** (Zellgröße des Tiefenrasters, 2–10 m, Standard wie bisher ≈ 2,9 m):
  die Unterwasser-Tiefen dürfen gröber gerechnet werden, das spart bei großen Karten Zeit.
- Editor-Plugin: Knopf „Landform“ legt ein Polygon mit vier Eckpunkten an, Umriss im Editor sichtbar.
- Werkzeug `tools/svg_to_land.py`: wandelt Pfade/Polygone aus einer SVG-Datei in `LandShape`-Knoten
  (optional, für das Nachzeichnen von Karten).
- Doku und Tests.

Keine Änderung für vorhandene Level: ohne `LandShape` bleibt alles wie bisher.

## Capabilities

### New Capabilities
<!-- keine -->

### Modified Capabilities
- `levels`: Landmassen als Vektor-Polygone, einstellbare Zellgröße des Tiefenrasters
- `karte`: scharfe Uferlinie der Seekarte aus den Vektorformen

## Impact

- Neu: `scripts/level/land_shape.gd`, `tools/svg_to_land.py`, `tests/land_shape_test.gd`
- Geändert: `scripts/sea_chart.gd` (`depth_at` + Land-Textur + Shader), `scripts/level/level.gd`
  (`depth_cell`, Formen im Tiefenmodell, Land-Textur), `addons/regatta_editor/plugin.gd`,
  `tests/level_check.gd`, Doku (`level.md`, `seekarte.md`, `bahnen-bauen.md`, `werkzeuge.md`)
