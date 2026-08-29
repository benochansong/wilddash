extends "res://modes/logspire_leap/logspire_phase3_director_v5_route_clearance_core.gd"

## Final R3 event-geometry visibility and Titan corridor stability guard.
##
## The original Living Tree event created two large bridge bodies above the
## spiral route, rotated them steeply while collision was disabled, then dropped
## them into place at 64% progress. The bridge helper only aligned horizontal
## yaw, so the 2.2m vertical rise between spiral platforms became a floating
## horizontal slab over the lower approach. That could block the player/camera
## and make the view jump when the event changed state.
##
## Production now keeps the authored bridge idea but removes the unstable motion:
## both bridges are installed from the start as thin, fully-collidable ramps that
## follow the true 3D vector between their endpoint platforms. The leaf/audio
## spectacle is intentionally sacrificed for route readability and camera safety.

const STATIC_LIVING_BRIDGE_WIDTH: float = 3.8
const STATIC_LIVING_BRIDGE_THICKNESS: float = 0.55
const STATIC_LIVING_BRIDGE_SURFACE_OFFSET: float = 0.30

func configure(world: Node, graph: Node) -> void:
	super(world, graph)
	_stabilize_living_tree_route_bridges()
	_sync_event_geometry_visibility()

func _physics_process(delta: float) -> void:
	super(delta)
	if not _configured:
		return
	_sync_event_geometry_visibility()

func _stabilize_living_tree_route_bridges() -> void:
	var pairs: Array[Array] = [
		[&"Z5_SPIRAL_03", &"Z5_SPIRAL_04"],
		[&"Z5_SPIRAL_05", &"Z5_SPIRAL_06"],
	]
	var count: int = mini(_living_branches.size(), pairs.size())
	for i: int in range(count):
		var data: Dictionary = _living_branches[i]
		var body := data.get("body") as AnimatableBody3D
		if body == null or not is_instance_valid(body):
			continue
		var from_id: StringName = pairs[i][0]
		var to_id: StringName = pairs[i][1]
		var from: Vector3 = _platform_position(from_id) + Vector3.UP * STATIC_LIVING_BRIDGE_SURFACE_OFFSET
		var to: Vector3 = _platform_position(to_id) + Vector3.UP * STATIC_LIVING_BRIDGE_SURFACE_OFFSET
		var delta: Vector3 = to - from
		if delta.length_squared() <= 0.001:
			continue

		# Center the body between the real endpoint heights and point local -Z at
		# the destination. Unlike the old yaw-only setup, this includes pitch and
		# therefore makes a genuine ramp instead of an overhead horizontal slab.
		body.global_position = (from + to) * 0.5
		body.look_at(to, Vector3.UP)
		body.collision_layer = 1
		body.collision_mask = 2
		body.visible = true

		var bridge_size := Vector3(
			STATIC_LIVING_BRIDGE_WIDTH,
			STATIC_LIVING_BRIDGE_THICKNESS,
			maxf(2.0, delta.length())
		)
		var visual := body.get_node_or_null("Mesh") as MeshInstance3D
		var mesh := visual.mesh as BoxMesh if visual != null else null
		if mesh != null:
			mesh.size = bridge_size
		var collision := body.get_node_or_null("Collision") as CollisionShape3D
		var shape := collision.shape as BoxShape3D if collision != null else null
		if shape != null:
			shape.size = bridge_size

		data["final_position"] = body.global_position
		data["final_rotation"] = body.rotation
		data["start_position"] = body.global_position
		data["start_rotation"] = body.rotation
		_living_branches[i] = data

	# Prevent the 64% state transition from moving these large bodies through the
	# camera or the player. The route graph sees the already-ready bridge state.
	_living_tree_state = &"STATE_B"
	_living_tree_elapsed = LIVING_TREE_MOVE_SECONDS
	if _living_leaves != null:
		_living_leaves.visible = false
	if _graph != null and _graph.has_method("set_world_state"):
		_graph.call("set_world_state", &"STATE_B")
	print("LOGSPIRE LIVING TREE ROUTE STABLE bridges=%d static=true sloped=true moving_event=false camera_cut=false" % count)

func _sync_event_geometry_visibility() -> void:
	for data: Dictionary in _living_branches:
		var body := data.get("body") as AnimatableBody3D
		if body == null or not is_instance_valid(body):
			continue
		# A collision-free giant branch must never render as a solid wall.
		body.visible = body.collision_layer != 0

	if _last_tree != null and is_instance_valid(_last_tree):
		# The finale tree follows the same invariant: visible means collidable.
		_last_tree.visible = _last_tree.collision_layer != 0
