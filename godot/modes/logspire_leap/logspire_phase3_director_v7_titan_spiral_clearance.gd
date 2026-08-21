extends "res://modes/logspire_leap/logspire_phase3_director_v6_upper_portal_cleanup.gd"

## Round 3 Titan Tree mid-spiral clearance repair.
##
## The Safe Route collision audit showed two different blockers inside Z5:
## 1) the old LivingBranch bridge proxies intersected normal jump capsules, and
## 2) the oversized late spiral boards curled back over the next jump arcs.
##
## Keep the authored route points, jump power, checkpoints and recovery rules.
## This pass removes the redundant LivingBranch gameplay collision and trims only
## the late Titan spiral board footprint so the visible mesh matches the actual
## playable clearance. No teleport, speed boost or hidden player assist is used.

const TITAN_SPIRAL_CLEAR_IDS: Array[StringName] = [
	&"Z5_SPIRAL_06",
	&"Z5_SPIRAL_07",
	&"Z5_SPIRAL_08",
	&"Z5_SPIRAL_09",
	&"Z5_SPIRAL_10",
]
const TITAN_SPIRAL_VISUAL_MAX_WIDTH: float = 9.8
const TITAN_SPIRAL_VISUAL_MAX_LENGTH: float = 12.4
const TITAN_SPIRAL_COLLISION_MAX_WIDTH: float = 10.2
const TITAN_SPIRAL_COLLISION_MAX_LENGTH: float = 12.8

func configure(world: Node, graph: Node) -> void:
	super(world, graph)
	_trim_titan_spiral_tail_clearance()

## V5 converted the two LivingBranch set pieces into solid sloped bridges. The
## final runtime audit proves those bridges actually cross the normal Safe Route
## jump capsule (03->04 and 05->06), so they are now visual/gameplay-retired.
## The expanded Safe Route platforms already provide the intended traversal.
func _stabilize_living_tree_route_bridges() -> void:
	var retired: int = 0
	for i: int in range(_living_branches.size()):
		var data: Dictionary = _living_branches[i]
		var body := data.get("body") as AnimatableBody3D
		if body == null or not is_instance_valid(body):
			continue
		body.collision_layer = 0
		body.collision_mask = 0
		body.visible = false
		body.set_meta(&"retired_for_safe_route_clearance", true)
		var collision := body.get_node_or_null("Collision") as CollisionShape3D
		if collision != null:
			collision.disabled = true
		retired += 1

	_living_tree_state = &"STATE_B"
	_living_tree_elapsed = LIVING_TREE_MOVE_SECONDS
	if _living_leaves != null:
		_living_leaves.visible = false
	if _graph != null and _graph.has_method("set_world_state"):
		_graph.call("set_world_state", &"STATE_B")
	print("R3 TITAN SPIRAL LIVING BRANCH CLEARANCE retired=%d collision=false moving_event=false safe_route=true" % retired)

func _trim_titan_spiral_tail_clearance() -> void:
	if _world == null or not is_instance_valid(_world):
		return
	var trimmed: int = 0
	for platform_id: StringName in TITAN_SPIRAL_CLEAR_IDS:
		var root := _world.get_node_or_null(NodePath(String(platform_id))) as Node3D
		if root == null:
			continue

		var mesh_instance := root.get_node_or_null("Mesh") as MeshInstance3D
		var box_mesh := mesh_instance.mesh as BoxMesh if mesh_instance != null else null
		if box_mesh != null:
			var visual_size: Vector3 = box_mesh.size
			visual_size.x = minf(visual_size.x, TITAN_SPIRAL_VISUAL_MAX_WIDTH)
			visual_size.z = minf(visual_size.z, TITAN_SPIRAL_VISUAL_MAX_LENGTH)
			box_mesh.size = visual_size

		var body := root.get_node_or_null("Collision") as StaticBody3D
		var collision := body.get_child(0) as CollisionShape3D if body != null and body.get_child_count() > 0 else null
		var box_shape := collision.shape as BoxShape3D if collision != null else null
		if box_shape != null:
			var collision_size: Vector3 = box_shape.size
			collision_size.x = minf(collision_size.x, TITAN_SPIRAL_COLLISION_MAX_WIDTH)
			collision_size.z = minf(collision_size.z, TITAN_SPIRAL_COLLISION_MAX_LENGTH)
			box_shape.size = collision_size

		_sync_world_platform_size(platform_id, box_mesh.size if box_mesh != null else Vector3.ZERO)
		root.set_meta(&"titan_spiral_clearance_trim", true)
		trimmed += 1

	print("R3 TITAN SPIRAL CLEARANCE READY trimmed=%d visual_max=%.1fx%.1f collision_max=%.1fx%.1f route_points_unchanged=true jump_power_unchanged=true teleport=false" % [
		trimmed,
		TITAN_SPIRAL_VISUAL_MAX_WIDTH,
		TITAN_SPIRAL_VISUAL_MAX_LENGTH,
		TITAN_SPIRAL_COLLISION_MAX_WIDTH,
		TITAN_SPIRAL_COLLISION_MAX_LENGTH,
	])

func _sync_world_platform_size(platform_id: StringName, visual_size: Vector3) -> void:
	if visual_size == Vector3.ZERO:
		return
	var index_value: Variant = _world.get("_platform_index_by_id")
	var sizes_value: Variant = _world.get("_platform_sizes")
	if not (index_value is Dictionary) or not (sizes_value is Array):
		return
	var index_by_id: Dictionary = index_value
	var sizes: Array = sizes_value
	var index: int = int(index_by_id.get(platform_id, -1))
	if index < 0 or index >= sizes.size():
		return
	var old_value: Variant = sizes[index]
	if not (old_value is Vector3):
		return
	var old_size: Vector3 = old_value
	sizes[index] = Vector3(visual_size.x, old_size.y, visual_size.z)
	_world.set("_platform_sizes", sizes)
