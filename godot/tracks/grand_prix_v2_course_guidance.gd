class_name WildDashGrandPrixV2CourseGuidance
extends Node3D

## V3.2 open-edge mode.
##
## The V2.8 version removed visible guardrails but still built a full-height
## invisible collision wall along both sides of the entire course. That made the
## road feel like a hidden tunnel. Round 1 now intentionally allows racers to
## leave the road/shoulder and enter the physical near-terrain band.
##
## Safety responsibility is split cleanly:
## - NO continuous lateral barrier collision is created here.
## - V2TerrainShell owns the ~10m physical terrain outside each shoulder.
## - GrandPrixV3OffroadController owns progressive speed loss / deep-offroad stop.
## - Existing deep-fall recovery remains available only for actual falls.

const VISUAL_OWNER_GROUP: StringName = &"wilddash_guardrail_visual_owner"

var _collision_enabled: bool = false

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	call_deferred("_report_state")

func get_barrier_collision_shape_count() -> int:
	return 0

func get_barrier_chunk_count() -> int:
	return 0

func get_barrier_mesh_count() -> int:
	return 0

func get_rail_segment_count() -> int:
	return 0

func get_post_count() -> int:
	return 0

func get_max_rail_segment_length() -> float:
	return 0.0

func get_max_endpoint_error() -> float:
	return 0.0

func get_non_adjacent_link_count() -> int:
	return 0

func get_cross_side_link_count() -> int:
	return 0

func is_barrier_collision_enabled() -> bool:
	return false

func set_barrier_collision_enabled(enabled: bool) -> void:
	# Compatibility API retained for older diagnostics/controllers. Round 1 V3.2
	# deliberately refuses to recreate the continuous hidden wall.
	_collision_enabled = false
	if enabled:
		print("GRAND PRIX V3.2 OPEN EDGE ignores barrier enable request; offroad remains driveable")

func _report_state() -> void:
	await get_tree().process_frame
	var owners: Array[Node] = get_tree().get_nodes_in_group(VISUAL_OWNER_GROUP)
	print("GRAND PRIX V3.2 OPEN EDGE MODE visual_guardrail_owners=%d visual_guardrail_meshes=0 posts=0 rails=0 collision_shapes=0 collision_enabled=false offroad_driveable=true" % owners.size())
	if owners.size() != 0:
		push_error("V3.2 expected zero visible guardrail owners, got %d" % owners.size())
