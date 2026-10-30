# Proposal

## Why

Die Kollisionsform eines Bootes ist ein Kreis mit 3,6 m Radius. Das Boot ist aber nur etwa 9,4 m
lang und 3,2 m breit. Zwei Boote, die nebeneinander fahren, „berühren“ sich deshalb schon bei
7,2 m Mittenabstand – obwohl zwischen den Rümpfen noch mehr als 4 m Wasser liegen. Das löst
Kollisionsstrafen, Bremsen und die Polizei viel zu früh aus.

## What Changes

- Die Kollisionsform eines Bootes folgt dem Rumpf: lang und schmal statt kreisrund (Länge
  etwa 9,4 m, Breite etwa 3,4 m), mit der Ausrichtung des Bootes.
- Boot–Boot-Kollisionen prüfen diese Form: nebeneinander fahrende Boote kollidieren erst bei
  tatsächlicher Berührung der Rümpfe; Bug- und Heckkontakte bleiben so empfindlich wie nötig.
- Dieselbe Form gilt für Kollisionen mit Tonnen und festen Hindernissen, Polizeibooten und
  Berufsschiffen, damit sich alles gleich anfühlt.
- Die Computergegner rechnen ihren Sicherheitsabstand mit der neuen Form statt mit dem Kreis.

## Capabilities

### New Capabilities

(keine)

### Modified Capabilities
- `kollisionen`: Die Kollisionsform der Boote folgt dem Rumpf (lang und schmal) statt eines
  Kreises; Kollisionen entstehen erst bei echter Rumpfberührung.

## Impact

- `scripts/boat.gd` (Form), `scripts/main.gd` (Boot–Boot, feste Punkte, Polizeiboot),
  `scripts/level/shipping_lane.gd` (Berufsschiffe), `scripts/ai_input.gd` (Abstandsrechnung).
- Tests (`tests/hazard_test.gd`), Doku (`docs/referenz/konstanten.md`, `docs/skripte/boot.md`),
  OpenSpec-Spec `kollisionen`.
- Gameplay: Mehr Platz beim Überholen und Nebeneinanderfahren; Kollisionen mit Tonnen werden
  seitlich etwas später, am Bug unverändert früh erkannt.
