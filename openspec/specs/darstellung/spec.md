# darstellung Specification

## Purpose
Anforderungen der Capability `darstellung` des Segelspiels Regatta (aus archivierten Changes).

## Requirements

### Requirement: Vollbild
Das Spiel SHALL per F11 oder Alt+Enter zwischen Fenster und Vollbild umschalten.

#### Scenario: F11
- **WHEN** F11 gedrückt wird
- **THEN** wechselt der Modus

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

### Requirement: Weiche Modelle
Das Spiel SHALL Modelle mit abgerundeten Kanten und weicher Schattierung darstellen.

#### Scenario: Schiff
- **WHEN** ein Schiff gezeichnet wird
- **THEN** sind Kanten abgerundet

### Requirement: Bildrate
Das Spiel SHALL auch mit vier Booten und Berufsschiffen flüssig laufen.

#### Scenario: Vier Boote
- **WHEN** vier Boote fahren
- **THEN** bleibt die CPU-Zeit je Bild unter 10 ms (`tests/perf_test.gd`)
