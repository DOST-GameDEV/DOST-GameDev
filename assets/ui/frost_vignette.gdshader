// § THE STUN FROST — the screen half. 🧑 2026-08-06: *"can we have like a frost effect
// to indicate that an attacker is stunned after getting tagged?"*, with a reference
// image of an icy frame around a clear centre.
//
// ⚠️⚠️ EDGE-WEIGHTED, CENTRE-CLEAR, AND THAT SHAPE IS THE WHOLE REASON THIS CAN EXIST
// AT ALL. `hud.gd` records what happened the last time a full-screen tint was HELD
// rather than pulsed: *"a full-screen red ColorRect left on for forty seconds does not
// read as feedback. It reads as the renderer being broken: measured on the first
// captured frame of a live match, the entire arena was washed red."* The fix there was
// alpha — `DANGER_HOLD_ALPHA` 0.16, low enough to see through for a whole round.
//
// A tag stun is 5 seconds, far past the 0.45 s a flash gets and far short of a round.
// Dropping it to 0.16 would make the biggest moment in the defender's game invisible;
// holding it at flash strength would black out the arena. The reference resolves it: put
// the opacity where the player is NOT looking. The frame can be strong because the
// centre stays clear, so the stunned player still watches the round they cannot act in.
//
// ⚠️ PROCEDURAL, NOT A TEXTURE. The reference is photographic rime; this game is a flat
// two-band toon look with ink outlines, and a photoreal overlay would sit on top of it
// like a sticker. These cracks are drawn from value noise, so they carry the same
// hand-drawn irregularity as the rest of the art and cost no asset, no import, and no
// LFS entry.
shader_type canvas_item;

// 0 = clear, 1 = fully iced. Driven from the remaining stun, so the frost RECEDES as
// the effect wears off — which is the "tell the player when it is ending" half of the
// accessible-status guidance this was designed against.
uniform float coverage : hint_range(0.0, 1.0) = 0.0;
uniform vec4 frost_tint : source_color = vec4(0.66, 0.90, 0.95, 1.0);
uniform vec4 crack_color : source_color = vec4(0.80, 0.98, 1.0, 1.0);
// How far in from the frame the ice reaches at full coverage, in units of SCREEN
// HEIGHT. Tuned down from 0.36 after a rendered check: at that value the frost met in
// the middle and the arena read as fog rather than as a frame, which is the same
// "washed out" failure `hud.gd` already recorded once in red.
uniform float max_reach : hint_range(0.05, 0.5) = 0.15;
// Viewport width / height, written from `hud.gd`. ⚠️ WITHOUT IT THE BAND IS UNEVEN:
// UV is 0..1 on BOTH axes regardless of shape, so a fixed UV distance is ~1.8x more
// pixels horizontally than vertically on 16:9 — measured as a thick blue curtain down
// the left and right and a thin line top and bottom.
uniform float aspect = 1.7777;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float total = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		total += value_noise(p) * amp;
		p *= 2.0;
		amp *= 0.5;
	}
	return total;
}

void fragment() {
	// ⚠️ DISTANCE TO THE NEAREST EDGE, NOT RADIAL DISTANCE. `downed_vignette.gdshader`
	// next to this one uses `length(uv)`, which is right for a soft radial wash but
	// wrong here: on a 16:9 frame a radial falloff reaches the left and right edges long
	// before the top and bottom, so the ice would pool in the corners and leave the long
	// edges bare. The reference image frosts all four edges evenly.
	vec2 d = min(UV, vec2(1.0) - UV);
	// ⚠️ `d.x * aspect` PUTS BOTH AXES IN THE SAME UNIT — screen heights — so the band
	// is the same thickness in PIXELS on all four edges, which is what the reference
	// image shows and what a bare `min(d.x, d.y)` does not give on a wide frame.
	float edge = min(d.x * aspect, d.y);

	float reach = max_reach * coverage;
	// Break the boundary up so it is a ragged frost line rather than a clean border.
	float ragged = (fbm(UV * vec2(7.0 * aspect, 7.0)) - 0.5) * 0.07 * coverage;
	// ⚠️ A TIGHT TRANSITION, NOT A GRADIENT. A wide falloff is what made the first pass
	// read as haze: the ice needs a definable front with clear glass behind it, so the
	// player can still watch the round they are locked out of.
	float body = 1.0 - smoothstep(reach * 0.62, reach + ragged, edge);

	// Crystal filaments: thin bright ridges from folded noise, reaching FURTHER in than
	// the body does, so the frost has spindly fingers instead of a soft cloud. These
	// carry the effect's character — the body behind them is only their bed.
	float veins = 1.0 - abs(fbm(UV * vec2(5.0 * aspect, 5.0) + 11.0) * 2.0 - 1.0);
	veins = pow(clamp(veins, 0.0, 1.0), 12.0);
	float vein_mask = 1.0 - smoothstep(reach * 0.3, (reach + ragged) * 1.6, edge);
	float cracks = veins * vein_mask;

	// Frozen breath speckle, densest where the ice is thickest.
	float speck = pow(value_noise(UV * vec2(90.0 * aspect, 90.0)), 6.0) * body;

	vec3 rgb = mix(frost_tint.rgb, crack_color.rgb, clamp(cracks * 1.4 + speck, 0.0, 1.0));
	// ⚠️ TUNED DOWN FROM 0.58/0.90/0.45 ON A LOOK-AT — 🧑: *"lower down the opacity a bit
	// for the frozen screen. it's a bit too strong"*. The SHAPE was right at those
	// values and is untouched; only the weight came off. The filaments keep the largest
	// share of what is left, because they are what makes it read as ice rather than as a
	// blue haze — dropping them proportionally would have cost the effect its character
	// instead of just its strength.
	float alpha = clamp(body * 0.36 + cracks * 0.64 + speck * 0.28, 0.0, 1.0) * coverage;
	COLOR = vec4(rgb, alpha);
}
