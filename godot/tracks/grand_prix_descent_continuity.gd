class_name WildDashGrandPrixDescentContinuity
extends Node3D

const JOINT_ROUTE_INDICES: Array[int] = [11, 12, 13, 14, 15]
const ROUTE_WIDTHS: Array[float] = [18.0,18.0,14.0,14.0,12.0,8.0,16.0,14.0,11.0,10.0,18.0,17.0,18.0,16.0,10.0,20.0,18.0,18.0,22.0,22.0,20.0,15.0,14.0,13.0,13.0,12.0,11.0,12.0,18.0]
const BLEND_DISTANCE: float = 14.0
const DECK_THICKNESS: float = 0.74
const DECK_TOP_OFFSET: float = 0.08
const DECK_LENGTH_OVERLAP: float = 2.60

var _track: WildDashGrandPrixTrack
var _root: Node3D

func _ready() -> void:
	call_deferred("_configure")

func _configure() -> void:
	for _i: int in range(5):
		await get_tree().physics_frame
	_track = get_parent().get_node_or_null("GrandPrixWorldTrack") as WildDashGrandPrixTrack
	if _track == null:
		push_warning("RC9 DESCENT CONTINUITY: track not found")
		return
	var route: Array[Vector3] = _track.get_route_points()
	_root = Node3D.new()
	_root.name = "RC9DescentTransitionDecks"
	add_child(_root)
	var built: int = 0
	for route_index: int in JOINT_ROUTE_INDICES:
		if _build_deck(route, route_index):
			built += 1
	print("RC9 DESCENT CONTINUITY READY joints=%d" % built)

func _build_deck(route: Array[Vector3], route_index: int) -> bool:
	if route_index <= 0 or route_index >= route.size() - 1:
		return false
	var previous: Vector3 = route[route_index - 1]
	var point: Vector3 = route[route_index]
	var following: Vector3 = route[route_index + 1]
	var incoming: Vector3 = point - previous
	var outgoing: Vector3 = following - point
	if incoming.length_squared() <= 0.001 or outgoing.length_squared() <= 0.001:
		return false
	var before_distance: float = minf(BLEND_DISTANCE, incoming.length() * 0.32)
	var after_distance: float = minf(BLEND_DISTANCE, outgoing.length() * 0.32)
	var from: Vector3 = point - incoming.normalized() * before_distance
	var to: Vector3 = point + outgoing.normalized() * after_distance
	var length: float = from.distance_to(to)
	var width: float = maxf(ROUTE_WIDTHS[route_index - 1], ROUTE_WIDTHS[route_index]) + 0.8
	var offset: Vector3 = Vector3.DOWN * (DECK_THICKNESS * 0.5 - DECK_TOP_OFFSET)
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "DescentBlend_%02d" % route_index
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = (from + to) * 0.5 + offset
	_root.add_child(body)
	body.look_at(to + offset, Vector3.UP)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(width, DECK_THICKNESS, length + DECK_LENGTH_OVERLAP)
	collision.shape = shape
	body.add_child(collision)
	var visual: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = shape.size
	visual.mesh = mesh
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.105, 0.125, 0.135)
	material.roughness = 0.9
	visual.material_override = material
	body.add_child(visual)
	return true
