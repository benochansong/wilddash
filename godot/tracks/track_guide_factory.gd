class_name WildDashTrackGuideFactory
extends RefCounted

# Shared, static track guidance only. Route-specific placement remains with the
# track author so this helper never grows into a gameplay or environment God class.

static func create_direction_arrow(
	parent: Node3D,
	node_name: String,
	transforms: Array[Transform3D],
	material: Material
) -> MultiMeshInstance3D:
	return _create_batch(parent, node_name, _build_road_arrow_mesh(material), transforms)

static func create_curve_chevrons(
	parent: Node3D,
	node_name: String,
	transforms: Array[Transform3D],
	backing_material: Material,
	accent_material: Material
) -> MultiMeshInstance3D:
	return _create_batch(
		parent, node_name, _build_trackside_marker_mesh(backing_material, accent_material), transforms
	)

static func _create_batch(
	parent: Node3D,
	node_name: String,
	mesh: Mesh,
	transforms: Array[Transform3D]
) -> MultiMeshInstance3D:
	if transforms.is_empty():
		return null
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for index in range(transforms.size()):
		multimesh.set_instance_transform(index, transforms[index])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	parent.add_child(instance)
	return instance

static func _build_road_arrow_mesh(material: Material) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var parts: Array[Transform3D] = [
		_local_box(Vector3(0.0, 0.0, 0.12), Vector3(0.24, 0.045, 1.35)),
		_local_box(Vector3(-0.31, 0.0, -0.50), Vector3(0.22, 0.05, 0.88), Vector3(0.0, -PI * 0.25, 0.0)),
		_local_box(Vector3(0.31, 0.0, -0.50), Vector3(0.22, 0.05, 0.88), Vector3(0.0, PI * 0.25, 0.0)),
	]
	_append_box_surface(mesh, parts, material)
	return mesh

static func _build_trackside_marker_mesh(backing_material: Material, accent_material: Material) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var backing: Array[Transform3D] = [
		_local_box(Vector3(0.0, 1.35, 0.0), Vector3(2.35, 1.22, 0.14)),
		_local_box(Vector3(0.0, 0.48, 0.03), Vector3(0.18, 1.15, 0.18)),
	]
	var arrow: Array[Transform3D] = [
		_local_box(Vector3(-0.15, 1.35, -0.10), Vector3(1.05, 0.18, 0.08)),
		_local_box(Vector3(0.50, 1.56, -0.10), Vector3(0.18, 0.72, 0.08), Vector3(0.0, 0.0, -PI * 0.25)),
		_local_box(Vector3(0.50, 1.14, -0.10), Vector3(0.18, 0.72, 0.08), Vector3(0.0, 0.0, PI * 0.25)),
	]
	_append_box_surface(mesh, backing, backing_material)
	_append_box_surface(mesh, arrow, accent_material)
	return mesh

static func _append_box_surface(mesh: ArrayMesh, transforms: Array[Transform3D], material: Material) -> void:
	var primitive := BoxMesh.new()
	primitive.size = Vector3.ONE
	var surface := SurfaceTool.new()
	surface.set_material(material)
	for transform in transforms:
		surface.append_from(primitive, 0, transform)
	surface.commit(mesh)

static func _local_box(position: Vector3, size: Vector3, rotation := Vector3.ZERO) -> Transform3D:
	return Transform3D(Basis.from_euler(rotation).scaled(size), position)
