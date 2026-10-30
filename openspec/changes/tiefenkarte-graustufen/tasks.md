# Tasks

## 1. Level

- [ ] 1.1 `Level`: neue Felder `depth_image_black`, `depth_image_white`, `depth_image_invert`, `depth_image_rect`, `depth_image_outside` (Gruppe „Tiefenbild“, Standardwerte wie bisher), Setter leeren den Cache und aktualisieren die Vorschau
- [ ] 1.2 `_base_grid`: Helligkeit (Mittel R, G, B), lineare Umrechnung mit Invert, Abtasten über das Weltrechteck, Außentiefe, Fehlerfälle (Bild unlesbar, Größe 0)

## 2. Werkzeuge und Level

- [ ] 2.1 `tools/chart_to_depth.py`: Parameter `black` und `white` statt fester Werte, Ausgabe der verwendeten Zuordnung
- [ ] 2.2 `tools/make_levels.gd`: Kieler Förde setzt Schwarz-/Weißwert ausdrücklich; Seegrund bleibt unverändert (Vergleich der Tiefengitter)

## 3. Tests und Doku

- [ ] 3.1 `tests/depth_image_test.gd`: erzeugt kleine PNGs (Graustufen, Farbe, andere Auflösung), prüft Zuordnung (0/128/255), Invert, Teilrechteck mit Außentiefe und dass der Kieler-Förde-Grund unverändert bleibt
- [ ] 3.2 Doku: `docs/skripte/level.md`, `docs/referenz/bahnen-bauen.md` (Format, Felder, Beispiel, Schwellenwerte, Hinweis 8 Bit), `docs/skripte/werkzeuge.md`
- [ ] 3.3 `level_check.gd` und Hazard-Tests laufen weiter; `mkdocs build --strict` ohne Warnung; `openspec validate tiefenkarte-graustufen`
