extends Node

# Production players never have a WildDashAIController, so the headless
# WILDDASH_REALTIME_BALANCE pilot must not be allowed to use AI-only forward
# waypoint stall recovery. Otherwise a projection stall can teleport the
# synthetic player hundreds of metres ahead and produce a falsely short race.
# Real falls below the course still use the normal checkpoint recovery path.
func _physics_process(_delta: float) -> void:
	if DisplayServer.get_name() != "headless" or not OS.has_environment("WILDDASH_REALTIME_BALANCE"):
		return
	var mode := get_parent()
	if mode == null:
		return
	for driver_variant in mode.ai_drivers:
		var driver := driver_variant as WildDashAIController
		if driver == null or not driver.preserve_player_identity:
			continue
		# These are runtime state fields, not gameplay tuning values. Resetting only
		# the stall accumulator disables the AI-only forward snap for the synthetic
		# human pilot while retaining steering, collision and checkpoint recovery.
		driver.set("_recovery_stagnant_seconds", 0.0)
