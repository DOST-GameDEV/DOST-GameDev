shader_type canvas_item;
uniform vec4 fold_color : source_color = vec4(0.016, 0.031, 0.220, 1.0);
void fragment() {
	float tri = step(UV.x + UV.y, 0.99);
	COLOR = vec4(fold_color.rgb, 1.0 - tri);
}

