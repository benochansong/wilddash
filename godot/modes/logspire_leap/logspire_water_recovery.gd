extends Node3D

## LOGSPIRE CANOPY RIVER recovery authority.
## Falling onto a configured water basin pauses the normal race controller,
## switches to simple buoyant swimming, guides the racer to a local ladder,
## climbs onto a recovery deck, then restores the normal race/AI controllers.
## Existing checkpoint recovery remains the last-resort fallback.

signal water_recovered(racer: WildDashCharacterController, platform_id: StringName)

enum WaterState {
	RACING,
	FALLING,
	WATER_ENTRY,
	SWIMMING,
	LADDER_APPROACH,
	LADDER_CLIMB,
	RECOVERY_EXIT,
}

const SWIM_SCRIPT: Script = preload("res://modes/logspire_leap/logspire_swim_controller.gd")
const WATER_AI_SCRIPT: Script = preload("res://modes/logspire_leap/logspire_water_ai.gd")
const PLAYER_WATER_TIMEOUT: float = 13.5
const AI_WATER_TIMEOUT: float = 10.0
const LADDER_CLIMB_SECONDS: float = 2.15
const LADDER_ATTACH_RADIUS: float = 2.15
const WATER_GUIDANCE_INTERVAL: float = 0.45
const FALL_TRACK_MIN_SPEED: float = -0.75
const WATER_META: StringName = &"logspire_water_recovery_active"

var _root: Node
var _world: Node
var _graph: Node
var _ladder_system: Node
var _recovery: Node
var _hud: Node
var _swim: RefCounted
var _water_ai: RefCounted
var _configured: bool = false
var _pools: Array[Dictionary] = []
var _wave_nodes: Array[Dictionary] = []
var _water_material: StandardMaterial3D

var _state_by_id: Dictionary = {}
var _zone_by_id: Dictionary = {}
var _water_y_by_id: Dictionary = {}
var _ladder_by_id: Dictionary = {}
var _water_elapsed_by_id: Dictionary = {}
var _guidance_elapsed_by_id: Dictionary = {}
var _fall_start_y_by_id: Dictionary = {}
var _climb_elapsed_by_id: Dictionary = {}
var _climb_from_by_id: Dictionary = {}
var _climb_to_by_id: Dictionary = {}
var _driver_by_id: Dictionary = {}
var _aux_by_id: Dictionary = {}
var _paused_nodes_by_id: Dictionary = {}
var _last_swim_position_by_id: Dictionary = {}
var _water_entries: int = 0
var _water_recoveries: int = 0
var _water_fallbacks: int = 0
var _binding_elapsed: float = 0.0
var _wave_time: float = 0.0

func _ready() -> void:
	call_deferred("_bootstrap")

func _bootstrap() -> void:
	await get_tree().physics_frame
	_root = get_parent()
	if _root == null:
		return
	_world = _root.get_node_or_null("LogspireWorld")
	_graph = _root.get_node_or_null("PlatformGraph")
	_ladder_system = _root.get_node_or_null("LadderSystem")
	_recovery = _root.get_node_or_null("RecoverySystem")
	var hud_value: Variant = _root.get("hud")
	_hud = hud_value as Node
	if _world == null or _graph == null or _ladder_system == null or _recovery == null:
		push_error("LOGSPIRE WATER INIT FAIL missing world/graph/ladder/recovery")
		return
	_swim = SWIM_SCRIPT.new() as RefCounted
	_water_ai = WATER_AI_SCRIPT.new() as RefCounted
	_build_water_material()
	_build_canopy_river()
	_ladder_system.call("configure", _world, _graph, get_water_heights())
	if _recovery.has_method("set_water_recovery"):
		_recovery.call("set_water_recovery", self)
	if _recovery.has_signal("racer_recovered"):
		var callback := Callable(self, "_on_checkpoint_recovered")
		if not _recovery.is_connected("racer_recovered", callback):
			_recovery.connect("racer_recovered", callback)
	_refresh_racer_bindings()
	_configured = true
	print("LOGSPIRE WATER READY pools=%d ladders=%d swim_ratio=0.50 player_timeout=%.1fs ai_timeout=%.1fs climb=%.2fs rigidbody=false fallback=checkpoint" % [
		_pools.size(), int(_ladder_system.call("get_ladder_count")), PLAYER_WATER_TIMEOUT, AI_WATER_TIMEOUT, LADDER_CLIMB_SECONDS,
	])

func _process(delta: float) -> void:
	_wave_time += delta
	for value: Variant in _wave_nodes:
		if not (value is Dictionary):
			continue
		var entry: Dictionary = value
		var mesh := entry.get("node") as MeshInstance3D
		if mesh == null:
			continue
		var base_y: float = float(entry.get("base_y", mesh.position.y))
		var phase: float = float(entry.get("phase", 0.0))
		var position := mesh.position
		position.y = base_y + sin(_wave_time * 0.72 + phase) * 0.045
		mesh.position = position

func _physics_process(delta: float) -> void:
	if not _configured:
		return
	_binding_elapsed += delta
	if _binding_elapsed >= 1.0:
		_binding_elapsed = 0.0
		_refresh_racer_bindings()
	if not RaceManager.active:
		return

	for value: Variant in RaceManager.racers.duplicate():
		var racer := value as WildDashCharacterController
		if racer == null or not is_instance_valid(racer) or racer.finished:
			continue
		var racer_id: int = racer.get_instance_id()
		var state: int = int(_state_by_id.get(racer_id, WaterState.RACING))
		if state == WaterState.RACING or state == WaterState.FALLING:
			_track_fall_state(racer)
			continue
		if state == WaterState.SWIMMING or state == WaterState.LADDER_APPROACH:
			_update_swimming(racer, delta)
		elif state == WaterState.LADDER_CLIMB:
			_update_ladder_climb(racer, delta)

func should_handle_racer(racer: WildDashCharacterController) -> bool:
	if racer == null or not is_instance_valid(racer):
		return false
	var racer_id: int = racer.get_instance_id()
	var state: int = int(_state_by_id.get(racer_id, WaterState.RACING))
	if state not in [WaterState.RACING, WaterState.FALLING]:
		return true
	var pool: Dictionary = _pool_for_position(racer.global_position)
	if pool.is_empty():
		return false
	return racer.global_position.y <= float(pool.get("water_y", -999.0)) + 1.65

func is_water_recovering(racer: WildDashCharacterController) -> bool:
	if racer == null:
		return false
	return bool(racer.get_meta(WATER_META, false))

func get_water_heights() -> Dictionary:
	var result: Dictionary = {}
	for pool: Dictionary in _pool_layout():
		result[int(pool.get("zone", 0))] = float(pool.get("water_y", 0.0))
	return result

func _pool_layout() -> Array[Dictionary]:
	return [
		{"zone": 0, "center": Vector3(0.0, 0.25, -55.0), "size": Vector2(92.0, 154.0), "water_y": 0.25},
		{"zone": 1, "center": Vector3(0.0, -0.75, -165.0), "size": Vector2(92.0, 130.0), "water_y": -0.75},
		{"zone": 2, "center": Vector3(0.0, 8.75, -290.0), "size": Vector2(88.0, 140.0), "water_y": 8.75},
		{"zone": 3, "center": Vector3(0.0, 15.75, -440.0), "size": Vector2(108.0, 196.0), "water_y": 15.75},
		{"zone": 4, "center": Vector3(0.0, 23.25, -585.0), "size": Vector2(100.0, 136.0), "water_y": 23.25},
		{"zone": 5, "center": Vector3(0.0, 48.25, -720.0), "size": Vector2(100.0, 190.0), "water_y": 48.25},
	]

func _build_water_material() -> void:
	_water_material = StandardMaterial3D.new()
	_water_material.albedo_color = Color(0.035, 0.34, 0.37, 0.76)
	_water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_water_material.roughness = 0.22
	_water_material.metallic = 0.04
	_water_material.emission_enabled = true
	_water_material.emission = Color(0.02, 0.19, 0.15) * 0.58

func _build_canopy_river() -> void:
	_pools.clear()
	for pool: Dictionary in _pool_layout():
		var zone: int = int(pool.get("zone", 0))
		var center: Vector3 = pool.get("center", Vector3.ZERO)
		var size: Vector2 = pool.get("size", Vector2(80.0, 120.0))
		var water_y: float = float(pool.get("water_y", center.y))

		var mesh_node := MeshInstance3D.new()
		mesh_node.name = "CanopyRiver_Z%d" % [zone + 1]
		var mesh := BoxMesh.new()
		mesh.size = Vector3(size.x, 0.12, size.y)
		mesh.material = _water_material
		mesh_node.mesh = mesh
		mesh_node.position = Vector3(center.x, water_y, center.z)
		add_child(mesh_node)
		_wave_nodes.append({"node": mesh_node, "base_y": water_y, "phase": float(zone) * 0.9})

		var area := Area3D.new()
		area.name = "CanopyRiverArea_Z%d" % [zone + 1]
		area.position = Vector3(center.x, water_y - 1.0, center.z)
		area.collision_layer = 0
		area.collision_mask = 2
		area.monitoring = true
		area.monitorable = false
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(size.x, 4.0, size.y)
		collision.shape = shape
		area.add_child(collision)
		add_child(area)
		area.body_entered.connect(_on_water_body_entered.bind(zone, water_y))
		var runtime_pool := pool.duplicate(true)
		runtime_pool["area"] = area
		_pools.append(runtime_pool)

func _on_water_body_entered(body: Node3D, zone: int, water_y: float) -> void:
	var racer := body as WildDashCharacterController
	if racer == null or racer.finished or not RaceManager.active:
		return
	var racer_id: int = racer.get_instance_id()
	var state: int = int(_state_by_id.get(racer_id, WaterState.RACING))
	if state not in [WaterState.RACING, WaterState.FALLING]:
		return
	_enter_water(racer, zone, water_y)

func _enter_water(racer: WildDashCharacterController, zone: int, water_y: float) -> void:
	var racer_id: int = racer.get_instance_id()
	_state_by_id[racer_id] = WaterState.WATER_ENTRY
	_zone_by_id[racer_id] = zone
	_water_y_by_id[racer_id] = water_y
	_water_elapsed_by_id[racer_id] = 0.0
	_guidance_elapsed_by_id[racer_id] = WATER_GUIDANCE_INTERVAL
	racer.set_meta(WATER_META, true)
	_pause_racer_control(racer)

	var fall_start_y: float = float(_fall_start_y_by_id.get(racer_id, racer.global_position.y))
	var fall_height: float = maxf(0.0, fall_start_y - water_y)
	var position := racer.global_position
	position.y = water_y + 0.62
	racer.global_position = position
	racer.velocity *= 0.22
	racer.velocity.y = 0.0
	racer.current_speed *= 0.30

	var ladders: Array = _ladder_system.call("get_ladders_for_zone", zone)
	var ladder: Dictionary = _water_ai.call("choose_ladder", racer, zone, ladders, RaceManager.get_checkpoint_progress(racer))
	if ladder.is_empty():
		_start_checkpoint_fallback(racer, "no_valid_ladder")
		return
	_ladder_by_id[racer_id] = ladder
	_state_by_id[racer_id] = WaterState.SWIMMING
	_last_swim_position_by_id[racer_id] = racer.global_position
	_water_entries += 1
	_spawn_splash(racer.global_position)
	AudioManager.play_sfx_id("splash", 1.0)
	_pulse_camera(racer)
	if racer.is_player and DisplayServer.get_name() != "headless":
		_set_hud_message("FELL INTO THE CANOPY RIVER! · SWIM TO A LADDER")
	print("LOGSPIRE WATER ENTRY racer=%s fall_height=%.1f zone=%d state=SWIMMING" % [
		RaceManager.get_racer_label(racer), fall_height, zone + 1,
	])
	if not racer.is_player:
		print("LOGSPIRE WATER AI RECOVERY racer=%s ladder=%s zone=%d" % [
			RaceManager.get_racer_label(racer), String(ladder.get("id", &"")), zone + 1,
		])

func _update_swimming(racer: WildDashCharacterController, delta: float) -> void:
	var racer_id: int = racer.get_instance_id()
	var zone: int = int(_zone_by_id.get(racer_id, 0))
	var water_y: float = float(_water_y_by_id.get(racer_id, racer.global_position.y))
	var ladder_value: Variant = _ladder_by_id.get(racer_id, {})
	var ladder: Dictionary = ladder_value if ladder_value is Dictionary else {}
	if ladder.is_empty():
		var candidates: Array = _ladder_system.call("get_ladders_for_zone", zone)
		ladder = _water_ai.call("choose_ladder", racer, zone, candidates, RaceManager.get_checkpoint_progress(racer))
		if ladder.is_empty():
			_start_checkpoint_fallback(racer, "ladder_path_failure")
			return
		_ladder_by_id[racer_id] = ladder

	var bottom: Vector3 = ladder.get("bottom", racer.global_position)
	var direction := Vector3.ZERO
	var controlled_by_player: bool = racer.is_player and DisplayServer.get_name() != "headless"
	if controlled_by_player:
		direction = _swim.call("get_player_direction")
	else:
		direction = bottom - racer.global_position
		direction.y = 0.0
		if direction.length_squared() > 0.001:
			direction = direction.normalized()
	_state_by_id[racer_id] = WaterState.LADDER_APPROACH if Vector2(racer.global_position.x - bottom.x, racer.global_position.z - bottom.z).length() < 6.0 else WaterState.SWIMMING
	_swim.call("apply_swim", racer, direction, water_y, delta)
	_water_elapsed_by_id[racer_id] = float(_water_elapsed_by_id.get(racer_id, 0.0)) + delta
	_guidance_elapsed_by_id[racer_id] = float(_guidance_elapsed_by_id.get(racer_id, 0.0)) + delta

	var planar_distance: float = Vector2(racer.global_position.x - bottom.x, racer.global_position.z - bottom.z).length()
	if controlled_by_player and float(_guidance_elapsed_by_id[racer_id]) >= WATER_GUIDANCE_INTERVAL:
		_guidance_elapsed_by_id[racer_id] = 0.0
		_set_hud_message("RECOVERY ROUTE · LADDER %.0fm · CLIMB!" % planar_distance)
	if planar_distance <= float(ladder.get("attach_radius", LADDER_ATTACH_RADIUS)):
		_begin_ladder_climb(racer, ladder)
		return

	var timeout: float = PLAYER_WATER_TIMEOUT if controlled_by_player else AI_WATER_TIMEOUT
	if float(_water_elapsed_by_id[racer_id]) >= timeout:
		_start_checkpoint_fallback(racer, "water_timeout")

func _begin_ladder_climb(racer: WildDashCharacterController, ladder: Dictionary) -> void:
	var racer_id: int = racer.get_instance_id()
	_state_by_id[racer_id] = WaterState.LADDER_CLIMB
	_climb_elapsed_by_id[racer_id] = 0.0
	_climb_from_by_id[racer_id] = racer.global_position
	_climb_to_by_id[racer_id] = ladder.get("exit", racer.global_position + Vector3.UP * 4.0)
	racer.velocity = Vector3.ZERO
	AudioManager.play_sfx_id("wood_land", 0.78)
	if racer.is_player and DisplayServer.get_name() != "headless":
		_set_hud_message("CLIMB! · BACK TO THE RACE")
	print("LOGSPIRE LADDER ATTACH racer=%s ladder=%s zone=%d" % [
		RaceManager.get_racer_label(racer), String(ladder.get("id", &"")), int(ladder.get("zone", 0)) + 1,
	])

func _update_ladder_climb(racer: WildDashCharacterController, delta: float) -> void:
	var racer_id: int = racer.get_instance_id()
	var elapsed: float = float(_climb_elapsed_by_id.get(racer_id, 0.0)) + delta
	_climb_elapsed_by_id[racer_id] = elapsed
	var from_value: Variant = _climb_from_by_id.get(racer_id, racer.global_position)
	var to_value: Variant = _climb_to_by_id.get(racer_id, racer.global_position)
	var from: Vector3 = from_value if from_value is Vector3 else racer.global_position
	var to: Vector3 = to_value if to_value is Vector3 else racer.global_position
	var t: float = clampf(elapsed / LADDER_CLIMB_SECONDS, 0.0, 1.0)
	var eased: float = t * t * (3.0 - 2.0 * t)
	racer.global_position = from.lerp(to, eased)
	racer.velocity = Vector3.ZERO
	if t >= 1.0:
		_finish_water_recovery(racer)

func _finish_water_recovery(racer: WildDashCharacterController) -> void:
	var racer_id: int = racer.get_instance_id()
	var ladder_value: Variant = _ladder_by_id.get(racer_id, {})
	var ladder: Dictionary = ladder_value if ladder_value is Dictionary else {}
	var exit_value: Variant = ladder.get("exit", racer.global_position)
	var exit_position: Vector3 = exit_value if exit_value is Vector3 else racer.global_position
	racer.reset_motion(exit_position)
	racer.current_speed = maxf(racer.cruise_speed * 0.64, 4.2)
	_release_racer_control(racer)
	_state_by_id[racer_id] = WaterState.RACING
	racer.set_meta(WATER_META, false)
	_water_recoveries += 1
	var recovery_time: float = float(_water_elapsed_by_id.get(racer_id, 0.0)) + LADDER_CLIMB_SECONDS
	var platform_id := StringName(ladder.get("platform_id", &""))
	AudioManager.play_sfx_id("jump", 0.72)
	_notify_platform_ai_recovered(racer)
	if racer.is_player and DisplayServer.get_name() != "headless":
		_set_hud_message("BACK TO THE RACE! · WATER RECOVERY %.1fs" % recovery_time)
	print("LOGSPIRE LADDER EXIT racer=%s zone=%d platform=%s" % [
		RaceManager.get_racer_label(racer), int(ladder.get("zone", 0)) + 1, String(platform_id),
	])
	print("LOGSPIRE WATER RECOVERY racer=%s recovery_time=%.2f ladder=%s total=%d" % [
		RaceManager.get_racer_label(racer), recovery_time, String(ladder.get("id", &"")), _water_recoveries,
	])
	water_recovered.emit(racer, platform_id)
	_clear_water_runtime(racer_id)

func _start_checkpoint_fallback(racer: WildDashCharacterController, reason: String) -> void:
	if racer == null:
		return
	var racer_id: int = racer.get_instance_id()
	if int(_state_by_id.get(racer_id, WaterState.RACING)) == WaterState.RECOVERY_EXIT:
		return
	_state_by_id[racer_id] = WaterState.RECOVERY_EXIT
	_water_fallbacks += 1
	print("LOGSPIRE WATER FALLBACK racer=%s reason=%s water_time=%.2f total=%d" % [
		RaceManager.get_racer_label(racer), reason, float(_water_elapsed_by_id.get(racer_id, 0.0)), _water_fallbacks,
	])
	if not racer.is_player:
		print("LOGSPIRE WATER AI FALLBACK racer=%s reason=%s" % [RaceManager.get_racer_label(racer), reason])
	if _recovery != null and _recovery.has_method("force_checkpoint_recovery"):
		_recovery.call("force_checkpoint_recovery", racer, "water_%s" % reason)
	else:
		_release_racer_control(racer)
		racer.set_meta(WATER_META, false)
		_state_by_id[racer_id] = WaterState.RACING

func _on_checkpoint_recovered(racer: WildDashCharacterController, _target_id: StringName) -> void:
	if racer == null:
		return
	var racer_id: int = racer.get_instance_id()
	if int(_state_by_id.get(racer_id, WaterState.RACING)) != WaterState.RECOVERY_EXIT:
		return
	_release_racer_control(racer)
	racer.set_meta(WATER_META, false)
	_state_by_id[racer_id] = WaterState.RACING
	_notify_platform_ai_recovered(racer)
	_clear_water_runtime(racer_id)

func _track_fall_state(racer: WildDashCharacterController) -> void:
	var racer_id: int = racer.get_instance_id()
	if racer.velocity.y <= FALL_TRACK_MIN_SPEED:
		_state_by_id[racer_id] = WaterState.FALLING
		_fall_start_y_by_id[racer_id] = maxf(float(_fall_start_y_by_id.get(racer_id, racer.global_position.y)), racer.global_position.y)
	else:
		_state_by_id[racer_id] = WaterState.RACING
		if racer.is_on_floor():
			_fall_start_y_by_id.erase(racer_id)

func _pause_racer_control(racer: WildDashCharacterController) -> void:
	var racer_id: int = racer.get_instance_id()
	var paused: Array[Node] = []
	var nodes: Array[Node] = [racer]
	var driver := _driver_by_id.get(racer_id) as Node
	if driver != null:
		nodes.append(driver)
	var aux_value: Variant = _aux_by_id.get(racer_id, [])
	if aux_value is Array:
		for node_value: Variant in aux_value:
			var aux := node_value as Node
			if aux != null:
				nodes.append(aux)
	for node: Node in nodes:
		if node == null or not is_instance_valid(node):
			continue
		if node.is_physics_processing():
			paused.append(node)
			node.set_physics_process(false)
	_paused_nodes_by_id[racer_id] = paused

func _release_racer_control(racer: WildDashCharacterController) -> void:
	if racer == null:
		return
	var racer_id: int = racer.get_instance_id()
	var paused_value: Variant = _paused_nodes_by_id.get(racer_id, [])
	if paused_value is Array:
		for node_value: Variant in paused_value:
			var node := node_value as Node
			if node != null and is_instance_valid(node):
				node.set_physics_process(true)
	_paused_nodes_by_id.erase(racer_id)

func _refresh_racer_bindings() -> void:
	for value: Variant in RaceManager.racers:
		var racer := value as WildDashCharacterController
		if racer == null or not is_instance_valid(racer):
			continue
		var racer_id: int = racer.get_instance_id()
		if not _state_by_id.has(racer_id):
			_state_by_id[racer_id] = WaterState.RACING
			_aux_by_id[racer_id] = []

	for node_value: Variant in get_tree().get_nodes_in_group("wilddash_ai_driver"):
		var node := node_value as Node
		if node == null:
			continue
		var racer_value: Variant = node.get("_racer")
		var racer := racer_value as WildDashCharacterController
		if racer != null:
			_driver_by_id[racer.get_instance_id()] = node

	if _root != null:
		for child_value: Variant in _root.get_children():
			var child := child_value as Node
			if child == null or not String(child.name).ends_with("LogspireJumpAI"):
				continue
			var racer_value: Variant = child.get("_racer")
			var racer := racer_value as WildDashCharacterController
			if racer == null:
				continue
			var racer_id: int = racer.get_instance_id()
			var aux: Array = _aux_by_id.get(racer_id, [])
			if not aux.has(child):
				aux.append(child)
			_aux_by_id[racer_id] = aux

func _notify_platform_ai_recovered(racer: WildDashCharacterController) -> void:
	if racer == null:
		return
	var aux_value: Variant = _aux_by_id.get(racer.get_instance_id(), [])
	if not (aux_value is Array):
		return
	for node_value: Variant in aux_value:
		var node := node_value as Node
		if node != null and node.has_method("notify_recovered"):
			node.call("notify_recovered")

func _pool_for_position(position: Vector3) -> Dictionary:
	var best: Dictionary = {}
	var best_water_y: float = -INF
	for pool: Dictionary in _pools:
		var center: Vector3 = pool.get("center", Vector3.ZERO)
		var size: Vector2 = pool.get("size", Vector2.ZERO)
		var water_y: float = float(pool.get("water_y", center.y))
		if absf(position.x - center.x) > size.x * 0.5 or absf(position.z - center.z) > size.y * 0.5:
			continue
		if position.y > water_y + 2.5:
			continue
		if water_y > best_water_y:
			best_water_y = water_y
			best = pool
	return best

func _set_hud_message(text: String) -> void:
	if _hud != null and _hud.has_method("set_message"):
		_hud.call("set_message", text)

func _pulse_camera(racer: WildDashCharacterController) -> void:
	if racer == null or not racer.is_player or _root == null:
		return
	var camera := _root.get_node_or_null("ChaseCamera") as Camera3D
	if camera == null:
		return
	var normal_fov: float = camera.fov
	camera.fov = minf(90.0, normal_fov + 3.0)
	var tween := create_tween()
	tween.tween_property(camera, "fov", normal_fov, 0.34)

func _spawn_splash(position: Vector3) -> void:
	var particles := GPUParticles3D.new()
	particles.name = "WaterSplash"
	particles.amount = 18
	particles.lifetime = 0.55
	particles.one_shot = true
	particles.explosiveness = 0.92
	particles.position = position
	var quad := QuadMesh.new()
	quad.size = Vector2(0.18, 0.18)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.35, 0.90, 0.82, 0.84)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad.material = material
	particles.draw_pass_1 = quad
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 58.0
	process.initial_velocity_min = 3.0
	process.initial_velocity_max = 6.2
	process.gravity = Vector3(0.0, -8.5, 0.0)
	particles.process_material = process
	add_child(particles)
	particles.emitting = true
	_expire_effect(particles, 0.9)

func _expire_effect(node: Node, seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
	if node != null and is_instance_valid(node):
		node.queue_free()

func _clear_water_runtime(racer_id: int) -> void:
	_zone_by_id.erase(racer_id)
	_water_y_by_id.erase(racer_id)
	_ladder_by_id.erase(racer_id)
	_water_elapsed_by_id.erase(racer_id)
	_guidance_elapsed_by_id.erase(racer_id)
	_fall_start_y_by_id.erase(racer_id)
	_climb_elapsed_by_id.erase(racer_id)
	_climb_from_by_id.erase(racer_id)
	_climb_to_by_id.erase(racer_id)
	_last_swim_position_by_id.erase(racer_id)
