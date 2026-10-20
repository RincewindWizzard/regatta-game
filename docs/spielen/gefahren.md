# Gefahren und Tiere

Gefahrengebiete sind in der Karte **magenta gestrichelt** umrandet. Sie sind absichtlich
sichtbar: Man darf sie jederzeit ansehen, nur nicht in sie hineinfahren. Die Technik dahinter
steht in [Gefahren, Tiere, Effekte](../skripte/gefahren.md).

## Minenfeld

![Minenfeld](../bilder/minenfeld.png)

* Schwarze Kugeln mit Stacheln und rot blinkendem Licht, umgeben von gelben Sperrtonnen.
* Wer eine Seemine **berührt** (Abstand unter 4,8 m), **explodiert**: Feuerball, Rauch,
  Trümmer, Druckwelle. Das Boot sinkt und ist **aus dem Rennen**.
* Die anderen segeln weiter. Sind alle Boote draußen, endet das Rennen mit „Alle Boote
  verloren!“.
* 30 m vor der Grenze erscheint die Meldung „Achtung: Minenfeld voraus!“.

## Polizei-Sperrgebiet

* Wer hineinfährt, bekommt „Sperrgebiet! Sofort umkehren!“. Bleibt das Boot **1,6 Sekunden**
  im Gebiet, nähert sich die **Wasserschutzpolizei** mit Blaulicht und Sirene.
* Das Boot wird **8 Sekunden** festgehalten und durchsucht (Motor aus, Fahrt läuft aus,
  Steuern und Schot gesperrt).
* Danach gibt es **25 Sekunden Schonfrist**, damit man das Gebiet verlassen kann.

## Sirenen-Insel

![Sirenen-Insel](../bilder/sireneninsel.png)

* Die Insel hat Sirenen auf den Felsen, wandernde Noten und türkise Wellenringe. Die
  gestrichelte magenta Linie zeigt, **wie nah man ihr kommen darf**.
* Wer die Linie überfährt, bleibt stehen, das Boot dreht sich langsam zur Insel, rund
  **7 Sekunden** lang. Dann 25 Sekunden Schonfrist.

## Berufsschifffahrt

![Frachter und Tanker in der Lotsenrinne](../bilder/schifffahrt.png)

In der **Lotsenrinne** gibt es einen Schifffahrtsweg: Containerschiffe, Tanker und
Massengutfrachter (je rund 80 m lang, 7 kn) fahren das Fahrwasser hinauf und hinunter. Auf der
Karte zeigen magenta **Richtungspfeile** die beiden Fahrspuren, in der Minikarte sind die Schiffe
dunkle Striche.

* Die Schiffe fahren **rechts** (Rechtsfahrgebot): Nordwärts in der östlichen, südwärts in der
  westlichen Spur. In der Mitte bleibt eine etwa 28 m breite Lücke.
* **Ausweichen** ist Pflicht: Ein Schiff weicht nicht aus. Wer mit dem Rumpf zusammenstößt, wird
  hart zurückgeworfen, verliert 30 % Fahrt und hat **5 Sekunden** lang halb so viel Vortrieb
  (Meldung „Kollision mit Berufsschiff!“).
* Ist ein Schiff **näher als 95 m** (bis zum Rumpf), kommt eine Warnung mit dem Namen des
  Schiffs („Hanse Trader: Berufsschiff! Ausweichen!“) und ein tiefes Signalhorn.
* Die Schiffe ziehen einen weißen **Kielwasser-Keil** hinter sich her. Er zeigt, wo sie
  gefahren sind, bremst aber nicht.
* Ein Schiff **überholt** Boote auch von hinten: Beim Kreuzen im Fahrwasser gelegentlich über
  die Schulter schauen!

Die Computergegner rechnen die Positionen der Schiffe für die nächsten 12 Sekunden voraus und
weichen ihnen aus. Technik: [Gefahren, Tiere, Effekte](../skripte/gefahren.md#shipping-lane-gd).

## Tiere und Wracks

| Tier | Verhalten |
|---|---|
| Tümmler | Gruppe springt in Bögen im Kreis, Spritzer beim Ein- und Austauchen |
| Wal | zieht Kreise, taucht auf, bläst eine Fontäne, taucht mit hochgereckter Fluke ab |
| Möwen | kreisen mit Schlagflügeln, ihr Schatten läuft über das Wasser |
| Seehunde | liegen auf Fels oder Sandbank, heben den Kopf |
| Wrack | gestrandetes Schiff mit Spanten und Mast, **fest**: Boote prallen ab, die KI umfährt es |

![Wrack](../bilder/wrack.png)

Alle Tiere sind reine Dekoration und stören die Boote nicht.
