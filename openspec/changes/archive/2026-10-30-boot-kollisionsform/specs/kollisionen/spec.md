# Spec Delta

## ADDED Requirements

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
