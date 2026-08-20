extends "res://modes/logspire_leap/logspire_water_recovery_v14_safe_vine_reentry.gd"

## Round 3 vine-only recovery authority.
## Falling into water no longer asks the player or AI to find a root stair or
## ladder. After a short confirmed submersion, Vine Rescue pulls the racer back
## to the audited Safe Route re-entry supplied by V14.
## Existing ladder/root source stays preserved, but production recovery does not
## select or traverse those routes.
##
## Water-graze safety:
## CharacterRoot is the racer foot origin. Merely overlapping the water Area3D,
## brushing the surface, or momentarily losing is_on_floor() on a rounded log is
## never enough to enter recovery. The feet must be meaningfully below the water
## surface, no solid support may exist under the footprint, and that unsupported
## submerged state must persist for a short confirmation window.
##
## Direct-vine handoff:
## older recovery layers snap a confirmed fall to the visible water surface
## before choosing a ladder/root route. V15 keeps their bookkeeping but restores
## the actual fall position in the same physics step and starts Vine Rescue
## immediately, so the camera never cuts to a temporary water-surface tableau.

const VINE_ONLY_CAPTURE_DELAY_SECONDS: float = 0.22
const VINE_ONLY_REQUIRED_FOOT_SUBMERSION: float = 0.26
const VINE_ONLY_ENTRY_CONFIRM_SECONDS: float = 0.18
const VINE_ONLY_SUPPORT_GRACE_SECONDS: float = 0.24
const VINE_ONLY_SUPPORT_PROBE_UP: float = 0.24
const VINE_ONLY_SUPPORT_PROBE_DEPTH: float = 1.35
const VINE_ONLY_SUPPORT_SAMPLE_RADIUS_MIN: float = 0.42
const VINE_ONLY_SUPPORT_SAMPLE_RADIUS_MAX: float = 0.72
const VINE_ONLY_SUPPORT_MAX_DROP: float = 0.92
const VINE_ONLY_WORLD_SUPPORT_MASK: int = 5

var _vine_only_elapsed_by_id: Dictionary = {}
var _vine_only_entry_candidate_since_msec_by_id: Dictionary = {}
var _vine_only_last_support_msec_by_id: Dictionary = {}

func _is_real_water_entry(racer: WildDashCharacterController, water_y: float) -> bool:
	if racer == null or not is_instance_valid(racer) or racer.finished or not RaceManager.active:
		return false
	var racer_id: int = racer.get_instance_id()
	var now_msec: int = Time.get_ticks_msec()

	# Grounded racers and racers with any nearby solid support under their foot
	# footprint are still racing. This is the key rounded-log/cylinder guard.
	if racer.is_on_floor() or _has_nearby_surface_support(racer):
		_vine_only_last_support_msec_by_id[racer_id] = now_msec
		_vine_only_entry_candidate_since_msec_by_id.erase(racer_id)
		return false

	# A genuine fall must still be descending. Surface skim, jump apex and upward
	# bounce frames cannot become water recovery.
	if racer.velocity.y > WATER_ENTRY_MIN_DOWN_SPEED:
		_vine_only_entry_candidate_since_msec_by_id.erase(racer_id)
		return false

	# CharacterRoot is the foot origin. Require the feet themselves to be below
	# the surface instead of accepting a body capsule that merely touches water.
	if racer.global_position.y > water_y - VINE_ONLY_REQUIRED_FOOT_SUBMERSION:
		_vine_only_entry_candidate_since_msec_by_id.erase(racer_id)
		return false

	# Rounded moving logs can lose floor contact for a frame at an edge. Give the
	# last confirmed support a short grace period before water can take authority.
	var last_support_msec: int = int(_vine_only_last_support_msec_by_id.get(racer_id, -1000000))
	if last_support_msec > 0:
		var since_support_seconds: float = float(now_msec - last_support_msec) / 1000.0
		if since_support_seconds < VINE_ONLY_SUPPORT_GRACE_SECONDS:
			_vine_only_entry_candidate_since_msec_by_id.erase(racer_id)
			return false

	# The unsupported, foot-submerged state must persist. A real fall naturally
	# remains valid; a one-frame graze resets before Vine Rescue can begin.
	if not _vine_only_entry_candidate_since_msec_by_id.has(racer_id):
		_vine_only_entry_candidate_since_msec_by_id[racer_id] = now_msec
		return false
	var started_msec: int = int(_vine_only_entry_candidate_since_msec_by_id.get(racer_id, now_msec))
	var confirmed_seconds: float = float(now_msec - started_msec) / 1000.0
	return confirmed_seconds >= VINE_ONLY_ENTRY_CONFIRM_SECONDS

func should_handle_racer(racer: WildDashCharacterController) -> bool:
	if racer == null or not is_instance_valid(racer):
		return false
	if bool(racer.get_meta(WATER_META, false)):
		return true
	var racer_id: int = racer.get_instance_id()
	var state: int = int(_state_by_id.get(racer_id, WaterState.RACING))
	if state not in [WaterState.RACING, WaterState.FALLING]:
		return true
	if racer.is_on_floor() or _has_nearby_surface_support(racer):
		return false
	if racer.velocity.y > WATER_ENTRY_MIN_DOWN_SPEED:
		return false
	var pool: Dictionary = _pool_for_position(racer.global_position)
	if pool.is_empty():
		return false
	var water_y: float = float(pool.get("water_y", -999.0))
	return racer.global_position.y <= water_y - VINE_ONLY_REQUIRED_FOOT_SUBMERSION * 0.5

func _has_nearby_surface_support(racer: WildDashCharacterController) -> bool:
	if racer == null or not is_instance_valid(racer):
		return false
	var world: World3D = racer.get_world_3d()
	if world == null:
		return false

	var sample_radius: float = 0.50
	var collision := racer.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision != null:
		var capsule := collision.shape as CapsuleShape3D
		if capsule != null:
			sample_radius = clampf(
				capsule.radius * 0.78,
				VINE_ONLY_SUPPORT_SAMPLE_RADIUS_MIN,
				VINE_ONLY_SUPPORT_SAMPLE_RADIUS_MAX
			)

	var right: Vector3 = racer.global_transform.basis.x
	right.y = 0.0
	if right.length_squared() <= 0.001:
		right = Vector3.RIGHT
	else:
		right = right.normalized()
	var forward: Vector3 = -racer.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.001:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()
	var diagonal_a := (right + forward).normalized()
	var diagonal_b := (right - forward).normalized()
	var offsets: Array[Vector3] = [
		Vector3.ZERO,
		right * sample_radius,
		-right * sample_radius,
		forward * sample_radius,
		-forward * sample_radius,
		diagonal_a * sample_radius,
		-diagonal_a * sample_radius,
		diagonal_b * sample_radius,
		-diagonal_b * sample_radius,
	]

	for offset: Vector3 in offsets:
		var ray_from: Vector3 = racer.global_position + offset + Vector3.UP * VINE_ONLY_SUPPORT_PROBE_UP
		var ray_to: Vector3 = racer.global_position + offset - Vector3.UP * VINE_ONLY_SUPPORT_PROBE_DEPTH
		var query := PhysicsRayQueryParameters3D.create(ray_from, ray_to)
		query.collision_mask = VINE_ONLY_WORLD_SUPPORT_MASK
		query.exclude = [racer.get_rid()]
		query.collide_with_areas = false
		query.collide_with_bodies = true
		query.hit_from_inside = true
		var hit: Dictionary = world.direct_space_state.intersect_ray(query)
		if hit.is_empty():
			continue
		var hit_position: Vector3 = hit.get("position", Vector3.INF)
		if hit_position == Vector3.INF:
			continue
		var drop: float = racer.global_position.y - hit_position.y
		if drop >= -0.12 and drop <= VINE_ONLY_SUPPORT_MAX_DROP:
			return true
	return false

func _enter_water(racer: WildDashCharacterController, zone: int, water_y: float) -> void:
	if racer == null or not is_instance_valid(racer) or racer.finished or not RaceManager.active:
		return
	var racer_id: int = racer.get_instance_id()
	var state: int = int(_state_by_id.get(racer_id, WaterState.RACING))

	# V10 has an emergency deep-water reacquire path that can call _enter_water()
	# without going through V3/V15 entry guards. Make this function the final
	# authority too, so no inherited path can bypass the rounded-log protection.
	if not is_water_recovering(racer) and state in [WaterState.RACING, WaterState.FALLING]:
		if not _is_real_water_entry(racer, water_y):
			print("LOGSPIRE VINE ENTRY BYPASS REJECT racer=%s zone=%d body_y=%.2f water_y=%.2f strict_guard=true" % [
				RaceManager.get_racer_label(racer), zone + 1, racer.global_position.y, water_y,
			])
			return

	# Preserve the true fall position. Older recovery code temporarily snaps the
	# racer to water_y + 0.62, which produced the visible one-frame camera cut to
	# the water surface even though R3 immediately uses Vine Rescue afterward.
	var fall_position: Vector3 = racer.global_position
	super(racer, zone, water_y)
	if racer == null or not is_instance_valid(racer) or not is_water_recovering(racer):
		return

	racer.global_position = fall_position
	racer.velocity = Vector3.ZERO
	racer.current_speed = 0.0
	_vine_only_entry_candidate_since_msec_by_id.erase(racer_id)
	_vine_only_last_support_msec_by_id.erase(racer_id)
	_vine_only_elapsed_by_id[racer_id] = VINE_ONLY_CAPTURE_DELAY_SECONDS
	_preferred_target_by_id.erase(racer_id)
	_ladder_by_id.erase(racer_id)
	_clear_recovery_camera_focus_if_needed(racer)
	_set_ux_state(racer, RecoveryUXState.SWIMMING)

	# Start the direct pull in the same physics step. This removes the obsolete
	# intermediate water-surface tableau while retaining the visible vine motion.
	_begin_vine_rescue(racer)
	var direct_started: bool = StringName(_traversal_kind_by_id.get(racer_id, &"")) == &"vine_rescue"
	if racer.is_player and DisplayServer.get_name() != "headless":
		_set_hud_message("VINE RESCUE · HOLD ON!" if direct_started else "VINE RESCUE · INCOMING")
	print("LOGSPIRE VINE ONLY RECOVERY START racer=%s zone=%d direct_vine=%s water_surface_snap=false foot_submersion=%.2fm support_guard=9ray ladder=false stairs=false" % [
		RaceManager.get_racer_label(racer), zone + 1, str(direct_started), VINE_ONLY_REQUIRED_FOOT_SUBMERSION,
	])

func _update_swimming(racer: WildDashCharacterController, delta: float) -> void:
	if racer == null or not is_instance_valid(racer) or not is_water_recovering(racer):
		return
	_cancel_stale_checkpoint_recovery(racer)
	racer.collision_mask = 1
	var racer_id: int = racer.get_instance_id()
	var traversal_kind := StringName(_traversal_kind_by_id.get(racer_id, &""))
	if traversal_kind != &"":
		return

	_preferred_target_by_id.erase(racer_id)
	_ladder_by_id.erase(racer_id)
	_clear_recovery_camera_focus_if_needed(racer)
	var water_y: float = float(_water_y_by_id.get(racer_id, racer.global_position.y))
	_enforce_surface_lock(racer, water_y, delta)
	racer.velocity.x = 0.0
	racer.velocity.z = 0.0

	var elapsed: float = float(_vine_only_elapsed_by_id.get(racer_id, 0.0)) + delta
	_vine_only_elapsed_by_id[racer_id] = elapsed
	if elapsed < VINE_ONLY_CAPTURE_DELAY_SECONDS:
		return

	_begin_vine_rescue(racer)
	if StringName(_traversal_kind_by_id.get(racer_id, &"")) == &"vine_rescue":
		print("LOGSPIRE VINE ONLY CAPTURE racer=%s elapsed=%.2f direct_pull=true ladder=false stairs=false" % [
			RaceManager.get_racer_label(racer), elapsed,
		])

func _choose_recovery_target(_racer: WildDashCharacterController, _zone: int) -> Dictionary:
	return {}

func _ladder_capture_candidate(_racer: WildDashCharacterController, _zone: int) -> Dictionary:
	return {}

func _begin_root_climb(racer: WildDashCharacterController, _ramp: Dictionary) -> void:
	_begin_vine_rescue(racer)

func _begin_ladder_climb(racer: WildDashCharacterController, _ladder: Dictionary) -> void:
	_begin_vine_rescue(racer)

func _clear_reliability_runtime(racer_id: int) -> void:
	_vine_only_entry_candidate_since_msec_by_id.erase(racer_id)
	_vine_only_last_support_msec_by_id.erase(racer_id)
	_vine_only_elapsed_by_id.erase(racer_id)
	super(racer_id)
