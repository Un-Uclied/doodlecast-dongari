shader_type canvas_item;
render_mode unshaded;
uniform float flame_time = 0.0;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
varying vec2 local_point;

float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	vec4 h = fract(sin(vec4(dot(cell, vec2(127.1, 311.7)), dot(cell + vec2(1.0, 0.0), vec2(127.1, 311.7)), dot(cell + vec2(0.0, 1.0), vec2(127.1, 311.7)), dot(cell + vec2(1.0), vec2(127.1, 311.7)))) * 43758.5453);
	return mix(mix(h.x, h.y, f.x), mix(h.z, h.w, f.x), f.y);
}

void vertex() {
	local_point = VERTEX;
}

void fragment() {
	vec2 pixel = floor(local_point / 1.5);
	vec2 flow = vec2(pixel.x * 0.2, pixel.y * 0.1 + flame_time * 4.5);
	float curl = noise(flow + vec2(noise(flow * 0.5) * 2.0, 0.0));
	float heat = smoothstep(0.25, 0.8, curl * 0.75 + noise(flow * 2.0) * 0.25);
	vec3 fire = mix(vec3(0.75, 0.055, 0.025), vec3(1.0, 0.57, 0.12), heat);
	fire = mix(fire, vec3(1.0, 0.9, 0.5), smoothstep(0.87, 1.0, heat) * 0.7);
	COLOR *= vec4(fire, (0.23 + heat * 0.4) * fade);
}
