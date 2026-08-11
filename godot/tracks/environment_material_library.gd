class_name WildDashEnvironmentMaterialLibrary
extends RefCounted

const SURFACE_SHADER: Shader = preload("res://tracks/stylized_surface.gdshader")
const WATER_SHADER: Shader = preload("res://tracks/stylized_water.gdshader")

static var _palette: Dictionary = {}

static func get_palette() -> Dictionary:
	if _palette.is_empty():
		_palette = _build_palette()
	return _palette

static func has_required_materials() -> bool:
	var palette := get_palette()
	for key: StringName in [
		&"asphalt", &"dirt", &"grass", &"rock", &"wood", &"metal",
		&"concrete", &"water", &"hazard", &"finish", &"wet_rock",
	]:
		if not palette.has(key) or palette[key] == null:
			return false
	return true

static func _build_palette() -> Dictionary:
	var metal := _standard(Color("7f969b"), 0.38, Color.BLACK, 0.68)
	var concrete := _surface(Color("4a545b"), Color("303940"), 0.94, 0.36, 0.10, 0.01, 0.0, 0.10)
	var finish := _standard(Color("20a8c8"), 0.48, Color("20a8c8") * 0.10, 0.12)
	return {
		&"asphalt": _surface(Color("343b43"), Color("252b31"), 0.93, 0.42, 0.13, 0.10),
		&"dirt": _surface(Color("9b6947"), Color("72482f"), 0.98, 0.24, 0.19, 0.05, 0.0, 0.08),
		&"grass": _surface(Color("527f40"), Color("315d35"), 1.0, 0.35, 0.15, 0.02),
		&"rock": _surface(Color("775d4c"), Color("4c3c36"), 0.97, 0.28, 0.22, 0.02, 0.0, 0.28),
		&"wood": _surface(Color("714b2e"), Color("49301f"), 0.92, 0.76, 0.13, 0.02, 0.34, 0.05),
		&"metal": metal,
		&"concrete": concrete,
		&"bridge": metal,
		&"tunnel": concrete,
		&"water": _water(),
		&"wet_rock": _surface(Color("53666a"), Color("33494e"), 0.40, 0.42, 0.12, 0.03, 0.0, 0.16),
		&"hazard": _standard(Color("ed5d46"), 0.64, Color("ed5d46") * 0.08),
		&"finish": finish,
		&"event_blue": finish,
		&"curb_light": _standard(Color("e7ddd0"), 0.78),
		&"curb_warning": _standard(Color("ed704d"), 0.72),
		&"road_line": _standard(Color("f3e8c8"), 0.66, Color("f3e8c8") * 0.08),
		&"guardrail": metal,
		&"foliage": _surface(Color("407b42"), Color("27543a"), 0.98, 0.55, 0.14, 0.02),
		&"foliage_light": _surface(Color("709747"), Color("41713d"), 0.98, 0.60, 0.12, 0.02),
		&"tunnel_light": _standard(Color("ffd47a"), 0.32, Color("ffd47a") * 1.45),
	}

static func _water() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = WATER_SHADER
	return material

static func _surface(
	base_color: Color,
	variation_color: Color,
	roughness: float,
	detail_scale: float,
	detail_strength: float,
	wear_strength: float,
	directional_strength := 0.0,
	layering_strength := 0.0
) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SURFACE_SHADER
	material.set_shader_parameter(&"base_color", base_color)
	material.set_shader_parameter(&"variation_color", variation_color)
	material.set_shader_parameter(&"roughness_value", roughness)
	material.set_shader_parameter(&"detail_scale", detail_scale)
	material.set_shader_parameter(&"detail_strength", detail_strength)
	material.set_shader_parameter(&"wear_strength", wear_strength)
	material.set_shader_parameter(&"directional_strength", directional_strength)
	material.set_shader_parameter(&"layering_strength", layering_strength)
	return material

static func _standard(
	color: Color,
	roughness: float,
	emission := Color.BLACK,
	metallic := 0.0
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	if emission != Color.BLACK:
		material.emission_enabled = true
		material.emission = emission
	return material
