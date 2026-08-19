extends "res://modes/logspire_leap/logspire_water_recovery_v14_safe_vine_reentry.gd"

## Round 3 vine-only recovery authority.
## Falling into water no longer asks the player or AI to find a root stair or
## ladder. After a very short readable splash pause, Vine Rescue pulls the racer
## back to the audited Safe Route re-entry supplied by V14.
## Existing ladder/root source stays preserved, but production recovery does not
## select or traverse those routes.
##
## Water-graze safety:
## touching the water Area3D is not enough to start recovery. Round 3 contains
## low logs and cylinders whose tops sit close to the water surface, so a racer
## can briefly lose Godot's is_on_floor state while still being physically
## supported. V15 therefore requires meaningful immersion, no nearby dry/world
## support under the racer, and a short sustained-water confirmation window.

const VINE_ONLY_CAPTURE_DELAY_SECONDS: float = 0.22
const VINE_ONLY_ENTRY_MAX_BODY_ABOVE_SURFACE: float = 0.72
const VINE_ONLY_ENTRY_CONFIRM_SECONDS: float = 0.12
const VINE_ONLY_SUPPORT_PROBE_UP: float = 0.18
const VINE_ONLY_SUPPORT_PROBE_DEPTH: float = 1.65
const VINE_ONLY_SUPPORT_SURFACE_TOLERANCE: float = 0.20
const VINE_ONLY_WORLD_SUPPORT_MASK: int = 1

var _vine_only_elapsed_by_id: Dictionary = {}
var _vine_only_entry_candidate_since_msec_by_id: Dictionary = {}

func _is_real_water_entry(racer: WildDashCharacterController, water_y: float) -> bool:
	if racer == null or not is_instance_valid(racer):
		return false
	var racer_id: int = racer.get_instance_id()

	# Keep all proven V3 entry guards first: racers on a floor, racers that are
	# not descending, and bodies still clearly above the surface are rejected.
	if not super(racer, water_y):
		_vine_only_entry_candidate_since_msec_by_id.erase(racer_id)
		return false

	# V3 intentionally had a generous 1.05 m body band. For the low cylinders in
	# Titan Tree that can classify a foot-level graze as water entry. Require the
	# body to sink farther before Vine-only recovery is even considered.
	if racer.global_position.y > water_y + VINE_ONLY_ENTRY_MAX_BODY_ABOVE_SURFACE:
		_vine_only_entry_candidate_since_msec_by_id.erase(racer_id)
		return false

	# is_on_floor() can flicker false for a physics frame on rounded logs. A short
	# world-only ray catches the actual support surface and keeps the racer alive
	# when a log/cylinder is still directly underneath at water level or above.
	if _has_nearby_surface_support(racer, water_y):
		_vine_only_entry_candidate_since_msec_by_id.erase(racer_id)
		return false

	# A splash/graze must persist briefly before becoming authoritative water
	# recovery. A genuine fall keeps descending and passes this window naturally.
	var now_msec: int = Time.get_ticks_msec()
	if not _vine_only_entry_candidate_since_msec_by_id.has(racer_id):
		_vine_only_entry_candidate_since_msec_by_id[racer_id] = now_msec
		return false
	var started_msec: int = int(_vine_only_entry_candidate_since_msec_by_id.get(racer_id, now_msec))
	var confirmed_seconds: float = float(now_msec - started_msec) / 1000.0
	return confirmed_seconds >= VINE_ONLY_ENTRY_CONFIRM_SECONDS

func _has_nearby_surface_support(racer: WildDashCharacterController, water_y: float) -> bool:
	if racer == null or not is_instance_valid(racer):
		return false
	var world: World3D = racer.get_world_3d()
	if world == null:
		return false

	var ray_from: Vector3 = racer.global_position + Vector3.UP * VINE_ONLY_SUPPORT_PROBE_UP
	var ray_to: Vector3 = racer.global_position - Vector3.UP * VINE_ONLY_SUPPORT_PROBE_DEPTH
	var query := PhysicsRayQueryParameters3D.create(ray_from, ray_to)
	query.collision_mask = VINE_ONLY_WORLD_SUPPORT_MASK
	query.exclude = [racer.get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit: Dictionary = world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var hit_position: Vector3 = hit.get("position", Vector3.INF)
	if hit_position == Vector3.INF:
		return false
	return hit_position.y >= water_y - VINE_ONLY_SUPPORT_SURFACE_TOLERANCE

func _enter_water(racer: WildDashCharacterController, zone: int, water_y: float) -> void:
	super(racer, zone, water_y)
	if racer == null or not is_instance_valid(racer) or not is_water_recovering(racer):
		return
	var racer_id: int = racer.get_instance_id()
	_vine_only_entry_candidate_since_msec_by_id.erase(racer_id)
	_vine_only_elapsed_by_id[racer_id] = 0.0
	_preferred_target_by_id.erase(racer_id)
	_ladder_by_id.erase(racer_id)
	_set_ux_state(racer, RecoveryUXState.SWIMMING)
	if racer.is_player and DisplayServer.get_name() != "headless":
		_set_hud_message("VINE RESCUE · INCOMING")
	print("LOGSPIRE VINE ONLY RECOVERY START racer=%s zone=%d splash_delay=%.2fs ladder=false stairs=false" % [
		RaceManager.get_racer_label(racer), zone + 1, VINE_ONLY_CAPTURE_DELAY_SECONDS,
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
	_vine_only_elapsed_by_id.erase(racer_id)
	super(racer_id)
