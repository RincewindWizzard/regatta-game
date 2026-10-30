# Tasks

## 1. Level und Spielzustand

- [ ] 1.1 `Level.tutorial` (Export) und Beschreibung ergänzen; `GameState` kennt Tutorial-Betrieb (ein Spieler, keine KI, Treibstoff 0, Wind/Böen aus dem Level)
- [ ] 1.2 `tools/make_levels.gd`: Level „Segelschule“ (`09_segelschule.tscn`) erzeugen (Wind Nord 5 m/s ohne Dreher/Böen, kein Motor, Startplatz, zwei Regattatonnen für die Acht, Übungstonne für den Aufschießer, Kulisse); `tests/level_check.gd` prüft ihn
- [ ] 1.3 `Main`: im Tutorial Countdown überspringen, Gegner, Rangliste, Kursverfolgung und Ziel abschalten; Neustart (Start/F5) und Abbruch (Esc/Zurück-Taste) bleiben

## 2. Aufgabenlogik

- [ ] 2.1 `scripts/tutorial.gd`: Aufgabenliste, Zustandsmaschine, Konstanten (Toleranzen, Haltedauer)
- [ ] 2.2 Kurse zum Wind (Am Wind, Halber Wind, Raumschots, Vorwind) über den wahren Windeinfallswinkel mit Haltedauer und Fahrtgrenze
- [ ] 2.3 Vollkreis frei über aufsummierte Kursänderung; Achten um zwei Regattatonnen: Kursänderung zählt nur innerhalb 45 m um die aktuelle Tonne, Tonnenwechsel mit Gegenrichtung, Richtungswechsel-Reset, 120-s-Fenster, Hinweis mit Entfernung zur Tonne
- [ ] 2.4 Aufschießer: Übungstonne, „angelaufen“-Bedingung, Stopp-Kriterium, Hinweise zur Entfernung
- [ ] 2.5 Mann über Bord: Auslöser, Marker (Rettungsring/Kopf/Licht/Beschriftung), Retten-Kriterium, „Zu schnell“-Meldung
- [ ] 2.6 Erfolg je Aufgabe (Klang, Meldung), Abschluss mit Zeit

## 3. Anzeige und Menü

- [ ] 3.1 HUD: `_draw_tutorial` als Overlay mittig über dem Boot (große Schrift mit Kontur, Umbruch, Einblenden beim Aufgabenwechsel), Aufgabe n/8 klein darüber, Fortschrittsbalken darunter, Hinweiszeile, Entfernung/Peilung zur Person, Abschlussanzeige
- [ ] 3.2 Menü: Segelschule als Tutorial listen (ohne Bahnlänge), Besetzung/Wind/Treibstoff-Auswahl für Tutorial deaktivieren oder ignorieren, Beschreibung

## 4. Tests und Doku

- [ ] 4.1 `tests/tutorial_test.gd`: Headless-Szenarien je Aufgabe (Bootzustand setzen, Aufgabe schaltet weiter; Negativfälle: falscher Kurs, zu schnell, zu spät, Kreis zu weit von den Tonnen, falsche Tonnenfolge/Drehrichtung)
- [ ] 4.2 Bestehende Tests (`level_check`, Hazard-Tests) und ein Regatta-Lauf laufen weiter; Screenshots der Segelschule prüfen
- [ ] 4.3 Doku: `docs/spielen` (Segelschule, Aufgaben und Tipps), `docs/skripte` (Tutorial-Skript), `docs/referenz` (Konstanten), README, Bahnenliste
- [ ] 4.4 `mkdocs build --strict`, `openspec validate tutorial-level`
