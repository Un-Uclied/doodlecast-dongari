shader_type canvas_item;
render_mode unshaded;

uniform vec4 background_color : source_color = vec4(0.065, 0.027, 0.078, 0.985);
uniform vec4 ink_color : source_color = vec4(0.79, 0.51, 0.23, 0.09);

float spade(vec2 p) {
	float tip = max(abs(p.x) * 0.832 - (p.y + 0.28) * 0.555, p.y - 0.02);
	float lobes = length(vec2(abs(p.x) - 0.10, p.y)) - 0.12;
	float stem_width = mix(0.025, 0.085, clamp((p.y - 0.05) / 0.16, 0.0, 1.0));
	float stem = max(abs(p.x) - stem_width, max(0.04 - p.y, p.y - 0.21));
	return min(min(tip, lobes), stem);
}

void fragment() {
	vec2 pixels = FRAGCOORD.xy;
	vec2 drift = (pixels + vec2(TIME * 3.0, TIME * 7.0)) / vec2(112.0, 128.0);
	drift.x += mod(floor(drift.y), 2.0) * 0.5;
	vec2 cell = floor(drift);
	vec2 p = (fract(drift) - 0.5) * 1.5;
	float diamond = abs(p.x) * 1.35 + abs(p.y) - 0.23;
	float suit = mod(cell.x + cell.y, 2.0);
	float shape = 1.0 - smoothstep(-0.009, 0.009, mix(spade(p), diamond, suit));
	vec3 ink = mix(vec3(0.56, 0.30, 0.62), ink_color.rgb, suit);
	float vignette = smoothstep(0.15, 0.8, distance(SCREEN_UV, vec2(0.5)));
	vec3 color = background_color.rgb * (1.0 - vignette * 0.3);
	color += ink * ink_color.a * shape;
	COLOR = vec4(color, background_color.a) * COLOR;
}
