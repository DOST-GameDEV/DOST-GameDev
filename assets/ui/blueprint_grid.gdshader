shader_type canvas_item;
uniform float grid_size : hint_range(8.0, 64.0, 1.0) = 24.0;
uniform vec4 bg_color : source_color = vec4(0.882, 0.898, 0.910, 1.0);
uniform vec4 line_color : source_color = vec4(0.0, 0.502, 0.914, 0.09);
void fragment() {
	vec2 grid = mod(FRAGCOORD.xy, grid_size);
	float on_line = step(grid_size - 1.0, grid.x) + step(grid_size - 1.0, grid.y);
	COLOR = mix(bg_color, vec4(line_color.rgb, 1.0), clamp(on_line, 0.0, 1.0) * line_color.a * 11.0);
}

