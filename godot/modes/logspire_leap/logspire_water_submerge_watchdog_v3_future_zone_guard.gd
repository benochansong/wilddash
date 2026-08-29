extends "res://modes/logspire_leap/logspire_water_submerge_watchdog_v2_route_guard.gd"

## Keep the emergency submerge watchdog from becoming a second CP4 rewind path
## while WaterRecovery V17 is deliberately rejecting the future Z6 water volume.
## The primary recovery layer exposes the progression lock; during that lock the
## watchdog treats WaterRecovery as authoritative and never calls its inherited
## hard checkpoint escape. Once CP6 is reached, normal watchdog behavior resumes.

const FUTURE_ZONE_WATCHDOG_LOG_COOLDOWN_MSEC: int = 1500

var _future_zone_watchdog_last_log_msec_by_id: Dictionary = {}

func _ready() -> void:
	super()
	print("LOGSPIRE SUBMERGE WATCHDOG V3 READY future_zone_lock_defer=true cp4_to_cp5_hard_escape_block=true")

func _primary_water_recovery_active(racer: WildDashCharacterController) -> bool:
	if racer != null and is_instance_valid(racer) and _water != null and is_instance_valid(_water):
		if _water.has_method("is_future_water_locked_for_racer") and bool(_water.call("is_future_water_locked_for_racer", racer)):
			_log_future_zone_watchdog_defer(racer)
			return true
	return super(racer)

func _log_future_zone_watchdog_defer(racer: WildDashCharacterController) -> void:
	if racer == null or not is_instance_valid(racer):
		return
	var racer_id: int = racer.get_instance_id()
	var now_msec: int = Time.get_ticks_msec()
	var last_msec: int = int(_future_zone_watchdog_last_log_msec_by_id.get(racer_id, -1000000))
	if now_msec - last_msec < FUTURE_ZONE_WATCHDOG_LOG_COOLDOWN_MSEC:
		return
	_future_zone_watchdog_last_log_msec_by_id[racer_id] = now_msec
	print("r3_water_watchdog_future_zone_deferred racer=%s checkpoint=%d hard_checkpoint_escape=false no_rewind=true authority=WaterRecoveryV17" % [
		RaceManager.get_racer_label(racer),
		RaceManager.get_checkpoint_progress(racer),
	])
