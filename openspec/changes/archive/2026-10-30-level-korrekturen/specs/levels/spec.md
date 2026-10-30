## ADDED Requirements

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
