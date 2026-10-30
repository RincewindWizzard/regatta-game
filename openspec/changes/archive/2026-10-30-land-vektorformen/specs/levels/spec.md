# Spec Delta

## ADDED Requirements

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
