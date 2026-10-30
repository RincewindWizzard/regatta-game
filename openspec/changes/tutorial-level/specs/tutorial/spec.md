# Spec Delta

## Purpose
Geführte Segelübungen im Spiel: Der Spieler lernt in der Segelschule nacheinander Kurse zum Wind, Kreise, Achten, Aufschießer und das Mann-über-Bord-Manöver.

## ADDED Requirements

### Requirement: Segelschule ist ein Tutorial statt einer Regatta
Das Spiel SHALL einen Level „Segelschule“ anbieten, der als Tutorial abläuft: ohne Countdown, ohne Computergegner, ohne Rangliste und ohne Start-/Ziellinie. Das Spiel SHALL das Tutorial immer mit genau einem menschlichen Spieler starten.

#### Scenario: Tutorial aus dem Menü starten
- **WHEN** der Spieler im Menü die Segelschule wählt und das Spiel startet
- **THEN** beginnt das Tutorial sofort mit der ersten Aufgabe, und es fährt nur das Boot des Spielers

#### Scenario: Andere Besetzung eingestellt
- **WHEN** im Menü zwei Spieler oder Computergegner eingestellt sind und die Segelschule gewählt wird
- **THEN** startet das Tutorial trotzdem mit einem Spieler und ohne Computergegner

### Requirement: Feste Übungsbedingungen
Das Tutorial SHALL mit gleichbleibendem Wind aus fester Richtung, ohne Böen und Winddreher und ohne Motor ablaufen, damit alle Übungen reproduzierbar sind.

#### Scenario: Wind bleibt konstant
- **WHEN** das Tutorial läuft
- **THEN** ändern sich Windrichtung und Windstärke nicht

### Requirement: Aufgaben nacheinander
Das Tutorial SHALL die Aufgaben Am Wind, Halber Wind, Raumschots, Vorwind, Vollkreis, Achten, Aufschießer an der Tonne und Mann über Bord in genau dieser Reihenfolge stellen. Eine Aufgabe SHALL erst beginnen, wenn die vorige gelöst ist; Aufgaben können nicht übersprungen werden.

#### Scenario: Aufgabe gelöst
- **WHEN** der Spieler die aktuelle Aufgabe löst
- **THEN** meldet das Spiel den Erfolg mit Klang und zeigt die nächste Aufgabe

#### Scenario: Aufgabe noch offen
- **WHEN** der Spieler etwas anderes segelt als verlangt
- **THEN** bleibt die Aufgabe offen und die Anleitung bleibt sichtbar

### Requirement: Anleitung und Fortschritt
Das HUD SHALL während des Tutorials die laufende Aufgabe (Nummer von acht, Name), eine kurze Anleitung und – wo die Aufgabe eine Haltedauer oder Drehung verlangt – einen Fortschrittsbalken zeigen. Das Spiel SHALL bei einem Fehlversuch (z. B. Kurs verlassen) einen kurzen Hinweis geben.

#### Scenario: Haltedauer läuft
- **WHEN** der Spieler einen verlangten Kurs hält
- **THEN** füllt sich der Fortschrittsbalken, und beim Verlassen des Kurses geht er zurück

### Requirement: Kurse zum Wind
Für die Aufgaben Am Wind, Halber Wind, Raumschots und Vorwind SHALL das Spiel verlangen, den jeweiligen Kurs zum wahren Wind mit Fahrt mindestens 6 Sekunden lang zu halten: Am Wind 40°–55°, Halber Wind 80°–100°, Raumschots 120°–145°, Vorwind 165°–180° Windeinfallswinkel; die Fahrt muss mindestens 1,2 m/s betragen.

#### Scenario: Am Wind gehalten
- **WHEN** der Spieler mit mindestens 1,2 m/s 6 Sekunden lang zwischen 40° und 55° zum wahren Wind segelt
- **THEN** gilt die Aufgabe Am Wind als gelöst

#### Scenario: Zu spitz oder zu abgefallen
- **WHEN** der Windeinfallswinkel den Bereich verlässt
- **THEN** zählt die Haltedauer nicht weiter und der Hinweis nennt, ob angeluvt oder abgefallen werden soll

### Requirement: Vollkreis
Das Spiel SHALL die Aufgabe Vollkreis als gelöst werten, wenn der Spieler mit Fahrt eine Drehung um mindestens 340° in eine Richtung ohne Richtungswechsel fährt.

#### Scenario: Kreis gesegelt
- **WHEN** der Spieler mit mehr als 0,8 m/s eine zusammenhängende Drehung von mindestens 340° in eine Richtung fährt
- **THEN** gilt der Vollkreis als gelöst

### Requirement: Achten
Das Tutorial SHALL für die Aufgabe Achten zwei Regattatonnen (etwa 70 m auseinander, quer zum Wind) im Übungsgebiet zeigen. Das Spiel SHALL die Aufgabe als gelöst werten, wenn der Spieler zuerst die eine Tonne mit mindestens 340° zusammenhängender Drehung in einer Richtung umrundet, dabei innerhalb von 45 m um diese Tonne bleibt, und danach innerhalb von 120 Sekunden die andere Tonne ebenso in die Gegenrichtung umrundet. Die Anleitung SHALL nennen, mit welcher Tonne und in welcher Drehrichtung begonnen wird.

#### Scenario: Acht um zwei Tonnen gesegelt
- **WHEN** der Spieler erst die eine Tonne in einer Richtung und innerhalb von 120 Sekunden die andere Tonne in der Gegenrichtung jeweils vollständig umrundet
- **THEN** gilt die Acht als gelöst

#### Scenario: Kreis fern der Tonnen
- **WHEN** der Spieler einen Vollkreis weiter als 45 m von der aktuellen Zieltonne fährt
- **THEN** zählt die Drehung nicht und der Hinweis nennt die Entfernung zur Tonne

#### Scenario: Zu lange Pause
- **WHEN** nach der ersten Tonne mehr als 120 Sekunden vergehen
- **THEN** beginnt die Aufgabe Achten von vorn mit der ersten Tonne

### Requirement: Aufschießer an der Tonne
Das Spiel SHALL eine Übungstonne anzeigen und die Aufgabe Aufschießer als gelöst werten, wenn der Spieler die Tonne mit Fahrt (mindestens 1,5 m/s aus mehr als 25 m Entfernung) anläuft und dann höchstens 8 m von ihr entfernt mit weniger als 0,5 m/s Fahrt zum Stehen kommt, mit dem Bug höchstens 45° neben dem Wind.

#### Scenario: Aufgeschossen
- **WHEN** der Spieler die Tonne anläuft, in den Wind schießt und neben der Tonne stehen bleibt
- **THEN** gilt der Aufschießer als gelöst

#### Scenario: Zu weit entfernt gestoppt
- **WHEN** der Spieler weiter als 8 m von der Tonne stehen bleibt
- **THEN** bleibt die Aufgabe offen und der Hinweis nennt die Entfernung

### Requirement: Mann über Bord
Das Spiel SHALL in der letzten Aufgabe „Mann über Bord!“ melden und eine Person im Wasser (sichtbare Markierung) hinter dem Boot absetzen, sobald der Spieler mit Fahrt auf Halbwindkurs segelt. Die Aufgabe SHALL als gelöst gelten, wenn das Boot höchstens 6 m von der Person entfernt mit weniger als 0,8 m/s Fahrt zum Stehen kommt. Das HUD SHALL Entfernung und Richtung zur Person anzeigen.

#### Scenario: Person gerettet
- **WHEN** der Spieler zurückwendet und höchstens 6 m neben der Person mit weniger als 0,8 m/s stoppt
- **THEN** gilt die Person als gerettet und die Aufgabe als gelöst

#### Scenario: Zu schnell vorbei
- **WHEN** das Boot die Person mit mehr als 0,8 m/s innerhalb von 6 m passiert
- **THEN** meldet das Spiel „Zu schnell – nochmal anlaufen“ und die Aufgabe bleibt offen

### Requirement: Abschluss und Neustart
Nach der letzten Aufgabe SHALL das Spiel „Segelschule bestanden“ mit der benötigten Zeit anzeigen. Der Spieler SHALL das Tutorial neu starten oder ins Menü zurückkehren können, auch mit dem Controller.

#### Scenario: Tutorial beendet
- **WHEN** die letzte Aufgabe gelöst ist
- **THEN** erscheint die Abschlussanzeige mit der Zeit und dem Hinweis auf Neustart und Menü
