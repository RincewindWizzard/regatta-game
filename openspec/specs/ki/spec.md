# ki Specification

## Purpose
Anforderungen der Capability `ki` des Segelspiels Regatta (aus archivierten Changes).

## Requirements

### Requirement: Ausweichen der KI
Computerboote SHALL Berufsschiffen ausweichen und bei Gefahr einen Fluchtkurs fahren.

#### Scenario: Schiff nähert sich
- **WHEN** ein Rumpf in den nächsten 13 s zu nahe käme
- **THEN** wählt die KI einen Fluchtkurs
