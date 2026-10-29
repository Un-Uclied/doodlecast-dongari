shader_type canvas_item;
render_mode unshaded, blend_add;

uniform float aura_time = 0.0;
uniform float rage : hint_range(0.0, 1.0) = 0.0;
varying vec2 local_point;

void vertex() {
	local_point = VERTEX;
}

void fragment() {
	vec2 p = floor(local_point) / 48.0;
	float d = length(p * vec2(1.0, 1.1));
	float a = atan(p.y, p.x);
	float curl = sin(a * 5.0 - aura_time * 1.8) * 0.055 + sin(a * 9.0 + aura_time) * 0.025;
	float wisps = exp(-pow((d - 0.58 - curl) * 7.0, 2.0));
	float haze = exp(-d * d * 4.0) * 0.4;
	float fade = 1.0 - smoothstep(0.72, 1.0, d);
	vec3 ink = mix(vec3(0.53, 0.18, 0.85), vec3(0.95, 0.49, 0.18), rage * 0.45);
	COLOR = vec4(ink, (wisps + haze) * fade * (0.26 + rage * 0.08));
}
