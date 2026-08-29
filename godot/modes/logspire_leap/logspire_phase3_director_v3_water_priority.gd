extends "res://modes/logspire_leap/logspire_phase3_director_v2_performance.gd"

## Water recovery owns the racer once a splash has happened.
## The finale's delayed recovery branch must not teleport a swimmer away before
## they can reach and climb a ladder.

func _recover_final_after_delay(racer: WildDashCharacterController, racer_id: int) -> void:
	await get_tree().create_timer(FINAL_RECOVERY_DELAY_SECONDS).timeout
	if racer == null or not is_instance_valid(racer) or racer.finished:
		_final_recovery_pending.erase(racer_id)
		return
	if bool(racer.get_meta(&"logspire_water_recovery_active", false)):
		_final_recovery_pending.erase(racer_id)
		print("LOGSPIRE FINAL RECOVERY CANCELLED BY WATER racer=%s ladder_priority=true" % RaceManager.get_racer_label(racer))
		return
	var water := get_parent().get_node_or_null("WaterRecovery")
	if water != null and water.has_method("should_handle_racer") and bool(water.call("should_handle_racer", racer)):
		_final_recovery_pending.erase(racer_id)
		print("LOGSPIRE FINAL RECOVERY CANCELLED BY WATER racer=%s water_authority=true" % RaceManager.get_racer_label(racer))
		return
	var target: Vector3 = _platform_position(&"Z6_07") + Vector3.UP * 1.35
	var forward: Vector3 = _platform_forward(&"Z6_07")
	racer.reset_motion(target)
	racer.current_speed = racer.cruise_speed * 0.82
	if forward.length_squared() > 0.001:
		racer.rotation.y = atan2(-forward.x, -forward.z)
	_final_recovery_pending.erase(racer_id)
	print("LOGSPIRE RECOVERY racer=%s target=Z6_07 delay=%.2fs final_jump=true" % [RaceManager.get_racer_label(racer), FINAL_RECOVERY_DELAY_SECONDS])
