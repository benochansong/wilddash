extends "res://modes/logspire_leap/logspire_recovery_system.gd"

## When Canopy River is active, legacy recovery Area3D volumes must never restart
## a racer before they reach a ladder. Absolute out-of-world fallback remains in
## the parent recovery system for genuinely invalid positions outside the river.

var _legacy_area_recovery_disabled: bool = false

func set_water_recovery(value: Node) -> void:
	super(value)
	if value != null:
		_disable_legacy_area_recovery()

func _on_recovery_area_body_entered(body: Node3D, area: Area3D) -> void:
	if _water_recovery != null and is_instance_valid(_water_recovery):
		var racer := body as WildDashCharacterController
		if racer != null and is_instance_valid(racer):
			cancel_pending_for_water(racer)
		return
	super(body, area)

func _disable_legacy_area_recovery() -> void:
	if _legacy_area_recovery_disabled or _world == null:
		return
	var areas_value: Variant = _world.call("get_recovery_areas")
	var disabled_count: int = 0
	if areas_value is Array:
		for value: Variant in areas_value:
			var area := value as Area3D
			if area == null:
				continue
			area.monitoring = false
			disabled_count += 1
	_legacy_area_recovery_disabled = true
	print("LOGSPIRE LEGACY AREA RECOVERY DISABLED count=%d ladder_only=true checkpoint_restart=false" % disabled_count)
