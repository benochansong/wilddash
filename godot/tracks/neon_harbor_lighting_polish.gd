class_name WildDashNeonHarborLightingPolish
extends Node3D

const ROUTE_LIGHT_INDICES: Array[int] = [1, 3, 5, 8, 10, 12, 14, 17, 20, 22, 24]
const WARM_LIGHT := Color(1.0, 0.72, 0.38)
const COOL_LIGHT := Color(0.48, 0.82, 1.0)

var _track: WildDashNeonHarborTrack
var _installed := false

func _ready() -> void:
	call_deferred("_install_when_ready")

func _install_when_ready() -> void:
	for _attempt in range(8):
		_track = get_parent().get_node_or_null("NeonHarborWorldTrack") as WildDashNeonHarborTrack
		if _track != null:
			break
		await get_tree().process_frame
	if _track == null:
		push_warning("Neon Harbor lighting polish could not find track")
		return
	_apply_environment_fill()
	_brighten_key_materials()
	_build_practical_route_lights()
	_build_tunnel_fill_lights()
	_build_finish_floodlight()
	_installed = true
	print("NEON HARBOR LIGHTING POLISH PASS ambient=1.22 route_lights=%d tunnel_lights=3 shadows=false" % ROUTE_LIGHT_INDICES.size())

func is_installed() -> bool:
	return _installed

func _apply_environment_fill() -> void:
	var world := _track.get_node_or_null("NeonHarborWorldEnvironment") as WorldEnvironment
	if world != null and world.environment != null:
		world.environment.background_mode = Environment.BG_COLOR
		world.environment.background_color = Color(0.028, 0.060, 0.145)
		world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		world.environment.ambient_light_color = Color(0.40, 0.49, 0.68)
		world.environment.ambient_light_energy = 1.22
		world.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC

	var moon := _track.get_node_or_null("HarborMoonLight") as DirectionalLight3D
	if moon != null:
		moon.light_color = Color(0.66, 0.78, 1.0)
		moon.light_energy = 0.68

	var mode_sun := get_parent().find_child("Sun", true, false) as DirectionalLight3D
	if mode_sun != null:
		mode_sun.light_color = Color(0.52, 0.64, 0.88)
		mode_sun.light_energy = 0.52

func _brighten_key_materials() -> void:
	var decoration := _track.get_node_or_null("DecorationGeometry")
	if decoration == null:
		return
	_set_material_albedo(decoration.get_node_or_null("HarborRoadSurface"), Color(0.11, 0.15, 0.215))
	_set_material_albedo(decoration.get_node_or_null("HarborGuardrails"), Color(0.38, 0.47, 0.57))
	_set_material_albedo(decoration.get_node_or_null("WarehouseBodies"), Color(0.21, 0.27, 0.37))
	_set_material_albedo(decoration.get_node_or_null("IndustrialTunnelPanels"), Color(0.34, 0.39, 0.47))
	_set_emission_energy(decoration.get_node_or_null("HarborRoadEdges"), 0.78)
	_set_emission_energy(decoration.get_node_or_null("StreetLampGlow"), 1.45)
	_set_emission_energy(decoration.get_node_or_null("IndustrialTunnelLights"), 1.55)
	_set_emission_energy(decoration.get_node_or_null("NeonBuildingWindows"), 1.35)

func _build_practical_route_lights() -> void:
	var route := _track.get_route_points()
	for list_index in range(ROUTE_LIGHT_INDICES.size()):
		var route_index: int = ROUTE_LIGHT_INDICES[list_index]
		if route_index < 0 or route_index >= route.size():
			continue
		var light := OmniLight3D.new()
		light.name = "PracticalRouteLight_%02d" % route_index
		light.position = route[route_index] + Vector3.UP * 6.2
		light.light_color = WARM_LIGHT if list_index % 3 != 1 else COOL_LIGHT
		light.light_energy = 1.45 if list_index % 3 != 1 else 1.28
		light.omni_range = 29.0
		light.omni_attenuation = 1.35
		light.shadow_enabled = false
		add_child(light)

func _build_tunnel_fill_lights() -> void:
	var route := _track.get_route_points()
	if route.size() <= 14:
		return
	var a: Vector3 = route[13]
	var b: Vector3 = route[14]
	for index in range(3):
		var light := OmniLight3D.new()
		light.name = "TunnelFill_%02d" % index
		light.position = a.lerp(b, 0.22 + float(index) * 0.28) + Vector3.UP * 3.4
		light.light_color = Color(0.52, 0.88, 1.0)
		light.light_energy = 1.55
		light.omni_range = 17.5
		light.omni_attenuation = 1.2
		light.shadow_enabled = false
		add_child(light)

func _build_finish_floodlight() -> void:
	var light := OmniLight3D.new()
	light.name = "FinishFloodLight"
	light.position = _track.get_finish_position() + Vector3.UP * 7.0
	light.light_color = Color(0.78, 0.92, 1.0)
	light.light_energy = 1.85
	light.omni_range = 32.0
	light.omni_attenuation = 1.25
	light.shadow_enabled = false
	add_child(light)

func _set_material_albedo(node: Node, color: Color) -> void:
	if not node is MultiMeshInstance3D:
		return
	var instance := node as MultiMeshInstance3D
	var material := instance.material_override as StandardMaterial3D
	if material != null:
		material.albedo_color = color

func _set_emission_energy(node: Node, energy: float) -> void:
	if not node is MultiMeshInstance3D:
		return
	var instance := node as MultiMeshInstance3D
	var material := instance.material_override as StandardMaterial3D
	if material != null and material.emission_enabled:
		material.emission_energy_multiplier = energy
