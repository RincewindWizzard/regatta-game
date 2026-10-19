# Exportiert die Dehler 31 in Einzelteile für Godot (Y oben, Bug nach +Z, Backbord +X).
import bpy, sys, bmesh
from mathutils import Vector, Matrix
src, outdir = sys.argv[-2], sys.argv[-1]
bpy.ops.wm.open_mainfile(filepath=src)
dg = bpy.context.evaluated_depsgraph_get()

ORIGIN = Vector((4.3, 0.0, 0.0))          # Root-Knochen = Drehpunkt des Bootes
GROUPS = {
    "hull": (["Rumpf", "Fenster", "Scheuerleiste", "Schiebeluk", "Reling_und_Beschlaege",
              "Stagen_und_Wanten", "Mast", "Flagge", "Name_BB", "Name_StB",
              "Traveller_und_Bloecke", "Kiel"], ORIGIN),
    "main": (["Grosssegel", "Grossbaum", "Baumblock"], Vector((5.9, 0.0, 2.15))),
    "jib": (["Fock"], Vector((9.22, 0.0, 1.1524))),
    "tiller": (["Pinne", "Ruderblatt"], Vector((0.95, 0.0, 0.0))),
}
ROT = Matrix.Rotation(-1.5707963, 4, 'Z')  # Bug +X -> -Y (wird im glTF zu +Z)

# Materialien vereinfachen: Grundfarbe = Viewport-Farbe (die Node-Bäume sind prozedural)
for m in bpy.data.materials:
    col = m.diffuse_color[:]
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(bsdf.outputs[0], out.inputs[0])
    bsdf.inputs["Base Color"].default_value = col
    rough = 0.45
    metal = 0.0
    if any(k in m.name for k in ("Alu", "Niro", "Drahtseil")):
        metal, rough = 0.7, 0.3
    if "Fenster" in m.name:
        rough = 0.05
    if "Segel" in m.name or "Teak" in m.name or "Antirutsch" in m.name:
        rough = 0.8
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal

scene = bpy.context.scene
# alles Alte entfernen, nur die neu erzeugten Teile exportieren
originals = list(bpy.data.objects)
meshes = {}
for gname, (names, pivot) in GROUPS.items():
    coll = bpy.data.collections.new(gname)
    scene.collection.children.link(coll)
    for n in names:
        o = bpy.data.objects[n]
        e = o.evaluated_get(dg)
        me = bpy.data.meshes.new_from_object(e, preserve_all_data_layers=False, depsgraph=dg)
        me.transform(ROT @ Matrix.Translation(-pivot) @ o.matrix_world)
        no = bpy.data.objects.new(n + "_x", me)
        coll.objects.link(no)
    meshes[gname] = list(coll.objects)
for o in originals:
    bpy.data.objects.remove(o, do_unlink=True)
for gname in GROUPS:
    for o in scene.objects:
        o.select_set(o in meshes[gname])
    path = f"{outdir}/dehler31_{gname}.glb"
    bpy.ops.export_scene.gltf(filepath=path, use_selection=True, export_apply=True,
                              export_yup=True, export_materials='EXPORT', export_cameras=False,
                              export_lights=False, export_animations=False, export_skins=False)
    print("exported", path, len(meshes[gname]), "objects")
