extends "res://modes/logspire_leap/logspire_water_recovery_v3_entry_guard.gd"

## Deep-swim recovery pass.
## Normal water recovery must end at a ladder, not at a checkpoint timer.
## Checkpoint recovery remains only for genuinely invalid states such as a zone
## with no valid ladder or leaving the authored water volume entirely.

func _enter_water(racer: WildDashCharacterController, zone: int, water_y: float) -> void:
	super(racer, zone, water_y)
	if racer == null or not is_instance_valid(racer):
		return
	if not bool(racer.get_meta(WATER_META, false)):
		return
	var visual := racer.get_visual()
	if visual != null:
		# No dedicated production Swim clip exists yet. Jump pose keeps the body
		# visibly afloat instead of looking like a ground-running animation.
		visual.play_state(&"Jump", true)

func _start_checkpoint_fallback(racer: WildDashCharacterController, reason: String) -> void:
	if racer == null or not is_instance_valid(racer):
		return
	if reason == "water_timeout" or reason == "ladder_path_failure":
		var racer_id: int = racer.get_instance_id()
		var zone: int = int(_zone_by_id.get(racer_id, 0))
		var ladders: Array = _ladder_system.call("get_ladders_for_zone", zone) if _ladder_system != null else []
		var ladder: Dictionary = _water_ai.call(
			"choose_ladder",
			racer,
			zone,
			ladders,
			RaceManager.get_checkpoint_progress(racer)
		) if _water_ai != null else {}
		if not ladder.is_empty():
			_ladder_by_id[racer_id] = ladder
			_water_elapsed_by_id[racer_id] = 0.0
			_state_by_id[racer_id] = WaterState.SWIMMING
			if racer.is_player and DisplayServer.get_name() != "headless":
				_set_hud_message("KEEP SWIMMING · REACH THE LADDER")
			print("LOGSPIRE WATER RECOVERY RETRY racer=%s reason=%s ladder=%s checkpoint_respawn=false" % [
				RaceManager.get_racer_label(racer),
				reason,
				String(ladder.get("id", &"")),
			])
			return
	super(racer, reason)

func _finish_water_recovery(racer: WildDashCharacterController) -> void:
	super(racer)
	if racer == null or not is_instance_valid(racer):
		return
	var visual := racer.get_visual()
	if visual != null:
		visual.play_state(&"Idle", true)
