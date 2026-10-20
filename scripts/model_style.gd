@tool
class_name ModelStyle
extends RefCounted
## Gemeinsamer Grafikstil für 3D-Modelle: dünne Tusche-Kontur wie auf einer gedruckten
## Karte (konstante Pixelbreite, unabhängig vom Zoom) und Umfärben einzelner Materialien.

const OUTLINE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled;

uniform float width_px = 1.0;
uniform vec4 ink : source_color = vec4(0.12, 0.13, 0.18, 1.0);

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 n = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec2 dir = (PROJECTION_MATRIX * vec4(n, 0.0)).xy;
	if (length(dir) > 0.0001) {
		clip.xy += normalize(dir) * width_px * 2.0 / VIEWPORT_SIZE * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	ALBEDO = ink.rgb;
}
"""

static var _outline_mat: ShaderMaterial


static func outline_material() -> ShaderMaterial:
	if _outline_mat == null:
		var sh := Shader.new()
		sh.code = OUTLINE_SHADER
		_outline_mat = ShaderMaterial.new()
		_outline_mat.shader = sh
	return _outline_mat


## Kontur für alle Meshes unterhalb von root
static func outline(root: Node) -> void:
	for mi in _meshes(root):
		mi.material_overlay = outline_material()


## Schattenwurf für alle Meshes unterhalb von root abschalten (spart Zeichenaufrufe)
static func no_shadows(root: Node) -> void:
	for mi in _meshes(root):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Färbt alle Flächen mit dem Material namens material_name um
static func tint(root: Node, material_name: String, col: Color) -> void:
	for mi in _meshes(root):
		for i in mi.mesh.get_surface_count():
			var m := mi.get_active_material(i)
			if m and m.resource_name == material_name and m is BaseMaterial3D:
				var copy: BaseMaterial3D = m.duplicate()
				copy.albedo_color = col
				mi.set_surface_override_material(i, copy)


## Quader mit abgerundeten Kanten und weichen Normalen (statt harter BoxMesh-Kanten).
## size = Abmessungen, r = Rundungsradius, n = Unterteilung je Seitenkante.
static func rounded_box(size: Vector3, r := 0.12, n := 3) -> ArrayMesh:
	var half := size * 0.5
	r = minf(r, minf(half.x, minf(half.y, half.z)) * 0.9)
	var inner := half - Vector3(r, r, r)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(1)
	var faces := [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]
	for nrm in faces:
		var u: Vector3 = Vector3.UP if absf(nrm.y) < 0.9 else Vector3.RIGHT
		var t1: Vector3 = nrm.cross(u).normalized()
		var t2: Vector3 = nrm.cross(t1).normalized()
		var grid := []
		for i in n + 1:
			var row := []
			for j in n + 1:
				var a := lerpf(-1.0, 1.0, float(i) / n)
				var b := lerpf(-1.0, 1.0, float(j) / n)
				var p: Vector3 = nrm * half + t1 * a * half.abs().dot(t1.abs()) + t2 * b * half.abs().dot(t2.abs())
				var q := p.clamp(-inner, inner)
				var d := p - q
				var nn: Vector3 = d.normalized() if d.length() > 1e-5 else nrm
				row.append([q + nn * r, nn])
			grid.append(row)
		for i in n:
			for j in n:
				var c := [grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]]
				for idx in [0, 2, 1, 0, 3, 2]:
					st.set_normal(c[idx][1])
					st.add_vertex(c[idx][0])
	var mesh := st.commit()
	return mesh


## Alle Meshes unterhalb von root
static func meshes_of(root: Node) -> Array[MeshInstance3D]:
	return _meshes(root)


static func _meshes(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if root is MeshInstance3D:
		out.append(root)
	for c in root.get_children():
		out.append_array(_meshes(c))
	return out
