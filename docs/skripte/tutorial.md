# Die Segelschule: `tutorial.gd`

Die Segelschule ist ein Level mit `Level.tutorial = true`. Sie läuft **ohne Rennlogik**; die
Aufgabenlogik steckt in einer eigenen Klasse, die vom `Main` angelegt wird. Spieler-Sicht:
[Segelschule](../spielen/segelschule.md).

## Wie der Ablauf umgeschaltet wird

| Stelle | Änderung für das Tutorial |
|---|---|
| `Level.tutorial` (Export) | kennzeichnet den Level; das Menü zeigt „Tutorial · 1 Spieler …“ statt der Bahnlänge |
| `GameState.apply_wind`, `start_fuel` | Wind, Böen und Treibstoff kommen aus dem Level, Menü-Überschreibungen werden ignoriert |
| `Main._ready` | nur **ein** Mensch (`slots` wird ersetzt), `course.disabled = true`, Zustand sofort `racing`, `Tutorial` wird als Kindknoten angelegt |
| `Course.disabled` | `update_progress` tut nichts: Start, Tonnen und Ziel zählen nicht |
| `Boat` | der Richtungspfeil zur nächsten Tonne ist aus |
| `RaceHud` | statt Countdown/Ziel zeichnet `_draw_tutorial` das Overlay; Panel ohne „Platz“ und ohne Ziel |

Nach der letzten Aufgabe setzt `tutorial.finished` den Zustand auf `finished`; Start/Enter
(`restart()`) lädt die Szene neu, `Esc` bzw. die Zurück-Taste führt ins Menü.

## `scripts/tutorial.gd`

`class_name Tutorial`, `extends Node`. Eine **Zustandsmaschine**: `index` ist die laufende Aufgabe
(Liste `TASKS` mit `id`, `titel`, `text`), `progress` (0…1), `hint` (Fehlhinweis), `done`.
`step(delta)` wertet den Bootszustand aus (die Engine ruft es aus `_physics_process`; Tests rufen es
direkt). Alle Schwellen sind Konstanten am Dateianfang.

| Aufgabe | Auswertung |
|---|---|
| Kurse zum Wind | `true_wind_angle()` = Winkel zwischen Bug und der Richtung, aus der der Wind kommt (`acos` des Skalarprodukts). Liegt er im Bereich aus `RANGES` und ist die Fahrt ≥ `MIN_SPEED`, wächst `progress` um `delta / HOLD_TIME`, sonst fällt er mit dreifacher Geschwindigkeit |
| Vollkreis | `_accumulate_turn()` summiert `angle_difference(alt, neu)` des Kurses (nur bei Fahrt > 0,8 m/s). Kehrt die Drehrichtung um mehr als 0,6 rad um, beginnt die Summe neu. Ab 340° gelöst |
| Achten | wie Vollkreis, aber nur im Umkreis `EIGHT_RADIUS` um die aktuelle Tonne (`Acht_A`, dann `Acht_B`); erst links herum (+), dann rechts herum (−) innerhalb `EIGHT_WINDOW`, sonst von vorn |
| Aufschießer | nach einem **Anlauf** (`_armed`: ≥ 1,5 m/s aus > 25 m) zählt Stehenbleiben: ≤ 8 m, < 0,5 m/s, Bug ≤ 45° zum Wind |
| Mann über Bord | Auslöser: ≥ 2 m/s auf Halbwindkurs für 2 s; `_drop_mob()` setzt die Person 15 m hinter das Boot und baut den Marker (Ring, Kopf, Licht, Schild); gelöst bei ≤ 6 m und < 0,8 m/s, schnelles Vorbeifahren gibt „Zu schnell“ |

Dass die Drehrichtung positiv „nach links“ heißt, folgt aus der Kursdefinition des Bootes:
`heading` wächst gegen den Uhrzeigersinn (Blick von oben, Norden oben).

## Level `09_segelschule.tscn`

Erzeugt von `_segelschule()` in `tools/make_levels.gd`: offenes Wasser (14 m), Nordwind 5 m/s ohne
Böen und Dreher, `fuel_liters = 0`, Startplatz bei (0, 40) und drei `CourseMark`s, die das Skript
**über ihren Namen** findet: `Acht_A` (−35, −90), `Acht_B` (35, −90) und `Uebungstonne` (150, −30).
Wer Aufgaben verschieben will, verschiebt diese Knoten im Editor.

## HUD-Overlay

`RaceHud._draw_tutorial` zeichnet die Anleitung als große Schrift (34 px mit weißer Kontur, Umbruch
auf 60 % der Bildbreite) **über dem Boot** – der Block endet 100 px über der Bildmitte, damit er das
Namensschild nicht verdeckt –, darüber „Aufgabe n/8 · Titel“, darunter den Fortschrittsbalken, bei
„Mann über Bord“ Entfernung und Richtung zur Person und zuletzt den Hinweis. Beim Aufgabenwechsel
blendet der Text über `flash` ein.

## Tests

* `tests/tutorial_test.gd`: Headless, ohne Grafik. Setzt Kurs, Fahrt und Position direkt und prüft
  je Aufgabe Positiv- und Negativfälle (zu langsam, falscher Winkel, Kreis zu weit von den Tonnen,
  Stehen ohne Anlauf, zu schnell an der Person vorbei) und den Abschluss.
* `tests/tutorial_shots.gd`: Bilder mit Grafik (Overlay, Mann über Bord, Ende).
