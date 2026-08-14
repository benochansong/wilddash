class_name WildDashGrandPrixV3WorldFoundation
extends Node3D

## Grand Prix V3.5 world grounding.
##
## Round 1 is a land race, not a floating sky track. This controller adds one
## broad, low foundation under the complete sampled route bounds so an extreme
## offroad excursion can never fall into the void. Normal play still uses the
## road/shoulder/terrain collision above this foundation; the foundation is only
## the final physical landmass beneath the whole course.

const WORLD_MARGIN: float = 95.0
const FOUNDATION_TOP_DROP: float = 0.85
const FOUNDATION_THICKNESS: float = 3.0

var _track: WildDashGrandPrixV2Track
var _route: Array[Vector3] = []
var _foundation_body: StaticBody3D
var _foundation_visual: MeshInstance3D

func _ready() -> void:
	process_priority = 124
	call_deferred("_build_when_ready")

func _build_when_ready() -> void:
	for _frame: int in range(8):
		await get_tree().process_frame
	_track = _find_v2_track(get_parent())
	if _track == null:
		push_warning("GrandPrixV3WorldFoundation: V2 track unavailable")
		return
	_route = _track.get_route_points()
	if _route.size() < 2:
		push_warning("GrandPrixV3WorldFoundation: route unavailable")
		return

	var minimum: Vector3 = _route[0]
	var maximum: Vector3 = _route[0]
	for point: Vector3 in _route:
		minimum.x = minf(minimum.x, point.x)
		minimum.y = minf(minimum.y, point.y)
		minimum.z = minf(minimum.z, point.z)
		maximum.x = maxf(maximum.x, point.x)
		maximum.y = maxf(maximum.y, point.y)
		maximum.z = maxf(maximum.z, point.z)

	var size_x: float = maxf(80.0, maximum.x - minimum.x + WORLD_MARGIN * 2.0)
	var size_z: float = maxf(80.0, maximum.z - minimum.z + WORLD_MARGIN * 2.0)
	var top_y: float = minimum.y - FOUNDATION_TOP_DROP
	var center: Vector3 = Vector3(
		(minimum.x + maximum.x) * 0.5,
		top_y - FOUNDATION_THICKNESS * 0.5,
		(minimum.z + maximum.z) * 0.5
	)

	_foundation_body = StaticBody3D.new()
	_foundation_body.name = "V35WorldFoundationCollision"
	_foundation_body.collision_layer = 1
	_foundation_body.collision_mask = 0
	_foundation_body.position = center
	add_child(_foundation_body)

	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(size_x, FOUNDATION_THICKNESS, size_z)
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "WorldFoundationShape"
	collision.shape = shape
	_foundation_body.add_child(collision)

	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(size_x, FOUNDATION_THICKNESS, size_z)
	_foundation_visual = MeshInstance3D.new()
	_foundation_visual.name = "V35WorldFoundationVisual"
	_foundation_visual.mesh = mesh
	_foundation_visual.position = center
	_foundation_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.18, 0.25, 0.16, 1.0)
	material.roughness = 1.0
	_foundation_visual.material_override = material
	add_child(_foundation_visual)

	print("GRAND PRIX V3.5 WORLD FOUNDATION READY size=%.0fx%.0f top_y=%.2f route_min_y=%.2f margin=%.0f collision=true visual=true" % [
		size_x,
		size_z,
		top_y,
		minimum.y,
		WORLD_MARGIN,
	])

func _find_v2_track(root: Node) -> WildDashGrandPrixV2Track:
	if root == null:
		return null
	if root is WildDashGrandPrixV2Track:
		return root as WildDashGrandPrixV2Track
	for child: Node in root.get_children():
		var found: WildDashGrandPrixV2Track = _find_v2_track(child)
		if found != null:
			return found
	return null
