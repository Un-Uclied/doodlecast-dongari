shader_type canvas_item;
render_mode unshaded, blend_add;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float radius = 32.0;
varying vec2 local_point;

void vertex() {
	local_point = VERTEX;
}

void fragment() {
	vec2 p = floor(local_point) / max(radius, 1.0);
	float d = length(p);
	float front = mix(0.08, 1.0, 1.0 - pow(1.0 - progress, 3.0));
	float uneven = sin(atan(p.y, p.x) * 12.0 + progress * 8.0) * 0.012;
	float ring = (1.0 - smoothstep(0.01, 0.065, abs(d - front + uneven))) * pow(1.0 - progress, 1.5);
	float flash = exp(-d * d * 20.0) * pow(1.0 - progress, 6.0);
	vec3 fire = mix(vec3(1.0, 0.22, 0.035), vec3(1.0, 0.9, 0.55), flash);
	COLOR = vec4(fire, clamp(ring * 0.7 + flash * 0.85, 0.0, 1.0)) * COLOR;
}
