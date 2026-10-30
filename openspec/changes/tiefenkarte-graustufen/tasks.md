# Tasks

## 1. Kartenfläche pro Level

- [x] 1.1 `SeaChart`: `area_min`/`area_size` (Vector2) statt Konstanten, rechteckiges Tiefengitter (`grid_w`, `grid_h`), Hilfsfunktionen `area_rect()` und `cell_size()`; Tiefe lesen, Textur und Shader (`vec2 area_size`) angepasst
- [x] 1.2 `Level`: `map_size`, `map_origin` (Standard wie bisher, Begrenzung 300–3000 m), setzen die Kartenfläche vor Berechnung und Vorschau; `race_area`, Gitterberechnung, Malbild-Zuordnung angepasst
- [x] 1.3 `ShoalArea.carve_grid`, `RiverChannel`, `Boat` (Kartenrand), `make_map_image`/Minimap/Menü-Vorschau auf die neue Fläche umstellen

## 2. Tiefenbild

- [x] 2.1 `Level`: Felder `depth_image_black`, `depth_image_white`, `depth_image_invert`, `depth_image_warp`, `depth_image_noise` (Standardwerte wie im Design, Setter leeren Cache und aktualisieren die Vorschau)
- [x] 2.2 `_base_grid`: Abtasten in Weltmetern mit Verschiebung durch Rauschen, bikubische Interpolation, Helligkeit = Mittel R, G, B, lineare Zuordnung mit Invert, Tiefenrauschen; deterministisch über `seabed_seed`; Fehlerfälle
- [x] 2.3 Editor-Plugin: Felder im Inspector gruppiert (Karte, Tiefenbild), Vorschau reagiert auf Änderungen

## 3. Werkzeuge und Level

- [x] 3.1 `tools/chart_to_depth.py`: Parameter `black`/`white`, Größe, Meldung der Zuordnung
- [x] 3.2 `tools/make_levels.gd`: Kieler Förde setzt Zuordnung, Kartengröße und Rauschen ausdrücklich; Küste/Tiefe prüfen (`level_check`)

## 4. Tests und Doku

- [x] 4.1 `tests/depth_image_test.gd`: Zuordnung (0/128/255, Farbe), Invert, Karte 2000 × 800 m mit gestrecktem Bild, Standardkarte unverändert, Determinismus (zwei Läufe gleich), Rauschen 0 = glatt
- [x] 4.2 Kachelmuster prüfen: grobes Testbild (z. B. 16 × 16) auf große Karte, Tiefenkarte als Bild ausgeben (`tests/depth_png.gd`) und Pixelkanten vergleichen
- [x] 4.3 Regression: alle Level (`level_check`), Hazard-Tests, KI-Läufe und Screenshots vor/nach dem Umbau; Messung der Aufbauzeit großer Karten
- [x] 4.4 Doku: `docs/skripte/level.md`, `docs/skripte/seekarte.md`, `docs/referenz/bahnen-bauen.md` (Format, Felder, Beispiel, Schwellenwerte, Hinweis 8 Bit), `docs/skripte/werkzeuge.md`
- [x] 4.5 `mkdocs build --strict` ohne Warnung (ohne `-q` prüfen), `openspec validate tiefenkarte-graustufen`
