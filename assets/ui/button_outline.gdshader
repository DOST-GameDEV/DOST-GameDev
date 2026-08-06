shader_type canvas_item;


uniform float rim_alpha : hint_range(0.0, 1.0) = 0.0;
uniform vec4 rim_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float rim_width : hint_range(0.0, 16.0) = 3.0;
uniform float brightness : hint_range(0.5, 2.0) = 1.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 px = TEXTURE_PIXEL_SIZE * rim_width;

	float neighbour = 1.0;
	neighbour = min(neighbour, texture(TEXTURE, UV + vec2(px.x, 0.0)).a);
	neighbour = min(neighbour, texture(TEXTURE, UV - vec2(px.x, 0.0)).a);
	neighbour = min(neighbour, texture(TEXTURE, UV + vec2(0.0, px.y)).a);
	neighbour = min(neighbour, texture(TEXTURE, UV - vec2(0.0, px.y)).a);
	neighbour = min(neighbour, texture(TEXTURE, UV + px).a);
	neighbour = min(neighbour, texture(TEXTURE, UV - px).a);
	neighbour = min(neighbour, texture(TEXTURE, UV + vec2(px.x, -px.y)).a);
	neighbour = min(neighbour, texture(TEXTURE, UV + vec2(-px.x, px.y)).a);

	float rim = clamp(tex.a - neighbour, 0.0, 1.0) * rim_alpha;
	COLOR.rgb = mix(COLOR.rgb * brightness, rim_color.rgb, rim);
}

