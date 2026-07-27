// Flat-shaded toon material for character and hero-prop meshes.
// Handoff.md §4, M-4 step 1.
//
// Uses Godot's built-in diffuse_toon render mode — a hard 2-band step between
// lit and shadow — with no specular response. The flat albedo stays close to
// the swatch colour at any angle, which is the whole look of the moodboard.
//
// albedo_color is set per-surface by character_visual.gd::_apply_toon_pass()
// from the .mtl colour (UiTheme.DEFENSE / HIGHLIGHT / INK / etc.). It is also
// the handle the hit-flash system tweens: character_visual.gd::flash_hit()
// calls set_shader_parameter("albedo_color", Color.WHITE) then tweens back.
// The outline ShaderMaterial (outline.gdshader) does NOT carry this uniform;
// character_visual.gd::_collect_meshes() skips any ShaderMaterial that lacks it.
shader_type spatial;
render_mode cull_back, diffuse_toon;

uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	ALBEDO = albedo_color.rgb;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
}
