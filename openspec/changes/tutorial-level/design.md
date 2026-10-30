# Design

## Context

Heute besteht jeder Level aus einer `StartLine`, `CourseMark`s und Gefahren; `Course` verfolgt
Start, Tonnen und Ziel, `main.gd` steuert Warten → Countdown → Rennen → Ziel, `hud.gd` zeichnet
Panels, Rangliste, Minimap und Meldungen. Die Besetzung kommt aus `GameState.CREW_OPTIONS`. Der
Wind kommt aus dem Level (`wind_from_deg`, `wind_speed`, `wind_shift_deg`, `gusts`), das Menü kann
ihn überschreiben (`wind_choice`, `gust_choice`, `fuel_choice`). Das Boot liefert Kurs
(`heading`), Fahrt (`speed()`), scheinbaren Wind (`awa`) und Position; den wahren Wind liefert
`WindField.get_wind`.

## Goals / Non-Goals

**Goals:**
- Tutorial als eigener Level-Typ mit eigener, testbarer Aufgabenlogik (reine Zustandsmaschine
  über Bootzustand und Wind, ohne Rennlogik).
- Wiederverwendung von Level-, HUD- und Menü-Struktur; keine Änderung der Regatta-Abläufe.

**Non-Goals:**
- Kein Netzwerkspiel und keine Computergegner im Tutorial.
- Keine Wertung/Bestenliste, keine Sprachausgabe, keine zusätzlichen Aufgaben (z. B. Wende, Halse,
  Reffen) in dieser Änderung.

## Decisions

1. **Level-Flag `tutorial` am `Level`.** Ein exportiertes Feld `tutorial := false`; `Menu` und
   `Main` fragen es ab. Alternative: Dateiname-Konvention – verworfen, weil unsichtbar und
   fehleranfällig.
2. **Aufgabenlogik in einem eigenen `Tutorial`-Skript** (`scripts/tutorial.gd`, `RefCounted`/`Node`),
   das von `Main` angelegt und pro Physikschritt mit dem Boot gefüttert wird. Aufgaben sind eine
   geordnete Liste `{id, titel, text, update(Boot, Wind, delta) → Fortschritt 0..1}`. Dadurch sind
   sie in Headless-Tests ohne Grafik prüfbar (Bootzustand direkt setzen, Schritt aufrufen).
3. **Erkennung über den wahren Windeinfallswinkel**, nicht den scheinbaren: Winkel zwischen
   Bugrichtung und der Richtung, aus der der Wind kommt (0° = genau gegen den Wind).
   Haltedauer: Fortschritt steigt im Bereich (nur mit Fahrt ≥ 1,2 m/s), außerhalb fällt er mit
   dreifacher Geschwindigkeit; Ziel 6 s. Bereiche: Am Wind 40°–55°, Halb 80°–100°, Raum 120°–145°,
   Vorwind 165°–180°.
4. **Kreise über aufsummierte Kursänderung.** Pro Schritt wird `angle_difference` des Kurses
   aufsummiert (nur bei Fahrt > 0,8 m/s); ein Richtungswechsel um mehr als ca. 0,6 rad gegen die
   bisherige Drehrichtung setzt die Summe zurück. Der Vollkreis ist frei (≥ 340°, ohne Tonne).
   Die Acht zählt die Kursänderung nur, solange das Boot höchstens 45 m von der aktuellen
   Zieltonne entfernt ist (sonst Summe zurück und Hinweis mit der Entfernung); nach dem ersten
   Kreis (≥ 340°) wechselt das Ziel auf die zweite Tonne und die Drehrichtung muss sich umkehren;
   dafür bleiben 120 s. Die zwei Regattatonnen sind einfache gelbe Tonnen ohne Kollision, damit man
   sie eng umkreisen kann.
5. **Aufschießer an einer `CourseMark`-ähnlichen Übungstonne** (gelbe Tonne ohne Rundungslogik,
   keine Kollision, damit man „an“ der Tonne stehen kann). Erst wenn das Boot mit ≥ 1,5 m/s aus
   > 25 m Entfernung kam („angelaufen“), zählt das Stehenbleiben (< 0,5 m/s, ≤ 8 m, Bug ≤ 45° neben
   dem Wind). So löst Stehen am Anfang die Aufgabe nicht zufällig.
6. **Mann über Bord als einfacher Marker.** Auslöser: Fahrt ≥ 2 m/s auf Halbwindkurs für 2 s; die
   Person wird 15 m hinter dem Boot abgesetzt (Rettungsring, Kopf, blinkendes Licht,
   Beschriftung), sie treibt nicht. Gelöst bei ≤ 6 m und < 0,8 m/s; schneller Vorbeilauf gibt eine
   Meldung. Alternative: realistischer Drift – verworfen (Komplexität, Test).
7. **Ablauf ohne Rennlogik.** In `Main` überspringt das Tutorial Countdown (Zustand `racing`
   sofort, `race_time` zählt als Tutorial-Zeit), `Course`-Fortschritt, Gegner, Rangliste und Ziel;
   die Startlinie dient nur als Startplatz (kein Ziel). Die Besetzung wird erzwungen: ein Mensch,
   keine KI, Treibstoff 0, Wind/Böen wie im Level (Menü-Überschreibungen werden ignoriert).
8. **Overlay statt Panel** (`_draw_tutorial`): Die Anleitung steht als große Schrift (etwa 34 px,
   weiße Kontur wie die bestehenden Meldungen, Umbruch auf höchstens 60 % der Bildbreite) mittig über
   dem Boot. Die Kamera hält das Boot in der Bildmitte; der Text sitzt etwa 140 px darüber und
   verdeckt das Boot nicht. Aufgabe n/8 und Titel klein darüber, Fortschrittsbalken darunter,
   Fehlhinweis als kleinere zweite Zeile; bei Mann über Bord zusätzlich Entfernung und Peilung zur
   Person. Beim Aufgabenwechsel blendet der Text kurz ein. Abschluss: große Meldung mit Zeit in der
   Mitte. Die bestehende Meldungszeile (`show_message`) meldet Erfolge.
9. **Steuerung:** Neustart über Start-Taste/`F5`, Abbruch über Esc bzw. Zurück-Taste (bereits
   vorhanden). Keine neuen Tasten.
10. **Level-Erzeugung** in `tools/make_levels.gd` (`_segelschule`): offenes Wasser 14 m tief, Wind
    aus 0° mit 5 m/s, `wind_shift_deg = 0`, `gusts = 0`, `fuel_liters = 0`, große Übungsfläche mit
    magenta Grenze, Startplatz in der Mitte, zwei Regattatonnen für die Acht bei (−35, −90) und (35, −90) relativ zum
    Start (70 m auseinander, quer zum Wind), Übungstonne für den Aufschießer etwa 150 m vor dem
    Start getrennt davon, dazu ein paar
    Kardinaltonnen als Kulisse. Eine Windfahne/Pfeil zeigt die Windrichtung (vorhanden).

Annahmen (kein Rückfragebedarf): Windrichtung Nord, 5 m/s; Toleranzen und Haltedauer wie oben; die
Aufgabenfolge ist fest und nicht überspringbar; Reihenfolge der Drehrichtung bei der Acht ist
beliebig, die Anleitung nennt „zuerst nach links/rechts“ anhand der ersten gefahrenen Richtung.

## Risks / Trade-offs

- Toleranzen können für Anfänger zu streng oder zu locker sein → Werte als Konstanten in
  `tutorial.gd`, leicht nachjustierbar; Hinweise nennen die Abweichung.
- Aufschießen ohne Motor und nur mit Schot/Ruder ist schwer → Tonne weit genug von Land und
  Hinweis in der Anleitung („Schot fieren, in den Wind drehen“); Erfolgsradius 8 m großzügig.
- Der Rennablauf in `main.gd`/`hud.gd` bekommt Sonderfälle; Risiko von Regressionen →
  bestehende Hazard-/Level-Tests und ein Regatta-Lauf laufen weiter, Tutorial-Pfad hinter einem
  Flag.
