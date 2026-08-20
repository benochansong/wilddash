extends "res://modes/logspire_leap/logspire_water_recovery.gd"

## Telemetry/polish adapter kept separate from the core water state machine.

func _enter_water(racer: WildDashCharacterController, zone: int, water_y: float) -> void:
	super(racer, zone, water_y)
	if racer == null or not is_instance_valid(racer):
		return
	var racer_id: int = racer.get_instance_id()
	var ladder_value: Variant = _ladder_by_id.get(racer_id, {})
	var ladder: Dictionary = ladder_value if ladder_value is Dictionary else {}
	if ladder.is_empty():
		return
	print("LOGSPIRE SWIM racer=%s ladder=%s zone=%d speed_ratio=0.50" % [
		RaceManager.get_racer_label(racer),
		String(ladder.get("id", &"")),
		zone + 1,
	])
