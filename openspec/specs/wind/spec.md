# wind Specification

## Purpose
Anforderungen der Capability `wind` des Segelspiels Regatta (aus archivierten Changes).

## Requirements

### Requirement: Windschatten
Das Spiel SHALL Boote im Lee von Land deutlich weniger Wind geben.

#### Scenario: Hinter Land
- **WHEN** ein Boot im Windschatten liegt
- **THEN** ist die Windstärke stark reduziert
