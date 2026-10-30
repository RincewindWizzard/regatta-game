# Design

## Context

`Level.depth_image` (Pfad eines PNG) wird in `_base_grid(res)` eingelesen: `_load_depth_image()` liest die
Rohdatei (`FileAccess.get_file_as_bytes` + `Image.load_png_from_buffer`, damit es auch im exportierten
Spiel geht) und tastet sie bilinear in das Tiefengitter ab. Die Zuordnung ist fest
(`-8 + v · 0,1`, Kanal R) und das Bild füllt das ganze Gebiet `SeaChart.AREA_MIN` ..
`AREA_MIN + AREA_SIZE` (1280 m). Der Wert steckt in `Level` und in `tools/chart_to_depth.py`.

## Goals / Non-Goals

**Goals:**
- Zuordnung Grau → Tiefe und Bildlage einstellbar, mit Standardwerten, die das heutige Verhalten
  exakt erhalten.
- Beliebige Bildgröße; Farbbilder; sichtbar und wirksam in allen Vorschauen.

**Non-Goals:**
- Keine 16-Bit-Auswertung (Godot lädt PNGs mit 8 Bit je Kanal; höhere Genauigkeit lässt sich über
  den Wertebereich erreichen) und keine nichtlinearen Kurven oder Paletten.
- Keine zweite Bildquelle (kein Mischen mehrerer Tiefenbilder), keine Änderung des Pinsels.

## Decisions

1. **Neue Export-Felder an `Level`** (Gruppe „Seegrund“, neben `depth_image`):
   `depth_image_black` (Tiefe bei Wert 0, Standard −8,0 m), `depth_image_white` (Tiefe bei Wert 255,
   Standard +17,5 m), `depth_image_invert` (Standard aus), `depth_image_rect` (`Rect2` in Weltmetern,
   Standard = Kartengebiet), `depth_image_outside` (Tiefe außerhalb, Standard −8,0 m = Land).
   Alternative: nur Minimum und Maximum ohne Invert – verworfen, weil „hell = flach“ bei
   Seekarten-Rastern üblich ist; Tauschen von Schwarz und Weiß erledigt es ebenso, `invert` ist aber
   lesbarer. Wir behalten beides schlank: `invert` vertauscht die beiden Tiefen.
2. **Umrechnung:** `t = Helligkeit/255`, `Tiefe = lerp(black, white, t)`; mit `invert`
   `lerp(white, black, t)`. Helligkeit = Mittel der Kanäle R, G, B (bei Graustufen gleich R).
3. **Abtasten:** Für jede Gitterzelle (Weltposition) wird `uv = (p − rect.position) / rect.size`
   gebildet; liegt `uv` außerhalb [0,1], gilt `depth_image_outside`, sonst bilinear (Kantenpixel
   gespiegelt/geklemmt). So wirkt die Auflösung des Bildes unabhängig vom Spielraster.
4. **Cache-Schlüssel:** Der Gitter-Cache (`_base_cache`) wird bei jeder Änderung eines dieser Felder
   geleert, die Setter rufen `queue_preview()` wie bei den vorhandenen Seegrund-Feldern; das
   Menü-Vorschaubild (`menu.gd`, `compute_depth`) und `Level` im Editor (`@tool`) nutzen denselben Weg.
5. **Werkzeug:** `tools/chart_to_depth.py` bekommt die Parameter `black`, `white` (und schreibt sie in
   die Meldung) statt der festen Konstanten; seine Standardwerte entsprechen denen des Levels. Der
   Kieler-Förde-Level setzt die Werte ausdrücklich (Dokumentation durch Beispiel).
6. **Fehlerfälle:** Nicht lesbares Bild → Warnung und zufälliger Grund wie bisher; `rect.size`
   mit 0 → Warnung und Kartengebiet.

## Risks / Trade-offs

- Verstellte Werte können Land/Wasser verschieben (Küste liegt bei −0,8 m) → die Vorschau zeigt es
  sofort; die Doku nennt die Schwellen (Land < −0,8 m, flach < 1 m, Tiefgang 1 m).
- 8 Bit → 256 Stufen: Bei sehr großem Wertebereich (z. B. 0–100 m) wird die Tiefe grob (≈ 0,4 m) →
  in der Doku genannt; Wertebereich passend wählen.
- Mehr Einstellungen im Inspector → übersichtlich in einer Untergruppe „Tiefenbild“.
