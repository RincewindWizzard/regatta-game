# kollisionen Specification

## Purpose
Anforderungen der Capability `kollisionen` des Segelspiels Regatta (aus archivierten Changes).

## Requirements

### Requirement: Nachteil bei Bootskollision
Das Spiel SHALL bei einer Kollision zweier Boote beide bremsen und mit einer kurzen Vortriebsstrafe belegen, ohne ein Boot auszuschließen.

#### Scenario: Zusammenstoß
- **WHEN** zwei Boote zusammenstoßen
- **THEN** verlieren beide Fahrt und erhalten eine Strafzeit

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

### Requirement: Kollisionsform folgt dem Rumpf
Das Spiel SHALL die Kollisionsform eines Bootes aus der Rumpfform ableiten (lang und schmal, etwa 9,4 m lang und 3,4 m breit, in Richtung des Bootskurses ausgerichtet) und SHALL eine Kollision erst melden, wenn sich die Rümpfe tatsächlich berühren.

#### Scenario: Boote fahren nebeneinander
- **WHEN** zwei Boote parallel mit mindestens 4 m seitlichem Abstand zwischen den Mittellinien aneinander vorbeifahren
- **THEN** wird keine Kollision erkannt, kein Tempo verloren und keine Polizei gerufen

#### Scenario: Rümpfe berühren sich seitlich
- **WHEN** zwei parallel fahrende Boote weniger als etwa 3,4 m seitlichen Abstand zwischen den Mittellinien haben
- **THEN** wird eine Kollision erkannt

#### Scenario: Bugkontakt
- **WHEN** zwei Boote mit den Bugs aufeinander zufahren
- **THEN** wird die Kollision erst erkannt, wenn sich die Bugs berühren (Mittenabstand etwa 9,4 m)

### Requirement: Einheitliche Kollisionsform für alle Hindernisse
Das Spiel SHALL dieselbe rumpfförmige Kollisionsform des Bootes auch gegenüber Tonnen, festen Hindernissen, Polizeibooten und Berufsschiffen verwenden.

#### Scenario: Seitlich an einer Tonne vorbei
- **WHEN** ein Boot seitlich an einer Tonne vorbeifährt und der Rumpf die Tonne nicht berührt
- **THEN** entsteht keine Kollision

#### Scenario: Rumpf trifft Tonne
- **WHEN** der Rumpf eines Bootes eine Tonne berührt
- **THEN** prallt das Boot ab wie bisher

### Requirement: Computergegner nutzen die Rumpfform
Die Computergegner SHALL ihren Sicherheitsabstand zu anderen Booten, Tonnen und Schiffen aus der Rumpfform berechnen.

#### Scenario: Überholen
- **WHEN** ein Computerboot ein anderes Boot überholt
- **THEN** hält es seitlich nur den für die Rumpfbreite nötigen Abstand und fährt nicht unnötig weit außen
