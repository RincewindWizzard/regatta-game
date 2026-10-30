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
