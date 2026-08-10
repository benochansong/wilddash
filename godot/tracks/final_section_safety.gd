extends Node

# Applied after WildDashGrandPrixTrack has procedurally built the route.
# The final sector must remain technical, but the safe main route should not
# create an infinite fall/respawn loop when 10-15 racers arrive together.
const FINAL_WIDTHS := {
	23: 18.0, # Safe Detour B
	24: 18.0, # B Merge
	25: 18.0, # Final Technical
	26: 20.0, # Final Straight
}

func _ready() -> void:
	call_deferred("_apply_final_sector_safety")

func _apply_final_sector_safety() -> void:
	var track := get_parent() as Node3D
	if track == null:
		return

	# The Shortcut B gate and static Final Chicane remain. Removing only the
	# additional final rotating sweeper prevents triple-stacking hazards on the
	# mandatory safe route while preserving a meaningful technical finish.
	var final_sweeper := track.get_node_or_null("FinalSweeper")
	if final_sweeper != null:
		final_sweeper.queue_free()

	for index_variant in FINAL_WIDTHS.keys():
		var index := int(index_variant)
		var width := float(FINAL_WIDTHS[index_variant])
		_widen_segment_and_rails(track, index, width)

	print("FINAL SECTOR SAFETY PASS widths=18/18/18/20 final_sweeper=false chicane=true shortcutB_gate=true")

func _widen_segment_and_rails(track: Node3D, index: int, width: float) -> void:
	var prefix := "Road_%02d_" % index
	var road: CSGBox3D = null
	for child in track.get_children():
		if child is CSGBox3D and String(child.name).begins_with(prefix):
			road = child as CSGBox3D
			break
	if road == null:
		return

	var size := road.size
	size.x = width
	road.size = size
	var right := road.global_transform.basis.x.normalized()
	var rail_y := road.global_position.y + 0.87
	for side_data in [["L", -1.0], ["R", 1.0]]:
		var rail := track.get_node_or_null("Rail_%02d_%s" % [index, side_data[0]]) as CSGBox3D
		if rail == null:
			continue
		var side := float(side_data[1])
		var target := road.global_position + right * (width * 0.5 + 0.2) * side
		target.y = rail_y
		rail.global_position = target
