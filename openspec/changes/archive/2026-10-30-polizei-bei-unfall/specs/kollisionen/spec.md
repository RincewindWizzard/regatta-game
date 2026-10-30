## ADDED Requirements

### Requirement: Kontrolle nach Unfall
Das Spiel SHALL nach einem Zusammenstoß beide Boote anhalten; wer nach KVR ausweichen musste, SHALL länger kontrolliert werden als der andere.

#### Scenario: Frontaler Aufprall
- **WHEN** zwei Boote mit mehr als 1 m/s zusammenstoßen
- **THEN** wird der Verursacher 20 s, der andere 7 s kontrolliert

### Requirement: Knappes Vorbeifahren
Das Spiel SHALL beim knappen seitlichen Vorbeifahren ohne echten Aufprall keine Polizei rufen.

#### Scenario: Seitlich vorbei
- **WHEN** zwei Boote sich nur streifen
- **THEN** bleibt die Polizei aus

### Requirement: Ein Polizeiboot
Das Spiel SHALL pro Unfall nur ein Polizeiboot zeigen.

#### Scenario: Zwei Segelboote
- **WHEN** zwei Segelboote kollidieren
- **THEN** erscheint ein Polizeiboot beim Verursacher
