shader_type canvas_item;
render_mode unshaded;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform bool radial_fill = false;
uniform float fill_start = 0.0;
uniform float fill_end = 160.0;
varying vec2 local_position;

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	float distance_along = radial_fill ? length(local_position) : local_position.x;
	float front = mix(fill_start, fill_end + 1.0, progress);
	float filled = (1.0 - smoothstep(front - 0.5, front + 0.5, distance_along)) * step(0.0001, progress);
	COLOR = vec4(1.0, 0.055, 0.025, mix(0.14, 0.48, filled)) * COLOR;
}
