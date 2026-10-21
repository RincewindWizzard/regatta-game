# Wandelt eine Seekarte (Bild) in eine Seegrund-Karte für ein Level um.
#
# Eingabe: PNG einer Seekarte (Land gelb/grau, Wasser weiß/blau). Das Skript
#   1. trennt Land und Wasser über die Farbe und füllt Beschriftungen/Symbole,
#   2. behält nur das zusammenhängende Wasser um einen Startpunkt (Förde ohne Seen),
#   3. verbreitert alle Wasserwege um "erode" Meter (verkleinerte Karte sonst zu eng),
#   4. rechnet Abstand zur Küste in Tiefe um (flach am Ufer, tiefer zur Mitte),
#   5. schreibt ein 8-Bit-Bild, das Level.depth_image einliest: Wert v -> Tiefe = -8 + 0,1 * v.
#
# Aufruf: python tools/chart_to_depth.py <seekarte.png> <ausgabe.png> <json-mit-Parametern>
import json, sys
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

Image.MAX_IMAGE_PIXELS = None
src, out, cfg_path = sys.argv[1], sys.argv[2], sys.argv[3]
cfg = json.load(open(cfg_path))

im = np.asarray(Image.open(src).convert("RGB")).astype(int)
R, G, B = im[..., 0], im[..., 1], im[..., 2]
mx, mn = im.max(axis=2), im.min(axis=2)

# Land: blassgelb (R etwas über B) oder graue Bebauung. Wasser: weiß oder bläulich. Kräftiges Gelb,
# Leuchtfeuer-Sektoren (kräftiges Gelb) sind Kartenzeichen im Wasser und zählen als Wasser;
# dünne Linien und Schrift werden durch Schließen/Öffnen bereinigt.
yellow = ((R - B) > 22) & ((R - B) <= 95)
grey = ((mx - mn) < 14) & (mx < 238)
white = mn >= 236
blue = (B - R) > 12
magenta = (R > 170) & (B > 90) & (G < 150) & ((R - G) > 50)
sat_yellow = (R - B) > 95
water_c = (white | blue | sat_yellow) & ~yellow & ~grey
water_c = ndi.binary_closing(water_c, iterations=6)
water_c = ndi.binary_opening(water_c, iterations=2)
for (bx0, by0, bx1, by1) in cfg.get("blank", []):         # Einschübe/Legenden der Karte ausblenden
    water_c[by0:by1, bx0:bx1] = False
# Straßen und Gräben an Land hängen sonst am Wasser: Kern des Wassers bestimmen (Öffnen mit großem
# Element trennt dünne Verbindungen), dann nur knapp um den Kern herum wieder aufbauen
core_c = ndi.binary_opening(water_c, iterations=7)
lab, n = ndi.label(core_c)
seed = tuple(cfg["seed"][::-1])          # (x, y) -> (y, x)
core = lab == lab[seed]
water = ndi.binary_dilation(core, iterations=8) & water_c
# kleine Landflecken (Beschriftungen) im Wasser entfernen
land_lab, ln = ndi.label(~water)
sizes = ndi.sum(np.ones_like(land_lab), land_lab, index=np.arange(1, ln + 1))
for i, sz in enumerate(sizes, start=1):
    if sz < cfg.get("min_land_px", 200000):
        water[land_lab == i] = True
Image.fromarray((water * 255).astype(np.uint8)).resize((500, 708)).save(out.replace(".png", "_mask.png"))

# Ausschnitt: Welt (x, z) in Metern -> Bildpunkt; AREA = (-640, -840), 1280 m, RES Pixel
k = cfg["m_per_px"]                         # Spielmeter je Kartenpixel
x0, y0 = cfg["x0"], cfg["y0"]               # Bildpunkt der Weltecke (-640, -840)
RES = cfg.get("res", 640)
cell = 1280.0 / RES
xs = x0 + (np.arange(RES) + 0.5) * cell / k
ys = y0 + (np.arange(RES) + 0.5) * cell / k
H, W = water.shape
yy, xx = np.meshgrid(np.clip(ys.astype(int), 0, H - 1), np.clip(xs.astype(int), 0, W - 1), indexing="ij")
w = water[yy, xx]
outside = (ys[:, None] >= H) | (xs[None, :] >= W) | (ys[:, None] < 0) | (xs[None, :] < 0)
w = np.where(outside, False, w)

# Wasserwege verbreitern: Land um "erode" Meter zurückziehen
dist_land = ndi.distance_transform_edt(w) * cell        # Abstand zum Land (Wasserzellen)
dist_water = ndi.distance_transform_edt(~w) * cell      # Abstand zum Wasser (Landzellen)
e = cfg.get("erode", 0.0)
sd = np.where(w, dist_land + e, -(dist_water - e))      # vorzeichenbehaftet: + Wasser, - Land
sd = np.where(~w & (dist_water <= e), np.abs(dist_water - e) * 0 + (e - dist_water), sd)
slope = cfg.get("slope", 0.1)                           # Meter Tiefe je Meter Abstand
depth = -0.8 + sd * slope
depth = np.clip(depth, -8.0, cfg.get("max_depth", 14.0))
v = np.round((depth + 8.0) / 0.1).astype(np.uint8)
Image.fromarray(v, "L").save(out)
print("geschrieben", out, v.shape, "Wasseranteil %.2f" % w.mean())
