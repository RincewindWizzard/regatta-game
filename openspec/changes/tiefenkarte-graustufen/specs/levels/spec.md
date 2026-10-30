# Spec Delta

## ADDED Requirements

### Requirement: Seegrund aus einem PNG-Raster
Ein Level SHALL seinen Seegrund aus einem PNG-Bild beziehen können, das die Wassertiefe als Helligkeit kodiert. Das Bild SHALL jede Größe und Auflösung haben dürfen, und Graustufen- wie Farbbilder SHALL über ihre Helligkeit ausgewertet werden (Alpha wird ignoriert).

#### Scenario: Bild anderer Auflösung
- **WHEN** ein Level ein Tiefenbild mit beliebiger Auflösung verwendet
- **THEN** wird der Seegrund daraus ohne Vorverarbeitung berechnet und weich (bilinear) abgetastet

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
- **THEN** ändert sich sein Seegrund nicht

### Requirement: Lage des Tiefenbildes
Der Level SHALL die Lage des Bildes als Rechteck in Weltmetern (Position und Größe) einstellen können; ohne Angabe SHALL das Bild das ganze Kartengebiet abdecken. Außerhalb des Bildes SHALL eine einstellbare Tiefe gelten (Standard: Land).

#### Scenario: Bild deckt nur einen Teil ab
- **WHEN** das Bild auf ein Teilrechteck der Karte gelegt wird
- **THEN** stammt der Seegrund dort aus dem Bild, ringsum gilt die eingestellte Außentiefe

### Requirement: Sichtbare Einstellungen
Die Einstellungen des Tiefenbildes SHALL im Inspector des Levels sichtbar sein, und Editor-Vorschau sowie Menü-Vorschau SHALL sie berücksichtigen.

#### Scenario: Zuordnung geändert
- **WHEN** der Entwickler Schwarz- oder Weißwert im Inspector ändert
- **THEN** aktualisiert sich die Vorschau des Seegrunds
