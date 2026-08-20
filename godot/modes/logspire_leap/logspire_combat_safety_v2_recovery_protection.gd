extends "res://modes/logspire_leap/logspire_combat_safety.gd"

## Prevent a successful water recovery from immediately turning into another
## fall because of a body check or residual knockback at the safe deck exit.

const RECOVERY_PROTECTION_META: StringName = &"logspire_recovery_protection_until"

func _update_racer_safety(racer: WildDashCharacterController, delta: float) -> void:
	if racer != null and is_instance_valid(racer):
		var until: float = float(racer.get_meta(RECOVERY_PROTECTION_META, -1.0))
		var now: float = Time.get_ticks_msec() * 0.001
		if now <= until:
			racer.set("_knockback_velocity", Vector3.ZERO)
		else:
			if racer.has_meta(RECOVERY_PROTECTION_META):
				racer.remove_meta(RECOVERY_PROTECTION_META)
	super(racer, delta)
