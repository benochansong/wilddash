extends "res://modes/logspire_leap/logspire_phase3_director_v5_route_clearance.gd"

## Round 3 upper Titan visual/collision cleanup.
## The previous route-clearance pass shrank only the Titan collision core while
## leaving the 86 m production trunk visually intact. Z6_START sits inside that
## visual cylinder, so racers appeared to phase through solid wood even though
## the physics corridor was technically open.
##
## This pass ends the central trunk below the upper transition, removes the old
## high branches that crossed the portal sightline, adds two collision-free side
## forks to preserve the giant-tree silhouette, and shortens the invisible trunk
## collision to the same lower-trunk height. The upper Z5 -> Z6 route is therefore
## a real open-air portal instead of a hidden-collision tunnel through a mesh.

const TITAN_UPPER_PORTAL_TOP_Y: float = 45.0
const TITAN_UPPER_PORTAL_COLLISION_RADIUS: float = 0.70
const TITAN_UPPER_FORK_OFFSET_X: float = 9.2
const TITAN_UPPER_FORK_HEIGHT: float = 24.0
const TITAN_UPPER_FORK_BOTTOM_RADIUS: float = 2.65
const TITAN_UPPER_FORK_TOP_RADIUS: float = 1.75
const TITAN_UPPER_FORK_CENTER_Y: float = 56.0
const TITAN_UPPER_BRANCH_FIRST_INDEX: int = 5

func configure(world: Node, graph: Node) -> void:
	super(world, graph)
	_open_titan_upper_portal()

func _open_titan_upper_portal() -> void:
	if _world == null or not is_instance_valid(_world):
		return
	var titan := _world.get_node_or_null("TitanTreeProduction") as Node3D
	if titan == null:
		push_warning("R3 TITAN UPPER PORTAL missing TitanTreeProduction")
		return

	var trunk := titan.get_node_or_null("TitanTrunk") as MeshInstance3D
	var trunk_mesh := trunk.mesh as CylinderMesh if trunk != null else null
	if trunk == null or trunk_mesh == null:
		push_warning("R3 TITAN UPPER PORTAL missing TitanTrunk mesh")
		return

	var old_height: float = trunk_mesh.height
	var old_bottom_y: float = trunk.global_position.y - old_height * 0.5
	var lower_height: float = maxf(18.0, TITAN_UPPER_PORTAL_TOP_Y - old_bottom_y)
	var lower_center_y: float = old_bottom_y + lower_height * 0.5
	trunk_mesh.height = lower_height
	trunk_mesh.top_radius = minf(trunk_mesh.top_radius, 4.8)
	trunk.global_position.y = lower_center_y
	trunk.set_meta(&"upper_route_portal_open", true)

	# Remove the high decorative branches that occupied the same visual corridor.
	# Two side forks are added below to keep the Titan silhouette connected to the
	# canopy without putting a solid-looking object on the playable center line.
	var hidden_branches: int = 0
	for i: int in range(TITAN_UPPER_BRANCH_FIRST_INDEX, 9):
		var branch := titan.get_node_or_null("TitanBranch_%02d" % i) as MeshInstance3D
		if branch != null:
			branch.visible = false
			branch.set_meta(&"retired_for_upper_portal", true)
			hidden_branches += 1

	_build_titan_portal_forks(titan, trunk_mesh.material)
	_sync_upper_trunk_collision(lower_center_y, lower_height)

	# Keep the lowest canopy clusters above the player's transition sightline.
	for i: int in range(14):
		var canopy := titan.get_node_or_null("TitanCanopy_%02d" % i) as MeshInstance3D
		if canopy != null and canopy.global_position.y < 74.0:
			var position := canopy.global_position
			position.y = 74.0
			canopy.global_position = position

	print("R3 TITAN UPPER PORTAL READY old_trunk_height=%.1f lower_trunk_height=%.1f portal_top_y=%.1f hidden_upper_branches=%d side_forks=2 visual_phase_through=false collision_phase_through=false" % [
		old_height, lower_height, TITAN_UPPER_PORTAL_TOP_Y, hidden_branches,
	])

func _build_titan_portal_forks(titan: Node3D, bark_material: Material) -> void:
	var existing := titan.get_node_or_null("TitanUpperPortalForks") as Node3D
	if existing != null:
		existing.queue_free()

	var root := Node3D.new()
	root.name = "TitanUpperPortalForks"
	root.set_meta(&"visual_only", true)
	titan.add_child(root)
	for side: float in [-1.0, 1.0]:
		var fork := MeshInstance3D.new()
		fork.name = "PortalFork_%s" % ("L" if side < 0.0 else "R")
		var mesh := CylinderMesh.new()
		mesh.bottom_radius = TITAN_UPPER_FORK_BOTTOM_RADIUS
		mesh.top_radius = TITAN_UPPER_FORK_TOP_RADIUS
		mesh.height = TITAN_UPPER_FORK_HEIGHT
		mesh.material = bark_material
		fork.mesh = mesh
		root.add_child(fork)
		fork.global_position = Vector3(
			_titan_center.x + side * TITAN_UPPER_FORK_OFFSET_X,
			TITAN_UPPER_FORK_CENTER_Y,
			_titan_center.z + 1.2
		)
		fork.rotation_degrees = Vector3(0.0, 0.0, -side * 11.0)
		fork.set_meta(&"visual_only", true)
		fork.set_meta(&"gameplay_collision", false)

func _sync_upper_trunk_collision(center_y: float, height: float) -> void:
	if _major_collision_root == null or not is_instance_valid(_major_collision_root):
		return
	var trunk_body := _major_collision_root.get_node_or_null("TitanTrunkCollision") as StaticBody3D
	if trunk_body == null or trunk_body.get_child_count() <= 0:
		return
	var collision := trunk_body.get_child(0) as CollisionShape3D
	var shape := collision.shape as CylinderShape3D if collision != null else null
	if shape == null:
		return
	shape.height = height
	shape.radius = minf(shape.radius, TITAN_UPPER_PORTAL_COLLISION_RADIUS)
	var position := trunk_body.global_position
	position.y = center_y
	trunk_body.global_position = position
	trunk_body.set_meta(&"upper_route_portal_open", true)
