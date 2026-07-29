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

// ⚠️ AN EXACT COPY OF toon.gdshader'S WIND BLOCK, AND IT MUST STAY ONE.
// This pass is an inverted hull of the SAME vertices the toon pass displaces. If
// only the toon pass moves them, a swaying garment swims around inside an ink
// border that stands perfectly still — which looks far worse than no wind at all.
// Both are driven from the same parameters by env_toon_pass.gd, which sets them
// on the toon material and copies them onto this one. Change one, change both.
uniform float wind_strength : hint_range(0.0, 0.5) = 0.0;
uniform float wind_speed : hint_range(0.0, 6.0) = 1.4;
uniform float wind_anchor_y = 2.62;
uniform float wind_drop = 0.62;

void vertex() {
	if (wind_strength > 0.0) {
		float drop = clamp((wind_anchor_y - VERTEX.y) / max(wind_drop, 0.001), 0.0, 1.0);
		float phase = (MODEL_MATRIX[3].x + MODEL_MATRIX[3].z) * 0.7;
		float t = TIME * wind_speed + phase;
		float amount = drop * drop * wind_strength;
		VERTEX.x += sin(t) * amount;
		VERTEX.z += sin(t * 0.7 + 1.3) * amount * 0.5;
		VERTEX.y -= (1.0 - cos(sin(t) * 0.6)) * amount * 0.4;
	}
	VERTEX += NORMAL * outline_width;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
