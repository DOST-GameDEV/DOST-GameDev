shader_type canvas_item;
uniform vec4 vignette_color : source_color = vec4(0.97, 0.0, 0.0, 0.6);
void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float dist = length(uv);
	float alpha = smoothstep(0.3, 1.2, dist) * vignette_color.a;
	COLOR = vec4(vignette_color.rgb, alpha);
}

