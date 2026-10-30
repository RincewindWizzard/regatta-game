## ADDED Requirements

### Requirement: Polizeikontrolle
Das Spiel SHALL ein Boot im Polizei-Sperrgebiet 12 s kontrollieren und die Ansage „Führerschein und Fahrzeugpapiere, bitte!“ zeigen.

#### Scenario: Einfahrt
- **WHEN** ein Boot länger als 1,6 s im Sperrgebiet bleibt
- **THEN** wird es angehalten und kontrolliert

### Requirement: Abschleppen
Das Spiel SHALL das Boot nach der Kontrolle aus dem Sperrgebiet ziehen und danach 25 s Schonfrist geben.

#### Scenario: Ende der Kontrolle
- **WHEN** die Kontrolle endet
- **THEN** liegt das Boot außerhalb des Gebiets

### Requirement: Fahrverhalten
Das Polizeiboot SHALL mit dem Bug in Fahrtrichtung kurven und nur im Wasser fahren.

#### Scenario: Anfahrt
- **WHEN** es sich dem Boot nähert
- **THEN** fährt es eine Kurve und liegt am Ende parallel

### Requirement: Rammen
Das Spiel SHALL das Polizeiboot als Hindernis behandeln; wer es rammt, SHALL 16 s kontrolliert werden.

#### Scenario: Rammen
- **WHEN** ein Boot das Polizeiboot trifft
- **THEN** prallt es ab und wird kontrolliert
