shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 shallow_color : source_color = vec4(0.08, 0.48, 0.58, 0.90);
uniform vec4 deep_color : source_color = vec4(0.025, 0.17, 0.32, 0.94);
uniform vec4 reflection_tint : source_color = vec4(0.52, 0.82, 0.92, 1.0);
uniform float wave_scale : hint_range(0.01, 2.0) = 0.12;
uniform float wave_speed : hint_range(0.0, 4.0) = 0.48;
uniform float wave_strength : hint_range(0.0, 0.5) = 0.12;

varying vec3 local_position;

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	vec2 p = local_position.xz * wave_scale;
	float wave_a = sin(p.x * 2.2 + TIME * wave_speed);
	float wave_b = cos(p.y * 1.7 - TIME * wave_speed * 0.74);
	float cross_wave = sin((p.x + p.y) * 1.15 + TIME * wave_speed * 0.42);
	float waves = (wave_a + wave_b + cross_wave) / 3.0;
	float depth_mix = smoothstep(-0.8, 0.9, waves + sin(p.x * 0.31) * 0.35);
	vec3 color = mix(deep_color.rgb, shallow_color.rgb, depth_mix);
	float glint = pow(max(0.0, wave_a * wave_b), 5.0) * 0.22;
	ALBEDO = mix(color, reflection_tint.rgb, glint);
	ROUGHNESS = clamp(0.28 + waves * 0.08, 0.16, 0.42);
	SPECULAR = 0.72;
	NORMAL_MAP = vec3(0.5 + wave_a * wave_strength, 0.5 + wave_b * wave_strength, 1.0);
	ALPHA = mix(deep_color.a, shallow_color.a, depth_mix);
}
