# Proposal

## Why

Ein Level kann seinen Seegrund bereits aus einem PNG-Bild beziehen (`depth_image`, so entstand die
Kieler Förde). Heute gilt dafür aber: Die Bedeutung der Graustufen ist **fest eingebaut** (Wert 0 =
−8 m, Wert 255 = +17,5 m), das Bild muss das **ganze 1280 × 1280 m große Kartengebiet** abdecken, und
die Abtastung ist **bilinear** – bei Bildern mit grober Auflösung erscheinen die Tiefenlinien dadurch
eckig und mit sichtbarem Kachelmuster. Wer eine eigene Tiefenkarte (z. B. aus Seekarten- oder
Geodaten, mit anderem Wertebereich und Format) einsetzen will, muss sie vorher umrechnen.

## What Changes

- Das PNG-Raster wird zu einer **frei einstellbaren Tiefenkarte**: Der Level legt fest, welche Tiefe
  **Schwarz (0)** und welche **Weiß (255)** bedeutet; dazwischen wird linear umgerechnet. Optional lässt
  sich die Zuordnung umkehren (hell = flach). Graustufen- und Farbbilder (Helligkeit zählt), beliebige
  Auflösung.
- Die **Kartengröße ist pro Level einstellbar**: Länge und Breite in Metern (nicht nur quadratisch,
  Standard 1280 × 1280 m, Bereich 300–3000 m). Das **PNG wird auf diese Größe skaliert** (gestreckt, ohne
  festes Seitenverhältnis). Seekarte, Kartenrand, Regattagebiet, Minimap und Vorschauen folgen der
  Kartengröße.
- **Weiche Abtastung ohne Kachelmuster:** Das Bild wird nicht linear, sondern **glatt (bikubisch)**
  abgetastet und zusätzlich mit **etwas Rauschen** versehen (leichte Verschiebung der Abtastposition
  und kleines Tiefenrauschen). Dadurch verlaufen Tiefenlinien und Küste natürlich statt entlang der
  Pixelraster. Das Rauschen ist **deterministisch** (aus dem Seegrund-Seed des Levels): Host, Clients
  und KI sehen denselben Grund.
- Die Einstellungen sind im Inspector des Levels sichtbar und werden von Editor- und Menü-Vorschau
  berücksichtigt.
- Bestehende Level behalten ihr Verhalten bis auf die glattere Abtastung (Küste verschiebt sich um
  höchstens wenige Meter): Die Standardwerte entsprechen der bisherigen Zuordnung und Kartengröße.
  `tools/chart_to_depth.py` schreibt die Werte, die der Level erwartet.
- Doku beschreibt Format, Einstellungen und ein Beispiel.

## Capabilities

### New Capabilities

(keine)

### Modified Capabilities
- `levels`: Der Seegrund eines Levels kann aus einem PNG-Raster mit einstellbarer Bedeutung der
  Graustufen kommen; die Kartengröße ist einstellbar, das Bild wird skaliert und glatt mit Rauschen
  abgetastet.

## Impact

- `scripts/sea_chart.gd` (Kartengebiet wird pro Level gesetzt statt Konstante, rechteckiges
  Tiefengitter, Shader-Parameter), `scripts/level/level.gd` (neue Export-Felder, Einlesen,
  Abtasten), `scripts/level/shoal_area.gd`, `scripts/level/river_channel.gd`, `scripts/boat.gd`
  (Kartenrand), Regattagebiet (`race_area`), Editor-Plugin (Inspector, Vorschau),
  `tools/chart_to_depth.py`, `tools/make_levels.gd`.
- Tests (`tests/`), Doku (`docs/skripte/level.md`, `docs/skripte/seekarte.md`,
  `docs/referenz/bahnen-bauen.md`).
- Keine Änderung des Spielablaufs; vorhandene Level behalten Größe und Zuordnung.
