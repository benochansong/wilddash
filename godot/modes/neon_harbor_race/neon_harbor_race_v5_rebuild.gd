extends "res://modes/neon_harbor_race/neon_harbor_race_v4_wild_tide.gd"

## Round 3 Rebuild V5.
##
## V3 corrected the original fixed 14.x targets, but three systems then fought
## over AI target_speed: V3 pace, V4 terrain pace, and legacy AIPackTactics with
## its production 1.35 base-speed scale. That tug-of-war also kept most racers on
## one route, producing the visible slow clump. V5 makes Round 3 pace + branch
## assignment authoritative and disables only the legacy Round-3 pack-tactics
## process. Other rounds retain AIPackTactics unchanged.

const FAST_IDS: Array[StringName] = [&"rabbit", &"fox", &"cat"]
const MID_IDS: Array[StringName] = [&"dog", &"wolf", &"deer", &"monkey"]
const POWER_IDS: Array[StringName] = [&"bear", &"boar", &"elephant", &"crocodile", &"raccoon"]
const FAST_PACE_SCALE: float = 1.10
const MID_PACE_SCALE: float = 1.05
const POWER_PACE_SCALE: float = 1.015
const OPENING_LEAD_BONUS: float = 1.025
const OPENING_LEAD_SECONDS: float = 12.0
const SEPARATION_NEAR: float = 2.5
const SEPARATION_FAR: float = 5.0
const MAX_SEPARATION_LANE: float = 2.6
const PACK_LOG_SECONDS: float = 4.0

var _route_network: WildDashWildTideRouteNetwork
var _v5_initialized: bool = false
var _v5_route_by_racer: Dictionary = {}
var _v5_base_lane_by_racer: Dictionary = {}
var _v5_slot_by_racer: Dictionary = {}
var _v5_lead_ids: Dictionary = {}
var _v5_pack_log_elapsed: float = 0.0

func _ready() -> void:
	super._ready()
	call_deferred("_bootstrap_v5")

func _configure_night_sun() -> void:
	# The inherited mode calls this old compatibility hook before it instantiates
	# the track. Hide that blue night key light; WildTideDaylightTrack owns the
	# authoritative warm sun and WorldEnvironment.
	var legacy_sun: DirectionalLight3D = get_node_or_null("Sun") as DirectionalLight3D
	if legacy_sun != null:
		legacy_sun.visible = false

func _bootstrap_v5() -> void:
	for _attempt: int in range(90):
		_route_network = get_node_or_null("WildTideRouteNetwork") as WildDashWildTideRouteNetwork
		if _route_network != null and _route_network.is_ready() and not ai_racers.is_empty() and ai_drivers.size() >= ai_racers.size():
			break
		await get_tree().physics_frame
	if _route_network == null or not _route_network.is_ready():
		push_warning("ROUND3 V5 route network unavailable; keeping safe main route")
		return

	_disable_legacy_round3_pack_tactics()
	_assign_lead_group()
	_assign_branch_routes()
	_apply_start_spread_profiles()
	_v5_initialized = true
	print("ROUND3 REBUILD V5 READY daytime=true fast_lead=%d multi_route=true legacy_pack_tactics=false separation=true pace_tiers=true" % _v5_lead_ids.size())

func _process(delta: float) -> void:
	super(delta)
	if not _v5_initialized or not RaceManager.active:
		return
	_v5_pack_log_elapsed += delta
	if _v5_pack_log_elapsed >= PACK_LOG_SECONDS:
		_v5_pack_log_elapsed = 0.0
		_log_v5_pack_state()

func _disable_legacy_round3_pack_tactics() -> void:
	var disabled: int = 0
	for node: Node in get_tree().get_nodes_in_group("wilddash_ai_tactics"):
		if node == null or node.get_parent() != self:
			continue
		node.set_process(false)
		disabled += 1
	print("ROUND3 AI CONTROL legacy_pack_tactics_disabled=%d reason=pace_tug_of_war route_authority_v5" % disabled)

func _assign_lead_group() -> void:
	_v5_lead_ids.clear()
	for racer: WildDashCharacterController in ai_racers:
		if racer == null or not FAST_IDS.has(racer.animal_id):
			continue
		_v5_lead_ids[racer.get_instance_id()] = true
		if _v5_lead_ids.size() >= 3:
			break

func _assign_branch_routes() -> void:
	var populations: Dictionary = {}
	for index: int in range(ai_racers.size()):
		if index >= ai_drivers.size():
			break
		var racer: WildDashCharacterController = ai_racers[index]
		var driver: WildDashAIController = ai_drivers[index]
		if racer == null or driver == null:
			continue
		var route_id: StringName = _route_network.choose_route(racer.animal_id, index, populations)
		var route: Array[Vector3] = _route_network.get_route(route_id)
		if route.size() < 2:
			route_id = WildDashWildTideRouteNetwork.ROUTE_BALANCED
			route = _route_network.get_route(route_id)
		if route.size() >= 2:
			_append_finish_runout(route)
			driver.set_race_route(route)
		_v5_route_by_racer[racer.get_instance_id()] = route_id
		_v5_slot_by_racer[racer.get_instance_id()] = index
		populations[route_id] = int(populations.get(route_id, 0)) + 1
	print("ROUND3 ROUTE POPULATION water=%d land=%d elevated=%d canopy=%d breakthrough=%d balanced=%d" % [
		int(populations.get(WildDashWildTideRouteNetwork.ROUTE_DEEP_WATER, 0)),
		int(populations.get(WildDashWildTideRouteNetwork.ROUTE_DRY_DOCK, 0)),
		int(populations.get(WildDashWildTideRouteNetwork.ROUTE_ELEVATED, 0)),
		int(populations.get(WildDashWildTideRouteNetwork.ROUTE_CANOPY, 0)),
		int(populations.get(WildDashWildTideRouteNetwork.ROUTE_BREAKTHROUGH, 0)),
		int(populations.get(WildDashWildTideRouteNetwork.ROUTE_BALANCED, 0)),
	])

func _apply_start_spread_profiles() -> void:
	for index: int in range(ai_racers.size()):
		if index >= ai_drivers.size():
			break
		var racer: WildDashCharacterController = ai_racers[index]
		var driver: WildDashAIController = ai_drivers[index]
		if racer == null or driver == null:
			continue
		var column: int = index % 5
		var base_lane: float = (float(column) - 2.0) * 0.72
		if index % 2 == 1:
			base_lane *= -1.0
		_v5_base_lane_by_racer[racer.get_instance_id()] = base_lane
		driver.preferred_lane = base_lane
		driver.lane_wander = 0.12 + float(index % 3) * 0.05
		driver.avoidance_distance = 9.0 + float(index % 2) * 0.8

func _get_start_grid_offset(slot: int) -> Vector3:
	# Five columns and deeper rows stop fifteen racers spawning as one compact
	# four-column ball while staying inside the 20 m opening road.
	var columns: int = 5
	var row: int = slot / columns
	var column: int = slot % columns
	var center: float = float(columns - 1) * 0.5
	var stagger: float = 0.55 if row % 2 == 1 else 0.0
	return Vector3((float(column) - center) * 2.85 + stagger, 0.1, float(row) * 4.15)

func _round3_desired_speed(racer: WildDashCharacterController, base_speed: float) -> float:
	if racer == null:
		return base_speed
	return base_speed * _v5_pace_tier_scale(racer) * _round3_difficulty_scale()

func _round3_gap_scale(progress_gap: float) -> float:
	# V3 started slowing leaders at only 20 m and reached 0.90x by 90 m. Combined
	# with AIController's own gentle rubber band this made the whole field wait.
	# V5 leaves normal racing alone until the lead is genuinely large.
	if progress_gap >= 105.0:
		return 0.955
	if progress_gap >= 80.0:
		return 0.970
	if progress_gap >= 55.0:
		return 0.985
	if progress_gap <= -75.0:
		return 1.020
	return 1.0

func _round3_update_ai_pace(_elapsed: float) -> void:
	if not _v5_initialized or player == null:
		return
	_update_v5_pace_and_dispersion()

func _update_wild_tide_ai() -> void:
	if not _v5_initialized or player == null:
		return
	var hazard_serial: int = -1
	var hazard_type: StringName = &""
	var hazard_center: Vector3 = Vector3.ZERO
	if _titan_controller != null:
		hazard_serial = _titan_controller.get_hazard_serial()
		hazard_type = _titan_controller.get_active_hazard()
		hazard_center = _titan_controller.get_active_hazard_center()
	if hazard_serial != _last_hazard_serial and hazard_type != &"":
		_last_hazard_serial = hazard_serial
		_assign_hazard_responses(hazard_serial, hazard_type, hazard_center)
	_update_v5_pace_and_dispersion()

func _update_v5_pace_and_dispersion() -> void:
	var player_progress: float = RaceManager.get_track_progress(player)
	var race_seconds: float = RaceManager.get_elapsed_seconds()
	var now_seconds: float = Time.get_ticks_msec() / 1000.0
	for index: int in range(ai_racers.size()):
		if index >= ai_drivers.size():
			break
		var racer: WildDashCharacterController = ai_racers[index]
		var driver: WildDashAIController = ai_drivers[index]
		if racer == null or driver == null or racer.finished:
			continue
		var racer_id: int = racer.get_instance_id()
		var base_speed: float = _round3_get_canonical_ai_speed(racer)
		var gap: float = RaceManager.get_track_progress(racer) - player_progress
		var gap_scale: float = _round3_gap_scale(gap)
		var tier_scale: float = _v5_pace_tier_scale(racer)
		if race_seconds <= OPENING_LEAD_SECONDS and _v5_lead_ids.has(racer_id):
			tier_scale *= OPENING_LEAD_BONUS
		var terrain_scale: float = float(racer.get_meta(&"wild_tide_speed_multiplier", 1.0))
		var desired: float = base_speed * tier_scale * _round3_difficulty_scale() * gap_scale * terrain_scale
		var min_scale: float = 0.82 if terrain_scale < 0.95 else 0.92
		var max_scale: float = 1.48 if racer.animal_id == &"crocodile" else 1.24
		driver.target_speed = clampf(desired, base_speed * min_scale, base_speed * max_scale)

		var dodge_until: float = float(_hazard_dodge_until_by_id.get(racer_id, 0.0))
		if dodge_until > now_seconds:
			continue
		_hazard_dodge_until_by_id.erase(racer_id)
		var base_lane: float = float(_v5_base_lane_by_racer.get(racer_id, 0.0))
		var separation: float = _calculate_local_separation(racer)
		driver.preferred_lane = clampf(base_lane + separation, -3.2, 3.2)

func _v5_pace_tier_scale(racer: WildDashCharacterController) -> float:
	if racer == null:
		return 1.0
	if FAST_IDS.has(racer.animal_id):
		return FAST_PACE_SCALE
	if MID_IDS.has(racer.animal_id):
		return MID_PACE_SCALE
	if POWER_IDS.has(racer.animal_id):
		return POWER_PACE_SCALE
	return 1.03

func _calculate_local_separation(racer: WildDashCharacterController) -> float:
	var right: Vector3 = racer.global_transform.basis.x
	right.y = 0.0
	if right.length_squared() <= 0.001:
		right = Vector3.RIGHT
	else:
		right = right.normalized()
	var steer: float = 0.0
	var nearby: int = 0
	for other_value: Variant in RaceManager.racers:
		var other: WildDashCharacterController = other_value as WildDashCharacterController
		if other == null or other == racer or other.finished:
			continue
		var offset: Vector3 = other.global_position - racer.global_position
		offset.y = 0.0
		var distance: float = offset.length()
		if distance <= 0.05 or distance > SEPARATION_FAR:
			continue
		nearby += 1
		var side: float = offset.dot(right)
		var away_sign: float = -1.0 if side >= 0.0 else 1.0
		if absf(side) < 0.20:
			away_sign = -1.0 if racer.get_instance_id() % 2 == 0 else 1.0
		var weight: float = 1.0 - clampf((distance - SEPARATION_NEAR) / maxf(0.1, SEPARATION_FAR - SEPARATION_NEAR), 0.0, 1.0)
		if distance <= SEPARATION_NEAR:
			weight = 1.0
		steer += away_sign * (0.75 + weight * 1.35)
	if nearby >= 3 and absf(steer) < 0.45:
		steer = -1.5 if racer.get_instance_id() % 2 == 0 else 1.5
	return clampf(steer, -MAX_SEPARATION_LANE, MAX_SEPARATION_LANE)

func _round3_log_pack_state() -> void:
	if _v5_initialized:
		_log_v5_pack_state()

func _log_v5_pack_state() -> void:
	if RaceManager.racers.is_empty():
		return
	var leader_progress: float = -INF
	for racer_value: Variant in RaceManager.racers:
		var racer: WildDashCharacterController = racer_value as WildDashCharacterController
		if racer != null and not racer.finished:
			leader_progress = maxf(leader_progress, RaceManager.get_track_progress(racer))
	if leader_progress == -INF:
		return
	var lead_pack: int = 0
	var main_pack: int = 0
	var chase_pack: int = 0
	var max_cluster: int = 0
	for racer_value: Variant in RaceManager.racers:
		var racer: WildDashCharacterController = racer_value as WildDashCharacterController
		if racer == null or racer.finished:
			continue
		var gap_to_leader: float = leader_progress - RaceManager.get_track_progress(racer)
		if gap_to_leader <= 15.0:
			lead_pack += 1
		elif gap_to_leader <= 48.0:
			main_pack += 1
		else:
			chase_pack += 1
		var cluster: int = 1
		for other_value: Variant in RaceManager.racers:
			var other: WildDashCharacterController = other_value as WildDashCharacterController
			if other == null or other == racer or other.finished:
				continue
			if racer.global_position.distance_to(other.global_position) <= 5.0:
				cluster += 1
		max_cluster = maxi(max_cluster, cluster)
	print("ROUND3 AI PACK STATE lead_pack=%d main_pack=%d chase_pack=%d max_cluster=%d fast_lead_target=%d routes=%d" % [
		lead_pack, main_pack, chase_pack, max_cluster, _v5_lead_ids.size(), _route_network.get_route_count() if _route_network != null else 0,
	])
