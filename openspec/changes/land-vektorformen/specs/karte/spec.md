# Spec Delta

## ADDED Requirements

### Requirement: Scharfe Uferlinie aus Vektorformen
Die Seekarte SHALL die Uferlinie von Land-Umrissen (auch Bézier-Kurven) scharf zeichnen, unabhängig von der Auflösung des Tiefenrasters.

#### Scenario: Ecken und Kanten
- **WHEN** ein Land-Umriss spitze Ecken oder lange gerade Kanten hat
- **THEN** zeigt die Karte sie ohne Rasterstufen oder Verrundung

#### Scenario: Grobes Raster
- **WHEN** das Tiefenraster grob gerechnet wird (z. B. 8 m Zellen)
- **THEN** bleibt die Uferlinie der Umrisse scharf, nur die Tiefenfarben sind gröber
