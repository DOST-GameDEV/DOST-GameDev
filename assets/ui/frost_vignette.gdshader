shader_type canvas_item;

uniform float coverage : hint_range(0.0, 1.0) = 0.0;
uniform vec4 frost_tint : source_color = vec4(0.66, 0.90, 0.95, 1.0);
uniform vec4 crack_color : source_color = vec4(0.80, 0.98, 1.0, 1.0);
uniform float max_reach : hint_range(0.05, 0.5) = 0.15;
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
	vec2 d = min(UV, vec2(1.0) - UV);
	float edge = min(d.x * aspect, d.y);

	float reach = max_reach * coverage;
	float ragged = (fbm(UV * vec2(7.0 * aspect, 7.0)) - 0.5) * 0.07 * coverage;
	float body = 1.0 - smoothstep(reach * 0.62, reach + ragged, edge);

	float veins = 1.0 - abs(fbm(UV * vec2(5.0 * aspect, 5.0) + 11.0) * 2.0 - 1.0);
	veins = pow(clamp(veins, 0.0, 1.0), 12.0);
	float vein_mask = 1.0 - smoothstep(reach * 0.3, (reach + ragged) * 1.6, edge);
	float cracks = veins * vein_mask;

	float speck = pow(value_noise(UV * vec2(90.0 * aspect, 90.0)), 6.0) * body;

	vec3 rgb = mix(frost_tint.rgb, crack_color.rgb, clamp(cracks * 1.4 + speck, 0.0, 1.0));
	float alpha = clamp(body * 0.36 + cracks * 0.64 + speck * 0.28, 0.0, 1.0) * coverage;
	COLOR = vec4(rgb, alpha);
}

