// Inverted-hull outline pass for character and hero-prop meshes.
// Handoff.md §4, M-4 step 2.
//
// Applied to a duplicate MeshInstance3D (see character_visual.gd::_apply_toon_pass)
// that shares the same Mesh resource. cull_front renders only back faces; combined
// with vertex inflation along the normal this produces an ink outline seen from
// outside. Unshaded so the outline is always INK regardless of lighting.
//
// Keep outline_width small — at the ~4.5-unit TPP distance these characters live
// at, 0.025 reads as a clean ink border without eating into the albedo colour.
//
// This shader has NO albedo_color uniform deliberately — character_visual.gd's
// _collect_meshes() skips ShaderMaterials that lack it, so the outline mesh is
// excluded from the hit-flash system (an outline that flashes white reads as a
// lit border, not a hit response).
shader_type spatial;
render_mode cull_front, unshaded;

uniform vec4 outline_color : source_color = vec4(0.01569, 0.03137, 0.21961, 1.0);
uniform float outline_width : hint_range(0.0, 0.1, 0.001) = 0.025;

void vertex() {
	VERTEX += NORMAL * outline_width;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
