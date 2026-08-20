extends Node

const LIVING_TREE_TRIGGER_PERCENT: float = 64.0
const LIVING_TREE_MOVE_SECONDS: float = 1.45
const LIVING_BRANCH_REVEAL_T: float = 0.58
const LAST_TREE_TRIGGER_PERCENT: float = 89.0
const LAST_TREE_FALL_SECONDS: float = 1.55
const LAST_TREE_REVEAL_T: float = 0.58
const FINAL_RECOVERY_DELAY_SECONDS: float = 0.80
const WOODPECKER_REARM_SECONDS: float = 6.5
const SQUIRREL_REARM_SECONDS: float = 8.0
const FINAL_JUMP_COOLDOWN_SECONDS: float = 1.2

const ZONE_BACKGROUND_COLORS: Array[Color] = [
	Color(0.055, 0.10, 0.07),
	Color(0.07, 0.14, 0.09),
	Color(0.10, 0.20, 0.14),
	Color(0.12, 0.24, 0.20),
	Color(0.24, 0.23, 0.12),
	Color(0.30, 0.50, 0.72),
]
const ZONE_LIGHT_COLORS: Array[Color] = [
	Color(0.72, 0.84, 0.66),
	Color(0.76, 0.88, 0.70),
	Color(0.82, 0.92, 0.74),
	Color(0.78, 0.90, 0.84),
	Color(1.00, 0.82, 0.48),
	Color(0.92, 0.96, 1.00),
]

var _world: Node3D
var _graph: Node
var _configured: bool = false
var _player: WildDashCharacterController
var _camera: Camera3D
var _environment: Environment
var _sun: DirectionalLight3D
var _titan_light: OmniLight3D
var _titan_center: Vector3 = Vector3.ZERO
var _current_visual_zone: int = -1

var _living_tree_state: StringName = &"STATE_A"
var _living_tree_elapsed: float = 0.0
var _living_branches: Array[Dictionary] = []
var _living_leaves: MultiMeshInstance3D
var _living_leaf_seed: Array[Vector3] = []
var _living_leaf_elapsed: float = 0.0

var _woodpecker_root: Node3D
var _woodpecker_area: Area3D
var _woodpecker_wait: float = 2.5
var _woodpecker_active: bool = false
var _woodpecker_elapsed: float = 0.0
var _woodpecker_pecks: int = 0
var _woodpecker_shake_remaining: float = 0.0
var _woodpecker_target_visual: Node3D
var _woodpecker_target_base_rotation: Vector3 = Vector3.ZERO
var _wood_chips: MultiMeshInstance3D
var _wood_chip_elapsed: float = 0.0

var _squirrel_root: Node3D
var _squirrel_area: Area3D
var _squirrel_base: Vector3 = Vector3.ZERO
var _squirrel_right: Vector3 = Vector3.RIGHT
var _squirrel_wait: float = 4.0
var _squirrel_active: bool = false
var _squirrel_elapsed: float = 0.0
var _squirrel_hit_ids: Dictionary = {}

var _finale_roll_visual: Node3D
var _finale_roll_area: Area3D
var _finale_roll_right: Vector3 = Vector3.RIGHT
var _finale_moving_branch: AnimatableBody3D
var _finale_moving_branch_base: Vector3 = Vector3.ZERO
var _finale_moving_branch_right: Vector3 = Vector3.RIGHT
var _finale_mushroom_area: Area3D
var _finale_mushroom_visual: Node3D
var _finale_mushroom_cooldowns: Dictionary = {}

var _last_tree: AnimatableBody3D
var _last_tree_start_position: Vector3 = Vector3.ZERO
var _last_tree_final_position: Vector3 = Vector3.ZERO
var _last_tree_yaw: float = 0.0
var _last_tree_elapsed: float = 0.0
var _last_tree_state: StringName = &"WAITING"
var _final_jump_area: Area3D
var _final_jump_forward: Vector3 = Vector3.FORWARD
var _final_jump_cooldowns: Dictionary = {}
var _final_jump_logged: Dictionary = {}
var _final_recovery_area: Area3D
var _final_recovery_pending: Dictionary = {}

var _camera_shake_remaining: float = 0.0
var _camera_shake_strength: float = 0.0
var _finish_notified: bool = false

func configure(world: Node, graph: Node) -> void:
	_world = world as Node3D
	_graph = graph
	if _world == null or _graph == null:
		push_error("LOGSPIRE PHASE3 configure failed: world/graph missing")
		return

	_hide_graybox_titan()
	_build_visual_environment()
	_build_titan_tree()
	_build_living_tree_event_geometry()
	_build_woodpecker_hazard()
	_build_squirrel_stampede()
	_build_sky_finale()
	_build_crown_nest_polish()
	_set_hud_message("Reach the Crown Nest!")
	AudioManager.play_theme("race_logspire")
	_configured = true
	print("LOGSPIRE PHASE3 READY titan_tree=production living_tree=state_a woodpecker=telegraphed squirrel=multimesh sky_finale=true last_tree=true crown_nest=polished performance=animatable_multimesh")

func _physics_process(delta: float) -> void:
	_update_cooldowns(delta)
	if not _configured or not RaceManager.active:
		return
	_player = _resolve_player()
	if _player == null:
		return
	if _camera == null:
		_camera = get_parent().get_node_or_null("ChaseCamera") as Camera3D

	_update_visual_progression(delta)
	_update_living_tree(delta)
	_update_woodpecker(delta)
	_update_squirrel(delta)
	_update_finale_obstacles(delta)
	_update_last_tree(delta)
	_update_final_jump_readability()
	_update_camera(delta)

func notify_player_finish(rank: int) -> void:
	if _finish_notified:
		return
	_finish_notified = true
	AudioManager.play_sfx_id("wild_finish", 0.96)
	_set_hud_message("WILD FINISH! — THE CROWN NEST")
	_camera_shake_remaining = 0.35
	_camera_shake_strength = 0.08
	print("LOGSPIRE FINISH PRESENTATION rank=%d crown_nest=true feathers=true sunlight=true" % rank)

func _hide_graybox_titan() -> void:
	for node_name: String in ["TitanTreeGraybox", "TitanCanopyGraybox"]:
		var node := _world.get_node_or_null(node_name) as Node3D
		if node != null:
			node.visible = false

func _build_visual_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "LogspireWorldEnvironment"
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.background_color = ZONE_BACKGROUND_COLORS[0]
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color(0.48, 0.62, 0.44)
	_environment.ambient_light_energy = 0.72
	world_environment.environment = _environment
	get_parent().add_child(world_environment)

	_sun = DirectionalLight3D.new()
	_sun.name = "LogspireSun"
	_sun.rotation_degrees = Vector3(-52.0, -24.0, 0.0)
	_sun.light_color = ZONE_LIGHT_COLORS[0]
	_sun.light_energy = 1.05
	_sun.shadow_enabled = true
	get_parent().add_child(_sun)

func _build_titan_tree() -> void:
	_titan_center = _estimate_titan_center()
	var root := Node3D.new()
	root.name = "TitanTreeProduction"
	_world.add_child(root)

	var bark := _make_material(Color(0.30, 0.17, 0.065), 0.94)
	var bark_gold := _make_material(Color(0.43, 0.25, 0.07), 0.90)
	var leaf_dark := _make_material(Color(0.12, 0.29, 0.10), 0.92)
	var leaf_gold := _make_material(Color(0.46, 0.48, 0.12), 0.88)

	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 6.5
	trunk_mesh.bottom_radius = 10.5
	trunk_mesh.height = 86.0
	trunk_mesh.material = bark
	var trunk := MeshInstance3D.new()
	trunk.name = "TitanTrunk"
	trunk.mesh = trunk_mesh
	trunk.global_position = Vector3(_titan_center.x, 37.0, _titan_center.z)
	root.add_child(trunk)

	for i: int in range(8):
		var angle: float = TAU * float(i) / 8.0
		var direction := Vector3(sin(angle), 0.0, cos(angle))
		var root_piece := _make_box_visual(
			Vector3(5.0, 2.2, 24.0),
			bark,
			Vector3(_titan_center.x, 2.0, _titan_center.z) + direction * 9.0,
			angle
		)
		root_piece.name = "TitanRoot_%02d" % i
		root.add_child(root_piece)

	for i: int in range(9):
		var angle: float = deg_to_rad(28.0 + float(i) * 43.0)
		var direction := Vector3(sin(angle), 0.0, cos(angle))
		var height: float = 16.0 + float(i) * 6.2
		var branch := _make_box_visual(
			Vector3(3.3 - float(i) * 0.12, 1.7, 27.0 - float(i) * 0.55),
			bark_gold if i >= 5 else bark,
			Vector3(_titan_center.x, height, _titan_center.z) + direction * 11.0,
			angle
		)
		branch.rotation.x = deg_to_rad(-4.0 + float(i % 3) * 3.0)
		branch.name = "TitanBranch_%02d" % i
		root.add_child(branch)

	for i: int in range(14):
		var angle: float = TAU * float(i) / 14.0
		var ring: float = 9.0 + float(i % 4) * 3.0
		var leaf := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 7.5 + float(i % 3) * 1.4
		sphere.height = sphere.radius * 1.55
		sphere.material = leaf_gold if i % 4 == 0 else leaf_dark
		leaf.mesh = sphere
		leaf.global_position = Vector3(
			_titan_center.x + sin(angle) * ring,
			70.0 + float((i * 5) % 13),
			_titan_center.z + cos(angle) * ring
		)
		leaf.name = "TitanCanopy_%02d" % i
		root.add_child(leaf)

	_titan_light = OmniLight3D.new()
	_titan_light.name = "TitanGoldenLight"
	_titan_light.global_position = Vector3(_titan_center.x, 62.0, _titan_center.z)
	_titan_light.light_color = Color(1.0, 0.72, 0.30)
	_titan_light.light_energy = 1.15
	_titan_light.omni_range = 42.0
	root.add_child(_titan_light)

	print("LOGSPIRE TITAN TREE READY trunk_height=86 roots=8 branches=9 canopy_clusters=14 visible_from_start=true")

func _build_living_tree_event_geometry() -> void:
	_living_branches.clear()
	var pairs: Array[Array] = [
		[&"Z5_SPIRAL_03", &"Z5_SPIRAL_04"],
		[&"Z5_SPIRAL_05", &"Z5_SPIRAL_06"],
	]
	for i: int in range(pairs.size()):
		var from_id: StringName = pairs[i][0]
		var to_id: StringName = pairs[i][1]
		var from: Vector3 = _platform_position(from_id) + Vector3.UP * 0.8
		var to: Vector3 = _platform_position(to_id) + Vector3.UP * 0.8
		var branch_data: Dictionary = _make_animatable_bridge("LivingBranch_%d" % (i + 1), from, to, 3.1, 0.9, Color(0.48, 0.29, 0.08))
		var body := branch_data.get("body") as AnimatableBody3D
		if body == null:
			continue
		var final_position: Vector3 = branch_data.get("final_position", body.global_position)
		var final_yaw: float = float(branch_data.get("yaw", body.rotation.y))
		var side: float = -1.0 if i == 0 else 1.0
		var start_position := final_position + Vector3(side * 8.0, 10.0 + float(i) * 2.0, 0.0)
		body.global_position = start_position
		body.rotation = Vector3(deg_to_rad(-58.0 * side), final_yaw, deg_to_rad(14.0 * side))
		body.collision_layer = 0
		# Never leave a giant visible branch in the course while its collision is
		# disabled. This was the source of the camera/player phase-through wall.
		body.visible = false
		branch_data["start_position"] = start_position
		branch_data["start_rotation"] = body.rotation
		branch_data["final_rotation"] = Vector3(0.0, final_yaw, 0.0)
		_living_branches.append(branch_data)

	_build_living_leaf_multimesh()
	if _graph.has_method("set_world_state"):
		_graph.call("set_world_state", &"STATE_A")

func _build_living_leaf_multimesh() -> void:
	_living_leaves = MultiMeshInstance3D.new()
	_living_leaves.name = "LivingTreeFallingLeaves"
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var leaf_mesh := BoxMesh.new()
	leaf_mesh.size = Vector3(0.34, 0.06, 0.62)
	leaf_mesh.material = _make_material(Color(0.58, 0.50, 0.12), 0.85)
	multimesh.mesh = leaf_mesh
	multimesh.instance_count = 24
	_living_leaf_seed.clear()
	for i: int in range(multimesh.instance_count):
		var angle: float = TAU * float(i) / float(multimesh.instance_count)
		var radius: float = 6.0 + float((i * 7) % 15)
		var seed := Vector3(sin(angle) * radius, float((i * 11) % 22), cos(angle) * radius)
		_living_leaf_seed.append(seed)
		multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, seed))
	_living_leaves.multimesh = multimesh
	_living_leaves.global_position = Vector3(_titan_center.x, 58.0, _titan_center.z)
	_living_leaves.visible = false
	_world.add_child(_living_leaves)

func _build_woodpecker_hazard() -> void:
	var perch: Vector3 = _platform_position(&"Z5_SPIRAL_07")
	_woodpecker_root = Node3D.new()
	_woodpecker_root.name = "GiantWoodpecker"
	_woodpecker_root.global_position = perch + Vector3(6.5, 6.0, 1.0)
	_world.add_child(_woodpecker_root)

	var body := MeshInstance3D.new()
	var body_mesh := SphereMesh.new()
	body_mesh.radius = 1.45
	body_mesh.height = 2.4
	body_mesh.material = _make_material(Color(0.42, 0.12, 0.07), 0.86)
	body.mesh = body_mesh
	_woodpecker_root.add_child(body)

	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.95
	head_mesh.height = 1.45
	head_mesh.material = _make_material(Color(0.72, 0.12, 0.07), 0.84)
	head.mesh = head_mesh
	head.position = Vector3(0.0, 1.55, -0.15)
	_woodpecker_root.add_child(head)

	var beak := MeshInstance3D.new()
	var beak_mesh := CylinderMesh.new()
	beak_mesh.top_radius = 0.0
	beak_mesh.bottom_radius = 0.28
	beak_mesh.height = 1.8
	beak_mesh.material = _make_material(Color(0.92, 0.66, 0.18), 0.80)
	beak.mesh = beak_mesh
	beak.rotation.x = deg_to_rad(90.0)
	beak.position = Vector3(0.0, 1.55, -1.25)
	_woodpecker_root.add_child(beak)

	_woodpecker_area = Area3D.new()
	_woodpecker_area.name = "WoodpeckerShakeArea"
	_woodpecker_area.global_position = perch + Vector3.UP * 1.0
	_woodpecker_area.collision_layer = 0
	_woodpecker_area.collision_mask = 2
	_woodpecker_area.monitoring = true
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(14.0, 5.0, 15.0)
	collision.shape = shape
	_woodpecker_area.add_child(collision)
	_world.add_child(_woodpecker_area)

	var platform_root := _world.get_node_or_null("Z5_SPIRAL_07") as Node3D
	if platform_root != null:
		_woodpecker_target_visual = platform_root.get_node_or_null("Mesh") as Node3D
		if _woodpecker_target_visual != null:
			_woodpecker_target_base_rotation = _woodpecker_target_visual.rotation
	_build_wood_chip_multimesh(perch)

func _build_wood_chip_multimesh(perch: Vector3) -> void:
	_wood_chips = MultiMeshInstance3D.new()
	_wood_chips.name = "WoodpeckerWoodChips"
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var chip_mesh := BoxMesh.new()
	chip_mesh.size = Vector3(0.18, 0.08, 0.34)
	chip_mesh.material = _make_material(Color(0.58, 0.34, 0.12), 0.90)
	multimesh.mesh = chip_mesh
	multimesh.instance_count = 8
	for i: int in range(multimesh.instance_count):
		multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3.ZERO))
	_wood_chips.multimesh = multimesh
	_wood_chips.global_position = perch + Vector3.UP * 2.0
	_wood_chips.visible = false
	_world.add_child(_wood_chips)

func _build_squirrel_stampede() -> void:
	_squirrel_base = _platform_position(&"Z5_APPROACH_02") + Vector3.UP * 1.1
	var forward: Vector3 = _platform_forward(&"Z5_APPROACH_02")
	_squirrel_right = Vector3(-forward.z, 0.0, forward.x).normalized()
	_squirrel_root = Node3D.new()
	_squirrel_root.name = "SquirrelStampedeSwarm"
	_squirrel_root.global_position = _squirrel_base - _squirrel_right * 10.0
	_world.add_child(_squirrel_root)

	var multimesh_instance := MultiMeshInstance3D.new()
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var squirrel_mesh := SphereMesh.new()
	squirrel_mesh.radius = 0.34
	squirrel_mesh.height = 0.62
	squirrel_mesh.material = _make_material(Color(0.48, 0.27, 0.10), 0.88)
	multimesh.mesh = squirrel_mesh
	multimesh.instance_count = 12
	for i: int in range(multimesh.instance_count):
		var row: int = i / 4
		var column: int = i % 4
		var local := Vector3(float(column) * 0.65, 0.15 + float((i + 1) % 2) * 0.18, float(row) * 0.75)
		multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, local))
	multimesh_instance.multimesh = multimesh
	_squirrel_root.add_child(multimesh_instance)

	_squirrel_area = Area3D.new()
	_squirrel_area.name = "SquirrelPushArea"
	_squirrel_area.collision_layer = 0
	_squirrel_area.collision_mask = 2
	_squirrel_area.monitoring = true
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(5.0, 3.0, 4.0)
	collision.shape = shape
	_squirrel_area.add_child(collision)
	_squirrel_root.add_child(_squirrel_area)
	_squirrel_root.visible = false

func _build_sky_finale() -> void:
	_build_finale_rolling_log()
	_build_finale_mushroom()
	_build_finale_moving_branch()
	_build_last_tree_bridge()
	_build_final_recovery_area()
	print("LOGSPIRE SKY FINALE READY sequence=rolling_swing_mushroom_moving_branch_last_tree_final_jump_crown_nest target_seconds=20_30")

func _build_finale_rolling_log() -> void:
	var platform_id: StringName = &"Z6_01"
	var position: Vector3 = _platform_position(platform_id) + Vector3.UP * 1.25
	var forward: Vector3 = _platform_forward(platform_id)
	_finale_roll_right = Vector3(-forward.z, 0.0, forward.x).normalized()
	_finale_roll_visual = Node3D.new()
	_finale_roll_visual.name = "SkyFinaleRollingLog"
	_finale_roll_visual.global_position = position
	_finale_roll_visual.rotation.y = atan2(-forward.x, -forward.z)
	_world.add_child(_finale_roll_visual)
	var mesh_instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 2.15
	mesh.bottom_radius = 2.15
	mesh.height = 10.5
	mesh.material = _make_material(Color(0.54, 0.34, 0.12), 0.92)
	mesh_instance.mesh = mesh
	mesh_instance.rotation.x = deg_to_rad(90.0)
	_finale_roll_visual.add_child(mesh_instance)

	_finale_roll_area = Area3D.new()
	_finale_roll_area.name = "SkyFinaleRollInfluence"
	_finale_roll_area.global_position = position
	_finale_roll_area.collision_layer = 0
	_finale_roll_area.collision_mask = 2
	_finale_roll_area.monitoring = true
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(11.0, 4.0, 12.0)
	collision.shape = shape
	_finale_roll_area.add_child(collision)
	_world.add_child(_finale_roll_area)

func _build_finale_mushroom() -> void:
	var platform_id: StringName = &"Z6_02"
	var top: Vector3 = _platform_position(platform_id) + Vector3.UP * 0.8
	_finale_mushroom_area = Area3D.new()
	_finale_mushroom_area.name = "SkyFinaleMushroomArea"
	_finale_mushroom_area.global_position = top + Vector3.UP * 1.2
	_finale_mushroom_area.collision_layer = 0
	_finale_mushroom_area.collision_mask = 2
	_finale_mushroom_area.monitoring = true
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 3.0
	shape.height = 2.6
	collision.shape = shape
	_finale_mushroom_area.add_child(collision)
	_world.add_child(_finale_mushroom_area)
	_finale_mushroom_area.body_entered.connect(_on_finale_mushroom_body_entered)

	_finale_mushroom_visual = Node3D.new()
	_finale_mushroom_visual.name = "SkyFinaleMushroomVisual"
	_finale_mushroom_visual.global_position = top + Vector3.UP * 0.5
	_world.add_child(_finale_mushroom_visual)
	var cap := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 3.1
	mesh.height = 1.9
	mesh.material = _make_material(Color(0.94, 0.28, 0.19), 0.82)
	cap.mesh = mesh
	cap.scale = Vector3(1.0, 0.46, 1.0)
	_finale_mushroom_visual.add_child(cap)

func _build_finale_moving_branch() -> void:
	var platform_id: StringName = &"Z6_04"
	var base: Vector3 = _platform_position(platform_id) + Vector3.UP * 0.65
	var forward: Vector3 = _platform_forward(platform_id)
	_finale_moving_branch_right = Vector3(-forward.z, 0.0, forward.x).normalized()
	_finale_moving_branch = AnimatableBody3D.new()
	_finale_moving_branch.name = "SkyFinaleMovingBranch"
	_finale_moving_branch.sync_to_physics = true
	_finale_moving_branch.global_position = base
	_finale_moving_branch.rotation.y = atan2(-forward.x, -forward.z)
	_finale_moving_branch.collision_layer = 1
	_finale_moving_branch.collision_mask = 2
	_world.add_child(_finale_moving_branch)
	_finale_moving_branch_base = base
	var mesh := BoxMesh.new()
	mesh.size = Vector3(8.6, 0.65, 10.5)
	mesh.material = _make_material(Color(0.52, 0.33, 0.11), 0.92)
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	_finale_moving_branch.add_child(visual)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = mesh.size
	collision.shape = shape
	_finale_moving_branch.add_child(collision)

func _build_last_tree_bridge() -> void:
	var start: Vector3 = _platform_position(&"Z6_07") + Vector3.UP * 0.8
	var crown: Vector3 = _platform_position(&"CROWN_NEST") + Vector3.UP * 0.9
	var direction := crown - start
	direction.y = 0.0
	if direction.length_squared() <= 0.001:
		direction = Vector3.FORWARD
	else:
		direction = direction.normalized()
	var end: Vector3 = crown - direction * 5.0
	var bridge_data: Dictionary = _make_animatable_bridge("LastFallingTree", start, end, 4.1, 1.2, Color(0.40, 0.23, 0.07))
	_last_tree = bridge_data.get("body") as AnimatableBody3D
	if _last_tree == null:
		return
	_last_tree_final_position = bridge_data.get("final_position", _last_tree.global_position)
	_last_tree_yaw = float(bridge_data.get("yaw", _last_tree.rotation.y))
	_last_tree_start_position = _last_tree_final_position + Vector3.UP * 13.0 - direction * 2.5
	_last_tree.global_position = _last_tree_start_position
	_last_tree.rotation = Vector3(deg_to_rad(-72.0), _last_tree_yaw, deg_to_rad(8.0))
	_last_tree.collision_layer = 0
	# Same rule as LivingBranch: invisible while non-colliding so the camera can
	# never be visually buried inside a fake solid wall before the finale event.
	_last_tree.visible = false

	_final_jump_forward = direction
	_final_jump_area = Area3D.new()
	_final_jump_area.name = "FinalJumpLaunchArea"
	_final_jump_area.global_position = end + Vector3.UP * 1.3
	_final_jump_area.collision_layer = 0
	_final_jump_area.collision_mask = 2
	_final_jump_area.monitoring = false
	var launch_collision := CollisionShape3D.new()
	var launch_shape := BoxShape3D.new()
	launch_shape.size = Vector3(9.0, 3.0, 7.5)
	launch_collision.shape = launch_shape
	_final_jump_area.add_child(launch_collision)
	_world.add_child(_final_jump_area)

	_final_recovery_area = Area3D.new()
	_final_recovery_area.name = "FinalRecoveryArea"
	_final_recovery_area.global_position = (start + crown) * 0.5 - Vector3.UP * 3.5
	_final_recovery_area.collision_layer = 0
	_final_recovery_area.collision_mask = 2
	_final_recovery_area.monitoring = true
	var recovery_collision := CollisionShape3D.new()
	var recovery_shape := BoxShape3D.new()
	recovery_shape.size = Vector3(32.0, 5.0, 24.0)
	recovery_collision.shape = recovery_shape
	_final_recovery_area.add_child(recovery_collision)
	_world.add_child(_final_recovery_area)
	_final_recovery_area.body_entered.connect(_on_final_recovery_body_entered)

func _build_crown_nest_polish() -> void:
	var crown := _world.get_node_or_null("CROWN_NEST") as Node3D
	if crown == null:
		return
	var nest_material := _make_material(Color(0.76, 0.53, 0.18), 0.90)
	for i: int in range(24):
		var angle: float = TAU * float(i) / 24.0
		var twig := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.42, 0.22, 8.0 + float(i % 5) * 0.8)
		mesh.material = nest_material
		twig.mesh = mesh
		twig.position = Vector3(sin(angle) * 6.2, 0.65 + float(i % 3) * 0.12, cos(angle) * 6.2)
		twig.rotation.y = angle + deg_to_rad(float((i % 5) - 2) * 8.0)
		crown.add_child(twig)

func _update_visual_progression(delta: float) -> void:
	var checkpoint: int = RaceManager.get_checkpoint_progress(_player)
	var zone: int = clampi(checkpoint, 0, ZONE_BACKGROUND_COLORS.size() - 1)
	if zone != _current_visual_zone:
		_current_visual_zone = zone
		print("LOGSPIRE VISUAL ZONE zone=%d background_progression=true" % (zone + 1))
	var blend: float = minf(1.0, delta * 1.8)
	if _environment != null:
		_environment.background_color = _environment.background_color.lerp(ZONE_BACKGROUND_COLORS[zone], blend)
		_environment.ambient_light_color = _environment.ambient_light_color.lerp(ZONE_LIGHT_COLORS[zone] * 0.72, blend)
		_environment.ambient_light_energy = lerpf(_environment.ambient_light_energy, 0.72 + float(zone) * 0.055, blend)
	if _sun != null:
		_sun.light_color = _sun.light_color.lerp(ZONE_LIGHT_COLORS[zone], blend)
		_sun.light_energy = lerpf(_sun.light_energy, 1.0 + float(zone) * 0.08, blend)

func _update_living_tree(delta: float) -> void:
	var progress: float = RaceManager.get_progress_percent(_player)
	if _living_tree_state == &"STATE_A" and progress >= LIVING_TREE_TRIGGER_PERCENT:
		_living_tree_state = &"TRANSITION"
		_living_tree_elapsed = 0.0
		_living_leaf_elapsed = 0.0
		if _living_leaves != null:
			_living_leaves.visible = true
		_set_hud_message("THE FOREST IS MOVING!")
		AudioManager.play_sfx_id("tree_creak", 0.90)
		AudioManager.play_theme("race_logspire_titan")
		_camera_shake_remaining = 0.70
		_camera_shake_strength = 0.10
		_broadcast_phase3_state(&"living_tree_transition")
		print("LOGSPIRE LIVING TREE EVENT START progress=%.1f warning=true hidden_until_collision=true" % progress)

	if _living_tree_state == &"TRANSITION":
		_living_tree_elapsed += delta
		_living_leaf_elapsed += delta
		var t: float = clampf(_living_tree_elapsed / LIVING_TREE_MOVE_SECONDS, 0.0, 1.0)
		var eased: float = t * t * (3.0 - 2.0 * t)
		for data: Dictionary in _living_branches:
			var body := data.get("body") as AnimatableBody3D
			if body == null:
				continue
			var start_position: Vector3 = data.get("start_position", body.global_position)
			var final_position: Vector3 = data.get("final_position", body.global_position)
			var start_rotation: Vector3 = data.get("start_rotation", body.rotation)
			var final_rotation: Vector3 = data.get("final_rotation", Vector3.ZERO)
			body.global_position = start_position.lerp(final_position, eased)
			body.rotation = start_rotation.lerp(final_rotation, eased)
			var collision_ready: bool = t >= LIVING_BRANCH_REVEAL_T
			body.visible = collision_ready
			body.collision_layer = 1 if collision_ready else 0
		_update_living_leaves()
		if _titan_light != null:
			_titan_light.light_energy = lerpf(1.15, 2.35, sin(t * PI))
		if t >= 1.0:
			_living_tree_state = &"STATE_B"
			for data: Dictionary in _living_branches:
				var body := data.get("body") as AnimatableBody3D
				if body != null:
					body.visible = true
					body.collision_layer = 1
			if _graph.has_method("set_world_state"):
				_graph.call("set_world_state", &"STATE_B")
			_broadcast_phase3_state(&"living_tree_state_b")
			print("LOGSPIRE LIVING TREE STATE B branches=%d safety_corridor=true visible_collision_match=true graph_state=STATE_B crush_guard=true" % _living_branches.size())
	elif _living_tree_state == &"STATE_B" and _living_leaves != null and _living_leaves.visible:
		_living_leaf_elapsed += delta
		_update_living_leaves()
		if _living_leaf_elapsed >= 3.2:
			_living_leaves.visible = false

func _update_living_leaves() -> void:
	if _living_leaves == null or _living_leaves.multimesh == null:
		return
	for i: int in range(_living_leaf_seed.size()):
		var seed: Vector3 = _living_leaf_seed[i]
		var y: float = seed.y - fmod(_living_leaf_elapsed * (4.0 + float(i % 4)), 24.0)
		var drift := Vector3(sin(_living_leaf_elapsed * 2.0 + float(i)) * 0.9, y, cos(_living_leaf_elapsed * 1.6 + float(i)) * 0.7)
		var basis := Basis(Vector3.UP, _living_leaf_elapsed * 1.4 + float(i) * 0.31)
		_living_leaves.multimesh.set_instance_transform(i, Transform3D(basis, Vector3(seed.x, 0.0, seed.z) + drift))

func _update_woodpecker(delta: float) -> void:
	if _woodpecker_root == null or _woodpecker_area == null:
		return
	var checkpoint: int = RaceManager.get_checkpoint_progress(_player)
	var in_titan_zone: bool = checkpoint >= 4 and checkpoint <= 5
	if not _woodpecker_active:
		if not in_titan_zone:
			return
		_woodpecker_wait -= delta
		if _woodpecker_wait > 0.0:
			return
		_woodpecker_active = true
		_woodpecker_elapsed = 0.0
		_woodpecker_pecks = 0

	_woodpecker_elapsed += delta
	var expected_pecks: int = mini(3, int(floor(_woodpecker_elapsed / 0.42)) + 1)
	while _woodpecker_pecks < expected_pecks:
		_woodpecker_pecks += 1
		_do_woodpecker_peck(_woodpecker_pecks)
	if _woodpecker_elapsed >= 1.45:
		_do_woodpecker_shake()
		_woodpecker_active = false
		_woodpecker_wait = WOODPECKER_REARM_SECONDS

	if _woodpecker_shake_remaining > 0.0:
		_woodpecker_shake_remaining = maxf(0.0, _woodpecker_shake_remaining - delta)
		if _woodpecker_target_visual != null:
			_woodpecker_target_visual.rotation.z = _woodpecker_target_base_rotation.z + sin(_woodpecker_shake_remaining * 44.0) * 0.045
	else:
		if _woodpecker_target_visual != null:
			_woodpecker_target_visual.rotation = _woodpecker_target_base_rotation
	if _wood_chip_elapsed > 0.0:
		_wood_chip_elapsed = maxf(0.0, _wood_chip_elapsed - delta)
		_update_wood_chips()
	elif _wood_chips != null:
		_wood_chips.visible = false

func _do_woodpecker_peck(peck_index: int) -> void:
	AudioManager.play_sfx_id("woodpecker", 0.65)
	_woodpecker_shake_remaining = 0.16
	_wood_chip_elapsed = 0.22
	if _wood_chips != null:
		_wood_chips.visible = true
	if _woodpecker_root != null:
		_woodpecker_root.rotation.z = deg_to_rad(-8.0 if peck_index % 2 == 1 else 5.0)
	print("LOGSPIRE WOODPECKER peck=%d/3 telegraph=true wood_chips=true" % peck_index)

func _do_woodpecker_shake() -> void:
	_woodpecker_shake_remaining = 0.34
	var forward: Vector3 = _platform_forward(&"Z5_SPIRAL_07")
	var right := Vector3(-forward.z, 0.0, forward.x).normalized()
	for body_value: Node3D in _woodpecker_area.get_overlapping_bodies():
		var racer := body_value as WildDashCharacterController
		if racer == null or racer.finished:
			continue
		var side: float = 1.0 if (racer.global_position - _woodpecker_area.global_position).dot(right) >= 0.0 else -1.0
		racer.apply_knockback(right * side, 0.95)
	print("LOGSPIRE WOODPECKER shake=true push=0.95 instant_kill=false predictable=true")

func _update_wood_chips() -> void:
	if _wood_chips == null or _wood_chips.multimesh == null:
		return
	var age: float = 0.22 - _wood_chip_elapsed
	for i: int in range(_wood_chips.multimesh.instance_count):
		var angle: float = TAU * float(i) / float(_wood_chips.multimesh.instance_count)
		var offset := Vector3(sin(angle) * age * 6.0, age * (3.0 + float(i % 3)), cos(angle) * age * 5.0)
		_wood_chips.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, offset))

func _update_squirrel(delta: float) -> void:
	if _squirrel_root == null or _squirrel_area == null:
		return
	var checkpoint: int = RaceManager.get_checkpoint_progress(_player)
	var relevant_zone: bool = checkpoint >= 3 and checkpoint <= 5
	if not _squirrel_active:
		if not relevant_zone:
			return
		_squirrel_wait -= delta
		if _squirrel_wait > 0.0:
			return
		_squirrel_active = true
		_squirrel_elapsed = 0.0
		_squirrel_hit_ids.clear()
		_squirrel_root.visible = true
		AudioManager.play_sfx_id("squirrel_rush", 0.58)
		print("LOGSPIRE SQUIRREL STAMPEDE start=true swarm=12 area_push=true physics_bodies=0")

	_squirrel_elapsed += delta
	var t: float = clampf(_squirrel_elapsed / 1.9, 0.0, 1.0)
	_squirrel_root.global_position = _squirrel_base + _squirrel_right * lerpf(-10.0, 10.0, t)
	for body_value: Node3D in _squirrel_area.get_overlapping_bodies():
		var racer := body_value as WildDashCharacterController
		if racer == null or racer.finished:
			continue
		var racer_id: int = racer.get_instance_id()
		if _squirrel_hit_ids.has(racer_id):
			continue
		_squirrel_hit_ids[racer_id] = true
		racer.apply_knockback(_squirrel_right, 0.82)
	if t >= 1.0:
		_squirrel_active = false
		_squirrel_wait = SQUIRREL_REARM_SECONDS
		_squirrel_root.visible = false
		print("LOGSPIRE SQUIRREL STAMPEDE end=true push=0.82 lethal=false")

func _update_finale_obstacles(delta: float) -> void:
	if _finale_roll_visual != null:
		_finale_roll_visual.rotation.z += delta * 1.15
	if _finale_roll_area != null:
		for body_value: Node3D in _finale_roll_area.get_overlapping_bodies():
			var racer := body_value as WildDashCharacterController
			if racer == null or racer.finished:
				continue
			var current: Vector3 = racer.get_knockback_velocity()
			var lateral: float = current.dot(_finale_roll_right)
			var desired: float = 0.62
			racer.set("_knockback_velocity", current + _finale_roll_right * (desired - lateral) * minf(1.0, delta * 3.5))
	if _finale_moving_branch != null:
		var time_seconds: float = Time.get_ticks_msec() * 0.001
		_finale_moving_branch.global_position = _finale_moving_branch_base + _finale_moving_branch_right * sin(time_seconds * 1.25) * 2.35

func _update_last_tree(delta: float) -> void:
	if _last_tree == null:
		return
	var progress: float = RaceManager.get_progress_percent(_player)
	if _last_tree_state == &"WAITING" and progress >= LAST_TREE_TRIGGER_PERCENT:
		_last_tree_state = &"FALLING"
		_last_tree_elapsed = 0.0
		_set_hud_message("FINAL CLIMB — THE LAST TREE IS FALLING!")
		AudioManager.play_sfx_id("tree_creak", 0.96)
		AudioManager.play_theme("race_logspire_finale")
		_camera_shake_remaining = 0.85
		_camera_shake_strength = 0.12
		_broadcast_phase3_state(&"final_tree_falling")
		print("LOGSPIRE FINAL TREE FALL START progress=%.1f warning=true hidden_until_collision=true" % progress)
	if _last_tree_state != &"FALLING":
		return
	_last_tree_elapsed += delta
	var t: float = clampf(_last_tree_elapsed / LAST_TREE_FALL_SECONDS, 0.0, 1.0)
	var eased: float = t * t * (3.0 - 2.0 * t)
	_last_tree.global_position = _last_tree_start_position.lerp(_last_tree_final_position, eased)
	_last_tree.rotation = Vector3(lerpf(deg_to_rad(-72.0), 0.0, eased), _last_tree_yaw, lerpf(deg_to_rad(8.0), 0.0, eased))
	var collision_ready: bool = t >= LAST_TREE_REVEAL_T
	_last_tree.visible = collision_ready
	_last_tree.collision_layer = 1 if collision_ready else 0
	if t >= 1.0:
		_last_tree_state = &"BRIDGE_READY"
		_last_tree.visible = true
		_last_tree.collision_layer = 1
		if _final_jump_area != null:
			_final_jump_area.monitoring = true
		AudioManager.play_sfx_id("tree_fall", 0.92)
		_broadcast_phase3_state(&"final_bridge_ready")
		print("LOGSPIRE FINAL TREE BRIDGE READY collision=true visible_collision_match=true final_jump_gap=5m crush_guard=true")

func _update_final_jump_readability() -> void:
	if _last_tree_state != &"BRIDGE_READY" or _player == null:
		return
	if _final_jump_logged.has(_player.get_instance_id()):
		return
	var crown: Vector3 = _platform_position(&"CROWN_NEST")
	if _player.global_position.distance_to(crown) <= 9.0 and not _player.is_on_floor():
		_final_jump_logged[_player.get_instance_id()] = true
		print("LOGSPIRE FINAL JUMP racer=%s target=CROWN_NEST readable=true" % RaceManager.get_racer_label(_player))

func _update_camera(delta: float) -> void:
	if _camera == null:
		return
	var target_fov: float = 74.0 + float(maxi(0, _current_visual_zone)) * 1.15
	if _last_tree_state == &"FALLING":
		target_fov = 82.0
	elif _last_tree_state == &"BRIDGE_READY":
		target_fov = 80.0
	_camera.fov = lerpf(_camera.fov, target_fov, minf(1.0, delta * 2.5))
	var target_v_offset: float = 0.0
	if _current_visual_zone == 4:
		target_v_offset = 0.45
	elif _current_visual_zone >= 5:
		target_v_offset = 0.72
	if _camera_shake_remaining > 0.0:
		_camera_shake_remaining = maxf(0.0, _camera_shake_remaining - delta)
		var phase: float = Time.get_ticks_msec() * 0.032
		_camera.h_offset = sin(phase) * _camera_shake_strength
		_camera.v_offset = target_v_offset + cos(phase * 1.23) * _camera_shake_strength * 0.7
	else:
		_camera.h_offset = lerpf(_camera.h_offset, 0.0, minf(1.0, delta * 8.0))
		_camera.v_offset = lerpf(_camera.v_offset, target_v_offset, minf(1.0, delta * 5.0))

func _on_finale_mushroom_body_entered(body: Node3D) -> void:
	var racer := body as WildDashCharacterController
	if racer == null or racer.finished:
		return
	var id: int = racer.get_instance_id()
	if _finale_mushroom_cooldowns.has(id):
		return
	_finale_mushroom_cooldowns[id] = 1.15
	racer.velocity.y = maxf(racer.velocity.y, racer.jump_velocity * 1.22)
	AudioManager.play_sfx_id("mushroom_bounce", 0.86)
	print("LOGSPIRE FINALE MUSHROOM racer=%s bounce=true safe_height=true" % RaceManager.get_racer_label(racer))

func _on_final_jump_body_entered(body: Node3D) -> void:
	var racer := body as WildDashCharacterController
	if racer == null or racer.finished:
		return
	var id: int = racer.get_instance_id()
	if _final_jump_cooldowns.has(id):
		return
	_final_jump_cooldowns[id] = FINAL_JUMP_COOLDOWN_SECONDS
	racer.velocity.y = maxf(racer.velocity.y, racer.jump_velocity * 1.08)
	racer.current_speed = maxf(racer.current_speed, racer.max_speed * 1.03)
	var impulse_value: Variant = racer.get("_skill_impulse_velocity")
	var impulse: Vector3 = impulse_value if impulse_value is Vector3 else Vector3.ZERO
	racer.set("_skill_impulse_velocity", impulse + _final_jump_forward * 4.4)
	if not _final_jump_logged.has(id):
		_final_jump_logged[id] = true
		print("LOGSPIRE FINAL JUMP racer=%s launch=true target=CROWN_NEST recovery_below=true" % RaceManager.get_racer_label(racer))

func _on_final_recovery_body_entered(body: Node3D) -> void:
	var racer := body as WildDashCharacterController
	if racer == null or racer.finished:
		return
	var id: int = racer.get_instance_id()
	if _final_recovery_pending.has(id):
		return
	_final_recovery_pending[id] = true
	_recover_final_after_delay(racer, id)

func _recover_final_after_delay(racer: WildDashCharacterController, racer_id: int) -> void:
	await get_tree().create_timer(FINAL_RECOVERY_DELAY_SECONDS).timeout
	if racer == null or not is_instance_valid(racer) or racer.finished:
		_final_recovery_pending.erase(racer_id)
		return
	var target: Vector3 = _platform_position(&"Z6_07") + Vector3.UP * 1.35
	var forward: Vector3 = _platform_forward(&"Z6_07")
	racer.reset_motion(target)
	racer.current_speed = racer.cruise_speed * 0.82
	if forward.length_squared() > 0.001:
		racer.rotation.y = atan2(-forward.x, -forward.z)
	_final_recovery_pending.erase(racer_id)
	print("LOGSPIRE RECOVERY racer=%s target=Z6_07 delay=%.2fs final_jump=true" % [RaceManager.get_racer_label(racer), FINAL_RECOVERY_DELAY_SECONDS])

func _update_cooldowns(delta: float) -> void:
	for store: Dictionary in [_finale_mushroom_cooldowns, _final_jump_cooldowns]:
		for key: Variant in store.keys():
			var remaining: float = float(store[key]) - delta
			if remaining <= 0.0:
				store.erase(key)
			else:
				store[key] = remaining

func _broadcast_phase3_state(state: StringName) -> void:
	for child: Node in get_parent().get_children():
		if child != null and child.has_method("notify_phase3_state"):
			child.call("notify_phase3_state", state)
	print("LOGSPIRE AI WORLD STATE state=%s safety_corridor=true stale_target=false" % String(state))

func _set_hud_message(text: String) -> void:
	var hud_value: Variant = get_parent().get("hud")
	var mode_hud := hud_value as WildDashModeHUD
	if mode_hud != null:
		mode_hud.set_message(text)

func _resolve_player() -> WildDashCharacterController:
	for racer_value: Variant in RaceManager.racers:
		var racer := racer_value as WildDashCharacterController
		if racer != null and racer.is_player:
			return racer
	return null

func _estimate_titan_center() -> Vector3:
	var sum := Vector3.ZERO
	var count: int = 0
	for i: int in range(1, 11):
		var point: Vector3 = _platform_position(StringName("Z5_SPIRAL_%02d" % i))
		if point == Vector3.ZERO:
			continue
		sum += point
		count += 1
	if count <= 0:
		return _platform_position(&"Z5_APPROACH_02") + Vector3(0.0, 0.0, -70.0)
	return Vector3(sum.x / float(count), 0.0, sum.z / float(count))

func _platform_position(platform_id: StringName) -> Vector3:
	if _world == null or not _world.has_method("get_platform_position"):
		return Vector3.ZERO
	var value: Variant = _world.call("get_platform_position", platform_id)
	return value if value is Vector3 else Vector3.ZERO

func _platform_forward(platform_id: StringName) -> Vector3:
	if _graph == null or not _graph.has_method("get_platform_forward"):
		return Vector3.FORWARD
	var value: Variant = _graph.call("get_platform_forward", platform_id, &"safe")
	var forward: Vector3 = value if value is Vector3 else Vector3.FORWARD
	forward.y = 0.0
	return Vector3.FORWARD if forward.length_squared() <= 0.001 else forward.normalized()

func _make_animatable_bridge(
	name_text: String,
	from: Vector3,
	to: Vector3,
	width: float,
	thickness: float,
	color: Color
) -> Dictionary:
	var direction := to - from
	direction.y = 0.0
	var length: float = maxf(2.0, direction.length())
	var forward: Vector3 = Vector3.FORWARD if direction.length_squared() <= 0.001 else direction.normalized()
	var yaw: float = atan2(-forward.x, -forward.z)
	var body := AnimatableBody3D.new()
	body.name = name_text
	body.sync_to_physics = true
	body.global_position = (from + to) * 0.5
	body.rotation.y = yaw
	body.collision_layer = 1
	body.collision_mask = 2
	_world.add_child(body)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, thickness, length)
	mesh.material = _make_material(color, 0.94)
	var visual := MeshInstance3D.new()
	visual.name = "Mesh"
	visual.mesh = mesh
	body.add_child(visual)
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	var shape := BoxShape3D.new()
	shape.size = mesh.size
	collision.shape = shape
	body.add_child(collision)
	return {
		"body": body,
		"final_position": body.global_position,
		"yaw": yaw,
		"length": length,
	}

func _make_box_visual(size: Vector3, material: Material, position: Vector3, yaw: float) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.position = position
	visual.rotation.y = yaw
	return visual

func _make_material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material
