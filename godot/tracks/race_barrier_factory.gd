class_name WildDashRaceBarrierFactory
extends RefCounted

const WORLD_LAYER := 1

static func add_box_barrier(
	parent: Node3D,
	node_name: String,
	center: Vector3,
	size: Vector3,
	rotation_y: float = 0.0,
	debug_color: Color = Color(1.0, 0.18, 0.12, 0.22)
) -> StaticBody3D:
	var basis := Basis(Vector3.UP, rotation_y)
	return add_transformed_box_barrier(parent, node_name, Transform3D(basis, center), size, debug_color)

static func add_transformed_box_barrier(
	parent: Node3D,
	node_name: String,
	world_transform: Transform3D,
	size: Vector3,
	debug_color: Color = Color(1.0, 0.18, 0.12, 0.22)
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	body.add_to_group("wilddash_hard_barrier")
	parent.add_child(body)
	body.global_transform = world_transform

	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = Vector3(maxf(0.2, size.x), maxf(0.2, size.y), maxf(0.2, size.z))
	collision.shape = shape
	body.add_child(collision)

	if OS.has_environment("WILDDASH_DEBUG_COLLISION"):
		var visual := MeshInstance3D.new()
		visual.name = "DebugBarrierVisual"
		var mesh := BoxMesh.new()
		mesh.size = shape.size
		visual.mesh = mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = debug_color
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		visual.material_override = material
		body.add_child(visual)
	return body

static func add_segment_barrier(
	parent: Node3D,
	node_name: String,
	a: Vector3,
	b: Vector3,
	lateral_offset: float,
	height: float = 2.4,
	thickness: float = 0.65,
	vertical_center: float = 1.15
) -> StaticBody3D:
	var flat_a := Vector3(a.x, 0.0, a.z)
	var flat_b := Vector3(b.x, 0.0, b.z)
	var direction := flat_b - flat_a
	if direction.length_squared() <= 0.001:
		return null
	var length := direction.length()
	direction /= length
	var right := Vector3(-direction.z, 0.0, direction.x)
	var center := (a + b) * 0.5 + right * lateral_offset + Vector3.UP * vertical_center
	var yaw := atan2(-direction.x, -direction.z)
	return add_box_barrier(parent, node_name, center, Vector3(thickness, height, length), yaw)

static func add_route_side_pair(
	parent: Node3D,
	name_prefix: String,
	a: Vector3,
	b: Vector3,
	road_width: float,
	extra_offset: float = 0.55,
	height: float = 2.4,
	thickness: float = 0.65
) -> Array[StaticBody3D]:
	var result: Array[StaticBody3D] = []
	var offset := road_width * 0.5 + extra_offset
	var left := add_segment_barrier(parent, name_prefix + "_L", a, b, -offset, height, thickness)
	var right := add_segment_barrier(parent, name_prefix + "_R", a, b, offset, height, thickness)
	if left != null:
		result.append(left)
	if right != null:
		result.append(right)
	return result
