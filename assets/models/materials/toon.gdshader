// Flat-shaded toon material for character and hero-prop meshes.
// Handoff.md §4, M-4 step 1. Extended for the kit overhaul, Checklist 7.1.
//
// Uses Godot's built-in diffuse_toon render mode — a hard 2-band step between
// lit and shadow — with no specular response. The flat albedo stays close to
// the swatch colour at any angle, which is the whole look of the moodboard.
//
// ⚠️ TEXTURE SUPPORT IS WHY THE KIT SWAP IS POSSIBLE AT ALL (Checklist 7.1).
// This shader used to be `ALBEDO = albedo_color.rgb` and nothing else, and
// `character_visual.gd::_apply_toon_pass()` applies it to EVERY surface of
// every Prop. The Kenney kits are textured off one shared palette atlas, so
// applied unchanged it collapsed each kit prop to a single flat colour — the
// whole model one shade of whatever its first material happened to be. The
// generated `.obj` props never noticed because they carry no texture: their
// colour IS a flat `Kd`.
//
// So `use_texture` stays false for a generated prop and the maths is bit-for-bit
// what it was, and turns true for a kit mesh, where `albedo_color` becomes a
// tint over the atlas rather than a replacement for it.
//
// ⚠️ FLASHING IS A SEPARATE UNIFORM NOW, AND IT HAD TO BECOME ONE.
// `flash_hit()` used to tween `albedo_color` white -> base. That cannot work on
// a textured surface: the resting tint of a kit mesh is white, so "flash to
// white" is a no-op and a hit on a kit prop would show nothing at all. Splitting
// the flash into its own `flash_amount`/`flash_color` pair fixes that and is
// better regardless — "what colour am I" and "am I being hit" were two meanings
// sharing one uniform, which is why the texture broke both at once.
//
// `flash_color` carries the tint so the two flavours still differ: WHITE for a
// landed hit (B-44), DEFENSE-tinted for a blocked one (Q-6), so a block is never
// mistaken for a hit at a glance.
//
// The outline ShaderMaterial (outline.gdshader) carries NONE of these uniforms;
// character_visual.gd::_collect_meshes() skips any ShaderMaterial without
// `flash_amount`, which is what keeps the outline out of the flash system.
shader_type spatial;
render_mode cull_back, diffuse_toon;

uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// hint_default_white so an unset sampler reads as 1.0 and multiplies to a no-op
// rather than sampling black — a black default would render every kit prop
// invisible the moment `use_texture` was set before the texture was assigned.
uniform sampler2D albedo_texture : source_color, hint_default_white;
uniform bool use_texture = false;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec3 base = albedo_color.rgb;
	if (use_texture) {
		base *= texture(albedo_texture, UV).rgb;
	}
	ALBEDO = mix(base, flash_color.rgb, flash_amount);
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
}
