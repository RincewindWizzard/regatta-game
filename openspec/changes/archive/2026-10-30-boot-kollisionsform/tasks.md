# Tasks

## 1. Form

- [x] 1.1 `Boat`: Konstanten `HULL_RADIUS` (1,7 m), `HULL_HALF_LENGTH`, `hull_circles()` (drei Kreise in Kursrichtung), `BOAT_RADIUS` als grobe Reichweite neu belegen

## 2. Kollisionen

- [x] 2.1 `Main._resolve_collisions`: Boot–Boot über die Kreispaare (größte Überlappung → Normale und Tiefe), Vorprüfung nach Mittenabstand; Reaktion, Kontakttimer und Polizeiauslösung bleiben
- [x] 2.2 Feste Punkte (Tonnen, Moles, Wracks) und Polizeiboot-Kreise gegen die Bootskreise prüfen
- [x] 2.3 `ShippingLane.update_boat` und Warnabstand: Bootskreise gegen das Rumpfpolygon
- [x] 2.4 `AIInput`: Sicherheitsabstände (`_ship_guard`, `_hazard`, Boot-zu-Boot) auf die neue Form abstimmen

## 3. Tests und Doku

- [x] 3.1 `tests/hazard_test.gd`: neue Szenarien „nebeneinander“ (4 m Abstand → keine Kollision, 3 m → Kollision) und „bug“ (Bug auf Bug erst bei ~9,4 m); vorhandene Szenarien (`kollision`, `rammen`, `schiff`, `polizei`) laufen weiter
- [x] 3.2 KI-Rennen (Lotsenrinne, Kieler Förde) vor und nach der Änderung vergleichen (Kollisionen, Grundberührungen, Zielankünfte)
- [x] 3.3 Doku: `docs/referenz/konstanten.md`, `docs/skripte/boot.md` (Kollisionsform), `docs/spielen/gefahren.md` (Unfallregel-Hinweis)
- [x] 3.4 `mkdocs build --strict`, `openspec validate boot-kollisionsform`
