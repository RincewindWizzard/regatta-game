# Spec Delta

## ADDED Requirements

### Requirement: Landmassen als Vektor-Polygone
Ein Level SHALL Landmassen als Polygone (`LandShape`) enthalten können, deren Eckpunkte im Leveleditor frei platzierbar sind. Die Uferlinie SHALL exakt dem Polygonumriss folgen, unabhängig von der Auflösung des Tiefenrasters.

#### Scenario: Exakte Kante
- **WHEN** ein Land-Polygon ein Rechteck mit scharfer Ecke beschreibt
- **THEN** liegt die Uferlinie (Tiefe −0,8 m) an jedem Punkt der Kante auf weniger als 0,2 m genau auf dem Umriss, auch an der Ecke

#### Scenario: Boot am Ufer
- **WHEN** ein Boot sich der Polygonkante nähert
- **THEN** wird es an der Polygonkante festgesetzt bzw. läuft auf Grund, nicht an einer gerasterten Kante

#### Scenario: Ohne Formen unverändert
- **WHEN** ein Level kein `LandShape` enthält
- **THEN** verhält sich die Tiefenberechnung wie bisher

### Requirement: Wasser-Polygone
Ein Polygon SHALL als Wasser markiert werden können; es hebt Land innerhalb seines Umrisses auf (z. B. Hafenbecken, See im Binnenrevier). Mehrere Formen SHALL in der Reihenfolge ihrer Szene wirken, sodass Wasser über Land Löcher ergibt.

#### Scenario: Hafenbecken
- **WHEN** ein Wasser-Polygon über einer Land-Polygonfläche liegt
- **THEN** ist innerhalb des Wasser-Umrisses befahrbares Wasser, außerhalb bleibt das Land

### Requirement: Einstellbare Zellgröße des Tiefenrasters
Der Level SHALL die Zellgröße des Tiefenrasters (2–10 m) einstellen können. Ohne Angabe SHALL die bisherige Zellgröße gelten.

#### Scenario: Grobes Raster
- **WHEN** ein Level eine Zellgröße von 8 m einstellt
- **THEN** wird das Tiefenraster mit dieser Zellgröße berechnet, die Polygon-Uferlinie bleibt exakt



### Requirement: Editor-Knopf für Landformen
Das Editor-Plugin SHALL für Landmassen einen Einfüge-Knopf „Landform“ bieten, der ein Polygon mit vier verschiebbaren Eckpunkten anlegt und den Umriss im Editor zeigt. Selbstüberschneidende oder zu kurze Polygone SHALL im Editor als Warnung angezeigt werden.

#### Scenario: Landform einfügen
- **WHEN** der Knopf „Landform“ gedrückt wird
- **THEN** entsteht ein `LandShape` mit vier `Marker3D`-Eckpunkten am Mauszeiger bzw. in der Kartenmitte

#### Scenario: Ungültiges Polygon
- **WHEN** ein Polygon weniger als drei Punkte hat oder sich selbst schneidet
- **THEN** zeigt der Editor eine Warnung am Knoten
