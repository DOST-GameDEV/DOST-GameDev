shader_type spatial;
render_mode cull_back, diffuse_toon;

uniform float wind_strength : hint_range(0.0, 0.5) = 0.0;
uniform float wind_speed : hint_range(0.0, 6.0) = 1.4;
uniform float wind_anchor_y = 2.62;
uniform float wind_drop = 0.62;

uniform vec4 rim_color : source_color = vec4(1.0, 0.87, 0.72, 1.0);
uniform float rim_strength : hint_range(0.0, 1.0) = 0.0;
uniform float rim_power : hint_range(0.5, 8.0) = 3.0;

uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D albedo_texture : source_color, hint_default_white;
uniform bool use_texture = false;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;

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

