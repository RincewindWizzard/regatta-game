# Design

## Context

`SeaChart.depth_at(p)` liest bilinear das Tiefengitter (Zellen ≈ 2,9 m); alles, was Land ist
(Boot, KI, Wind, Karte), entscheidet über `depth < LAND` (−0,8 m). Ein Polygon dazu zu rastern
würde die Kante auf die Zellgröße verschmieren. Gleichzeitig soll die Tiefe darunter gröber
rechenbar sein.

## Goals / Non-Goals

**Goals:** exakte Küstenform per Polygon; Boot/KI/Wind/Karte nutzen sie; Editor-Bearbeitung ohne
neues Fremdwerkzeug; grobere Tiefenzellen einstellbar; bestehende Level unverändert.

**Non-Goals:** keine Bézier-Kurven (Polygone mit vielen Punkten genügen), keine echte 3D-Küstengeometrie,
keine Höhen (Land bleibt flach), kein Import von GIS-Formaten außer SVG.

## Decisions

1. **Eckpunkte als `Marker3D`-Kinder.** `LandShape` (Node3D, `@tool`) liest die Position seiner
   `Marker3D`-Kinder (x, z, in Reihenfolge der Kinder) als Polygon. Verschieben, Duplizieren und
   Löschen geht mit den Bordmitteln des Godot-Editors, ohne eigenes Gizmo. Der Umriss wird im Editor
   als Linie gezeichnet. Mindestens 3 Punkte, selbstüberschneidende Polygone werden mit `even-odd`
   ausgewertet und im Editor mit einer Warnung (`_get_configuration_warnings`) markiert.
2. **Felder:** `kind` (LAND | WASSER), `shore_slope` (Meter Grundanstieg pro Meter, Standard wie bei
   Inseln, 0,22 → 1 m Tiefe auf ≈ 4,5 m), `shore_rocks`/`trees`/`houses` entfallen im ersten Schritt
   (Deko kann man über vorhandene Bausteine setzen).
3. **Tiefenfunktion exakt.** `LandShape.depth_profile(p)` liefert: im Polygon (Art Land)
   `LAND − Abstand_zur_Kante · 0,5`; außerhalb `LAND + Abstand · shore_slope · 1,0`, gedeckelt auf
   die Reichweite. Die Kante selbst ist exakt `LAND`. Art Wasser gräbt: im Polygon Tiefe der
   Umgebung bzw. mindestens `see_depth`, am Rand Übergang wie `ShoalArea.carve_grid`. Alle Formen
   werden in Kindreihenfolge angewendet, dadurch sind Löcher (Wasser über Land) möglich.
4. **Zwei Wege in `depth_at`:**
   a) *Raster*: `Level.compute_depth` bezieht die Formen wie Inseln ein (`minf` für Land,
      Ausgrabung für Wasser). Das ergibt das grobe Tiefenfeld.
   b) *Exakt*: `SeaChart` hält die Liste der Formen (statisch, gesetzt von `Level`, mit
      Begrenzungsrechteck + Spatial-Check). `depth_at(p)` = Raster; liegt `p` im Begrenzungsrechteck
      einer Form, wird zusätzlich `shape.depth_profile(p)` ausgewertet und das Ergebnis dort
      verwendet (Land: `minf`, Wasser: Land wird nur innerhalb des Polygons aufgehoben).
   So bleibt die Kante unabhängig von der Rasterweite. Aufwand pro Aufruf: ein Rechtecktest je Form,
   nur nahe Formen kosten Polygonabstand (O(Eckpunkte)).
5. **Scharfe Karte.** Zusätzlich zur Tiefentextur bekommt der Shader eine **Land-Distanztextur**
   (RF, Meter mit Vorzeichen, Zellgröße 1 m, nur über der Vereinigung der Begrenzungsrechtecke,
   höchstens 2048 × 2048). Der Shader nimmt dort die Uferlinie aus dieser Textur (Nulldurchgang,
   Smoothstep über ein Pixel), außerhalb weiter die Rastertiefe. Rote 1-m-Tiefenlinie bleibt am Raster.
   Die Textur wird im Tiefenaufbau gerechnet (Abstand Punkt–Polygon), im Editor mit gröberer Zelle.
6. **Zellgröße:** `Level.depth_cell` (m, 2–10, Standard 0 = wie bisher automatisch ≈ 2,9 m)
   ersetzt `game_res()`-Ableitung nur wenn gesetzt. Die Menü-Vorschau (160) und der Editor (256)
   bleiben unverändert grob.
7. **Küsten mischen.** Zufallsküsten (`coast_east/west`) und Tiefenbild bleiben; bei `LandShape`
   auf einer Küstenlinie gewinnt das Polygon (Land per `minf`, Wasser hebt Land nur im Polygon auf).
8. **SVG-Werkzeug.** `tools/svg_to_land.py` liest `<polygon>`/`<path>` (M/L/Z, Kurven werden in
   Linien zerlegt), skaliert auf `map_size`, schreibt eine `.tscn` mit `LandShape` + `Marker3D`-Kindern.

## Risks / Trade-offs

- `depth_at` wird häufig gerufen (KI) → Begrenzungsrechtecke und früher Ausstieg, Polygonabstand nur
  innerhalb der Reichweite; Messung in den Tests.
- Zwei Quellen für die Tiefe (Raster + Formen) können sich am Rand um die Rasterweite unterscheiden →
  Raster wird mit denselben Formen gefüllt, nur die Kante selbst ist exakt.
- Kind-Knoten als Eckpunkte sind für 100+ Punkte unhandlich → SVG-Import deckt das ab.

## Migration

Keine; ohne `LandShape` und `depth_cell` ändert sich nichts.
