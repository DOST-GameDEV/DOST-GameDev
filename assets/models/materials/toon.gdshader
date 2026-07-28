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
// ⚠️ WIND AND RIM LIVE IN THIS SHADER RATHER THAN IN MATERIALS OF THEIR OWN, AND
// THAT IS FORCED BY env_toon_pass.gd, NOT A PREFERENCE. That pass REPLACES every
// surface material on the map with this shader, so a separate `wind_cloth`
// material on the sampay would be overwritten the instant the map loaded. Both
// effects are therefore uniforms here, and both DEFAULT TO ZERO so every
// existing caller is bit-for-bit unchanged.
shader_type spatial;
render_mode cull_back, diffuse_toon;

// --- Wind. Zero by default; env_toon_pass.gd raises it for hung cloth only. ---
//
// Sway is proportional to how far a vertex hangs BELOW `wind_anchor_y`, so the
// pinned edge stays pinned and the free hem moves most. Phase is offset by the
// instance's own world position so a row of garments does not swing in lockstep,
// which is the tell that gives away a wind shader immediately.
//
// ⚠️ `outline.gdshader` CARRIES AN IDENTICAL COPY OF THIS BLOCK. It has to: the
// outline is an inverted hull of the SAME vertices, so if only one of the two
// displaces, the garment swims inside a stationary ink border. If you change the
// maths here, change it there in the same edit.
uniform float wind_strength : hint_range(0.0, 0.5) = 0.0;
uniform float wind_speed : hint_range(0.0, 6.0) = 1.4;
uniform float wind_anchor_y = 2.62;
uniform float wind_drop = 0.62;

// --- Rim light. Zero by default. ---
//
// ⚠️ IT MUST DEFAULT TO 0.0 AND BE ENABLED PER MATERIAL. This shader is on every
// character and every hero prop, the Can included, and the Can's colour is
// load-bearing for Dev_Plan.md §4.2 rule 1 (orange is ALWAYS offence, blue is
// ALWAYS defence). A rim term that shipped on by default would tint a
// team-critical silhouette on every map, which is the same class of bug as the
// orange kit can — caught once already by rendering, not by reading.
uniform vec4 rim_color : source_color = vec4(1.0, 0.87, 0.72, 1.0);
uniform float rim_strength : hint_range(0.0, 1.0) = 0.0;
uniform float rim_power : hint_range(0.5, 8.0) = 3.0;

uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// hint_default_white so an unset sampler reads as 1.0 and multiplies to a no-op
// rather than sampling black — a black default would render every kit prop
// invisible the moment `use_texture` was set before the texture was assigned.
uniform sampler2D albedo_texture : source_color, hint_default_white;
uniform bool use_texture = false;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;

void vertex() {
	// Early-out costs nothing on the GPU (it is uniform-branching, coherent
	// across the whole draw) and keeps every non-cloth mesh exactly as it was.
	if (wind_strength > 0.0) {
		float drop = clamp((wind_anchor_y - VERTEX.y) / max(wind_drop, 0.001), 0.0, 1.0);
		float phase = (MODEL_MATRIX[3].x + MODEL_MATRIX[3].z) * 0.7;
		float t = TIME * wind_speed + phase;
		// drop*drop, not drop: a hem should trail, and a linear falloff makes the
		// whole sheet shear like a rigid card pivoting at the line.
		float amount = drop * drop * wind_strength;
		VERTEX.x += sin(t) * amount;
		VERTEX.z += sin(t * 0.7 + 1.3) * amount * 0.5;
		VERTEX.y -= (1.0 - cos(sin(t) * 0.6)) * amount * 0.4;
	}
}

void fragment() {
	vec3 base = albedo_color.rgb;
	if (use_texture) {
		base *= texture(albedo_texture, UV).rgb;
	}
	if (rim_strength > 0.0) {
		float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0),
			rim_power);
		base = mix(base, rim_color.rgb, rim * rim_strength);
	}
	ALBEDO = mix(base, flash_color.rgb, flash_amount);
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
}
