
shader_type spatial;
render_mode cull_back, diffuse_toon;

uniform sampler2D source_map : source_color, filter_nearest, repeat_disable;
uniform vec4 palette[16] : source_color;
uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 0.0);

uniform float frost_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 frost_color : source_color = vec4(0.62, 0.87, 0.95, 1.0);
uniform vec4 frost_rim_color : source_color = vec4(0.85, 0.98, 1.0, 1.0);
const float FROST_MAX_MIX = 0.68;

void fragment() {
	vec2 cell = floor(clamp(UV, vec2(0.0), vec2(0.9999)) * 16.0);
	int col = int(cell.x);
	int row = int(cell.y);

	vec3 base;
	if (row >= 8) {
		base = palette[(col / 2) + (row >= 12 ? 8 : 0)].rgb;
	} else {
		base = texture(source_map, UV).rgb;
	}

	ALBEDO = mix(base, albedo_color.rgb, albedo_color.a);
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;

	if (frost_amount > 0.0) {
		vec3 world_normal = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
		float settle = mix(0.42, 1.0, clamp(world_normal.y * 0.5 + 0.5, 0.0, 1.0));
		ALBEDO = mix(ALBEDO, frost_color.rgb, frost_amount * settle * FROST_MAX_MIX);
		float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
		ALBEDO = mix(ALBEDO, frost_rim_color.rgb, rim * frost_amount);
		ROUGHNESS = mix(1.0, 0.25, frost_amount);
		SPECULAR = mix(0.0, 0.5, frost_amount);
	}
}

