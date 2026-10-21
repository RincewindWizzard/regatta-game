# Die Bahnen

Die vollständigen Karten aller Bahnen stehen unter [Die Karten](karten.md).

Alle Bahnen liegen als Godot-Szenen in `levels/` und erscheinen automatisch im Menü. Wie sie
aufgebaut sind, steht in [Level und Bausteine](../skripte/level.md); eigene Bahnen baut man
nach [Eigene Bahnen bauen](../referenz/bahnen-bauen.md).

| | Bahn | Datei | Besonderheit |
|---|---|---|---|
| 1 | Mittelgrund-Regatta | `01_mittelgrund.tscn` | Dreieckskurs zwischen Untiefen mit Kardinaltonnen, Leuchtturm, Plattenstrom (Gezeitenstrom). Tümmler, Wal, Möwen, Seehunde und ein Wrack |
| 2 | Kurzer Up-and-Down | `02_kurzer_up_and_down.tscn` | zum Einsegeln, leichter Wind, keine Tankstelle |
| 3 | Rund um Möwenhörn | `03_rund_um_moewenhoern.tscn` | einmal um die Leuchtturminsel, Seehundsstrom, **altes Minenfeld** im Südosten |
| 4 | Hafenausfahrt | `04_hafenausfahrt.tscn` | Start im Hafen zwischen Felsmolen, Strom in der Einfahrt, **Marine-Sperrgebiet** im Westen |
| 5 | Lotsenrinne | `05_lotsenrinne.tscn` | Kreuzen im betonnten Fahrwasser zwischen zwei Sandbänken, Ebbstrom, **Berufsschifffahrt** (Frachter, Tanker, Containerschiffe), ein Wrack auf der Westerbank |
| 6 | Schärengarten | `06_schaerengarten.tscn` | bewaldete Schären, Klippen, zwei Sunde mit Strömung, böiger Wind, **Tankstelle auf Granholm** im Norden, **Sirenen-Insel** im Süden |
| 7 | Flussregatta | `07_flussregatta.tscn` | Binnenrevier: den Mühlenfluss gegen den Strom hinauf in den Großen See und zurück, **Vogelschutzgebiet** mit Polizeikontrolle |
| 8 | Kieler Förde | `08_kieler_foerde.tscn` | **Strecke von A nach B** (nicht maßstabsgetreu): Start in der Schwentinemündung, Ziel vor dem Olympiahafen Schilksee. Ostseekai, Düsternbrook, Tirpitzmole, NOK-Schleuse Holtenau, **Friedrichsorter Enge** mit Leuchtturm, U-Boot-Ehrenmal und Marine-Ehrenmal Laboe; **Berufsschifffahrt** in der Fahrrinne, Marine-Sperrgebiet, zwei Tankstellen |

## Tipps pro Bahn

**Kieler Förde.** Der Start liegt im schmalen Fluss Schwentine ganz im Südosten, der Wind kommt
aus Westsüdwest: Die ersten Meter geht es also hoch am Wind aus dem Fluss. Dann führt die
Strecke die Förde nach Norden: **Ostseekai** (Kreuzfahrtterminal am Hörn, unten links) →
**Düsternbrook** (Hafen mit zwei Molen) → **Tirpitzmole** → **NOK Holtenau** (Schleusenmolen) →
**Friedrichsorter Enge** (links der Leuchtturm, rechts das U-Boot-Ehrenmal) → **Falkenstein**
und zum Schluss durch die Molen des **Olympiahafens Schilksee**, wo die Ziellinie liegt. Mitten
in der Förde fahren Frachter, Tanker und Containerschiffe hin und her: In der Enge ist es am
engsten, ein Zusammenstoß mit einem Schiff scheidet aus. Das Marine-Sperrgebiet vor dem
Arsenal ist tabu (Polizeikontrolle). Getankt werden kann am Hafen Düsternbrook und am
Falkenstein Anleger.


**Mittelgrund-Regatta.** Der Wind kommt aus Norden, also geht es zuerst gegen den Wind
(Luvtonne) und dann zurück. Die Untiefen sind mit Kardinaltonnen markiert: an der Südtonne
südlich vorbei, an der Nordtonne nördlich. Der Plattenstrom kentert alle vier Minuten.

**Rund um Möwenhörn.** Wind aus Nordwest. Die Südtonne liegt am Rand des Minenfeldes:
Wer sie zu weit überfährt, landet zwischen den Minen. Erst wenden, dann Kurs auf die Linie.

**Hafenausfahrt.** Wind aus Westen, also läuft man nach dem Start nicht direkt gegen den
Wind, sondern halb. Das Sperrgebiet im Westen liegt genau auf der Kreuzschlag-Linie.
Wer zu weit über die Layline hinausfährt, wird von der Wasserschutzpolizei angehalten.

**Lotsenrinne.** Eng. Rot an Backbord, grün an Steuerbord, wer die Tonnen schneidet, sitzt
fest. Der Ebbstrom schiebt gegen dich. Dazu kommt die **Berufsschifffahrt**: Alle 70 Sekunden
fährt ein Schiff durch die Rinne, abwechselnd nord- und südwärts, jeweils rechts. Zwischen den
beiden Spuren bleibt eine Lücke in der Mitte. Warte mit dem Wenden, bis das Schiff vorbei ist,
und kreuze nicht in dessen Bahn. Die Wendetonne (0, −580) liegt mitten im Schifffahrtsweg.

**Schärengarten.** Die erste Tankstelle liegt auf der **Nordseite von Granholm**, ungefähr
170 m vom Start, also genau in dem Bereich, in dem man zu Beginn gegen den Wind kreuzt. Die
Sirenen-Insel liegt südlich der Holmtonne: Die Tonne selbst ist sicher, wer sie aber weit
überfährt, hört den Gesang.

**Flussregatta.** Gegen die Strömung den engen Fluss hinauf. Hinter den Windstrichen sieht
man den Landschatten der Ufer: Wo kein Wind ist, hilft der Motor.
