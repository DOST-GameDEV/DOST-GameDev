shader_type spatial;
render_mode cull_front, unshaded;

uniform vec4 outline_color : source_color = vec4(0.01569, 0.03137, 0.21961, 1.0);
uniform float outline_width : hint_range(0.0, 0.1, 0.001) = 0.025;

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

