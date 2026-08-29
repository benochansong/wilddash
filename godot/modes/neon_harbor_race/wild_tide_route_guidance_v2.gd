class_name WildDashWildTideRouteGuidanceV2
extends "res://modes/neon_harbor_race/wild_tide_route_guidance.gd"

## Readability pass for Round 3 route arrows.
## Water/canopy/shortcut arrows keep their existing colors and authored route
## indices, but every arrow is lifted slightly above water/ground and enlarged so
## the chase camera can read branches before reaching the split.

const V2_ARROW_EXTRA_HEIGHT: float = 0.18
const V2_ARROW_PLANAR_SCALE: float = 1.18

func _ready() -> void:
	super._ready()
	call_deferred("_report_v2_when_ready")

func _create_arrow_shape(node_name: String, position: Vector3, target: Vector3, material: StandardMaterial3D) -> void:
	super._create_arrow_shape(node_name, position, target, material)
	var root: Node3D = get_node_or_null(node_name) as Node3D
	if root == null:
		return
	root.position.y += V2_ARROW_EXTRA_HEIGHT
	root.scale = Vector3(V2_ARROW_PLANAR_SCALE, 1.0, V2_ARROW_PLANAR_SCALE)

func get_guidance_counts() -> Dictionary:
	return {
		"main": _main_count,
		"water": _water_count,
		"canopy": _canopy_count,
		"shortcut": _shortcut_count,
	}

func _report_v2_when_ready() -> void:
	for _attempt: int in range(90):
		if _main_count > 0:
			break
		await get_tree().physics_frame
	print("ARROW GUIDE V2 READABILITY main=%d water=%d canopy=%d shortcut=%d extra_height=%.2f scale=%.2f water_above_surface=true" % [
		_main_count, _water_count, _canopy_count, _shortcut_count,
		V2_ARROW_EXTRA_HEIGHT, V2_ARROW_PLANAR_SCALE,
	])
