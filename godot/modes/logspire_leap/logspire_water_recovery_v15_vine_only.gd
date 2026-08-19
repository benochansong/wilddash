extends "res://modes/logspire_leap/logspire_water_recovery_v14_safe_vine_reentry.gd"

## Round 3 vine-only recovery authority.
## Falling into water no longer asks the player or AI to find a root stair or
## ladder. After a very short readable splash pause, Vine Rescue pulls the racer
## back to the audited Safe Route re-entry supplied by V14.
## Existing ladder/root source stays preserved, but production recovery does not
## select or traverse those routes.

const VINE_ONLY_CAPTURE_DELAY_SECONDS: float = 0.22

var _vine_only_elapsed_by_id: Dictionary = {}

func _enter_water(racer: WildDashCharacterController, zone: int, water_y: float) -> void:
	super(racer, zone, water_y)
	if racer == null or not is_instance_valid(racer) or not is_water_recovering(racer):
		return
	var racer_id: int = racer.get_instance_id()
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
	_vine_only_elapsed_by_id.erase(racer_id)
	super(racer_id)
