extends "res://modes/logspire_leap/logspire_water_recovery_v16_upper_canopy_cleanup.gd"

## Round 3 Titan Tree future-zone water authority guard.
##
## The Z6 canopy-river recovery volume is intentionally broad and sits near the
## same world height as the upper Titan spiral. During the CP4 -> CP5 climb, the
## player can therefore overlap the *future* Z6 water Area3D while still standing
## on authored Titan platforms, flow bridges or the CP5 landing shelf. A short
## loss of floor contact at a seam was enough for the inherited recovery stack to
## claim the racer and fall back to CP4, producing the observed 73% -> 62% rewind.
##
## Zone ownership is now progression-gated: Z6 water may not own a racer until
## the racer has actually reached the Z6_START checkpoint (CP6). A genuine fall
## before that point continues downward into the lower Titan water authority or
## the normal absolute-fall fail-safe; it is never converted into an early Z6
## checkpoint rewind. No racer transform, jump power or checkpoint progress is
## changed by this guard.

const FUTURE_WATER_ZONE_INDEX: int = 5
const FUTURE_WATER_UNLOCK_CHECKPOINT: int = 6
const FUTURE_WATER_GUARD_LOG_COOLDOWN_MSEC: int = 1200

var _future_water_guard_last_log_msec_by_id: Dictionary = {}

func _ready() -> void:
	super()
	print("LOGSPIRE WATER V17 TITAN FUTURE-ZONE GUARD READY z6_unlock_cp=%d cp4_to_cp5_rewind_block=true primary_authority_guard=true transform_write=false checkpoint_write=false" % FUTURE_WATER_UNLOCK_CHECKPOINT)

func is_future_water_locked_for_racer(racer: WildDashCharacterController) -> bool:
	if racer == null or not is_instance_valid(racer) or racer.finished or not RaceManager.active:
		return false
	if is_water_recovering(racer):
		return false
	if RaceManager.get_checkpoint_progress(racer) >= FUTURE_WATER_UNLOCK_CHECKPOINT:
		return false
	var pool: Dictionary = _pool_for_position(racer.global_position)
	if pool.is_empty():
		return false
	return int(pool.get("zone", -1)) == FUTURE_WATER_ZONE_INDEX

func should_handle_racer(racer: WildDashCharacterController) -> bool:
	if racer == null or not is_instance_valid(racer):
		return false
	if is_water_recovering(racer):
		return super(racer)
	if is_future_water_locked_for_racer(racer):
		_log_future_zone_block(racer, "should_handle")
		return false
	return super(racer)

func _enter_water(racer: WildDashCharacterController, zone: int, water_y: float) -> void:
	if racer == null or not is_instance_valid(racer) or racer.finished:
		return
	if zone == FUTURE_WATER_ZONE_INDEX and RaceManager.get_checkpoint_progress(racer) < FUTURE_WATER_UNLOCK_CHECKPOINT and not is_water_recovering(racer):
		# V15 keeps a short unsupported-entry confirmation timer. Clear it whenever
		# a future-zone overlap is rejected so repeated bridge-seam frames cannot
		# accumulate into a delayed false capture.
		_vine_only_entry_candidate_since_msec_by_id.erase(racer.get_instance_id())
		_log_future_zone_block(racer, "enter_water")
		return
	super(racer, zone, water_y)

func _log_future_zone_block(racer: WildDashCharacterController, source: String) -> void:
	if racer == null or not is_instance_valid(racer):
		return
	var racer_id: int = racer.get_instance_id()
	var now_msec: int = Time.get_ticks_msec()
	var last_msec: int = int(_future_water_guard_last_log_msec_by_id.get(racer_id, -1000000))
	if now_msec - last_msec < FUTURE_WATER_GUARD_LOG_COOLDOWN_MSEC:
		return
	_future_water_guard_last_log_msec_by_id[racer_id] = now_msec
	print("r3_future_zone_water_blocked racer=%s source=%s checkpoint=%d required_checkpoint=%d pool_zone=6 titan_route_active=true no_water_capture=true no_checkpoint_rewind=true" % [
		RaceManager.get_racer_label(racer),
		source,
		RaceManager.get_checkpoint_progress(racer),
		FUTURE_WATER_UNLOCK_CHECKPOINT,
	])
