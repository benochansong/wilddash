extends "res://modes/logspire_leap/logspire_platform_gameplay.gd"

## Godot 4.7.1 tree-order safety for Round 3 dynamic gameplay props.
##
## The base implementation writes global_position before fresh Node3D objects
## enter the SceneTree. That emits !is_inside_tree errors. A first repair that
## added the physics body before moving it removed that error, but exposed a
## one-frame PhysicsServer registration at the parent's origin; the Safe Route
## audit then saw Phase2_Z3_02 blocking START -> Z1_01.
##
## The correct construction contract is:
## 1. compute the desired GLOBAL transform from authored platform data;
## 2. convert it into LogspireWorld LOCAL space while the parent is valid;
## 3. assign the new node's local transform before add_child;
## 4. add the already-positioned body to the SceneTree.
##
## This keeps the original Phase 2 behavior/balance while making the first
## physics registration authoritative and free of global-transform access on an
## orphan Node3D.

func configure(world: Node, graph: Node) -> void:
	super(world, graph)
	print("LOGSPIRE PLATFORM TREE ORDER READY rolling_grove=true moving_logs=true mushroom=true vine=true local_transform_before_add=true first_physics_transform_valid=true")

func _world_3d() -> Node3D:
	return _world as Node3D

func _local_transform_for(global_position: Vector3, global_yaw: float = 0.0) -> Transform3D:
	var world := _world_3d()
	if world == null:
		return Transform3D(Basis(Vector3.UP, global_yaw), global_position)
	var desired_global := Transform3D(Basis(Vector3.UP, global_yaw), global_position)
	return world.global_transform.affine_inverse() * desired_global

func _local_position_for(global_position: Vector3) -> Vector3:
	var world := _world_3d()
	return global_position if world == null else world.to_local(global_position)

func _make_log_body(platform_id: StringName, radius: float, length: float, forward: Vector3) -> AnimatableBody3D:
	var top: Vector3 = _platform_top(platform_id)
	var yaw: float = atan2(-forward.x, -forward.z)
	var body := AnimatableBody3D.new()
	body.name = "Phase2_%s" % String(platform_id)
	body.collision_layer = 1
	body.collision_mask = 0
	body.sync_to_physics = true
	body.transform = _local_transform_for(top - Vector3.UP * radius, yaw)

	var spin := Node3D.new()
	spin.name = "SpinVisual"
	body.add_child(spin)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "LogMesh"
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.material = _make_material(Color(0.42, 0.27, 0.11))
	mesh_instance.mesh = mesh
	mesh_instance.rotation.x = PI * 0.5
	spin.add_child(mesh_instance)

	var marker := MeshInstance3D.new()
	marker.name = "RollMarker"
	var marker_mesh := BoxMesh.new()
	marker_mesh.size = Vector3(0.42, 0.42, length * 0.92)
	marker_mesh.material = _make_material(Color(0.76, 0.48, 0.15))
	marker.mesh = marker_mesh
	marker.position = Vector3(radius * 0.78, 0.0, 0.0)
	spin.add_child(marker)

	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = length
	collision.shape = shape
	collision.rotation.x = PI * 0.5
	body.add_child(collision)
	_world.add_child(body)
	return body

func _make_box_body(
	platform_id: StringName,
	size: Vector3,
	forward: Vector3,
	color: Color,
	material_override: StandardMaterial3D = null
) -> AnimatableBody3D:
	var top: Vector3 = _platform_top(platform_id)
	var yaw: float = atan2(-forward.x, -forward.z)
	var body := AnimatableBody3D.new()
	body.name = "Phase2_%s" % String(platform_id)
	body.collision_layer = 1
	body.collision_mask = 0
	body.sync_to_physics = true
	body.transform = _local_transform_for(top - Vector3.UP * (size.y * 0.5), yaw)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Visual"
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material_override if material_override != null else _make_material(color)
	mesh_instance.mesh = mesh
	body.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	_world.add_child(body)
	return body

func _build_mushroom(platform_id: StringName) -> void:
	var top: Vector3 = _platform_top(platform_id)
	var area := Area3D.new()
	area.name = "Phase2MushroomArea"
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitoring = true
	area.position = _local_position_for(top + Vector3.UP * 1.1)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 3.2
	shape.height = 2.2
	collision.shape = shape
	area.add_child(collision)
	_world.add_child(area)
	area.body_entered.connect(_on_mushroom_body_entered.bind(platform_id))

	var cap := MeshInstance3D.new()
	cap.name = "Phase2MushroomVisual"
	var mesh := SphereMesh.new()
	mesh.radius = 3.2
	mesh.height = 2.0
	mesh.material = _make_material(Color(0.82, 0.20, 0.18))
	cap.mesh = mesh
	cap.scale = Vector3(1.0, 0.45, 1.0)
	cap.position = _local_position_for(top + Vector3.UP * 0.55)
	_world.add_child(cap)

func _build_vine(platform_id: StringName) -> void:
	var top: Vector3 = _platform_top(platform_id)
	var area := Area3D.new()
	area.name = "Phase2VineArea"
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitoring = true
	area.position = _local_position_for(top + Vector3.UP * 2.5)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(6.5, 6.0, 8.5)
	collision.shape = shape
	area.add_child(collision)
	_world.add_child(area)
	area.body_entered.connect(_on_vine_body_entered.bind(platform_id))

	var vine := MeshInstance3D.new()
	vine.name = "Phase2VineVisual"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.16
	mesh.bottom_radius = 0.22
	mesh.height = 8.5
	mesh.material = _make_material(Color(0.18, 0.52, 0.16))
	vine.mesh = mesh
	vine.position = _local_position_for(top + Vector3.UP * 5.8)
	_world.add_child(vine)
