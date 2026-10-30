# Design

## Context

`SeaChart.depth_at(p)` liest bilinear das Tiefengitter (Zellen ≈ 2,9 m); alles, was Land ist
(Boot, KI, Wind, Karte), entscheidet über `depth < LAND` (−0,8 m). Ein Polygon dazu zu rastern
würde die Kante auf die Zellgröße verschmieren. Gleichzeitig soll die Tiefe darunter gröber
rechenbar sein.

## Goals / Non-Goals

**Goals:** exakte Küstenform per Bézier-Umriss; klare Vorrangregel „Raster = Grundlage, Spezifischeres gewinnt“; Boot/KI/Wind/Karte nutzen sie; Editor-Bearbeitung ohne
neues Fremdwerkzeug; grobere Tiefenzellen einstellbar; bestehende Level unverändert.

**Non-Goals:** keine echte 3D-Küstengeometrie,
keine Höhen (Land bleibt flach), kein Import von GIS-Formaten außer SVG.

## Decisions

1. **`LandShape extends Path3D`.** Der Umriss ist die `Curve3D` des Pfades (x/z; y ignoriert):
   Punkte mit `in`/`out`-Griffen ergeben Bézier-Kurven, Punkte ohne Griffe Ecken. Der Pfad-Editor
   von Godot (Punkte setzen, Griffe ziehen, „Kurve schließen“) wird ohne eigenes Gizmo genutzt.
   Die Kurve wird mit `tessellate_even_length` in eine Linie aus Strecken von höchstens 0,5 m zerlegt
   (Abweichung von der echten Kurve < 0,05 m); der Umriss gilt als geschlossen (letzter Punkt →
   erster Punkt, bei Kurve schließen ohne Lücke). Für `depth_at` wird die zerlegte Linie einmal
   zwischengespeichert und neu gebildet, wenn sich die Kurve ändert (`Curve3D.changed`).
   Selbstüberschneidung wird mit `even-odd` ausgewertet und als Editor-Warnung angezeigt.
2. **Felder:** `kind` (LAND | WASSER), `shore_slope` (m Grundanstieg pro m Abstand, Standard 0,22),
   `zone` (Breite des Gebiets um den Umriss, in dem die Form maßgeblich ist, Standard 60 m).
   Deko (Bäume, Häuser, Felsen) entfällt im ersten Schritt.
3. **Tiefenfunktion exakt.** `LandShape.depth_profile(p)` liefert: im Polygon (Art Land)
   `LAND − Abstand_zur_Kante · 0,5`; außerhalb `LAND + Abstand · shore_slope · 1,0`, gedeckelt auf
   die Reichweite. Die Kante selbst ist exakt `LAND`. Art Wasser gräbt: im Polygon Tiefe der
   Umgebung bzw. mindestens `see_depth`, am Rand Übergang wie `ShoalArea.carve_grid`. Alle Formen
   werden in Kindreihenfolge angewendet, dadurch sind Löcher (Wasser über Land) möglich.
4. **Zwei Wege in `depth_at`:**
   a) *Raster*: `Level.compute_depth` bezieht die Formen wie Inseln ein (`minf` für Land,
      Ausgrabung für Wasser). Das ergibt das grobe Tiefenfeld.
   b) *Exakt*: `SeaChart` hält die Liste der Formen (statisch, gesetzt von `Level`, mit
      Begrenzungsrechteck + Spatial-Check). `depth_at(p)` = Raster; liegt `p` im Begrenzungsrechteck
      einer Form, wird zusätzlich `shape.depth_profile(p)` ausgewertet und das Ergebnis dort
      verwendet (Land: `minf`, Wasser: Land wird nur innerhalb des Polygons aufgehoben).
   So bleibt die Kante unabhängig von der Rasterweite. Aufwand pro Aufruf: ein Rechtecktest je Form,
   nur nahe Formen kosten Polygonabstand (O(Eckpunkte)).
5. **Scharfe Karte.** Zusätzlich zur Tiefentextur bekommt der Shader eine **Land-Distanztextur**
   (RF, Meter mit Vorzeichen, Zellgröße 1 m, nur über der Vereinigung der Begrenzungsrechtecke,
   höchstens 2048 × 2048). Der Shader nimmt dort die Uferlinie aus dieser Textur (Nulldurchgang,
   Smoothstep über ein Pixel), außerhalb weiter die Rastertiefe. Rote 1-m-Tiefenlinie bleibt am Raster.
   Die Textur wird im Tiefenaufbau gerechnet (Abstand Punkt–Polygon), im Editor mit gröberer Zelle.
6. **Zellgröße:** `Level.depth_cell` (m, 2–10, Standard 0 = wie bisher automatisch ≈ 2,9 m)
   ersetzt `game_res()`-Ableitung nur wenn gesetzt. Die Menü-Vorschau (160) und der Editor (256)
   bleiben unverändert grob.
7. **Küsten mischen.** Zufallsküsten (`coast_east/west`) und Tiefenbild bleiben; bei `LandShape`
   auf einer Küstenlinie gewinnt das Polygon (Land per `minf`, Wasser hebt Land nur im Polygon auf).
8. **SVG-Werkzeug.** `tools/svg_to_land.py` liest `<polygon>`/`<path>` (M/L/C/S/Q/Z, Bogen wird in Kurven
   genähert), übernimmt Kurven als Bézier-Griffe, skaliert auf `map_size` und schreibt eine `.tscn` mit
   `LandShape`-Knoten und `Curve3D`.

## Vorrang: Raster ist Grundlage

Die Tiefe an einem Punkt wird in Schichten bestimmt, spätere Schichten gewinnen:

1. **Grundlage** (nur wo nichts Genaueres bekannt ist): Zufallsgrund oder Tiefenbild, Pinsel,
   Zufallsküste (`coast_east/west`).
2. **Spezifische Formen** in Szenenreihenfolge: `RiverChannel`/See, `ShoalArea` (Untiefe, Insel, See),
   Mole, Leuchtturmklippe, `LandShape`. Jede Form hat ein **Gebiet** (Fläche der Form plus Randband:
   Radius × Reichweite bzw. `zone` bei `LandShape`). **Im Gebiet ersetzt das Profil der Form die
   Grundlage** (`d = profil`), in den letzten ≈ 15 m des Gebiets wird per `smoothstep` zur Grundlage
   übergeblendet, damit keine Naht entsteht.

Folgen: Eine Landgrenze aus einem Polygon wird nicht durch Rasterland daneben verdoppelt (Rasterland
im Gebiet entfällt); eine Untiefenmarkierung mit „0,3 m“ gilt auch dort, wo der Zufallsgrund
0,1 m ergäbe. Für die vorhandenen Formen, die bisher mit `minf` zusammengeführt wurden, ändert sich
das Ergebnis nur dort, wo die Grundlage flacher als die Form war; das wird mit `level_check`, den
Hazard-Tests und einem Vorher/Nachher-Vergleich der Tiefenkarten aller Level geprüft. Weicht ein Level
sichtbar ab, bleibt für die betroffene Form `minf`.

## Risks / Trade-offs

- `depth_at` wird häufig gerufen (KI) → Begrenzungsrechtecke und früher Ausstieg, Polygonabstand nur
  innerhalb der Reichweite; Messung in den Tests.
- Zwei Quellen für die Tiefe (Raster + Formen) können sich am Rand um die Rasterweite unterscheiden →
  Raster wird mit denselben Formen gefüllt, nur die Kante selbst ist exakt.
- Der Pfad-Editor kennt kein „Fläche füllen“ – Selbstüberschneidungen sind möglich → Editor-Warnung.
- Der Vorrang „Form ersetzt Grundlage“ ändert vorhandene Level geringfügig → Regressionsvergleich (s. o.).

## Migration

Keine; ohne `LandShape` und `depth_cell` ändert sich nichts.
