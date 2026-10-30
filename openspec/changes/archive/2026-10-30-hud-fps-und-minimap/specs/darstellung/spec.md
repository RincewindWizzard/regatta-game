## ADDED Requirements

### Requirement: Minimap
Die Minimap SHALL das eigene Boot in der Bildmitte nicht verdecken.

#### Scenario: Rennen
- **WHEN** das HUD gezeichnet wird
- **THEN** sitzt die Minimap oben rechts

### Requirement: FPS-Anzeige
Das HUD SHALL die Bildrate unten rechts zeigen.

#### Scenario: Im Rennen
- **WHEN** das Rennen läuft
- **THEN** steht dort „n FPS“

### Requirement: Vorschau
Menü-Vorschau und Minimap SHALL Tankstellen und Warngebiete zeigen.

#### Scenario: Menü
- **WHEN** eine Bahn ausgewählt ist
- **THEN** sind Tankstellen und Zonen eingezeichnet
