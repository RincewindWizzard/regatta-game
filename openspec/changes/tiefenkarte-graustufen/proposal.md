# Proposal

## Why

Ein Level kann seinen Seegrund bereits aus einem PNG-Bild beziehen (`depth_image`, so entstand die
Kieler Förde). Die Bedeutung der Graustufen ist dabei aber **fest eingebaut** (Wert 0 = −8 m,
Wert 255 = +17,5 m), und das Bild muss genau das ganze 1280-m-Kartengebiet abdecken. Wer eine eigene
Tiefenkarte (z. B. aus Seekarten- oder Geodaten, mit anderen Wertebereichen) einsetzen will, muss sie
vorher in dieses Format umrechnen.

## What Changes

- Das PNG-Raster wird zu einer **frei einstellbaren Tiefenkarte**: Der Level legt fest, welche Tiefe
  **Schwarz (0)** und welche **Weiß (255)** bedeutet; dazwischen wird linear umgerechnet.
  Optional lässt sich die Zuordnung umkehren (hell = flach).
- Das Bild kann **beliebige Größe und Auflösung** haben und wird auf ein einstellbares
  **Weltrechteck** (Position und Größe in Metern) gelegt. Außerhalb des Bildes gilt eine
  einstellbare Tiefe (Standard: Land).
- Das Bild darf Graustufen oder Farbe haben (Helligkeit zählt), mit oder ohne Alpha.
- Die Einstellungen sind im Inspector des Levels sichtbar und werden im Menü-Vorschau- und
  Editor-Vorschaubild berücksichtigt.
- Bestehende Level (Kieler Förde) behalten ihr Verhalten: Die Standardwerte entsprechen der bisherigen
  festen Zuordnung. `tools/chart_to_depth.py` schreibt die Werte, die der Level erwartet.
- Doku beschreibt Format, Einstellungen und ein Beispiel.

## Capabilities

### New Capabilities

(keine)

### Modified Capabilities
- `levels`: Der Seegrund eines Levels kann aus einem PNG-Raster mit einstellbarer Bedeutung der
  Graustufen und einstellbarer Lage kommen.

## Impact

- `scripts/level/level.gd` (neue Export-Felder, Einlesen und Umrechnen), Editor-Plugin
  (Inspector-Anzeige), `tools/chart_to_depth.py`, `tools/make_levels.gd` (Kieler Förde mit
  ausdrücklichen Werten).
- Tests (`tests/`), Doku (`docs/skripte/level.md`, `docs/referenz/bahnen-bauen.md`).
- Keine Änderung des Spielablaufs; vorhandene Level bleiben unverändert.
