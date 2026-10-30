## ADDED Requirements

### Requirement: Rennen mit dem Controller abbrechen
Das Spiel SHALL ein laufendes Rennen abbrechen und zurück ins Menü (Lobby) führen, wenn auf einem
verbundenen Controller die Zurück-Taste (Select/Minus) mindestens 1 Sekunde gehalten wird.

#### Scenario: Zurück-Taste lange genug gehalten
- **WHEN** ein Spieler im Rennen die Zurück-Taste seines Controllers 1 Sekunde gedrückt hält
- **THEN** wird das Rennen verlassen und das Menü (bzw. die Lobby) angezeigt

#### Scenario: Zurück-Taste zu früh losgelassen
- **WHEN** die Zurück-Taste vor Ablauf der Sekunde losgelassen wird
- **THEN** läuft das Rennen weiter und der Fortschrittsbalken geht zurück

### Requirement: Hinweis zum Abbrechen
Das HUD SHALL bei verbundenem Controller darauf hinweisen, dass das Rennen durch Halten der
Zurück-Taste abgebrochen werden kann, und den Fortschritt anzeigen.

#### Scenario: Controller verbunden
- **WHEN** mindestens ein Controller verbunden ist
- **THEN** steht unten mittig „Zurück-Taste halten: Rennen abbrechen“
