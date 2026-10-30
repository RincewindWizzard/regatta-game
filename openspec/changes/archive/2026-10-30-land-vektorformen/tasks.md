# Tasks

## 1. LandShape-Baustein

- [x] 1.1 `scripts/level/land_shape.gd` (`@tool`, `class_name LandShape extends Path3D`): `kind` (LAND/WASSER), `shore_slope`, `zone`; `Curve3D` mit Bézier-Griffen → zerlegter Umriss (eigene Bézier-Zerlegung `LandPoly.flatten`, Abweichung < 0,04 m), zwischengespeichert, Neuaufbau bei `Curve3D.changed`/Transformänderung; Rechenregeln in `scripts/level/land_poly.gd` (Begrenzungsrechteck, Abstand mit Vorzeichen even-odd, `apply(p, d)`)
- [x] 1.2 Editor: Umriss sichtbar (Pfad-Editor von Godot, zusätzlich gezeichnete Linie), `_get_configuration_warnings` (< 3 Punkte, Selbstüberschneidung), Vorschau reagiert beim Ändern der Kurve
- [x] 1.3 Symbol (`addons/regatta_editor/icons/land.svg`)

## 2. Tiefenmodell (Schichten)

- [x] 2.1 `Level.compute_depth` nach dem Schichtenmodell: Grundlage (Bild/Zufall/Pinsel/Zufallsküste), dann alle Formen in Szenenreihenfolge; im Gebiet einer Form ersetzt ihr Profil die Grundlage, `smoothstep`-Überblendung (≈ 15 m) am Gebietsrand; Reichweite/Begrenzung
- [x] 2.2 Vorhandene Formen (`ShoalArea`, Insel, `Mole`, Leuchtturm, `RiverChannel`) auf das Schichtenmodell umstellen; Vorher/Nachher-Vergleich der Tiefenkarten aller Level, bei sichtbarer Abweichung dort `minf` beibehalten und begründen
- [x] 2.3 `SeaChart`: statische Formenliste, `depth_at` mit exakter Umrissauswertung in der Nähe der Formen; Aufbau aus dem Level
- [x] 2.4 `Level.depth_cell` (2–10 m, 0 = automatisch), Gitter-/`game_res()`-Anbindung; Vorschau/Editor-Auflösungen unverändert

## 3. Karte

- [x] 3.1 Kantentextur (RGF: Tiefe·Gewicht, Gewicht; Zellgröße 1 m, nur über den Formen, max. 2048²), `LandPoly.edge_image`
- [x] 3.2 Shader: scharfe Uferlinie/Sandfläche aus der Distanztextur; Minimap/Menü-Vorschau (`make_map_image`) nutzt `depth_at`

## 4. Editor und Werkzeuge

- [x] 4.1 Plugin: Knopf „Landform“ (geschlossene Kurve mit 4 Punkten, Griffe vorbelegt)
- [x] 4.2 `tools/svg_to_land.py`: SVG-Pfade/Polygone (M/L/C/S/Q/Z) → `LandShape`-Szene mit Bézier-Griffen, Skalierung auf `map_size`
- [x] 4.3 Beispiel `tools/beispiel_land.svg` (Insel mit Kurven, Hafenbecken) und Screenshot-Skript `tests/land_shape_shots.gd`; vorhandene Level bleiben unverändert

## 5. Tests und Doku

- [x] 5.1 `tests/land_shape_test.gd`: exakte Kante (Rechteck, Dreieck), Ecke, Bézier-Kreis (Abweichung < 0,2 m), Wasser über Land (Loch), Reihenfolge, Vorrang vor Tiefenbild-Land, Untiefe 0,3 m über flacherer Grundlage, keine Naht am Gebietsrand, Zellgröße 8 m, ohne Formen unverändert, `depth_at`-Laufzeit
- [x] 5.2 Screenshot der Seekarte mit Bézier-Küste (scharf) und `level_check`/Hazard-Regression
- [x] 5.3 Doku: `docs/skripte/level.md`, `docs/skripte/seekarte.md`, `docs/referenz/bahnen-bauen.md`, `docs/skripte/werkzeuge.md`
- [x] 5.4 `mkdocs build --strict` (ohne `-q`), `openspec validate land-vektorformen`
