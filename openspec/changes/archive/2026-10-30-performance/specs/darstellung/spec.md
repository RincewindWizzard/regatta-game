## ADDED Requirements

### Requirement: Bildrate
Das Spiel SHALL auch mit vier Booten und Berufsschiffen flüssig laufen.

#### Scenario: Vier Boote
- **WHEN** vier Boote fahren
- **THEN** bleibt die CPU-Zeit je Bild unter 10 ms (`tests/perf_test.gd`)
