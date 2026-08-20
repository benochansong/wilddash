extends "res://modes/logspire_leap/logspire_platform_gameplay.gd"

## Godot 4.7.1 tree-order safety for Round 3 dynamic gameplay props.
## The base implementation assigned global_position before the freshly created
## Node3D/AnimatableBody3D had entered the SceneTree. Godot rejects that access,
## leaving Rolling Grove replacement platforms at an invalid transform after
## the original graybox collision has already been disabled.
##
## Keep all Phase 2 gameplay/balance logic inherited. Only construction order is
## changed: add the node to LogspireWorld first, then assign global transforms.

func configure(world: Node, graph: Node) -> void:
	super(world, graph)
	print("LOGSPIRE PLATFORM TREE ORDER READY rolling_grove=true moving_logs=true mushroom=true vine=true add_before_global_transform=true")

func _make_log_body(platform_id: StringName, radius: float, length: float, forward: Vector3) -> AnimatableBody3D:
	var top: Vector3 = _platform_top(platform_id)
	var body := AnimatableBody3D.new()
	body.name = "Phase2_%s" % String(platform_id)
	body.collision_layer = 1
	body.collision_mask = 0
	body.sync_to_physics = true
	_world.add_child(body)
	body.global_position = top - Vector3.UP * radius
	body.rotation.y = atan2(-forward.x, -forward.z)

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
	return body

func _make_box_body(
	platform_id: StringName,
	size: Vector3,
	forward: Vector3,
	color: Color,
	material_override: StandardMaterial3D = null
) -> AnimatableBody3D:
	var top: Vector3 = _platform_top(platform_id)
	var body := AnimatableBody3D.new()
	body.name = "Phase2_%s" % String(platform_id)
	body.collision_layer = 1
	body.collision_mask = 0
	body.sync_to_physics = true
	_world.add_child(body)
	body.global_position = top - Vector3.UP * (size.y * 0.5)
	body.rotation.y = atan2(-forward.x, -forward.z)

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
	return body

func _build_mushroom(platform_id: StringName) -> void:
	var top: Vector3 = _platform_top(platform_id)
	var area := Area3D.new()
	area.name = "Phase2MushroomArea"
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitoring = true
	_world.add_child(area)
	area.global_position = top + Vector3.UP * 1.1
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 3.2
	shape.height = 2.2
	collision.shape = shape
	area.add_child(collision)
	area.body_entered.connect(_on_mushroom_body_entered.bind(platform_id))

	var cap := MeshInstance3D.new()
	cap.name = "Phase2MushroomVisual"
	var mesh := SphereMesh.new()
	mesh.radius = 3.2
	mesh.height = 2.0
	mesh.material = _make_material(Color(0.82, 0.20, 0.18))
	cap.mesh = mesh
	cap.scale = Vector3(1.0, 0.45, 1.0)
	_world.add_child(cap)
	cap.global_position = top + Vector3.UP * 0.55

func _build_vine(platform_id: StringName) -> void:
	var top: Vector3 = _platform_top(platform_id)
	var area := Area3D.new()
	area.name = "Phase2VineArea"
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitoring = true
	_world.add_child(area)
	area.global_position = top + Vector3.UP * 2.5
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(6.5, 6.0, 8.5)
	collision.shape = shape
	area.add_child(collision)
	area.body_entered.connect(_on_vine_body_entered.bind(platform_id))

	var vine := MeshInstance3D.new()
	vine.name = "Phase2VineVisual"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.16
	mesh.bottom_radius = 0.22
	mesh.height = 8.5
	mesh.material = _make_material(Color(0.18, 0.52, 0.16))
	vine.mesh = mesh
	_world.add_child(vine)
	vine.global_position = top + Vector3.UP * 5.8
