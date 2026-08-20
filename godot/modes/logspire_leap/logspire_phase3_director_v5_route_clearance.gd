extends "res://modes/logspire_leap/logspire_phase3_director_v5_route_clearance_core.gd"

## Production Round 3 route-clearance guard.
## Keeps the Titan approach stable and makes Sky Log Finale use simple, flat,
## deterministic gameplay collision with support-first recovery.

const STATIC_LIVING_BRIDGE_WIDTH: float = 3.8
const STATIC_LIVING_BRIDGE_THICKNESS: float = 0.55
const STATIC_LIVING_BRIDGE_SURFACE_OFFSET: float = 0.30
const FINALE_FLAT_LOG_SIZE := Vector3(8.4, 0.45, 10.4)
const FINALE_RECOVERY_VOLUME_SIZE := Vector3(28.0, 2.4, 22.0)
const FINALE_RECOVERY_DROP: float = 7.2
const FINALE_SUPPORT_VERTICAL_BELOW: float = 0.25
const FINALE_SUPPORT_VERTICAL_ABOVE: float = 1.55
const FINALE_SUPPORT_EXTRA_RADIUS: float = 0.75
const FINALE_SUPPORT_PHYSICS_RADIUS: float = 10.5
const FINALE_SAFE_IDS: Array[StringName] = [
	&"Z6_START",
	&"Z6_01",
	&"Z6_02",
	&"Z6_03",
	&"Z6_04",
	&"Z6_05",
	&"Z6_06",
	&"Z6_07",
	&"CROWN_NEST",
]

var _finale_enter_logged_by_id: Dictionary = {}
var _finale_support_last_by_id: Dictionary = {}

func configure(world: Node, graph: Node) -> void:
	super(world, graph)
	_stabilize_living_tree_route_bridges()
	_stabilize_sky_finale_route()
	_sync_event_geometry_visibility()

func _physics_process(delta: float) -> void:
	super(delta)
	if not _configured:
		return
	_sync_event_geometry_visibility()
	_log_finale_entries_and_support()

## The visual still reads as a log, but the playable route uses the authored
## Z6_01 BoxShape platform. No cylinder collision and no lateral rolling Area3D.
func _build_finale_rolling_log() -> void:
	var platform_id: StringName = &"Z6_01"
	var position: Vector3 = _platform_position(platform_id) + Vector3.UP * 0.64
	var forward: Vector3 = _platform_forward(platform_id)
	_finale_roll_right = Vector3(-forward.z, 0.0, forward.x).normalized()
	_finale_roll_visual = Node3D.new()
	_finale_roll_visual.name = "SkyFinaleRollingLog"
	_world.add_child(_finale_roll_visual)
	_finale_roll_visual.global_position = position
	_finale_roll_visual.rotation.y = atan2(-forward.x, -forward.z)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "FlatLogBoardVisual"
	var mesh := BoxMesh.new()
	mesh.size = FINALE_FLAT_LOG_SIZE
	mesh.material = _make_material(Color(0.54, 0.34, 0.12), 0.92)
	mesh_instance.mesh = mesh
	_finale_roll_visual.add_child(mesh_instance)

	_finale_roll_area = null
	print("r3_finale_log_removed object=SkyFinaleRollingLog cylinder=false replacement=flat_box collision_proxy=Z6_01")

## Keep a final-gap fail-safe, but place its thin box well below valid traversal
## so a normal jump/landing cannot enter it by brushing a route edge.
func _build_final_recovery_area() -> void:
	if _final_recovery_area != null and is_instance_valid(_final_recovery_area):
		_final_recovery_area.queue_free()
	var start: Vector3 = _platform_position(&"Z6_07")
	var crown: Vector3 = _platform_position(&"CROWN_NEST")
	var recovery_position: Vector3 = (start + crown) * 0.5 + Vector3.DOWN * FINALE_RECOVERY_DROP
	_final_recovery_area = Area3D.new()
	_final_recovery_area.name = "FinalJumpRecoveryBranch"
	_final_recovery_area.collision_layer = 0
	_final_recovery_area.collision_mask = 2
	_final_recovery_area.monitoring = true
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = FINALE_RECOVERY_VOLUME_SIZE
	collision.shape = shape
	_final_recovery_area.add_child(collision)
	_world.add_child(_final_recovery_area)
	_final_recovery_area.global_position = recovery_position
	_final_recovery_area.body_entered.connect(_on_final_recovery_body_entered)
	print("r3_finale_collision_adjust object=FinalJumpRecoveryBranch shape=box deep_fail_only=true drop=%.1f" % FINALE_RECOVERY_DROP)

## Finale safe-route geometry does not translate or roll under racers.
func _update_finale_obstacles(_delta: float) -> void:
	if _finale_moving_branch != null and is_instance_valid(_finale_moving_branch):
		_finale_moving_branch.global_position = _finale_moving_branch_base

func _stabilize_sky_finale_route() -> void:
	if _finale_moving_branch != null and is_instance_valid(_finale_moving_branch):
		_finale_moving_branch.global_position = _finale_moving_branch_base
		_finale_moving_branch.collision_layer = 1
		_finale_moving_branch.collision_mask = 2
		_finale_moving_branch.visible = true
		var collision := _finale_moving_branch.get_node_or_null("Collision") as CollisionShape3D
		var shape := collision.shape as BoxShape3D if collision != null else null
		if shape != null:
			shape.size.y = maxf(shape.size.y, 0.65)
		print("r3_finale_collision_adjust object=SkyFinaleMovingBranch shape=box static=true moving=false")

	if _last_tree != null and is_instance_valid(_last_tree):
		_last_tree.global_position = _last_tree_final_position
		_last_tree.rotation = Vector3(0.0, _last_tree_yaw, 0.0)
		_last_tree.collision_layer = 1
		_last_tree.collision_mask = 2
		_last_tree.visible = true
		_last_tree_state = &"STATIC_READY"
		_last_tree_elapsed = LAST_TREE_FALL_SECONDS
		if _final_jump_area != null:
			_final_jump_area.monitoring = true
		print("r3_finale_collision_adjust object=LastFallingTree shape=box static=true falling_event=false camera_cut=false")

## Preserve the final launch assist while the bridge itself remains static.
func _on_final_jump_body_entered(body: Node3D) -> void:
	var racer := body as WildDashCharacterController
	if racer == null or racer.finished or _last_tree_state not in [&"STATIC_READY", &"BRIDGE_READY"]:
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
		print("LOGSPIRE FINAL JUMP racer=%s launch=true target=CROWN_NEST recovery_below=true static_bridge=true" % RaceManager.get_racer_label(racer))

## Inherited _on_final_recovery_body_entered owns _final_recovery_pending.
## Clear that same dictionary on every exit so the fail-safe cannot loop or lock.
func _recover_final_after_delay(racer: WildDashCharacterController, racer_id: int) -> void:
	await get_tree().create_timer(FINAL_RECOVERY_DELAY_SECONDS).timeout
	if racer == null or not is_instance_valid(racer) or racer.finished:
		_final_recovery_pending.erase(racer_id)
		return

	var support_id: StringName = _finale_route_support_platform(racer)
	if support_id != &"":
		_final_recovery_pending.erase(racer_id)
		_log_finale_support_once(racer, support_id)
		print("r3_finale_false_water_blocked racer=%s source=final_recovery reason=valid_support object=%s" % [
			RaceManager.get_racer_label(racer), String(support_id),
		])
		return

	var crown: Vector3 = _platform_position(&"CROWN_NEST")
	var crown_delta: Vector3 = racer.global_position - crown
	var crown_vertical: float = absf(crown_delta.y)
	crown_delta.y = 0.0
	if crown_delta.length() <= 12.0 and crown_vertical <= 4.5:
		_final_recovery_pending.erase(racer_id)
		print("r3_finale_false_water_blocked racer=%s source=final_recovery reason=finish_approach" % RaceManager.get_racer_label(racer))
		return

	if bool(racer.get_meta(&"logspire_water_recovery_active", false)):
		_final_recovery_pending.erase(racer_id)
		print("r3_finale_water_guard racer=%s final_recovery=false reason=water_authority_active" % RaceManager.get_racer_label(racer))
		return
	var water := get_parent().get_node_or_null("WaterRecovery")
	if water != null and water.has_method("should_handle_racer") and bool(water.call("should_handle_racer", racer)):
		_final_recovery_pending.erase(racer_id)
		print("r3_finale_water_guard racer=%s final_recovery=false reason=water_authority_claimed" % RaceManager.get_racer_label(racer))
		return

	var target: Vector3 = _platform_position(&"Z6_07") + Vector3.UP * 1.35
	var forward: Vector3 = _platform_forward(&"Z6_07")
	print("r3_finale_recovery_trigger racer=%s source=final_gap target=Z6_07 supported=false" % RaceManager.get_racer_label(racer))
	racer.reset_motion(target)
	racer.current_speed = racer.cruise_speed * 0.82
	if forward.length_squared() > 0.001:
		racer.rotation.y = atan2(-forward.x, -forward.z)
	var recovery := get_parent().get_node_or_null("RecoverySystem")
	if recovery != null and recovery.has_method("begin_retry_grace"):
		recovery.call("begin_retry_grace", racer, "r3_finale_gap")
	_final_recovery_pending.erase(racer_id)
	_finale_support_last_by_id.erase(racer_id)
	print("r3_finale_recovery_exit racer=%s target=Z6_07 safe_spawn=true loop_guard=true" % RaceManager.get_racer_label(racer))

func _finale_route_support_platform(racer: WildDashCharacterController) -> StringName:
	if racer == null or not is_instance_valid(racer) or _world == null:
		return &""
	for platform_id: StringName in FINALE_SAFE_IDS:
		var platform_position: Vector3 = _platform_position(platform_id)
		var landing_radius: float = 4.0
		if _world.has_method("get_platform_landing_radius"):
			landing_radius = maxf(3.0, float(_world.call("get_platform_landing_radius", platform_id)))
		var planar := Vector2(
			racer.global_position.x - platform_position.x,
			racer.global_position.z - platform_position.z
		).length()
		var platform_top_y: float = platform_position.y + 0.40
		var foot_delta: float = racer.global_position.y - platform_top_y
		if planar <= landing_radius + FINALE_SUPPORT_EXTRA_RADIUS and foot_delta >= -FINALE_SUPPORT_VERTICAL_BELOW and foot_delta <= FINALE_SUPPORT_VERTICAL_ABOVE:
			return platform_id

	var water := get_parent().get_node_or_null("WaterRecovery")
	var physics_supported: bool = racer.is_on_floor()
	if not physics_supported and water != null and water.has_method("_has_nearby_surface_support"):
		physics_supported = bool(water.call("_has_nearby_surface_support", racer))
	if not physics_supported:
		return &""
	return _nearest_finale_platform(racer, FINALE_SUPPORT_PHYSICS_RADIUS)

func _nearest_finale_platform(racer: WildDashCharacterController, max_planar_distance: float) -> StringName:
	if racer == null or _world == null:
		return &""
	var best_id: StringName = &""
	var best_distance: float = max_planar_distance
	for platform_id: StringName in FINALE_SAFE_IDS:
		var position: Vector3 = _platform_position(platform_id)
		var distance: float = Vector2(
			racer.global_position.x - position.x,
			racer.global_position.z - position.z
		).length()
		if distance <= best_distance:
			best_distance = distance
			best_id = platform_id
	return best_id

func _log_finale_entries_and_support() -> void:
	if not RaceManager.active:
		return
	for value: Variant in RaceManager.racers.duplicate():
		var racer := value as WildDashCharacterController
		if racer == null or not is_instance_valid(racer) or racer.finished:
			continue
		var support_id: StringName = _finale_route_support_platform(racer)
		if support_id == &"":
			continue
		var racer_id: int = racer.get_instance_id()
		if not _finale_enter_logged_by_id.has(racer_id):
			_finale_enter_logged_by_id[racer_id] = true
			print("r3_finale_enter racer=%s object=%s safe_route=true" % [RaceManager.get_racer_label(racer), String(support_id)])
		_log_finale_support_once(racer, support_id)

func _log_finale_support_once(racer: WildDashCharacterController, support_id: StringName) -> void:
	if racer == null or support_id == &"":
		return
	var racer_id: int = racer.get_instance_id()
	var previous := StringName(_finale_support_last_by_id.get(racer_id, &""))
	if previous == support_id:
		return
	_finale_support_last_by_id[racer_id] = support_id
	print("r3_finale_support_surface racer=%s object=%s supported=true" % [
		RaceManager.get_racer_label(racer), String(support_id),
	])

func _stabilize_living_tree_route_bridges() -> void:
	var pairs: Array[Array] = [
		[&"Z5_SPIRAL_03", &"Z5_SPIRAL_04"],
		[&"Z5_SPIRAL_05", &"Z5_SPIRAL_06"],
	]
	var count: int = mini(_living_branches.size(), pairs.size())
	for i: int in range(count):
		var data: Dictionary = _living_branches[i]
		var body := data.get("body") as AnimatableBody3D
		if body == null or not is_instance_valid(body):
			continue
		var from_id: StringName = pairs[i][0]
		var to_id: StringName = pairs[i][1]
		var from: Vector3 = _platform_position(from_id) + Vector3.UP * STATIC_LIVING_BRIDGE_SURFACE_OFFSET
		var to: Vector3 = _platform_position(to_id) + Vector3.UP * STATIC_LIVING_BRIDGE_SURFACE_OFFSET
		var delta: Vector3 = to - from
		if delta.length_squared() <= 0.001:
			continue

		body.global_position = (from + to) * 0.5
		body.look_at(to, Vector3.UP)
		body.collision_layer = 1
		body.collision_mask = 2
		body.visible = true

		var bridge_size := Vector3(
			STATIC_LIVING_BRIDGE_WIDTH,
			STATIC_LIVING_BRIDGE_THICKNESS,
			maxf(2.0, delta.length())
		)
		var visual := body.get_node_or_null("Mesh") as MeshInstance3D
		var mesh := visual.mesh as BoxMesh if visual != null else null
		if mesh != null:
			mesh.size = bridge_size
		var collision := body.get_node_or_null("Collision") as CollisionShape3D
		var shape := collision.shape as BoxShape3D if collision != null else null
		if shape != null:
			shape.size = bridge_size

		data["final_position"] = body.global_position
		data["final_rotation"] = body.rotation
		data["start_position"] = body.global_position
		data["start_rotation"] = body.rotation
		_living_branches[i] = data

	_living_tree_state = &"STATE_B"
	_living_tree_elapsed = LIVING_TREE_MOVE_SECONDS
	if _living_leaves != null:
		_living_leaves.visible = false
	if _graph != null and _graph.has_method("set_world_state"):
		_graph.call("set_world_state", &"STATE_B")
	print("LOGSPIRE LIVING TREE ROUTE STABLE bridges=%d static=true sloped=true moving_event=false camera_cut=false" % count)

func _sync_event_geometry_visibility() -> void:
	for data: Dictionary in _living_branches:
		var body := data.get("body") as AnimatableBody3D
		if body == null or not is_instance_valid(body):
			continue
		body.visible = body.collision_layer != 0

	if _last_tree != null and is_instance_valid(_last_tree):
		_last_tree.visible = _last_tree.collision_layer != 0
