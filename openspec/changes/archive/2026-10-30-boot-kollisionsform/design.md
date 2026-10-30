# Design

## Context

`Boat.BOAT_RADIUS = 3.6` ist die einzige Form eines Bootes. Sie wird zweifach verwendet:
(1) Boot–Boot in `Main._resolve_collisions` mit `min_d = 2 · BOAT_RADIUS`, (2) Boot gegen Tonnen und
Hindernisse (`fp[1] + BOAT_RADIUS`), Polizeiboot-Kreise und Berufsschiffe
(`ShippingLane.update_boat`, Rumpfpolygon). Die Computergegner verwenden den Wert für Sicherheitsabstände
(`ai_input.gd`). Das Modell ist etwa 9,4 m lang und 3,2 m breit.

## Goals / Non-Goals

**Goals:**
- Kollision erst bei echter Rumpfberührung, mit der Ausrichtung des Bootes.
- Eine einzige Formdefinition, die alle Kollisionsarten gemeinsam nutzen.
- Geringe Kosten pro Physikschritt (vier Boote, mehrere Hindernisse).

**Non-Goals:**
- Keine Physik mit Drehimpuls/Rotation durch Stöße; die bestehende Reaktion (Abprallen,
  Bremsen, Strafzeit) bleibt.
- Kein Austausch der Form der Berufsschiffe (haben schon ein Rumpfpolygon).

## Decisions

1. **Drei Kreise entlang der Rumpfachse** (`Boat.hull_circles()`): Radius 1,7 m, Mittelpunkte bei
   −3,0 m, 0 und +3,0 m längs des Kurses. Das ergibt etwa 9,4 m × 3,4 m. Alternativen: orientierte
   Rechtecke mit SAT (genauer, aber mehr Code und Sonderfälle bei der Auflösung), Kapsel mit
   Segmentabstand (gut, aber Kreise sind einfacher zu kombinieren). Drei Kreise sind für ein
   Rumpf-Oval ausreichend und lassen sich überall wiederverwenden (Hindernisse, Polizeiboot
   bestehen schon aus Kreisen).
2. **Boot–Boot:** Paarweise Prüfung aller 3×3 Kreispaare; maßgeblich ist das Paar mit der
   größten Überlappung. Normale = Verbindungslinie dieser Kreismittelpunkte, Eindringtiefe =
   Summe der Radien − Abstand. Die Auflösung (Wegschieben, Tempoverlust, `collide`) bleibt wie bisher,
   nur mit dieser Normalen und Tiefe. Grobe Vorprüfung: Mittenabstand > 12 m → keine Prüfung.
3. **Hindernisse und Polizeiboot:** Kreise der Hindernisse werden gegen die drei Bootskreise
   geprüft (Hindernisradius + 1,7 m). Berufsschiffe: Abstand jedes Bootskreises zum Rumpfpolygon
   (`hull_query`) < 1,7 m; nächster Kreis liefert die Normale.
4. **Computergegner:** `BOAT_RADIUS` bleibt als Konstante für grobe Abstände (Kollisions-
   „Reichweite“, jetzt 4,7 m = halbe Länge) erhalten; die Sicherheitsabstände (+14 m, +20 m) werden
   gegen die neuen Distanzen geprüft. Ziel ist, dass die KI beim Überholen nicht schlechter wird.
5. **Konstanten** `HULL_RADIUS` und `HULL_HALF_LENGTH` in `boat.gd`; `BOAT_RADIUS` wird zur
   Reichweite (`HULL_HALF_LENGTH + HULL_RADIUS`) und damit nicht mehr für Boot–Boot benutzt.

## Risks / Trade-offs

- Bug- und Heckkontakte werden früher als bei seitlicher Annäherung erkannt – gewollt, aber die
  KI, die an Tonnen schneidet, kann häufiger streifen → KI-Rennen (Lotsenrinne, Kieler Förde) vor
  und nach der Änderung vergleichen.
- Drei Kreise nähern das Oval an; bei Querlage entstehen minimale Lücken zwischen den Kreisen
  (Boote könnten an der Taille „durchrutschen“) → Kreisabstand 3,0 m bei Radius 1,7 m überlappt
  die Kreise deutlich, daher keine Lücke.
- Die Zahl der Prüfungen steigt (9 statt 1 je Bootspaar); bei vier Booten vernachlässigbar.
