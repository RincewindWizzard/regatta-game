# Wandelt Pfade und Polygone einer SVG-Datei in LandShape-Knoten (Bézier-Umrisse) für ein Level um.
#
# Unterstützt: <path> (M L H V C S Q T Z, absolut und relativ), <polygon>, <polyline>, <rect>.
# Kurven bleiben Kurven (Bézier-Griffe), Quadratische werden in kubische umgerechnet. Bögen (A) werden
# durch eine Gerade zum Endpunkt ersetzt (mit Warnung). Jeder Unterpfad wird eine eigene Landform.
# Das SVG wird so auf die Karte skaliert, dass die viewBox (bzw. width/height) genau die Karte
# map_origin .. map_origin + map_size deckt (Seitenverhältnis wird nicht erhalten: Bild streckt wie
# beim Tiefenbild).
#
# Aufruf: python tools/svg_to_land.py <karte.svg> <ausgabe.tscn> [--size 1280 1280] [--origin -640 -840]
#                                      [--water id1,id2] [--only id]
#   --water  SVG-Elemente mit diesen ids werden Wasserformen (z. B. Hafenbecken)
# Die Ausgabe ist eine Szene mit einem Node3D "Land" und den LandShape-Kindern; im Level
# "Szene als Unterelement einfügen" (Instanziieren) oder die Knoten in das Level kopieren.
import re, sys, argparse
import xml.etree.ElementTree as ET

ap = argparse.ArgumentParser()
ap.add_argument("svg")
ap.add_argument("out")
ap.add_argument("--size", nargs=2, type=float, default=[1280.0, 1280.0])
ap.add_argument("--origin", nargs=2, type=float, default=[-640.0, -840.0])
ap.add_argument("--water", default="")
ap.add_argument("--only", default="")
args = ap.parse_args()
water_ids = set(x for x in args.water.split(",") if x)

root = ET.parse(args.svg).getroot()


def tag(e):
    return e.tag.split("}")[-1]


vb = root.get("viewBox")
if vb:
    vx, vy, vw, vh = [float(x) for x in re.split(r"[ ,]+", vb.strip())]
else:
    vx, vy = 0.0, 0.0
    vw = float(re.sub(r"[a-z%]+$", "", root.get("width", "1000")))
    vh = float(re.sub(r"[a-z%]+$", "", root.get("height", "1000")))
sx, sz = args.size[0] / vw, args.size[1] / vh


def world(p):
    return (args.origin[0] + (p[0] - vx) * sx, args.origin[1] + (p[1] - vy) * sz)


def tokens(d):
    for m in re.finditer(r"([MmLlHhVvCcSsQqTtAaZz])|(-?\d*\.?\d+(?:[eE][-+]?\d+)?)", d):
        yield m.group(1) or float(m.group(2))


def parse_path(d):
    """Liefert Unterpfade: Liste von Punkten [pos, in_rel, out_rel] (in SVG-Koordinaten)."""
    toks = list(tokens(d))
    i = 0
    subs, cur = [], None
    pos = (0.0, 0.0)
    start = pos
    cmd = None
    last_c2 = None   # letzter zweiter Kontrollpunkt (für S)
    last_q = None
    def num():
        nonlocal i
        v = toks[i]
        i += 1
        return v
    def add_seg(c1, c2, p):
        # setzt den out-Griff des letzten Punkts und hängt den neuen Punkt mit in-Griff an
        last = cur[-1]
        last[2] = (c1[0] - last[0][0], c1[1] - last[0][1])
        cur.append([p, (c2[0] - p[0], c2[1] - p[1]), (0.0, 0.0)])
    while i < len(toks):
        if isinstance(toks[i], str):
            cmd = toks[i]
            i += 1
            if cmd in "Zz":
                if cur:
                    subs.append((cur, True))
                    cur = None
                pos = start
                continue
        rel = cmd.islower()
        c = cmd.upper()
        ox, oy = pos if rel else (0.0, 0.0)
        if c == "M":
            x, y = num() + ox, num() + oy
            if cur:
                subs.append((cur, False))
            pos = start = (x, y)
            cur = [[pos, (0.0, 0.0), (0.0, 0.0)]]
            cmd = "l" if rel else "L"
            last_c2 = last_q = None
            continue
        if cur is None:
            cur = [[pos, (0.0, 0.0), (0.0, 0.0)]]
            start = pos
        if c == "L":
            p = (num() + ox, num() + oy)
            add_seg(pos, p, p)
            last_c2 = last_q = None
        elif c == "H":
            p = (num() + ox, pos[1])
            add_seg(pos, p, p)
            last_c2 = last_q = None
        elif c == "V":
            p = (pos[0], num() + oy)
            add_seg(pos, p, p)
            last_c2 = last_q = None
        elif c == "C":
            c1 = (num() + ox, num() + oy)
            c2 = (num() + ox, num() + oy)
            p = (num() + ox, num() + oy)
            add_seg(c1, c2, p)
            last_c2, last_q = c2, None
        elif c == "S":
            c1 = (2 * pos[0] - last_c2[0], 2 * pos[1] - last_c2[1]) if last_c2 else pos
            c2 = (num() + ox, num() + oy)
            p = (num() + ox, num() + oy)
            add_seg(c1, c2, p)
            last_c2, last_q = c2, None
        elif c in "QT":
            if c == "Q":
                q = (num() + ox, num() + oy)
            else:
                q = (2 * pos[0] - last_q[0], 2 * pos[1] - last_q[1]) if last_q else pos
            p = (num() + ox, num() + oy)
            c1 = (pos[0] + 2 / 3 * (q[0] - pos[0]), pos[1] + 2 / 3 * (q[1] - pos[1]))
            c2 = (p[0] + 2 / 3 * (q[0] - p[0]), p[1] + 2 / 3 * (q[1] - p[1]))
            add_seg(c1, c2, p)
            last_c2, last_q = None, q
        elif c == "A":
            for _ in range(5):
                num()
            p = (num() + ox, num() + oy)
            print("Warnung: Bogen (A) wird durch eine Gerade ersetzt", file=sys.stderr)
            add_seg(pos, p, p)
            last_c2 = last_q = None
        pos = cur[-1][0]
    if cur:
        subs.append((cur, False))
    return subs


def shape_pts(e):
    t = tag(e)
    if t == "path":
        return parse_path(e.get("d", ""))
    if t in ("polygon", "polyline"):
        nums = [float(x) for x in re.findall(r"-?\d*\.?\d+(?:[eE][-+]?\d+)?", e.get("points", ""))]
        pts = [[(nums[k], nums[k + 1]), (0.0, 0.0), (0.0, 0.0)] for k in range(0, len(nums) - 1, 2)]
        return [(pts, True)]
    if t == "rect":
        x, y, w, h = [float(e.get(k, 0)) for k in ("x", "y", "width", "height")]
        return [([[(x, y), (0, 0), (0, 0)], [(x + w, y), (0, 0), (0, 0)], [(x + w, y + h), (0, 0), (0, 0)], [(x, y + h), (0, 0), (0, 0)]], True)]
    return []


nodes = []
n = 0
for e in root.iter():
    if tag(e) not in ("path", "polygon", "polyline", "rect"):
        continue
    if args.only and e.get("id") != args.only:
        continue
    for pts, _closed in shape_pts(e):
        # geschlossen über Z: erster Punkt = letzter? dann doppelten Schlusspunkt entfernen (Umriss schließt von selbst)
        if len(pts) > 2 and abs(pts[0][0][0] - pts[-1][0][0]) < 1e-6 and abs(pts[0][0][1] - pts[-1][0][1]) < 1e-6:
            first_in = pts[-1][1]
            pts = pts[:-1]
            pts[0][1] = first_in   # der Griff des Schlusspunkts gehört zum ersten Punkt
        if len(pts) < 3:
            continue
        n += 1
        nodes.append((e.get("id") or "Land%d" % n, e.get("id") in water_ids, pts))

if not nodes:
    sys.exit("keine Pfade/Polygone gefunden")

lines = ['[gd_scene load_steps=%d format=3]' % (2 + len(nodes)),
         '',
         '[ext_resource type="Script" path="res://scripts/level/land_shape.gd" id="1"]',
         '']
for k, (nm, water, pts) in enumerate(nodes):
    flat = []
    for pos, cin, cout in pts:
        wp = world(pos)
        # Griffe sind relativ zum Punkt, nur skalieren
        flat += [cin[0] * sx, 0, cin[1] * sz, cout[0] * sx, 0, cout[1] * sz, wp[0], 0, wp[1]]
    arr = ", ".join(("%.3f" % v).rstrip("0").rstrip(".") if v != 0 else "0" for v in flat)
    lines += ['[sub_resource type="Curve3D" id="Curve3D_%d"]' % (k + 1),
              '_data = {', '"points": PackedVector3Array(%s),' % arr,
              '"tilts": PackedFloat32Array(%s)' % ", ".join(["0"] * len(pts)), '}',
              'point_count = %d' % len(pts), '']
lines += ['[node name="Land" type="Node3D"]', '']
for k, (nm, water, pts) in enumerate(nodes):
    safe = re.sub(r"[^A-Za-z0-9_]", "_", nm)
    lines += ['[node name="%s" type="Path3D" parent="."]' % safe,
              'script = ExtResource("1")',
              'curve = SubResource("Curve3D_%d")' % (k + 1)]
    if water:
        lines.append('kind = 1')
    lines.append('')
open(args.out, "w").write("\n".join(lines))
print("%d Landform(en) -> %s" % (len(nodes), args.out))
