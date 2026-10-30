# Spec Delta

## ADDED Requirements

### Requirement: Seegrund aus einem PNG-Raster
Ein Level SHALL seinen Seegrund aus einem PNG-Bild beziehen können, das die Wassertiefe als Helligkeit kodiert. Das Bild SHALL jede Größe und Auflösung haben dürfen, und Graustufen- wie Farbbilder SHALL über ihre Helligkeit ausgewertet werden (Alpha wird ignoriert).

#### Scenario: Bild anderer Auflösung
- **WHEN** ein Level ein Tiefenbild mit beliebiger Auflösung verwendet
- **THEN** wird der Seegrund daraus ohne Vorverarbeitung berechnet

#### Scenario: Farbbild
- **WHEN** das Bild Farben enthält
- **THEN** zählt die Helligkeit eines Pixels als Graustufenwert

### Requirement: Einstellbare Bedeutung der Graustufen
Der Level SHALL einstellen können, welche Wassertiefe Schwarz (0) und welche Weiß (255) bedeutet; dazwischen SHALL linear umgerechnet werden. Der Level SHALL die Zuordnung umkehren können (hell = flach). Ohne Angabe SHALL die bisherige Zuordnung gelten (0 = −8 m, 255 = +17,5 m).

#### Scenario: Eigene Zuordnung
- **WHEN** ein Level Schwarz = 0 m und Weiß = 20 m einstellt
- **THEN** ergibt ein mittleres Grau (128) rund 10 m Tiefe

#### Scenario: Umgekehrte Zuordnung
- **WHEN** die Zuordnung umgekehrt ist
- **THEN** bedeutet Weiß die kleinere und Schwarz die größere der beiden Tiefen

#### Scenario: Bestehende Level
- **WHEN** ein vorhandener Level (z. B. Kieler Förde) keine Zuordnung angibt
- **THEN** behält er seine Zuordnung von Grau zu Tiefe

### Requirement: Einstellbare Kartengröße
Ein Level SHALL Breite und Länge seiner Karte in Metern einstellen können (jeweils 300 bis 3000 m, nicht nur quadratisch; ohne Angabe 1280 × 1280 m). Das Tiefenbild SHALL auf diese Größe skaliert werden, unabhängig von seinem Seitenverhältnis. Seekarte, Kartenrand, Regattagebiet, Minimap und Vorschauen SHALL der Kartengröße folgen.

#### Scenario: Breite Karte
- **WHEN** ein Level eine Karte von 2000 × 800 m einstellt
- **THEN** zeigt die Seekarte genau diese Fläche, Boote werden an ihrem Rand begrenzt, und die Minimap bildet sie ab

#### Scenario: Bild anderer Größe
- **WHEN** das Tiefenbild ein anderes Seitenverhältnis als die Karte hat
- **THEN** wird es auf die ganze Karte gestreckt

#### Scenario: Standardkarte
- **WHEN** ein Level keine Größe angibt
- **THEN** ist die Karte 1280 × 1280 m groß wie bisher

### Requirement: Weiche Abtastung ohne Kachelmuster
Das Spiel SHALL das Tiefenbild glatt (nicht linear) abtasten und mit leichtem Rauschen versehen, sodass Tiefenlinien und Küste keine Pixel- oder Kachelmuster zeigen. Das Rauschen SHALL deterministisch sein (aus dem Seegrund-Seed des Levels), damit alle Mitspieler und die KI denselben Seegrund sehen. Stärke des Rauschens SHALL einstellbar sein.

#### Scenario: Grobes Bild
- **WHEN** ein Tiefenbild mit grober Auflösung auf eine große Karte skaliert wird
- **THEN** verlaufen die Tiefenlinien gerundet und unregelmäßig statt entlang der Pixelgrenzen

#### Scenario: Gleicher Grund bei allen
- **WHEN** zwei Spieler denselben Level spielen
- **THEN** ist die Tiefe an jedem Punkt auf beiden Rechnern identisch

#### Scenario: Rauschen aus
- **WHEN** die Rauschstärke auf 0 gestellt wird
- **THEN** entsteht der Grund allein aus der glatten Abtastung ohne Zufallsanteil

### Requirement: Sichtbare Einstellungen
Die Einstellungen des Tiefenbildes (Zuordnung, Kartengröße, Rauschen) SHALL im Inspector des Levels sichtbar sein, und Editor-Vorschau sowie Menü-Vorschau SHALL sie berücksichtigen.

#### Scenario: Wert geändert
- **WHEN** der Entwickler Schwarz-, Weißwert, Größe oder Rauschen im Inspector ändert
- **THEN** aktualisiert sich die Vorschau des Seegrunds
