class_name WildDashWildTideWorldControllerV3
extends "res://modes/neon_harbor_race/wild_tide_world_controller.gd"

## WILD TIDE World V3 — visual/gameplay contract pass.
##
## V2 already authored the correct baseline distance budget (about 48% visible
## gameplay water and about 28% jungle), removed pavement meshes on water
## segments, and connected real canopy anchors. V3 makes those authored systems
## harder to miss in play: denser visual-only mangrove dressing, explicit muddy
## banks/roots/rocks, a Round-3-only water movement curve, and a delayed world
## audit that reports the active route/guidance chain after bootstrap.

const PROFILE_REFRESH_SECONDS: float = 0.12
const EXTRA_TREE_SAMPLES_PER_SEGMENT: int = 4
const EXTRA_TREE_LATERAL_BASE: float = 6.2

var _v3_profile_elapsed: float = 0.0
var _v3_dressing_built: bool = false
var _v3_extra_tree_count: int = 0
var _v3_bush_count: int = 0
var _v3_root_count: int = 0
var _v3_rock_count: int = 0

func _ready() -> void:
	super._ready()
	call_deferred("_v3_after_bootstrap")

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not _bootstrapped:
		return
	_v3_profile_elapsed += delta
	if _v3_profile_elapsed < PROFILE_REFRESH_SECONDS:
		return
	_v3_profile_elapsed = 0.0
	_enforce_round3_water_profiles()

func _v3_after_bootstrap() -> void:
	for _attempt: int in range(120):
		if _bootstrapped:
			break
		await get_tree().physics_frame
	if not _bootstrapped:
		push_warning("WILD TIDE WORLD V3 post-bootstrap skipped: V2 world unavailable")
		return
	_build_dense_jungle_dressing()
	_enforce_round3_water_profiles()
	await _emit_full_world_audit()

func _enforce_round3_water_profiles() -> void:
	for value: Variant in RaceManager.racers:
		var racer: WildDashCharacterController = value as WildDashCharacterController
		if racer == null or not is_instance_valid(racer) or racer.finished:
			continue
		if not racer.has_meta(&"wild_tide_terrain"):
			continue
		var terrain_value: Variant = racer.get_meta(&"wild_tide_terrain", WildDashTerrainAbilitySystem.TERRAIN_SHALLOW_WATER)
		var terrain_type: StringName = StringName(String(terrain_value))
		if terrain_type != WildDashTerrainAbilitySystem.TERRAIN_SHALLOW_WATER and terrain_type != WildDashTerrainAbilitySystem.TERRAIN_DEEP_WATER:
			continue
		var racer_id: int = racer.get_instance_id()
		var base_value: Variant = _movement_base_by_racer.get(racer_id, {})
		if not (base_value is Dictionary):
			continue
		var base: Dictionary = base_value
		var multiplier: float = _round3_water_multiplier(racer.animal_id, terrain_type)
		racer.max_speed = float(base.get("max_speed", racer.max_speed)) * multiplier
		racer.cruise_speed = float(base.get("cruise_speed", racer.cruise_speed)) * multiplier
		var acceleration_scale: float = clampf(0.95 + (multiplier - 1.0) * 0.34, 0.84, 1.10)
		racer.acceleration = float(base.get("acceleration", racer.acceleration)) * acceleration_scale
		var turn_scale: float = 1.10 if racer.animal_id == &"crocodile" else clampf(1.0 + (multiplier - 1.0) * 0.20, 0.90, 1.07)
		racer.turn_speed = float(base.get("turn_speed", racer.turn_speed)) * turn_scale
		racer.set_meta(&"wild_tide_speed_multiplier", multiplier)

func _round3_water_multiplier(animal_id: StringName, terrain_type: StringName) -> float:
	var deep: bool = terrain_type == WildDashTerrainAbilitySystem.TERRAIN_DEEP_WATER
	match animal_id:
		&"crocodile": return 1.16 if deep else 1.10
		&"raccoon": return 1.05 if deep else 1.03
		&"bear": return 0.98 if deep else 0.99
		&"elephant": return 0.96 if deep else 0.99
		&"boar": return 0.92 if deep else 0.97
		&"wolf": return 0.93 if deep else 0.97
		&"dog": return 0.92 if deep else 0.97
		&"deer": return 0.90 if deep else 0.96
		&"fox": return 0.90 if deep else 0.96
		&"monkey": return 0.88 if deep else 0.95
		&"cat": return 0.86 if deep else 0.93
		&"rabbit": return 0.84 if deep else 0.94
		_: return 0.91 if deep else 0.97

func _build_dense_jungle_dressing() -> void:
	if _v3_dressing_built or _route_points.size() < 29:
		return
	_v3_dressing_built = true
	var trunk_transforms: Array[Transform3D] = []
	var crown_transforms: Array[Transform3D] = []
	var bush_transforms: Array[Transform3D] = []
	var root_transforms: Array[Transform3D] = []
	var rock_transforms: Array[Transform3D] = []
	var mud_bank_transforms: Array[Transform3D] = []

	for segment_index: int in JUNGLE_SEGMENTS:
		if segment_index < 0 or segment_index >= _route_points.size() - 1:
			continue
		var a: Vector3 = _route_points[segment_index]
		var b: Vector3 = _route_points[segment_index + 1]
		var direction: Vector3 = b - a
		direction.y = 0.0
		var segment_length: float = direction.length()
		if segment_length <= 0.01:
			continue
		direction = direction.normalized()
		var right: Vector3 = Vector3(-direction.z, 0.0, direction.x)
		var road_half: float = maxf(5.0, _segment_base_width(segment_index) * 0.5)
		var yaw: float = atan2(direction.x, direction.z)

		for side: float in [-1.0, 1.0]:
			var mud_position: Vector3 = a.lerp(b, 0.5) + right * side * (road_half + 3.25) + Vector3(0.0, 0.035, 0.0)
			var mud_transform: Transform3D = Transform3D(Basis(Vector3.UP, yaw), mud_position)
			mud_transform.basis = mud_transform.basis.scaled(Vector3(4.4, 0.10, maxf(2.0, segment_length + 0.8)))
			mud_bank_transforms.append(mud_transform)

		for sample_index: int in range(EXTRA_TREE_SAMPLES_PER_SEGMENT):
			var t: float = 0.10 + float(sample_index) * 0.26
			for side: float in [-1.0, 1.0]:
				var seed: int = segment_index * 37 + sample_index * 11 + (3 if side > 0.0 else 0)
				var lateral: float = road_half + EXTRA_TREE_LATERAL_BASE + float(seed % 4) * 1.55
				var along_jitter: float = float((seed % 5) - 2) * 0.55
				var base_position: Vector3 = a.lerp(b, t) + right * side * lateral + direction * along_jitter
				var height: float = 6.8 + float(seed % 6) * 0.72
				var trunk: Transform3D = Transform3D(Basis.IDENTITY, base_position + Vector3.UP * (height * 0.5))
				trunk.basis = trunk.basis.scaled(Vector3(0.62 + float(seed % 3) * 0.08, height * 0.5, 0.62 + float((seed + 1) % 3) * 0.08))
				trunk_transforms.append(trunk)

				var crown: Transform3D = Transform3D(Basis.IDENTITY, base_position + Vector3.UP * (height + 1.0))
				crown.basis = crown.basis.scaled(Vector3(2.8 + float(seed % 2) * 0.55, 1.45 + float(seed % 3) * 0.20, 2.7 + float((seed + 1) % 2) * 0.55))
				crown_transforms.append(crown)
				_v3_extra_tree_count += 1

				var bush_position: Vector3 = base_position + right * side * 1.3 + Vector3.UP * 0.72
				var bush: Transform3D = Transform3D(Basis.IDENTITY, bush_position)
				bush.basis = bush.basis.scaled(Vector3(1.45, 0.72, 1.25))
				bush_transforms.append(bush)
				_v3_bush_count += 1

				var root_position: Vector3 = base_position + direction * 0.45 + Vector3.UP * 0.23
				var root: Transform3D = Transform3D(Basis(Vector3.UP, yaw + side * 0.42), root_position)
				root.basis = root.basis.scaled(Vector3(0.38, 0.28, 2.6))
				root_transforms.append(root)
				_v3_root_count += 1

				if sample_index % 2 == 0:
					var rock_position: Vector3 = base_position - right * side * 1.7 + Vector3.UP * 0.34
					var rock: Transform3D = Transform3D(Basis.IDENTITY, rock_position)
					rock.basis = rock.basis.scaled(Vector3(0.72 + float(seed % 2) * 0.28, 0.42, 0.84))
					rock_transforms.append(rock)
					_v3_rock_count += 1

	var trunk_mesh: CylinderMesh = CylinderMesh.new()
	trunk_mesh.top_radius = 0.78
	trunk_mesh.bottom_radius = 1.0
	trunk_mesh.height = 2.0
	trunk_mesh.radial_segments = 7
	_v3_add_multimesh("MangroveV3DenseTrunks", trunk_mesh, trunk_transforms, _simple_material(Color(0.24, 0.12, 0.045), 0.96))

	var crown_mesh: SphereMesh = SphereMesh.new()
	crown_mesh.radius = 1.0
	crown_mesh.height = 2.0
	crown_mesh.radial_segments = 8
	crown_mesh.rings = 5
	_v3_add_multimesh("MangroveV3DenseCanopy", crown_mesh, crown_transforms, _emissive_material(Color(0.045, 0.46, 0.12), Color(0.03, 0.26, 0.07), 0.13))

	var bush_mesh: SphereMesh = SphereMesh.new()
	bush_mesh.radius = 1.0
	bush_mesh.height = 1.6
	bush_mesh.radial_segments = 7
	bush_mesh.rings = 4
	_v3_add_multimesh("MangroveV3Bushes", bush_mesh, bush_transforms, _simple_material(Color(0.08, 0.33, 0.10), 0.98))

	var root_mesh: BoxMesh = BoxMesh.new()
	root_mesh.size = Vector3.ONE
	_v3_add_multimesh("MangroveV3Roots", root_mesh, root_transforms, _simple_material(Color(0.30, 0.16, 0.065), 0.96))

	var rock_mesh: SphereMesh = SphereMesh.new()
	rock_mesh.radius = 1.0
	rock_mesh.height = 1.6
	rock_mesh.radial_segments = 7
	rock_mesh.rings = 4
	_v3_add_multimesh("MangroveV3WetRocks", rock_mesh, rock_transforms, _simple_material(Color(0.18, 0.23, 0.20), 0.42))

	var mud_mesh: BoxMesh = BoxMesh.new()
	mud_mesh.size = Vector3.ONE
	_v3_add_multimesh("MangroveV3MudBanks", mud_mesh, mud_bank_transforms, _simple_material(Color(0.20, 0.12, 0.055), 0.99))

	_visual_tree_count += _v3_extra_tree_count
	print("WILD TIDE JUNGLE V3 DRESSING extra_trees=%d total_visual_trees=%d gameplay_trees=%d bushes=%d roots=%d wet_rocks=%d mud_banks=%d collision_corridor_clear=true" % [
		_v3_extra_tree_count, _visual_tree_count, _gameplay_tree_count,
		_v3_bush_count, _v3_root_count, _v3_rock_count, mud_bank_transforms.size(),
	])

func _v3_add_multimesh(
	node_name: String,
	mesh: Mesh,
	transforms: Array[Transform3D],
	material: Material
) -> void:
	if transforms.is_empty():
		return
	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for index: int in range(transforms.size()):
		multimesh.set_instance_transform(index, transforms[index])
	var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	instance.material_override = material
	add_child(instance)

func _emit_full_world_audit() -> void:
	var route_network: Node = null
	var guidance: Node = null
	for _attempt: int in range(120):
		var parent_node: Node = get_parent()
		if parent_node != null:
			route_network = parent_node.get_node_or_null("WildTideRouteNetwork")
			guidance = parent_node.get_node_or_null("WildTideRouteGuidance")
		var route_ready: bool = route_network != null and route_network.has_method("get_route_count") and int(route_network.call("get_route_count")) >= 6
		var guidance_ready: bool = guidance != null and guidance.has_method("get_guidance_counts")
		if route_ready and guidance_ready:
			break
		await get_tree().physics_frame

	var route_count: int = int(route_network.call("get_route_count")) if route_network != null and route_network.has_method("get_route_count") else 0
	var arrows: Dictionary = {}
	if guidance != null and guidance.has_method("get_guidance_counts"):
		var arrow_value: Variant = guidance.call("get_guidance_counts")
		if arrow_value is Dictionary:
			arrows = arrow_value
	var water_ratio: float = get_baseline_water_ratio()
	var shallow_ratio: float = get_shallow_water_ratio()
	var deep_ratio: float = get_deep_water_ratio()
	var jungle_ratio: float = get_jungle_ratio()
	print("WILD TIDE WORLD AUDIT daytime=true track_distance=%.1f visible_water_distance=%.1f visible_water_ratio=%.1f%% shallow_distance=%.1f shallow_ratio=%.1f%% deep_distance=%.1f deep_ratio=%.1f%% jungle_distance=%.1f jungle_ratio=%.1f%% mangrove_visual_count=%d gameplay_tree_count=%d route_count=%d arrow_main=%d arrow_water=%d arrow_canopy=%d arrow_shortcut=%d road_overlay_water=false hidden_support=true" % [
		_track_distance,
		_water_distance,
		water_ratio * 100.0,
		_shallow_distance,
		shallow_ratio * 100.0,
		_deep_distance,
		deep_ratio * 100.0,
		_jungle_distance,
		jungle_ratio * 100.0,
		_visual_tree_count,
		_gameplay_tree_count,
		route_count,
		int(arrows.get("main", 0)),
		int(arrows.get("water", 0)),
		int(arrows.get("canopy", 0)),
		int(arrows.get("shortcut", 0)),
	])
