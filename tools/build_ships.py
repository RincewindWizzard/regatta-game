# Baut die drei Berufsschiffe (Containerschiff, Tanker, Massengutfrachter) in Blender und
# exportiert sie als glb. Zusätzlich schreibt das Skript die Rumpfkontur (für die Kollision) als JSON.
#
# Aufruf:  blender --background --python tools/build_ships.py -- models
#   (oder mit dem Python-Modul "bpy":  python tools/build_ships.py models)
#
# Blender-Koordinaten: Bug +X, Backbord +Y, oben +Z, Wasserlinie bei Z = 0, Länge 80 m, Breite 16 m.
# Beim Export wird wie beim Schlepper gedreht, sodass in Godot der Bug nach +Z zeigt.
# Godot skaliert die Modelle auf ship_length / beam der ShippingLane (Standard: 80 x 16 m).
import bpy, bmesh, math, sys, json, os
from mathutils import Vector, Matrix

out_dir = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else "models"
L = 80.0
B = 16.0
FREEBOARD = 6.0
NX = 48          # Spanten längs
NS = 12          # Punkte je Spant (von Backbord-Deckskante über den Kiel zur Steuerbord-Deckskante)

TYPES = {
    # Name: (Rumpffarbe, Schornsteinfarbe, Bugbeginn t, Bugform-Exponent)
    "container": ((0.10, 0.20, 0.38), (0.85, 0.15, 0.12), 0.74, 0.65),
    "tanker":    ((0.50, 0.12, 0.10), (0.95, 0.75, 0.10), 0.80, 0.55),
    "bulker":    ((0.14, 0.32, 0.26), (0.90, 0.90, 0.90), 0.78, 0.60),
}


def lin(rgb):
    return tuple(c ** 2.2 for c in rgb)          # sRGB-Farbwerte -> linear


def make_mat(name, rgb, rough=0.55, alpha=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*lin(rgb), 1)
    b.inputs["Roughness"].default_value = rough
    if alpha < 1.0:
        b.inputs["Alpha"].default_value = alpha
        m.surface_render_method = 'BLENDED'
    return m


# ---------------------------------------------------------------- Rumpfform (auch für die Kollision)

def half_beam(t, bow_start, bow_exp):
    """halbe Breite bei t = 0 (Heck) ... 1 (Bug); am Bug läuft sie auf 0 zusammen"""
    hb = B * 0.5
    stern = 0.72 + 0.28 * math.sin(min(t / 0.08, 1.0) * math.pi / 2)
    u = max(0.0, (t - bow_start) / (1.0 - bow_start))
    bow = max(1.0 - u ** 2.1, 0.0) ** bow_exp
    return hb * stern * bow


def keel(t):
    stern = 1.0 - 0.5 * max(0.0, (0.1 - t) / 0.1)
    s = max(0.0, (t - 0.88) / 0.12)
    return -3.2 * stern * (1.0 - 0.35 * s * s * (3 - 2 * s))


def build_hull(mats, bow_start, bow_exp):
    bm = bmesh.new()
    rows = []
    for i in range(NX + 1):
        t = i / NX
        x = -L / 2 + L * t
        hb = half_beam(t, bow_start, bow_exp)
        bot = keel(t)
        u = max(0.0, (t - bow_start) / (1.0 - bow_start))
        top = FREEBOARD + 1.2 * u * u               # Decksprung am Bug
        row = []
        for j in range(NS + 1):
            a = math.pi * j / NS
            s = math.sin(a)
            c = math.cos(a)
            y = hb * math.copysign(abs(c) ** 0.45, c)
            y *= 1.0 + 0.18 * u * (1.0 - s ** 0.6)      # Ausfall am Bug
            z = top - (top - bot) * s ** 0.4
            row.append(bm.verts.new((x, y, z)))
        rows.append(row)
    for i in range(NX):
        for j in range(NS):
            f = bm.faces.new((rows[i][j], rows[i + 1][j], rows[i + 1][j + 1], rows[i][j + 1]))
            zc = sum(v.co.z for v in f.verts) / 4
            f.material_index = 1 if zc < 0.9 else 0            # Unterwasseranstrich / Bordwand
        # Deck: Band zwischen Backbord- und Steuerbordkante
        f = bm.faces.new((rows[i][0], rows[i + 1][0], rows[i + 1][NS], rows[i][NS]))
        f.material_index = 2
    # Heckspiegel schließen
    f = bm.faces.new(rows[0])
    f.material_index = 0
    # Bug: Spant mit Breite 0 fällt zu einer Linie zusammen -> Punkte verschmelzen, Entartetes entfernen
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.dissolve_degenerate(bm, dist=1e-5, edges=bm.edges)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    open_edges = [e for e in bm.edges if len(e.link_faces) != 2]
    print("Rumpf: %d offene Kanten" % len(open_edges))
    me = bpy.data.meshes.new("Rumpf")
    bm.to_mesh(me)
    bm.free()
    for m in mats:
        me.materials.append(m)
    for p in me.polygons:
        p.use_smooth = True
    o = bpy.data.objects.new("Rumpf", me)
    bpy.context.scene.collection.objects.link(o)
    return o


def build_foam(mat, bow_start, bow_exp):
    """flacher weißer Schaumstreifen rund um den Wasserpass (statt Leuchtkegeln und Ringen)"""
    bm = bmesh.new()
    inner = []
    outer = []
    for i in range(NX + 1):
        t = i / NX
        x = -L / 2 + L * t
        hb = half_beam(t, bow_start, bow_exp) * 0.97
        off = 0.9 + 0.5 * (1.0 - t)
        inner.append((x, hb))
        outer.append((x + (1.8 if i == NX else 0.0), hb + off))
    for s in (1.0, -1.0):
        for i in range(NX):
            vs = [bm.verts.new((inner[i][0], s * inner[i][1], 0.05)),
                  bm.verts.new((outer[i][0], s * outer[i][1], 0.05)),
                  bm.verts.new((outer[i + 1][0], s * outer[i + 1][1], 0.05)),
                  bm.verts.new((inner[i + 1][0], s * inner[i + 1][1], 0.05))]
            f = bm.faces.new(vs if s > 0 else vs[::-1])
            f.normal_update()
            if f.normal.z < 0:
                f.normal_flip()
    me = bpy.data.meshes.new("Schaum")
    bm.to_mesh(me)
    bm.free()
    me.materials.append(mat)
    o = bpy.data.objects.new("Foam", me)
    bpy.context.scene.collection.objects.link(o)
    return o


# ---------------------------------------------------------------- Bauteile je Material gesammelt

class Parts:
    def __init__(self):
        self.bms = {}

    def _bm(self, mat):
        if mat.name not in self.bms:
            self.bms[mat.name] = (mat, bmesh.new())
        return self.bms[mat.name][1]

    def box(self, mat, size, center, rot_x=0.0):
        m = Matrix.Translation(center) @ Matrix.Rotation(rot_x, 4, 'X') @ Matrix.Diagonal((size[0], size[1], size[2], 1.0))
        bmesh.ops.create_cube(self._bm(mat), size=1.0, matrix=m)

    def cyl(self, mat, r_bottom, r_top, h, center, segs=12, axis='Z'):
        rot = Matrix.Identity(4)
        if axis == 'X':
            rot = Matrix.Rotation(math.pi / 2, 4, 'Y')
        elif axis == 'Y':
            rot = Matrix.Rotation(math.pi / 2, 4, 'X')
        m = Matrix.Translation(center) @ rot
        bmesh.ops.create_cone(self._bm(mat), cap_ends=True, segments=segs, radius1=r_bottom, radius2=r_top, depth=h, matrix=m)

    def objects(self, name):
        objs = []
        for key, (mat, bm) in self.bms.items():
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
            me = bpy.data.meshes.new(name + "_" + key)
            bm.to_mesh(me)
            bm.free()
            me.materials.append(mat)
            for p in me.polygons:
                p.use_smooth = True
            o = bpy.data.objects.new(name + "_" + key, me)
            bpy.context.scene.collection.objects.link(o)
            # weiche Kanten: abgerundete Kanten (Bevel) und flächengewichtete Normalen,
            # damit große Flächen eben bleiben und nur die Kanten weich auslaufen
            bev = o.modifiers.new("Bevel", 'BEVEL')
            bev.width = 0.22
            bev.segments = 2
            bev.limit_method = 'ANGLE'
            bev.angle_limit = math.radians(30.0)
            wn = o.modifiers.new("Normalen", 'WEIGHTED_NORMAL')
            wn.mode = 'FACE_AREA'
            wn.weight = 50
            wn.keep_sharp = False
            objs.append(o)
        return objs


def hull_half(x, bow_start, bow_exp):
    return half_beam((x + L / 2) / L, bow_start, bow_exp)


def superstructure(P, M, stack_mat, bow_start, bow_exp):
    xb = -L * 0.36
    w = B * 0.74
    top0 = FREEBOARD + 0.9
    decks = 4
    for k in range(decks):
        ww = w * (1.0 - 0.07 * k)
        d = L * (0.12 - 0.012 * k)
        z = top0 + 1.5 + k * 3.0
        P.box(M["white"], (d, ww, 3.0), (xb, 0, z))
        P.box(M["glass"], (d + 0.06, ww + 0.06, 1.0), (xb, 0, z + 0.2))
    by = top0 + 1.5 + decks * 3.0 + 0.4
    P.box(M["white"], (L * 0.06, B * 0.9, 2.2), (xb + L * 0.01, 0, by))
    P.box(M["glass"], (L * 0.06 + 0.06, B * 0.9 + 0.06, 1.0), (xb + L * 0.01, 0, by + 0.2))
    P.box(M["dark"], (L * 0.07, B * 0.96, 0.3), (xb + L * 0.01, 0, by + 1.3))
    # Schornstein mit Farbband und Kappe
    sx = xb - L * 0.065
    P.box(M["white"], (L * 0.05, B * 0.3, 7.0), (sx, 0, top0 + 4.0 + decks * 2.0))
    P.box(stack_mat, (L * 0.05 + 0.1, B * 0.3 + 0.1, 2.4), (sx, 0, top0 + 7.8 + decks * 2.0))
    P.box(M["dark"], (L * 0.05 + 0.2, B * 0.3 + 0.2, 0.4), (sx, 0, top0 + 9.2 + decks * 2.0))
    # Mast mit Radar
    my = by + 1.3
    P.cyl(M["steel"], 0.18, 0.12, 6.0, (xb + L * 0.01, 0, my + 3.0), 6)
    P.box(M["steel"], (0.5, 3.6, 0.35), (xb + L * 0.01, 0, my + 5.2))
    P.box(M["dark"], (0.45, 2.6, 0.3), (xb + L * 0.01, 0, my + 6.0))
    # Rettungsboote
    for s in (-1, 1):
        P.box(M["orange"], (6.0, 1.6, 1.2), (xb - L * 0.01, s * (w * 0.5 + 1.0), top0 + 4.5))
    # Vorschiff: Ankerwinde, Poller, Flaggenstock
    P.box(M["dark"], (4.0, B * 0.3, 1.2), (L * 0.42, 0, FREEBOARD + 1.4))
    for s in (-1, 1):
        P.cyl(M["steel"], 0.35, 0.35, 1.0, (L * 0.46, s * B * 0.12, FREEBOARD + 1.2), 6)
    P.cyl(M["steel"], 0.1, 0.1, 4.0, (L * 0.465, 0, FREEBOARD + 3.2), 6)
    P.box(M["lamp"], (0.9, 0.9, 0.6), (L * 0.465, 0, FREEBOARD + 5.3))


def cargo_container(P, M, bow_start, bow_exp):
    cols = [(0.82, 0.22, 0.15), (0.20, 0.42, 0.72), (0.92, 0.70, 0.14), (0.22, 0.58, 0.34),
            (0.72, 0.72, 0.74), (0.90, 0.90, 0.88), (0.35, 0.22, 0.50)]
    cmats = [make_mat("Container_%d" % i, c, 0.6) for i, c in enumerate(cols)]
    cw = B * 0.17
    cl = L * 0.075
    x = -L * 0.26
    bay = 0
    k = 0
    while x + cl < L * 0.3:
        # nur so viele Reihen, wie am Bugende der Bucht noch innerhalb des Rumpfes (mit Rand) passen
        hb = min(hull_half(x - cl * 0.5, bow_start, bow_exp), hull_half(x + cl * 0.5, bow_start, bow_exp)) * 0.92 - 0.4
        rows_n = max(0, min(5, int((2 * hb) // (cw + 0.12))))
        for r in range(rows_n):
            y = (r - (rows_n - 1) * 0.5) * (cw + 0.12)
            layers = max(1, min(5, 2 + (bay * 7) % 3 + ((bay + r) % 3) - 1))
            for lz in range(layers):
                k += 1
                P.box(cmats[(k * 5 + r + bay) % len(cmats)] if False else cmats[(k * 3 + r) % len(cmats)],
                      (cl, cw, 2.5), (x, y, FREEBOARD + 1.6 + lz * 2.55))
        x += cl + 0.5
        bay += 1


def cargo_tanker(P, M, bow_start, bow_exp):
    P.box(M["pipe"], (L * 0.6, 0.9, 0.7), (L * 0.04, 0, FREEBOARD + 1.5))
    P.box(M["walk"], (L * 0.6, B * 0.05, 0.4), (L * 0.04, B * 0.12, FREEBOARD + 1.25))
    for i in range(7):
        x = -L * 0.22 + i * L * 0.085
        P.box(M["pipe"], (0.5, B * 0.55, 0.5), (x, 0, FREEBOARD + 1.6))
        for s in (-1, 1):
            P.cyl(M["steel"], B * 0.07, B * 0.07, 0.9, (x, s * B * 0.24, FREEBOARD + 1.3), 8)
    P.box(M["yellow"], (0.8, B * 0.6, 0.5), (L * 0.05, 0, FREEBOARD + 2.1))
    P.box(M["yellow"], (0.5, 0.5, 6.0), (L * 0.05, B * 0.3, FREEBOARD + 4.0))


def cargo_bulker(P, M, bow_start, bow_exp):
    for i in range(5):
        x = -L * 0.24 + i * L * 0.135
        P.box(M["hatch"], (L * 0.1, B * 0.68, 1.4), (x, 0, FREEBOARD + 1.6))
        P.box(M["hatch_d"], (L * 0.1 + 0.2, B * 0.68 + 0.2, 0.3), (x, 0, FREEBOARD + 2.4))
    for i in range(2):
        x = -L * 0.08 + i * L * 0.27
        P.box(M["yellow"], (1.6, 1.6, 1.0), (x, B * 0.34, FREEBOARD + 1.5))
        P.cyl(M["yellow"], 0.6, 0.5, 7.0, (x, B * 0.34, FREEBOARD + 5.0), 10)
        P.box(M["yellow"], (12.0, 0.4, 0.4), (x + 3.0, B * 0.28, FREEBOARD + 8.0), -0.0)


def build_ship(kind):
    hull_rgb, stack_rgb, bow_start, bow_exp = TYPES[kind]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    hull_mats = [make_mat("Rumpf", hull_rgb, 0.45), make_mat("Unterwasser", (0.5, 0.11, 0.09), 0.6), make_mat("Deck", (0.33, 0.35, 0.36), 0.8)]
    M = {
        "white": make_mat("Aufbau_Weiss", (0.95, 0.95, 0.93), 0.45),
        "glass": make_mat("Fenster", (0.07, 0.12, 0.2), 0.15),
        "dark": make_mat("Dunkel", (0.16, 0.17, 0.2), 0.6),
        "steel": make_mat("Stahl", (0.55, 0.58, 0.6), 0.4),
        "orange": make_mat("Rettungsboot", (0.95, 0.45, 0.08), 0.5),
        "lamp": make_mat("Lampe", (0.95, 0.9, 0.5), 0.3),
        "pipe": make_mat("Rohr", (0.24, 0.24, 0.26), 0.5),
        "walk": make_mat("Laufsteg", (0.7, 0.68, 0.6), 0.7),
        "yellow": make_mat("Gelb", (0.85, 0.6, 0.1), 0.5),
        "hatch": make_mat("Luke", (0.72, 0.70, 0.58), 0.7),
        "hatch_d": make_mat("Luke_dunkel", (0.58, 0.56, 0.46), 0.7),
    }
    stack_mat = make_mat("Schornstein", stack_rgb, 0.5)
    build_hull(hull_mats, bow_start, bow_exp)
    P = Parts()
    superstructure(P, M, stack_mat, bow_start, bow_exp)
    {"container": cargo_container, "tanker": cargo_tanker, "bulker": cargo_bulker}[kind](P, M, bow_start, bow_exp)
    P.objects("Teil")
    build_foam(make_mat("Schaum", (1.0, 1.0, 1.0), 1.0, 0.5), bow_start, bow_exp)
    scene = bpy.context.scene
    for o in scene.objects:
        o.matrix_world = Matrix.Rotation(-math.pi / 2, 4, 'Z') @ o.matrix_world
    path = os.path.join(out_dir, "ship_%s.glb" % kind)
    bpy.ops.export_scene.gltf(filepath=path, use_selection=False, export_apply=True, export_yup=True,
                              export_cameras=False, export_lights=False)
    print("exportiert", path, len(scene.objects), "Objekte")
    # Rumpfkontur (Steuerbordseite, Heck -> Bug): [Anteil der Länge von der Mitte, Anteil der halben Breite]
    return [[round(i / NX - 0.5, 4), round(half_beam(i / NX, bow_start, bow_exp) / (B * 0.5), 4)] for i in range(NX + 1)]


os.makedirs(out_dir, exist_ok=True)
hulls = {}
for kind in TYPES:
    hulls[kind] = build_ship(kind)
with open(os.path.join(out_dir, "ship_hulls.json"), "w") as f:
    json.dump({"length": L, "beam": B, "hulls": hulls}, f)
print("Rumpfkonturen geschrieben")
