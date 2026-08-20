extends Node

## SKY LOG FINALE visual-only environment dressing.
##
## Gameplay water, water Areas, recovery authority and route collision remain
## owned by the existing Round 3 systems. This helper only reads the authored
## Z6 water surface bounds and adds collision-free stylized environment meshes.

const FINALE_WATER_SURFACE_PATH := NodePath("CanopyRiver_Z6")
const FINALE_WATER_FALLBACK_CENTER := Vector3(0.0, 48.25, -720.0)
const FINALE_WATER_FALLBACK_SIZE := Vector2(100.0, 190.0)
const FINALE_ROUTE_CLEAR_WIDTH: float = 32.0
const FINALE_BANK_WIDTH: float = 9.0
const FINALE_BANK_HEIGHT: float = 7.0
const FINALE_NEAR_BANK_DEPTH: float = 7.0
const FINALE_WATERFALL_HEIGHT: float = 24.0
const FINALE_VOID_DEPTH: float = 17.0

var _root: Node
var _world: Node3D
var _water: Node3D
var _finale_visual_root: Node3D
var _river_center: Vector3 = FINALE_WATER_FALLBACK_CENTER
var _river_size: Vector2 = FINALE_WATER_FALLBACK_SIZE
var _built: bool = false

func _ready() -> void:
	call_deferred("_bootstrap")

func _bootstrap() -> void:
	# WaterRecovery builds its visual surface through its own deferred bootstrap.
	# Waiting two physics frames lets us bind to the real MeshInstance when it is
	# available while retaining authored fallback bounds for headless/QA loads.
	await get_tree().physics_frame
	await get_tree().physics_frame
	_root = get_parent()
	if _root == null:
		return
	_world = _root.get_node_or_null("LogspireWorld") as Node3D
	_water = _root.get_node_or_null("WaterRecovery") as Node3D
	if _world == null:
		push_warning("r3_finale_visual_init_skipped reason=missing_world")
		return
	_resolve_finale_water_bounds()
	_ensure_finale_visual_root()
	if _finale_visual_root == null:
		return
	_build_finale_visual_river_banks()
	_build_finale_visual_waterfalls()
	_build_finale_underwater_occluders()
	_build_finale_mist_cards()
	_built = true
	print("r3_finale_visual_route_clear corridor_width=%.1f collision_free=true finish_sightline=true" % FINALE_ROUTE_CLEAR_WIDTH)

func _resolve_finale_water_bounds() -> void:
	_river_center = FINALE_WATER_FALLBACK_CENTER
	_river_size = FINALE_WATER_FALLBACK_SIZE
	if _water == null:
		return
	var surface := _water.get_node_or_null(FINALE_WATER_SURFACE_PATH) as MeshInstance3D
	if surface == null:
		return
	var mesh := surface.mesh as BoxMesh
	if mesh == null:
		return
	_river_center = surface.global_position
	_river_size = Vector2(mesh.size.x, mesh.size.z)

func _ensure_finale_visual_root() -> void:
	if _finale_visual_root != null and is_instance_valid(_finale_visual_root):
		return
	var existing := _world.get_node_or_null("SkyFinaleVisualPolish") as Node3D
	if existing != null:
		_finale_visual_root = existing
		return
	_finale_visual_root = Node3D.new()
	_finale_visual_root.name = "SkyFinaleVisualPolish"
	_finale_visual_root.set_meta(&"visual_only", true)
	_finale_visual_root.set_meta(&"gameplay_collision", false)
	_world.add_child(_finale_visual_root)

func _build_finale_visual_river_banks() -> void:
	if _finale_visual_root == null or _finale_visual_root.has_node("RiverBankLeft"):
		return
	var bark := _make_visual_material(Color(0.25, 0.13, 0.055), 0.96)
	var soil := _make_visual_material(Color(0.22, 0.19, 0.09), 0.94)
	var half_x: float = _river_size.x * 0.5
	var half_z: float = _river_size.y * 0.5
	var side_x: float = half_x - FINALE_BANK_WIDTH * 0.5 + 0.8
	var side_y: float = _river_center.y - FINALE_BANK_HEIGHT * 0.5 + 0.55
	var bank_depth: float = _river_size.y + 6.0

	_add_visual_box(
		"RiverBankLeft",
		Vector3(_river_center.x - side_x, side_y, _river_center.z),
		Vector3(FINALE_BANK_WIDTH, FINALE_BANK_HEIGHT, bank_depth),
		bark
	)
	_add_visual_box(
		"RiverBankRight",
		Vector3(_river_center.x + side_x, side_y, _river_center.z),
		Vector3(FINALE_BANK_WIDTH, FINALE_BANK_HEIGHT, bank_depth),
		bark
	)

	# Mask the upstream sheet edge while leaving a wide central opening for the
	# Z6_START -> Z6_01 route. The two ledges read as root/soil river banks.
	var side_segment_width: float = maxf(8.0, (_river_size.x - FINALE_ROUTE_CLEAR_WIDTH) * 0.5)
	var near_z: float = _river_center.z + half_z - FINALE_NEAR_BANK_DEPTH * 0.5 + 0.8
	var near_x: float = FINALE_ROUTE_CLEAR_WIDTH * 0.5 + side_segment_width * 0.5
	for side: float in [-1.0, 1.0]:
		_add_visual_box(
			"RiverEntryBank_%s" % ("L" if side < 0.0 else "R"),
			Vector3(_river_center.x + near_x * side, _river_center.y - 1.8, near_z),
			Vector3(side_segment_width, 4.8, FINALE_NEAR_BANK_DEPTH),
			soil
		)

	print("r3_finale_visual_bank_added side_banks=2 entry_banks=2 edge_masked=true route_gap=%.1f" % FINALE_ROUTE_CLEAR_WIDTH)

func _build_finale_visual_waterfalls() -> void:
	if _finale_visual_root == null or _finale_visual_root.has_node("FinaleWaterfallMain"):
		return
	var half_z: float = _river_size.y * 0.5
	var far_z: float = _river_center.z - half_z - 0.12
	var fall_center_y: float = _river_center.y - FINALE_WATERFALL_HEIGHT * 0.5
	var waterfall_material := _make_visual_material(
		Color(0.10, 0.72, 0.78, 0.62),
		0.20,
		Color(0.015, 0.16, 0.18)
	)
	var highlight_material := _make_visual_material(
		Color(0.62, 0.93, 0.92, 0.25),
		0.16,
		Color(0.02, 0.08, 0.08)
	)

	_add_visual_quad(
		"FinaleWaterfallMain",
		Vector3(_river_center.x, fall_center_y, far_z),
		Vector2(maxf(24.0, _river_size.x - 10.0), FINALE_WATERFALL_HEIGHT),
		waterfall_material
	)

	# A few cheap brighter strips break up the single rectangle and make the fall
	# read as flowing water from long camera distances.
	var strip_offsets: Array[float] = [-0.30, -0.10, 0.13, 0.31]
	for i: int in range(strip_offsets.size()):
		_add_visual_quad(
			"FinaleWaterfallRibbon_%02d" % (i + 1),
			Vector3(
				_river_center.x + _river_size.x * strip_offsets[i],
				fall_center_y - 0.6 + float(i % 2) * 0.8,
				far_z + 0.07
			),
			Vector2(5.5 + float(i % 2) * 2.0, FINALE_WATERFALL_HEIGHT * 0.88),
			highlight_material
		)

	print("r3_finale_visual_waterfall_added edge=downstream height=%.1f ribbons=%d collision_free=true" % [
		FINALE_WATERFALL_HEIGHT, strip_offsets.size(),
	])

func _build_finale_underwater_occluders() -> void:
	if _finale_visual_root == null or _finale_visual_root.has_node("UnderRiverBarkShelf"):
		return
	var dark_bark := _make_visual_material(Color(0.12, 0.065, 0.028), 0.98)
	var root_bark := _make_visual_material(Color(0.30, 0.16, 0.06), 0.95)
	var shelf_y: float = _river_center.y - FINALE_VOID_DEPTH

	# A deep bark/soil shelf gives the transparent river visual mass without
	# touching the gameplay recovery deck or changing any WaterRecovery Area.
	_add_visual_box(
		"UnderRiverBarkShelf",
		Vector3(_river_center.x, shelf_y, _river_center.z + 2.0),
		Vector3(maxf(30.0, _river_size.x - 14.0), 5.0, maxf(40.0, _river_size.y - 18.0)),
		dark_bark
	)

	# Hanging giant roots stay far outside the playable center corridor and mask
	# side-angle void views beneath the elevated river.
	var root_x: float = maxf(FINALE_ROUTE_CLEAR_WIDTH * 0.5 + 12.0, _river_size.x * 0.36)
	var root_z_offsets: Array[float] = [-0.30, 0.02, 0.31]
	for side: float in [-1.0, 1.0]:
		for i: int in range(root_z_offsets.size()):
			var height: float = 12.5 + float(i) * 1.7
			_add_visual_root_column(
				"HangingRoot_%s_%02d" % [("L" if side < 0.0 else "R"), i + 1],
				Vector3(
					_river_center.x + root_x * side,
					_river_center.y - height * 0.5 - 1.0,
					_river_center.z + _river_size.y * root_z_offsets[i]
				),
				2.2 + float(i) * 0.35,
				height,
				root_bark
			)

	print("r3_finale_visual_void_mask_added bark_shelf=true hanging_roots=6 route_corridor_clear=true")

func _build_finale_mist_cards() -> void:
	if _finale_visual_root == null or _finale_visual_root.has_node("WaterfallBaseMist"):
		return
	var half_z: float = _river_size.y * 0.5
	var far_z: float = _river_center.z - half_z
	var mist_material := _make_visual_material(Color(0.78, 0.94, 0.91, 0.20), 0.38)
	var deep_mist_material := _make_visual_material(Color(0.43, 0.72, 0.69, 0.09), 0.42)

	_add_visual_plane(
		"WaterfallBaseMist",
		Vector3(_river_center.x, _river_center.y - FINALE_WATERFALL_HEIGHT + 1.0, far_z + 4.0),
		Vector2(maxf(24.0, _river_size.x - 18.0), 16.0),
		mist_material
	)
	_add_visual_plane(
		"UnderCanopyRiverMist",
		Vector3(_river_center.x, _river_center.y - 11.5, _river_center.z + 4.0),
		Vector2(maxf(30.0, _river_size.x - 12.0), maxf(50.0, _river_size.y - 30.0)),
		deep_mist_material
	)

	print("r3_finale_visual_mist_added cards=2 void_occlusion=true waterfall_splash=true")

func _add_visual_box(name_text: String, world_position: Vector3, size: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name_text
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	node.mesh = mesh
	_finale_visual_root.add_child(node)
	node.global_position = world_position
	_mark_visual_only(node)
	return node

func _add_visual_root_column(
	name_text: String,
	world_position: Vector3,
	radius: float,
	height: float,
	material: StandardMaterial3D
) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name_text
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.72
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.material = material
	node.mesh = mesh
	_finale_visual_root.add_child(node)
	node.global_position = world_position
	_mark_visual_only(node)
	return node

func _add_visual_quad(name_text: String, world_position: Vector3, size: Vector2, material: StandardMaterial3D) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name_text
	var mesh := QuadMesh.new()
	mesh.size = size
	mesh.material = material
	node.mesh = mesh
	_finale_visual_root.add_child(node)
	node.global_position = world_position
	_mark_visual_only(node)
	return node

func _add_visual_plane(name_text: String, world_position: Vector3, size: Vector2, material: StandardMaterial3D) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name_text
	var mesh := PlaneMesh.new()
	mesh.size = size
	mesh.material = material
	node.mesh = mesh
	_finale_visual_root.add_child(node)
	node.global_position = world_position
	_mark_visual_only(node)
	return node

func _mark_visual_only(node: MeshInstance3D) -> void:
	node.set_meta(&"visual_only", true)
	node.set_meta(&"gameplay_collision", false)

func _make_visual_material(
	color: Color,
	roughness: float,
	emission: Color = Color(0.0, 0.0, 0.0, 1.0)
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	if color.a < 0.999:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if emission.r > 0.0 or emission.g > 0.0 or emission.b > 0.0:
		material.emission_enabled = true
		material.emission = emission
	return material
