shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.25, 0.25, 0.25, 1.0);
uniform vec4 variation_color : source_color = vec4(0.18, 0.18, 0.18, 1.0);
uniform float roughness_value : hint_range(0.0, 1.0) = 0.9;
uniform float detail_scale : hint_range(0.01, 8.0) = 1.0;
uniform float detail_strength : hint_range(0.0, 0.5) = 0.12;
uniform float wear_strength : hint_range(0.0, 0.5) = 0.08;

varying vec3 local_position;

float hash21(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	vec2 sample_position = local_position.xz * detail_scale;
	vec2 cell = floor(sample_position);
	float broad_noise = hash21(cell);
	float fine_noise = hash21(floor(sample_position * 3.17) + vec2(19.0, 7.0));
	float aggregate = mix(broad_noise, fine_noise, 0.35);
	float variation = (aggregate - 0.5) * 2.0 * detail_strength;
	float worn_path = (1.0 - smoothstep(0.08, 0.48, abs(local_position.x))) * wear_strength;
	vec3 surface_color = mix(base_color.rgb, variation_color.rgb, clamp(0.5 + variation, 0.0, 1.0));
	surface_color = mix(surface_color, surface_color * 1.12, worn_path);
	ALBEDO = surface_color;
	ROUGHNESS = clamp(roughness_value + (fine_noise - 0.5) * 0.08, 0.05, 1.0);
}
