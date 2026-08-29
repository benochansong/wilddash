shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.75;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float specular_level : hint_range(0.0, 1.0) = 0.32;
uniform vec4 rim_color : source_color = vec4(0.55, 0.72, 0.95, 1.0);
uniform float rim_strength : hint_range(0.0, 1.0) = 0.10;
uniform float rim_power : hint_range(1.0, 8.0) = 3.5;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_strength : hint_range(0.0, 4.0) = 0.0;

void fragment() {
	ALBEDO = albedo_color.rgb;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	SPECULAR = specular_level;
	float view_dot = max(dot(normalize(NORMAL), normalize(VIEW)), 0.0);
	float rim = pow(1.0 - view_dot, rim_power) * rim_strength;
	EMISSION = emission_color.rgb * emission_strength + rim_color.rgb * rim;
}
