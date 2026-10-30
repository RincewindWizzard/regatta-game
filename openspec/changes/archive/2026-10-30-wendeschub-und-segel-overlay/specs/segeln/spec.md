## ADDED Requirements

### Requirement: Wendeschub
Das Spiel SHALL nach einer Wende mit ausreichender Fahrt kurzzeitig zusätzlichen Vortrieb geben.

#### Scenario: Wende mit Fahrt
- **WHEN** ein Boot mit mindestens 1,3 m/s durch den Wind wendet
- **THEN** erhält es einen Schub und die Meldung „Wende – Schub!“

### Requirement: Segel-Overlay
Das Spiel SHALL die Segelstellung farbig am Segel anzeigen (grün optimal, orange zu weit weg, rot killt) und den idealen Baumwinkel als Linie zeigen; `T` schaltet das Overlay um.

#### Scenario: Overlay an
- **WHEN** das Overlay eingeschaltet ist
- **THEN** sind Segel und Geisterbaum eingefärbt
