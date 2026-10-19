# Eigene Bahnen bauen

Jede Bahn ist eine ganz normale Godot-Szene in `levels/`. Alles, was dort liegt, erscheint
automatisch im Startmenü. Das Plugin **Regatta Level-Editor** ist im Projekt bereits aktiv
(Technik: [Level-Editor-Plugin](../skripte/editor.md)).

## Neue Bahn anlegen

1. Im Dateisystem eine vorhandene Bahn duplizieren (Rechtsklick → *Duplizieren…*) und
   umbenennen, z. B. `levels/08_meine_bahn.tscn`. (Oder: neue Szene, Wurzel-Node vom Typ
   **Level** wählen.)
2. Szene öffnen. Am besten von oben schauen: im 3D-Viewport **Num 7** (Draufsicht), Mausrad
   zoomt. Die Seekarte wird live im Editor gezeichnet.
3. Im Inspector des **Level**-Nodes: Name, Beschreibung, Wind (Richtung, Stärke, Dreher, Böen)
   und Grundeigenschaften des Seegrunds (Tiefe, Variation, Zufallswert, Küsten).
4. Pflicht: **eine `StartLine`** und **mindestens eine `CourseMark`**. Ohne Startlinie
   bricht `main.gd` ab.

## Bausteine

Oben in der 3D-Werkzeugleiste gibt es **„+ Baustein“** (sichtbar, wenn das Level ausgewählt
ist). Eingefügte Bausteine landen in der Mitte der Ansicht. Verschieben/Drehen/Skalieren mit
den normalen Godot-Gizmos (`W`/`E`/`R`).

| Baustein | Bedeutung |
|---|---|
| **StartLine** | Start- und Ziellinie. Der Magenta-Pfeil zeigt die Startrichtung, das Ziel ist dieselbe Linie zurück. Breite im Inspector. Drehen erlaubt. → [Details](../skripte/level.md#start-line-gd) |
| **CourseMark** | Tonne. Die **Reihenfolge im Szenenbaum** ist die Rundungsreihenfolge (im Editor als „1.“, „2.“ … beschriftet). Zum Umsortieren einfach im Baum ziehen. |
| **ShoalArea** | Untiefe oder Insel (Art im Inspector). Radius im Inspector; mit Skalieren in X/Z und Drehen werden Ellipsen daraus. Inseln können einen Leuchtturm haben. |
| **SeaMark** | Seezeichen: Kardinaltonne Nord/Ost/Süd/West, Einzelgefahr, Fahrwasser rot/grün, Ansteuerung. Boote prallen ab. |
| **Mole** | Felsmole (Länge, Breite) mit Molenfeuer rot/grün/weiß am Kopf. Für Boote Land. |
| **Lighthouse** | Leuchtturm auf Felsklippe mit drehendem Lichtkegel, verschiedene Farbschemata. |
| **ChartRose** | Kompassrose als Dekoration. |
| **CurrentArea** (Strömung) | Strömungsfeld: Stärke in kn, Länge/Breite, optional Gezeitenperiode (Strom kentert). Fließt in Pfeilrichtung (lokal −Z), mit Drehen ausrichten. |
| **RiverChannel** (Flusslauf) | Ein Godot-`Path3D`: Punkte mit dem Pfad-Werkzeug setzen/ziehen. Gräbt einen Fluss ins Land, Breite (+ `width_curve`), Tiefe, Fließgeschwindigkeit vom ersten zum letzten Punkt, Uferbäume, Name. Schmal = schneller. |
| **ShoalArea „See“** | gräbt einen See ins Land (für Binnenreviere). |
| **FuelDock** (Tankstelle) | Steg mit Zapfsäule. Wurzel an Land setzen, Pfeil (lokal −Z) zeigt ins Wasser; der Liegeplatz liegt am Stegkopf. |
| **SeaLife** | Tümmler, Wal, Möwen, Seehunde, Wrack. `count` Tiere im Umkreis `range_m`. Wrack ist fest (`solid`). |
| **RestrictedArea** | Minenfeld (Boot explodiert, ausgeschieden) oder Polizei-Sperrgebiet (Kontrolle). Radius und Minenzahl im Inspector. |
| **SirenIsland** | Insel, deren Gesang Boote bis `song_range` vom Ufer festhält. |

Inseln (ShoalArea, Art „Insel“) haben im Inspector unter *Insel-Ausstattung* Bäume, Häuser und
Uferfelsen. Tipp: Untiefe auswählen und **„+ Baustein → Kardinaltonnen um ausgewählte
Untiefe“**: Dann stehen die vier Tonnen automatisch richtig. Die Grenze des Regattagebiets
stellst du am Level-Node unter *Regattagebiet → area_margin* ein, die Tankmenge unter
*Motor → fuel_liters*.

**Binnenrevier:** Am Level-Node *Seegrund → inland* einschalten. Dann ist alles Land, und Seen
(ShoalArea „See“) und Flüsse (RiverChannel) graben das Wasser hinein. Beispiel:
`levels/07_flussregatta.tscn`.

## Seegrund malen

Level-Node auswählen → in der Werkzeugleiste **Seegrund:** einen Pinsel wählen und mit der linken
Maustaste über die Karte malen. Die Karte zeigt die Änderung sofort.

| Pinsel | Wirkung |
|---|---|
| Flacher / Tiefer | Seegrund anheben / absenken (für Rinnen, Bänke, Fahrwasser) |
| Land | stark anheben: wird zu Land mit Uferlinie |
| Glätten | Kanten weich machen |
| Radierer | gemalte Änderungen zurücknehmen |
| Aus | normale Auswahl, Pinsel inaktiv |

Größe und Stärke stellst du daneben ein. Jeder Strich lässt sich mit **Strg+Z** rückgängig
machen; „Gemalten Grund löschen“ setzt alles zurück. Die Malerei wird in der Szene gespeichert.

**Spiellogik = Karte:** Tiefgang 1 m. Was auf der Karte flacher ist, ist auch im Spiel Grund.

## Checkliste vor dem Spielen

```bash
godot --headless --path . --script res://tests/level_check.gd
```

Prüft für **jede** Bahn:

* Startplätze, Linienmitte und alle Marken liegen in **mindestens 2,5 m** Wasser und im
  Regattagebiet,
* Tankstellen: Stegwurzel an Land (≤ 0,5 m), Liegeplatz in **mindestens 2 m** Wasser,
* die Linienenden sind befahrbar.

Zusätzlich lohnt sich ein Probelauf der KI:

```bash
godot --headless --fixed-fps 60 --path . --script res://tests/ai_race.gd -- res://levels/08_meine_bahn.tscn mix
```

Kommen alle vier Boote ins Ziel, ohne dauernd auf Grund zu laufen (`Grund`-Spalte) oder das
Gebiet zu verlassen, ist die Bahn gut befahrbar.

## Ein Rezept: Tankstelle auf einer Insel

1. Die Insel (`ShoalArea`, Art Insel, Radius 40 m) steht bei `(-150, 120)`.
2. Der Steg soll an die **Nordseite**. Nord ist −z, also muss der Pfeil des Stegs (lokal −Z)
   nach −z zeigen: **keine Drehung**.
3. Die **Wurzel** (Ursprung des Stegs) gehört 8 bis 10 m **in** die Insel, also bei
   `(-150, 88)` (Ufer bei `z = 120 − 40 = 80`).
4. Länge 40 m: Der Stegkopf liegt bei `z = 48`, der Liegeplatz bei `z ≈ 52`, rund 28 m vor dem
   Ufer, in tiefem Wasser.
5. `level_check.gd` ausführen. Es meldet, falls die Wurzel im Wasser oder der Liegeplatz zu
   flach ist.

Der **Liegeplatz muss weit genug vom Ufer entfernt** sein, sonst laufen Boote beim Anlegen auf
Grund (so war es bei der ersten Position im Schärengarten).

## Bahn per Skript erzeugen

Siehe [Werkzeuge und Tests](../skripte/werkzeuge.md#tools-make-levels-gd) und das Beispiel
[Ein Mini-Level von Hand bauen](../skripte/level.md#beispiel-ein-mini-level-von-hand-bauen).
