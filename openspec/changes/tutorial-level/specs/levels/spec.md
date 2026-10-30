# Spec Delta

## ADDED Requirements

### Requirement: Tutorial-Level
Ein Level SHALL als Tutorial gekennzeichnet werden können. Ein Tutorial-Level SHALL ohne Regattalogik (Countdown, Start-/Ziellinie, Rangliste, Gegner) ablaufen, nur einen Spieler zulassen und im Menü wie jeder andere Level wählbar sein.

#### Scenario: Tutorial im Menü
- **WHEN** das Menü die Level auflistet
- **THEN** erscheint die Segelschule mit einer Beschreibung als Tutorial und ohne Regatta-Kennzahlen wie Bahnlänge

#### Scenario: Kein Rennablauf
- **WHEN** ein Tutorial-Level läuft
- **THEN** wird keine Startlinie überquert, kein Ziel gewertet und keine Rangliste gezeigt
