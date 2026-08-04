shader_type spatial;
render_mode unshaded, skip_vertex_transform, cull_disabled, depth_draw_never, depth_test_disabled;

// CAMERA MOTION BLUR, BUILT HERE BECAUSE GODOT 4.7 DOES NOT HAVE ANY.
//
// 🧑 2026-08-04: *"can u build ur own motion blur but keep it off unless ticked on
// in settings"*. Checked before writing rather than assumed: ClassDB reports no
// `motion` or `blur` property on Environment on this build, and no `rendering/**`
// project setting provides one. So this is the whole feature.
//
// ⚠️ IT IS A DEPTH REPROJECTION, NOT A VELOCITY BUFFER. Godot does render motion
// vectors internally for TAA, but does not expose them to a spatial shader. What
// IS reachable is the depth buffer, and that is enough for CAMERA motion: unproject
// each pixel to a world position using this frame's inverse matrices, project it
// again with LAST frame's view-projection (handed in by motion_blur.gd), and the
// gap between the two screen positions is how far that pixel travelled. Sample
// along it and average.
//
// ⚠️ WHAT THAT BUYS AND WHAT IT COSTS. Turning, running and camera shake all blur
// correctly, because those move every pixel. A slipper thrown across a still camera
// does NOT blur — its motion is the object's, not the camera's, and object velocity
// is exactly what a depth reprojection cannot see. That is the honest limit of this
// technique and the reason it is cheap enough to hand to a weak machine.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;

// Last frame's view-projection, written every frame by motion_blur.gd.
uniform mat4 prev_view_proj;
// 0..1 from the settings slider-less tick; 1.0 is a full frame's worth of travel.
uniform float strength : hint_range(0.0, 1.0) = 0.5;
// ⚠️ THE SAFETY RAIL. Without it, the first frame after a camera cut (a round swap,
// an FPP/TPP switch, a respawn) reprojects against a matrix from somewhere else
// entirely and every pixel smears across the whole screen for one frame — the most
// visible possible glitch, and it happens exactly when the player is already
// disoriented. Capped in UV, so it is resolution independent.
uniform float max_travel : hint_range(0.0, 0.2) = 0.03;
uniform int samples : hint_range(2, 16) = 8;

void vertex() {
	// Fullscreen in clip space. The QuadMesh's own transform is irrelevant — this
	// is why `skip_vertex_transform` is on and why the node can hang off any camera
	// without being positioned.
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

// ⚠️ NO `return` ANYWHERE IN HERE, AND THAT IS A HARD LANGUAGE RULE, not a style
// choice: Godot's shading language rejects `return` inside `fragment()` outright
// ("Using 'return' in the 'fragment' processor function is incorrect"), and the
// shader then fails to COMPILE while `load()` still hands back a perfectly valid
// Shader resource — so the only symptom is an untextured quad and one line in the
// log. The early-outs below are therefore a single `blur` flag, not guard clauses.
void fragment() {
	vec3 result = texture(screen_tex, SCREEN_UV).rgb;
	float depth = texture(depth_tex, SCREEN_UV).r;
	// ⚠️ REVERSE-Z: 0.0 IS THE FAR PLANE, i.e. the sky. Reprojecting it divides by
	// ~0 and produces a garbage velocity, so it keeps the unblurred sample. The sky
	// has no parallax to blur anyway.
	if (depth > 0.0) {
		vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
		vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
		view.xyz /= view.w;
		vec4 world = INV_VIEW_MATRIX * vec4(view.xyz, 1.0);
		vec4 prev_clip = prev_view_proj * world;
		// w <= 0 is behind last frame's camera — no sane screen position to blur toward.
		if (prev_clip.w > 0.0) {
			vec2 prev_ndc = prev_clip.xy / prev_clip.w;
			// NDC -> UV is a halving; the y flip cancels because both points take it.
			vec2 travel = (ndc.xy - prev_ndc) * 0.5 * strength;
			float dist = length(travel);
			if (dist > 0.0001) {
				travel *= min(dist, max_travel) / dist;
				vec3 accum = vec3(0.0);
				float weight = 0.0;
				for (int i = 0; i < samples; i++) {
					float t = float(i) / float(samples - 1) - 0.5;
					vec2 uv = clamp(SCREEN_UV + travel * t, vec2(0.001), vec2(0.999));
					accum += texture(screen_tex, uv).rgb;
					weight += 1.0;
				}
				result = accum / weight;
			}
		}
	}
	ALBEDO = result;
}
