@tool
class_name ModelStyle
extends RefCounted
## Gemeinsamer Grafikstil für 3D-Modelle: dünne Tusche-Kontur wie auf einer gedruckten
## Karte (konstante Pixelbreite, unabhängig vom Zoom) und Umfärben einzelner Materialien.

const OUTLINE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled;

uniform float width_px = 1.4;
uniform vec4 ink : source_color = vec4(0.08, 0.08, 0.1, 1.0);

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


## Färbt alle Flächen mit dem Material namens material_name um
static func tint(root: Node, material_name: String, col: Color) -> void:
	for mi in _meshes(root):
		for i in mi.mesh.get_surface_count():
			var m := mi.get_active_material(i)
			if m and m.resource_name == material_name and m is BaseMaterial3D:
				var copy: BaseMaterial3D = m.duplicate()
				copy.albedo_color = col
				mi.set_surface_override_material(i, copy)


static func _meshes(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if root is MeshInstance3D:
		out.append(root)
	for c in root.get_children():
		out.append_array(_meshes(c))
	return out
