shader_type canvas_item;
render_mode unshaded;

uniform float reveal : hint_range(0.0, 1.0) = 0.0;
uniform float pattern_time = 0.0;

void fragment() {
	vec2 p = (UV - 0.5) * vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	float divide = UV.x + (UV.y - 0.5) * 0.2 - 0.5;
	vec3 ink = mix(vec3(0.11, 0.045, 0.17), vec3(0.055, 0.02, 0.07), smoothstep(-0.015, 0.015, divide));
	float halo = exp(-dot(p, p) * 3.5);
	ink += mix(vec3(0.16, 0.07, 0.22), vec3(0.19, 0.095, 0.035), step(0.0, divide)) * halo;
	float seam = exp(-abs(divide) * 270.0) * reveal;
	ink += vec3(0.6, 0.36, 0.1) * seam;
	vec2 tile = fract(p * 4.0 + vec2(pattern_time * 0.035, -pattern_time * 0.025)) - 0.5;
	float diamond = abs(tile.x) + abs(tile.y);
	float lattice = 1.0 - smoothstep(0.008, 0.025, abs(diamond - 0.3));
	float star = (1.0 - smoothstep(0.02, 0.05, abs(tile.x))) * (1.0 - smoothstep(0.08, 0.14, abs(tile.y)));
	ink += vec3(0.35, 0.21, 0.37) * (lattice * 0.11 + star * 0.08);
	float grain = fract(sin(dot(floor(FRAGCOORD.xy / 3.0), vec2(12.9898, 78.233))) * 43758.5453);
	ink += grain * 0.008;
	float edge = smoothstep(0.18, 0.85, length(p));
	COLOR = vec4(ink * (1.0 - edge * 0.7), 0.98);
}
