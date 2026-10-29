shader_type canvas_item;
render_mode unshaded;

uniform vec4 tint : source_color = vec4(1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 edge = abs(UV * 2.0 - 1.0);
	float distance_to_edge = max(edge.x, edge.y);
	float vignette = smoothstep(0.4, 1.0, distance_to_edge);
	COLOR = vec4(tint.rgb, vignette * vignette * strength);
}
