shader_type canvas_item;
render_mode unshaded;

uniform float beam_length = 4096.0;
uniform float half_width = 8.0;
uniform float flame_time = 0.0;
varying vec2 local_position;

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	vec2 p = floor(vec2(abs(local_position.x), local_position.y) * 0.5) * 2.0;
	float curl = sin(p.x * 0.13 - flame_time * 12.0) * 1.1;
	float ragged = sin(p.x * 0.71 - flame_time * 17.0) * 0.07;
	float lane = abs(p.y + curl) / half_width;
	float alpha = 1.0 - smoothstep(0.72, 1.0, lane + ragged);
	alpha *= 1.0 - smoothstep(beam_length * 0.5 - 3.0, beam_length * 0.5, abs(local_position.x));
	vec3 fire = mix(vec3(1.0, 0.12, 0.015), vec3(1.0, 0.65, 0.06), clamp(1.0 - lane, 0.0, 1.0));
	fire = mix(fire, vec3(1.0, 0.97, 0.65), 1.0 - smoothstep(0.12, 0.35, lane));
	COLOR = vec4(fire, alpha) * COLOR;
}
