# Design

## Context

`Level.depth_image` wird in `_base_grid(res)` eingelesen (`_load_depth_image()`: Rohdatei per
`FileAccess` + `Image.load_png_from_buffer`, damit es auch im exportierten Spiel geht) und bilinear in
das Tiefengitter abgetastet. Die Zuordnung ist fest (`-8 + v · 0,1`, Kanal R). Die Kartenfläche ist
global fest: `SeaChart.AREA_MIN = (-640, -840)`, `AREA_SIZE = 1280` (quadratisch), das Gitter
`SeaChart.RES = 448` quadratisch. Diese Konstanten stecken in `Level` (`compute_depth`, Malbild,
`race_area`, Vorschaugitter), `ShoalArea.carve_grid`, `RiverChannel`, `SeaChart` (Tiefe lesen, Shader,
Textur), `Boat` (Kartenrand) und in Tests/Werkzeugen.

## Goals / Non-Goals

**Goals:**
- Zuordnung Grau → Tiefe einstellbar; Kartengröße (Breite × Länge) pro Level einstellbar; Bild wird
  skaliert; glatte, verrauschte Abtastung ohne Kachelmuster; bestehende Level bleiben spielbar.
- Rauschen deterministisch, unabhängig von der Gitterauflösung und vom Rechner.

**Non-Goals:**
- Keine 16-Bit-Auswertung (Godot lädt 8 Bit je Kanal), keine Paletten/Kurven, kein Mischen mehrerer
  Bilder, keine Änderung des Pinsels außer der Skalierung auf die neue Fläche.
- Keine unendlichen Karten: Obergrenze 3000 m je Seite.

## Decisions

1. **Level-Felder** (Gruppe „Tiefenbild“/„Karte“): `map_size: Vector2` (Standard 1280 × 1280),
   `map_origin: Vector2` (Nordwestecke, Standard (−640, −840), damit alle vorhandenen Level
   unverändert bleiben), `depth_image_black` (Standard −8,0 m), `depth_image_white` (Standard
   +17,5 m), `depth_image_invert` (aus), `depth_image_warp` (Verschiebung der Abtastung in Metern,
   Standard 2,0), `depth_image_noise` (Tiefenrauschen in Metern, Standard 0,25). Alternative:
   `depth_image_rect`/Außentiefe – verworfen; das Bild füllt immer die ganze Karte (einfacher, passt
   zu „wird entsprechend skaliert“).
2. **Kartenfläche pro Level statt Konstante:** `SeaChart.AREA_MIN`/`AREA_SIZE` werden zu statischen
   Variablen `area_min: Vector2`, `area_size: Vector2`, gesetzt vom Level (in `prepare_for_game()` und
   vor jeder Vorschau-Berechnung). Das Tiefengitter wird rechteckig `grid_w × grid_h`; Zellgröße
   etwa 2,86 m wie bisher, höchstens 1024 Zellen je Achse (bei großen Karten wachsen die Zellen).
   Alternative: weiter quadratisches Gebiet und nur das Bild skalieren – verworfen, weil Länge und
   Breite ausdrücklich einstellbar sein sollen.
3. **Anzupassen:** `SeaChart` (Lesen der Tiefe mit `area_min`/`area_size` und `grid_w/h`, Textur,
   Shader-Parameter `area_min`, `area_size` als `vec2`, Zeichenfläche), `Level.compute_depth`,
   `_base_grid`, `race_area`, Malbild-Zuordnung (`PAINT_RES` bleibt quadratisch und wird über die
   Karte gestreckt), `ShoalArea.carve_grid`, `RiverChannel`, `Boat` (Kartenrand aus
   `area_min`/`area_size`), `make_map_image` (Menü/Minimap), Tests/Werkzeuge. Die Kartenränder sind
   überall über zwei Hilfsfunktionen `SeaChart.area_rect()` und `SeaChart.cell_size(res)` erreichbar.
4. **Abtasten:** Für eine Weltposition `p` (Zellmitte): Verschiebung `p' = p + warp(p)` mit
   `warp` = 2D-Rauschen (FastNoiseLite, Seed `seabed_seed`, Frequenz ~0,02/m, Amplitude
   `depth_image_warp`). Danach Bildkoordinate `uv = (p' − map_origin) / map_size`, Pixel =
   `uv · Bildgröße`, **bikubisch** (Catmull-Rom über 4 × 4 Pixel, Ränder geklemmt) statt bilinear;
   Helligkeit = Mittel von R, G, B. Tiefe = `lerp(black, white, t)` (bzw. umgekehrt) +
   `noise(p) · depth_image_noise` mit zweitem Rauschen (Frequenz ~0,15/m). Weil beides in **Weltmetern**
   gerechnet wird, hängt das Ergebnis nicht von der Gitterauflösung ab, und es ist auf allen
   Rechnern gleich. Alternative: nur Rauschen auf bilinear – verworfen, weil die Pixelkanten
   (Kacheln) sonst als Linien bleiben; Bikubisch plus Verschiebung bricht sie auf.
5. **Cache:** `_base_cache` und die Vorschau werden bei jeder Änderung eines Feldes geleert
   (Setter + `queue_preview()`), auch für die Menü-Vorschau (`compute_depth` mit kleinem Gitter).
6. **Werkzeug:** `tools/chart_to_depth.py` bekommt `black`/`white`, schreibt Karte in der
   Zielgröße und meldet die Zuordnung; Standardwerte wie im Level.
7. **Fehlerfälle:** unlesbares Bild → Warnung und zufälliger Grund wie bisher; Karte außerhalb
   300–3000 m → Wert wird auf den Bereich begrenzt (Warnung im Editor).

## Risks / Trade-offs

- Größerer Umbau (zentrales Kartenmaß) → Regressionsrisiko; Gegenmaßnahme: Standardwerte
  reproduzieren das alte Verhalten, vorhandene Level-Tests, `level_check`, KI-Läufe und Screenshots vor
  und nach dem Umbau.
- Bikubisch + Rauschen verändern die Küste leicht (Meter) → in der Doku genannt; bestehende Level
  werden mit denselben Schwellen (Land < −0,8 m, flach < 1 m) erneut mit `level_check` geprüft.
- Große Karten (bis 3000 m) kosten Rechenzeit beim Aufbau (GDScript-Schleife über das Gitter, bis
  1024²) → Aufbau einmal beim Laden, Obergrenze begrenzt die Kosten; Messung im Test.
- 8 Bit → 256 Stufen: bei sehr großem Wertebereich wird die Tiefe grob; das Tiefenrauschen
  verdeckt Stufen teilweise, die Doku rät zu passendem Wertebereich.
