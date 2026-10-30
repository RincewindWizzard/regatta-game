# steuerung Specification

## Purpose
Anforderungen der Capability `steuerung` des Segelspiels Regatta (aus archivierten Changes).

## Requirements

### Requirement: Schot per Schultertaste
Das Spiel SHALL die Schot mit den Schultertasten eines Controllers (auch einzelner Joy-Con) holen und fieren.

#### Scenario: Joy-Con
- **WHEN** ein einzelner Joy-Con verbunden ist und eine Schultertaste gedrückt wird
- **THEN** ändert sich die Schotstellung

### Requirement: Rennen mit dem Controller abbrechen
Das Spiel SHALL ein laufendes Rennen abbrechen und zurück ins Menü (Lobby) führen, wenn auf einem verbundenen Controller die Zurück-Taste mindestens 1 Sekunde gehalten wird.

#### Scenario: Lange genug gehalten
- **WHEN** die Zurück-Taste 1 Sekunde gehalten wird
- **THEN** wird das Rennen verlassen

#### Scenario: Zu früh losgelassen
- **WHEN** die Taste vorher losgelassen wird
- **THEN** läuft das Rennen weiter und der Balken geht zurück

### Requirement: Hinweis zum Abbrechen
Das HUD SHALL bei verbundenem Controller auf das Abbrechen durch Halten der Zurück-Taste hinweisen und den Fortschritt anzeigen.

#### Scenario: Controller verbunden
- **WHEN** mindestens ein Controller verbunden ist
- **THEN** steht unten mittig „Zurück-Taste halten: Rennen abbrechen“
