# Proposal

## Why

Wer Regatta zum ersten Mal spielt, muss das Segeln erst verstehen: Kurse zum Wind, Kreise,
Manöver. Heute gibt es dafür nur Texte in der Anleitung. Ein geführtes Tutorial im Spiel selbst
bringt die Grundlagen sofort und mit Rückmeldung bei.

## What Changes

- Neuer Level **„Segelschule“**, der nicht als Regatta, sondern als Tutorial abläuft: kein
  Countdown, keine Gegner, keine Rangliste, kein Ziel.
- Der Level ist **Einzelspieler** und im Menü wählbar; die Besetzung wird auf einen Menschen ohne
  Computergegner festgelegt, auch wenn im Menü etwas anderes eingestellt ist.
- Der Spieler löst **nacheinander** acht Aufgaben, jeweils mit Anleitung und Fortschrittsanzeige:
  1. Am Wind segeln
  2. Halber Wind
  3. Raumschots
  4. Vorwind
  5. Vollkreis
  6. Achten
  7. Aufschießer an der Tonne
  8. Mann-über-Bord-Manöver (Person im Wasser retten)
- Konstanter Wind ohne Böen und Dreher, kein Motor, damit die Übungen reproduzierbar sind.
- Nach der letzten Aufgabe erscheint eine Abschlussmeldung mit der benötigten Zeit; Neustart und
  Abbruch (Menü) bleiben möglich, auch mit dem Controller.
- Doku und README beschreiben das Tutorial.

## Capabilities

### New Capabilities
- `tutorial`: geführte Segelübungen mit Aufgabenfolge, Erkennung der Manöver, Anleitung im HUD und
  Abschluss.

### Modified Capabilities
- `levels`: Ein Level kann als Tutorial (Einzelspieler, ohne Rennlogik) statt als Regatta
  definiert sein.

## Impact

- Neuer Level `levels/09_segelschule.tscn` (erzeugt in `tools/make_levels.gd`).
- Spielablauf (`scripts/main.gd`), Kursverfolgung (`scripts/course.gd`), HUD (`scripts/hud.gd`),
  Menü (`scripts/menu.gd`, `scripts/game_state.gd`), neues Skript für die Aufgabenlogik.
- Tests (`tests/`), Doku (`docs/spielen/`, `docs/skripte/`), README.
- Keine Änderung der bestehenden Regatta-Level; kein Netzwerkspiel für das Tutorial.
