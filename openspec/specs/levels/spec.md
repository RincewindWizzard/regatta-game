# levels Specification

## Purpose
Anforderungen der Capability `levels` des Segelspiels Regatta (aus archivierten Changes).

## Requirements

### Requirement: Tankstellen im Gebiet
Jeder Level SHALL seine Tankstellen mit Liegeplatz im Wasser und innerhalb des Regattagebiets haben.

#### Scenario: Level-Check
- **WHEN** `level_check.gd` läuft
- **THEN** meldet es Abweichungen

### Requirement: Bäume an Land
Bäume SHALL nur an Land stehen.

#### Scenario: Flussregatta
- **WHEN** der Level aufgebaut wird
- **THEN** steht kein Baum im Wasser

### Requirement: Kieler Förde
Das Spiel SHALL einen Level „Kieler Förde“ nach der Seekarte bieten, der in der Schwentinemündung startet und vor dem Olympiahafen Schilksee endet.

#### Scenario: Rennen
- **WHEN** ein Boot die Ziellinie in Pfeilrichtung überquert
- **THEN** ist es im Ziel; ein Rundkurs ist nicht nötig

### Requirement: Wind
Der Level SHALL Westwind mit etwa 10 m/s haben.

#### Scenario: Start
- **WHEN** das Rennen startet
- **THEN** kommt der Wind aus 270°

### Requirement: Wahrzeichen
Der Level SHALL die genannten Wahrzeichen an ihren Kartenpunkten darstellen.

#### Scenario: Karte
- **WHEN** die Karte betrachtet wird
- **THEN** sind Leuchtturm, Ehrenmale, Molen und Hafenpunkte erkennbar

### Requirement: Tutorial-Level
Ein Level SHALL als Tutorial gekennzeichnet werden können. Ein Tutorial-Level SHALL ohne Regattalogik (Countdown, Start-/Ziellinie, Rangliste, Gegner) ablaufen, nur einen Spieler zulassen und im Menü wie jeder andere Level wählbar sein.

#### Scenario: Tutorial im Menü
- **WHEN** das Menü die Level auflistet
- **THEN** erscheint die Segelschule mit einer Beschreibung als Tutorial und ohne Regatta-Kennzahlen wie Bahnlänge

#### Scenario: Kein Rennablauf
- **WHEN** ein Tutorial-Level läuft
- **THEN** wird keine Startlinie überquert, kein Ziel gewertet und keine Rangliste gezeigt

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

### Requirement: Landmassen als Vektor-Polygone
Ein Level SHALL Landmassen als geschlossene Umrisse (`LandShape`) enthalten können, deren Punkte im Leveleditor frei platzierbar sind. Die Segmente SHALL gerade oder als Bézier-Kurven (mit Griffen) gezeichnet werden können. Die Uferlinie SHALL exakt dem Polygonumriss folgen, unabhängig von der Auflösung des Tiefenrasters.

#### Scenario: Exakte Kante
- **WHEN** ein Land-Polygon ein Rechteck mit scharfer Ecke beschreibt
- **THEN** liegt die Uferlinie (Tiefe −0,8 m) an jedem Punkt der Kante auf weniger als 0,2 m genau auf dem Umriss, auch an der Ecke

#### Scenario: Boot am Ufer
- **WHEN** ein Boot sich der Polygonkante nähert
- **THEN** wird es an der Polygonkante festgesetzt bzw. läuft auf Grund, nicht an einer gerasterten Kante

#### Scenario: Ohne Formen unverändert
- **WHEN** ein Level kein `LandShape` enthält
- **THEN** verhält sich die Tiefenberechnung wie bisher

#### Scenario: Bézier-Küste
- **WHEN** ein Umriss Punkte mit Bézier-Griffen enthält
- **THEN** folgt die Uferlinie der Kurve mit weniger als 0,2 m Abweichung, ohne Knicke zwischen den Punkten

### Requirement: Raster als Grundlage, Spezifischeres hat Vorrang
Das Tiefenraster (Zufallsgrund, Tiefenbild, Pinsel, Zufallsküste) SHALL nur als Grundlage dienen. Spezifischere Angaben (Land- und Wasser-Polygone, Untiefen, Inseln, Molen, Flüsse und Seen) SHALL in ihrem Gebiet Vorrang haben und die Grundlage dort ersetzen; später in der Szene stehende Formen SHALL früheren vorgehen. Am Rand des Gebiets SHALL weich zur Grundlage übergeblendet werden.

#### Scenario: Landgrenze aus dem Polygon
- **WHEN** die Grundlage (z. B. ein Tiefenbild) nahe einem Land-Polygon ebenfalls Land enthält
- **THEN** bestimmt allein das Polygon die Landgrenze in seinem Gebiet; Rasterland außerhalb des Polygons verschwindet dort

#### Scenario: Untiefenmarkierung
- **WHEN** eine Untiefe mit Mitteltiefe 0,3 m über einer Grundlage liegt, die dort 0,1 m ergäbe
- **THEN** beträgt die Tiefe in der Mitte 0,3 m

#### Scenario: Grundlage außerhalb
- **WHEN** ein Punkt außerhalb des Gebiets aller Formen liegt
- **THEN** gilt die Tiefe der Grundlage, ohne sichtbare Naht am Gebietsrand

#### Scenario: Reihenfolge
- **WHEN** zwei Formen sich überlappen
- **THEN** gilt die später in der Szene stehende

### Requirement: Wasser-Polygone
Ein Umriss SHALL als Wasser markiert werden können; er hebt Land innerhalb seines Umrisses auf (z. B. Hafenbecken, See im Binnenrevier). Mehrere Formen SHALL in der Reihenfolge ihrer Szene wirken, sodass Wasser über Land Löcher ergibt.

#### Scenario: Hafenbecken
- **WHEN** ein Wasser-Polygon über einer Land-Polygonfläche liegt
- **THEN** ist innerhalb des Wasser-Umrisses befahrbares Wasser, außerhalb bleibt das Land

### Requirement: Einstellbare Zellgröße des Tiefenrasters
Der Level SHALL die Zellgröße des Tiefenrasters (2–10 m) einstellen können. Ohne Angabe SHALL die bisherige Zellgröße gelten.

#### Scenario: Grobes Raster
- **WHEN** ein Level eine Zellgröße von 8 m einstellt
- **THEN** wird das Tiefenraster mit dieser Zellgröße berechnet, die Polygon-Uferlinie bleibt exakt

### Requirement: Editor-Knopf für Landformen
Das Editor-Plugin SHALL für Landmassen einen Einfüge-Knopf „Landform“ bieten, der eine geschlossene Kurve mit vier Punkten anlegt (bearbeitbar mit dem Pfad-Editor) und den Umriss im Editor zeigt. Selbstüberschneidende oder zu kurze Polygone SHALL im Editor als Warnung angezeigt werden.

#### Scenario: Landform einfügen
- **WHEN** der Knopf „Landform“ gedrückt wird
- **THEN** entsteht ein `LandShape` mit vier Punkten am Mauszeiger bzw. in der Kartenmitte

#### Scenario: Ungültiges Polygon
- **WHEN** ein Umriss weniger als drei Punkte hat oder sich selbst schneidet
- **THEN** zeigt der Editor eine Warnung am Knoten
