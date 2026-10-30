## ADDED Requirements

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
