class_name WildDashTrackMaterials
extends RefCounted

const SURFACE_SHADER: Shader = preload("res://tracks/stylized_surface.gdshader")

static func build_palette() -> Dictionary:
	return {
		&"asphalt": _surface(Color("343b43"), Color("252b31"), 0.94, 0.42, 0.13, 0.10),
		&"dirt": _surface(Color("9a6846"), Color("70472f"), 0.98, 0.24, 0.20, 0.05),
		&"grass": _surface(Color("4f7f3f"), Color("315d31"), 1.0, 0.35, 0.18, 0.02),
		&"rock": _surface(Color("765a49"), Color("4c3b35"), 0.97, 0.28, 0.24, 0.02),
		&"bridge": _surface(Color("66584b"), Color("403a36"), 0.88, 0.58, 0.12, 0.05),
		&"tunnel": _surface(Color("39434b"), Color("232a31"), 0.96, 0.44, 0.10, 0.01),
		&"curb_light": _standard(Color("e7ddd0"), 0.78),
		&"curb_warning": _standard(Color("ed704d"), 0.72),
		&"road_line": _standard(Color("f3e8c8"), 0.66, Color("f3e8c8") * 0.08),
		&"guardrail": _standard(Color("88a7ad"), 0.58),
		&"wood": _surface(Color("704a2e"), Color("4a301f"), 0.92, 0.75, 0.14, 0.02),
		&"foliage": _surface(Color("3f7f3d"), Color("24532d"), 0.98, 0.55, 0.16, 0.02),
		&"foliage_light": _surface(Color("6e9945"), Color("3d7137"), 0.98, 0.60, 0.14, 0.02),
		&"water": _standard(Color(0.05, 0.32, 0.56, 0.88), 0.30),
		&"tunnel_light": _standard(Color("ffd47a"), 0.32, Color("ffd47a") * 1.45),
		&"hazard": _standard(Color("f05a45"), 0.68, Color("f05a45") * 0.08),
	}

static func _surface(
	base_color: Color,
	variation_color: Color,
	roughness: float,
	detail_scale: float,
	detail_strength: float,
	wear_strength: float
) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SURFACE_SHADER
	material.set_shader_parameter(&"base_color", base_color)
	material.set_shader_parameter(&"variation_color", variation_color)
	material.set_shader_parameter(&"roughness_value", roughness)
	material.set_shader_parameter(&"detail_scale", detail_scale)
	material.set_shader_parameter(&"detail_strength", detail_strength)
	material.set_shader_parameter(&"wear_strength", wear_strength)
	return material

static func _standard(color: Color, roughness: float, emission := Color.BLACK) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	if emission != Color.BLACK:
		material.emission_enabled = true
		material.emission = emission
	return material
