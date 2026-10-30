# schifffahrt Specification

## Purpose
Anforderungen der Capability `schifffahrt` des Segelspiels Regatta (aus archivierten Changes).

## Requirements

### Requirement: Ausweichen
Das Spiel SHALL Berufsschiffe fahren lassen, denen Boote ausweichen müssen; eine Kollision SHALL das Boot aus dem Rennen nehmen.

#### Scenario: Zusammenstoß
- **WHEN** ein Boot den Rumpf eines Schiffs berührt
- **THEN** scheidet es aus

### Requirement: Rumpfkontur
Die Kollision SHALL der sichtbaren Rumpfform folgen (Kontur aus dem Blender-Skript).

#### Scenario: Bug
- **WHEN** ein Boot den Bug passiert
- **THEN** wird die spitze Form berücksichtigt

### Requirement: Modelle
Die Schiffe SHALL aus Blender-Modellen bestehen, die zum Stil von Schlepper und Segelboot passen.

#### Scenario: Darstellung
- **WHEN** ein Schiff gezeichnet wird
- **THEN** hat es einen geschlossenen Rumpf ohne Überschneidungen
