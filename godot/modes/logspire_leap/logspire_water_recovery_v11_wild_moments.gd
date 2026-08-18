extends "res://modes/logspire_leap/logspire_water_recovery_v10_surface_collision_guard.gd"

## Round 3 Wild Moments adapter. Recovery physics remains fully owned by V10;
## this layer only records successful player saves before runtime state is cleared.

func _finish_assisted_recovery(
	racer: WildDashCharacterController,
	exit_position: Vector3,
	message: String
) -> void:
	var duration: float = 0.0
	var kind: StringName = &"recovery"
	var zone: int = 0
	if racer != null and is_instance_valid(racer):
		var racer_id: int = racer.get_instance_id()
		duration = float(_recovery_elapsed_by_id.get(racer_id, 0.0))
		kind = StringName(_traversal_kind_by_id.get(racer_id, &"recovery"))
		zone = int(_zone_by_id.get(racer_id, 0))
		if racer.is_player:
			_record_recovery_highlight(racer, kind, duration, zone)
	super(racer, exit_position, message)

func _finish_water_recovery(racer: WildDashCharacterController) -> void:
	var duration: float = 0.0
	var kind: StringName = &"ladder"
	var zone: int = 0
	if racer != null and is_instance_valid(racer):
		var racer_id: int = racer.get_instance_id()
		duration = float(_recovery_elapsed_by_id.get(racer_id, 0.0))
		kind = StringName(_traversal_kind_by_id.get(racer_id, &"ladder"))
		zone = int(_zone_by_id.get(racer_id, 0))
		if racer.is_player:
			_record_recovery_highlight(racer, kind, duration, zone)
	super(racer)

func _record_recovery_highlight(
	racer: WildDashCharacterController,
	kind: StringName,
	duration: float,
	zone: int
) -> void:
	var rescue_kind: String = String(kind).to_upper().replace("_", " ")
	var importance: int = ResultManager.HIGHLIGHT_COOL
	var title: String = "WILD SAVE!"
	if kind == &"vine_rescue":
		importance = ResultManager.HIGHLIGHT_EPIC
		title = "VINE RESCUE!"
	elif duration <= 3.2:
		importance = ResultManager.HIGHLIGHT_EPIC
		title = "FAST RECOVERY!"
	ResultManager.record_highlight_event(&"logspire_leap", {
		"type": &"water_recovery",
		"racer": RaceManager.get_racer_label(racer),
		"target": rescue_kind,
		"importance": importance,
		"zone": "ZONE %d" % (zone + 1),
		"title": title,
		"description": "BACK IN %.1f SEC · %s" % [duration, rescue_kind],
		"metadata": {
			"duration": duration,
			"recovery_kind": String(kind),
			"zone": zone + 1,
		},
	})
