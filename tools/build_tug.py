# Baut einen stilisierten Hafenschlepper ("Spielzeug-Look") und exportiert ihn als glb.
# Blender-Koordinaten: Bug +X, Backbord +Y, oben +Z. Export wie beim Segelboot gedreht,
# sodass in Godot der Bug nach +Z zeigt.
import bpy, bmesh, math, sys
from mathutils import Vector, Matrix

out = sys.argv[-1]
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

def mat(name, rgb, rough=0.5, metal=0.0, emit=None):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    lin = tuple(c ** 2.2 for c in rgb)          # sRGB-Farbwerte -> linear
    b.inputs["Base Color"].default_value = (*lin, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emit:
        b.inputs["Emission Color"].default_value = (*emit, 1)
        b.inputs["Emission Strength"].default_value = 2.0
    return m

M = {
    "hull": mat("Rumpf_Schlepper", (0.06, 0.1, 0.2), 0.4),
    "band": mat("Wasserpass_Rot", (0.72, 0.1, 0.08), 0.5),
    "deck": mat("Deck_Gruen", (0.32, 0.42, 0.33), 0.8),
    "white": mat("Aufbau_Weiss", (0.94, 0.92, 0.85), 0.4),
    "roof": mat("Dach_Orange", (0.92, 0.38, 0.1), 0.45),
    "glass": mat("Fenster", (0.05, 0.12, 0.2), 0.1),
    "rubber": mat("Gummi", (0.05, 0.05, 0.05), 0.9),
    "black": mat("Schwarz", (0.04, 0.04, 0.045), 0.5),
    "steel": mat("Stahl", (0.55, 0.57, 0.6), 0.35, 0.6),
    "ring": mat("Rettungsring", (0.95, 0.4, 0.08), 0.5),
    "lamp": mat("Lampe", (1.0, 0.85, 0.4), 0.3, 0.0, (1.0, 0.8, 0.3)),
}

def obj_from_bm(name, bm, material, smooth=True):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    scene.collection.objects.link(o)
    me.materials.append(material)
    for p in me.polygons:
        p.use_smooth = smooth
    return o

def add_mod(o, kind, **kw):
    m = o.modifiers.new(kind.lower(), kind)
    for k, v in kw.items():
        setattr(m, k, v)
    return m

# ---------------------------------------------------------------- Rumpf (Spanten-Loft)
L = 14.0
def half_beam(x):            # x von -7 (Heck) bis +7 (Bug)
    t = (x + 7.0) / L
    stern = 0.82 + 0.18 * math.sin(min(t / 0.25, 1.0) * math.pi / 2)   # rundes Heck
    bow = math.cos(max(0.0, (t - 0.55) / 0.45) * math.pi / 2) ** 0.8    # spitzer Bug
    return 2.6 * stern * max(bow, 0.06)
def sheer(x):                # Decksprung: vorn höher
    t = (x + 7.0) / L
    return 1.5 + 0.9 * t ** 2.2
def bottom(x):
    t = (x + 7.0) / L
    return -1.3 + 1.1 * max(0.0, t - 0.75) / 0.25

NX, NS = 28, 12
bm = bmesh.new()
rows = []
for i in range(NX + 1):
    x = -7.0 + L * i / NX
    hb, top, bot = half_beam(x), sheer(x), bottom(x)
    row = []
    for j in range(NS + 1):          # von Backbord-Deckskante über Kiel zur Steuerbord-Deckskante
        a = math.pi * j / NS
        y = hb * math.cos(a)
        z = top - (top - bot) * math.sin(a) ** 0.7
        # bauchige Form: unten etwas einziehen
        y *= 0.75 + 0.25 * (1.0 - math.sin(a) ** 4)
        row.append(bm.verts.new((x, y, z)))
    rows.append(row)
for i in range(NX):
    for j in range(NS):
        bm.faces.new((rows[i][j], rows[i + 1][j], rows[i + 1][j + 1], rows[i][j + 1]))
# Heckspiegel schließen
bm.faces.new(list(reversed(rows[0])))
hull = obj_from_bm("Rumpf", bm, M["hull"])
hull.data.materials.append(M["band"])
for p in hull.data.polygons:          # roter Wasserpass knapp über der Wasserlinie
    if -0.2 < p.center.z < 0.45:
        p.material_index = 1
add_mod(hull, "SOLIDIFY", thickness=0.18, offset=-1.0)
add_mod(hull, "SUBSURF", levels=1, render_levels=1)

# Deck: Fläche entlang der Innenkante, etwas unter der Schanzkleid-Oberkante
bm = bmesh.new()
outline = []
for i in range(NX + 1):
    x = -7.0 + L * i / NX
    outline.append((x, half_beam(x) * 0.93))
pts = outline + [(x, -y) for (x, y) in reversed(outline)]
vs = []
for (x, y) in pts:
    vs.append(bm.verts.new((x, y, sheer(x) - 0.55)))
bm.faces.new(vs)
deck = obj_from_bm("Deck", bm, M["deck"], smooth=False)

# Fenderwulst rundherum (Kurve mit Rundprofil)
cd = bpy.data.curves.new("Fender", 'CURVE')
cd.dimensions = '3D'
cd.bevel_depth = 0.32
cd.bevel_resolution = 3
sp = cd.splines.new('POLY')
ring = [(x, half_beam(x) + 0.12, sheer(x) - 0.25) for (x, _) in outline]
ring = ring + [(x, -y, z) for (x, y, z) in reversed(ring)]
sp.points.add(len(ring) - 1)
for k, p in enumerate(ring):
    sp.points[k].co = (*p, 1)
sp.use_cyclic_u = True
fender = bpy.data.objects.new("Fenderwulst", cd)
scene.collection.objects.link(fender)
cd.materials.append(M["rubber"])

# dicker Bugfender ("Pudding")
bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=12, radius=1.0, location=(7.05, 0, sheer(7.0) - 0.5))
bow_f = bpy.context.object
bow_f.scale = (0.55, 0.9, 0.55)
bow_f.data.materials.append(M["rubber"])
bpy.ops.object.shade_smooth()

# Autoreifen an den Seiten
for k in range(4):
    for side in (1, -1):
        x = -4.5 + k * 2.6
        bpy.ops.mesh.primitive_torus_add(major_radius=0.38, minor_radius=0.14, location=(x, side * (half_beam(x) + 0.3), sheer(x) - 0.75),
                                         rotation=(math.pi / 2, 0, 0), major_segments=16, minor_segments=8)
        t = bpy.context.object
        t.data.materials.append(M["rubber"])
        bpy.ops.object.shade_smooth()

def box(name, size, loc, material, bevel=0.12, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.object
    o.name = name
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    o.data.materials.append(material)
    if bevel > 0:
        add_mod(o, "BEVEL", width=bevel, segments=3)
    bpy.ops.object.shade_smooth()
    return o

def cyl(name, r, h, loc, material, rot=(0, 0, 0), verts=24):
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=h, location=loc, rotation=rot, vertices=verts)
    o = bpy.context.object
    o.name = name
    o.data.materials.append(material)
    add_mod(o, "BEVEL", width=min(0.06, r * 0.3), segments=2)
    bpy.ops.object.shade_smooth()
    return o

dz = sheer(1.0) - 0.55     # Deckshöhe im Mittelschiff
# Aufbauten
box("Deckshaus", (6.0, 3.4, 1.3), (-0.5, 0, dz + 0.65), M["white"])
box("Steuerhaus", (3.2, 3.0, 1.8), (1.7, 0, dz + 1.3 + 0.9), M["white"], 0.15)
box("Fensterband", (3.26, 3.06, 0.6), (1.7, 0, dz + 1.3 + 1.15), M["glass"], 0.12)
box("Dach", (3.7, 3.4, 0.22), (1.75, 0, dz + 1.3 + 1.85), M["roof"], 0.08)
box("Deckshaus_Dach", (6.2, 3.55, 0.16), (-0.5, 0, dz + 1.33), M["roof"], 0.05)

# Schornstein, leicht nach achtern geneigt
tilt = (0, -0.14, 0)
cyl("Schornstein", 0.62, 2.4, (-1.8, 0, dz + 2.4), M["roof"], tilt)
cyl("Schornstein_Kappe", 0.66, 0.5, (-1.93, 0, dz + 3.55), M["black"], tilt)
cyl("Schornstein_Band", 0.65, 0.3, (-1.85, 0, dz + 2.6), M["white"], tilt)

# Mast mit Topplichtern auf dem Steuerhausdach
roof_z = dz + 1.3 + 1.96
cyl("Mast", 0.08, 3.0, (1.6, 0, roof_z + 1.5), M["steel"], verts=10)
box("Saling", (0.12, 1.6, 0.1), (1.6, 0, roof_z + 2.3), M["steel"], 0.02)
for k in range(3):   # drei Topplichter = Schleppverband
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.14, location=(1.75, 0, roof_z + 1.4 + k * 0.42), segments=12, ring_count=8)
    bpy.context.object.data.materials.append(M["lamp"])
    bpy.ops.object.shade_smooth()
cyl("Suchscheinwerfer", 0.22, 0.35, (2.6, 0, roof_z + 0.25), M["black"], (0, math.pi / 2, 0), 16)

# Rettungsringe an den Seiten des Deckshauses
for side in (1, -1):
    bpy.ops.mesh.primitive_torus_add(major_radius=0.38, minor_radius=0.1, location=(-1.0, side * 1.73, dz + 0.75),
                                     rotation=(math.pi / 2, 0, 0), major_segments=20, minor_segments=8)
    bpy.context.object.data.materials.append(M["ring"])
    bpy.ops.object.shade_smooth()

# Schleppgeschirr achtern: Poller, Schlepphaken, Schleppbogen
for side in (1, -1):
    cyl("Poller", 0.2, 0.6, (-5.2, side * 1.0, sheer(-5.2) - 0.25), M["black"], verts=16)
cyl("Hakenstuetze", 0.18, 1.0, (-3.9, 0, dz + 0.5), M["black"], verts=12)
box("Schlepphaken", (0.5, 0.2, 0.25), (-4.2, 0, dz + 1.0), M["steel"], 0.04)
ad = bpy.data.curves.new("Schleppbogen", 'CURVE')
ad.dimensions = '3D'
ad.bevel_depth = 0.1
ad.bevel_resolution = 2
asp = ad.splines.new('POLY')
arc = []
base_z = sheer(-4.7) - 0.55
for k in range(17):
    a = math.pi * k / 16
    arc.append((-4.7, 2.2 * math.cos(a), base_z + 1.6 * math.sin(a)))
asp.points.add(len(arc) - 1)
for k, p in enumerate(arc):
    asp.points[k].co = (*p, 1)
arch = bpy.data.objects.new("Schleppbogen", ad)
scene.collection.objects.link(arch)
ad.materials.append(M["black"])

# Ankerwinde vorn
cyl("Ankerwinde", 0.32, 1.2, (4.8, 0, sheer(4.8) - 0.25), M["steel"], (math.pi / 2, 0, 0), 16)

# ---------------------------------------------------------------- Export
for o in scene.objects:
    o.select_set(True)
bpy.context.view_layer.objects.active = hull
# alles nach Godot-Achsen drehen (Bug +X -> -Y, im glTF dann +Z)
for o in scene.objects:
    o.matrix_world = Matrix.Rotation(-math.pi / 2, 4, 'Z') @ o.matrix_world
bpy.ops.export_scene.gltf(filepath=out, use_selection=False, export_apply=True, export_yup=True,
                          export_cameras=False, export_lights=False)
print("exported", out, len(scene.objects), "objects")
