extends "res://modes/logspire_leap/logspire_phase3_director_v5_route_clearance.gd"

## Godot 4.7.1 construction-order repair for the production Titan Tree section.
##
## Several Phase3 builders assigned global_position to fresh Node3D instances
## before those nodes entered the SceneTree. Godot rejects that transform access
## and the affected prop can register at an unintended transform for its first
## physics frame. In the dense CP5 Titan corridor that can produce a visible or
## physical obstruction even when the route data itself is valid.
##
## V6 keeps the authored Phase3 behavior and V5 route-clearance rules, but every
## affected world child receives a parent-local transform before add_child.
## Dynamic bridges likewise enter physics already at their authoritative 3D
## transform instead of registering at the world origin first.

func configure(world: Node, graph: Node) -> void:
	super(world, graph)
	print("LOGSPIRE PHASE3 TREE SAFE READY titan=true woodpecker=true living_bridges=true finale=true local_before_add=true")

func _world_3d() -> Node3D:
	return _world as Node3D

func _world_local(global_position: Vector3) -> Vector3:
	var world := _world_3d()
	return global_position if world == null else world.to_local(global_position)

func _world_local_transform(global_transform: Transform3D) -> Transform3D:
	var world := _world_3d()
	return global_transform if world == null else world.global_transform.affine_inverse() * global_transform

func _build_titan_tree() -> void:
	_titan_center = _estimate_titan_center()
	var root := Node3D.new()
	root.name = "TitanTreeProduction"
	_world.add_child(root)

	var bark := _make_material(Color(0.30, 0.17, 0.065), 0.94)
	var bark_gold := _make_material(Color(0.43, 0.25, 0.07), 0.90)
	var leaf_dark := _make_material(Color(0.12, 0.29, 0.10), 0.92)
	var leaf_gold := _make_material(Color(0.46, 0.48, 0.12), 0.88)

	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 6.5
	trunk_mesh.bottom_radius = 10.5
	trunk_mesh.height = 86.0
	trunk_mesh.material = bark
	var trunk := MeshInstance3D.new()
	trunk.name = "TitanTrunk"
	trunk.mesh = trunk_mesh
	trunk.position = root.to_local(Vector3(_titan_center.x, 37.0, _titan_center.z))
	root.add_child(trunk)

	for i: int in range(8):
		var angle: float = TAU * float(i) / 8.0
		var direction := Vector3(sin(angle), 0.0, cos(angle))
		var global_position := Vector3(_titan_center.x, 2.0, _titan_center.z) + direction * 9.0
		var root_piece := _make_box_visual(
			Vector3(5.0, 2.2, 24.0),
			bark,
			root.to_local(global_position),
			angle
		)
		root_piece.name = "TitanRoot_%02d" % i
		root.add_child(root_piece)

	for i: int in range(9):
		var angle: float = deg_to_rad(28.0 + float(i) * 43.0)
		var direction := Vector3(sin(angle), 0.0, cos(angle))
		var height: float = 16.0 + float(i) * 6.2
		var global_position := Vector3(_titan_center.x, height, _titan_center.z) + direction * 11.0
		var branch := _make_box_visual(
			Vector3(3.3 - float(i) * 0.12, 1.7, 27.0 - float(i) * 0.55),
			bark_gold if i >= 5 else bark,
			root.to_local(global_position),
			angle
		)
		branch.rotation.x = deg_to_rad(-4.0 + float(i % 3) * 3.0)
		branch.name = "TitanBranch_%02d" % i
		root.add_child(branch)

	for i: int in range(14):
		var angle: float = TAU * float(i) / 14.0
		var ring: float = 9.0 + float(i % 4) * 3.0
		var leaf := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 7.5 + float(i % 3) * 1.4
		sphere.height = sphere.radius * 1.55
		sphere.material = leaf_gold if i % 4 == 0 else leaf_dark
		leaf.mesh = sphere
		var leaf_global := Vector3(
			_titan_center.x + sin(angle) * ring,
			70.0 + float((i * 5) % 13),
			_titan_center.z + cos(angle) * ring
		)
		leaf.position = root.to_local(leaf_global)
		leaf.name = "TitanCanopy_%02d" % i
		root.add_child(leaf)

	_titan_light = OmniLight3D.new()
	_titan_light.name = "TitanGoldenLight"
	_titan_light.position = root.to_local(Vector3(_titan_center.x, 62.0, _titan_center.z))
	_titan_light.light_color = Color(1.0, 0.72, 0.30)
	_titan_light.light_energy = 1.15
	_titan_light.omni_range = 42.0
	root.add_child(_titan_light)

	print("LOGSPIRE TITAN TREE READY trunk_height=86 roots=8 branches=9 canopy_clusters=14 visible_from_start=true tree_safe=true")

func _make_animatable_bridge(
	name_text: String,
	from: Vector3,
	to: Vector3,
	width: float,
	thickness: float,
	color: Color
) -> Dictionary:
	var delta: Vector3 = to - from
	var length: float = maxf(2.0, delta.length())
	var direction_3d: Vector3 = Vector3.FORWARD if delta.length_squared() <= 0.001 else delta.normalized()
	var planar := Vector3(delta.x, 0.0, delta.z)
	var forward: Vector3 = Vector3.FORWARD if planar.length_squared() <= 0.001 else planar.normalized()
	var yaw: float = atan2(-forward.x, -forward.z)
	var body := AnimatableBody3D.new()
	body.name = name_text
	body.sync_to_physics = true
	body.collision_layer = 1
	body.collision_mask = 2
	var desired_global := Transform3D(Basis.looking_at(direction_3d, Vector3.UP), (from + to) * 0.5)
	body.transform = _world_local_transform(desired_global)

	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, thickness, length)
	mesh.material = _make_material(color, 0.94)
	var visual := MeshInstance3D.new()
	visual.name = "Mesh"
	visual.mesh = mesh
	body.add_child(visual)
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	var shape := BoxShape3D.new()
	shape.size = mesh.size
	collision.shape = shape
	body.add_child(collision)
	_world.add_child(body)
	return {
		"body": body,
		"final_position": body.global_position,
		"yaw": yaw,
		"length": length,
	}

func _build_living_leaf_multimesh() -> void:
	_living_leaves = MultiMeshInstance3D.new()
	_living_leaves.name = "LivingTreeFallingLeaves"
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var leaf_mesh := BoxMesh.new()
	leaf_mesh.size = Vector3(0.34, 0.06, 0.62)
	leaf_mesh.material = _make_material(Color(0.58, 0.50, 0.12), 0.85)
	multimesh.mesh = leaf_mesh
	multimesh.instance_count = 24
	_living_leaf_seed.clear()
	for i: int in range(multimesh.instance_count):
		var angle: float = TAU * float(i) / float(multimesh.instance_count)
		var radius: float = 6.0 + float((i * 7) % 15)
		var seed := Vector3(sin(angle) * radius, float((i * 11) % 22), cos(angle) * radius)
		_living_leaf_seed.append(seed)
		multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, seed))
	_living_leaves.multimesh = multimesh
	_living_leaves.position = _world_local(Vector3(_titan_center.x, 58.0, _titan_center.z))
	_living_leaves.visible = false
	_world.add_child(_living_leaves)

func _build_woodpecker_hazard() -> void:
	var perch: Vector3 = _platform_position(&"Z5_SPIRAL_07")
	_woodpecker_root = Node3D.new()
	_woodpecker_root.name = "GiantWoodpecker"
	_woodpecker_root.position = _world_local(perch + Vector3(6.5, 6.0, 1.0))
	_world.add_child(_woodpecker_root)

	var body := MeshInstance3D.new()
	var body_mesh := SphereMesh.new()
	body_mesh.radius = 1.45
	body_mesh.height = 2.4
	body_mesh.material = _make_material(Color(0.42, 0.12, 0.07), 0.86)
	body.mesh = body_mesh
	_woodpecker_root.add_child(body)

	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.95
	head_mesh.height = 1.45
	head_mesh.material = _make_material(Color(0.72, 0.12, 0.07), 0.84)
	head.mesh = head_mesh
	head.position = Vector3(0.0, 1.55, -0.15)
	_woodpecker_root.add_child(head)

	var beak := MeshInstance3D.new()
	var beak_mesh := CylinderMesh.new()
	beak_mesh.top_radius = 0.0
	beak_mesh.bottom_radius = 0.28
	beak_mesh.height = 1.8
	beak_mesh.material = _make_material(Color(0.92, 0.66, 0.18), 0.80)
	beak.mesh = beak_mesh
	beak.rotation.x = deg_to_rad(90.0)
	beak.position = Vector3(0.0, 1.55, -1.25)
	_woodpecker_root.add_child(beak)

	_woodpecker_area = Area3D.new()
	_woodpecker_area.name = "WoodpeckerShakeArea"
	_woodpecker_area.position = _world_local(perch + Vector3.UP * 1.0)
	_woodpecker_area.collision_layer = 0
	_woodpecker_area.collision_mask = 2
	_woodpecker_area.monitoring = true
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(14.0, 5.0, 15.0)
	collision.shape = shape
	_woodpecker_area.add_child(collision)
	_world.add_child(_woodpecker_area)

	var platform_root := _world.get_node_or_null("Z5_SPIRAL_07") as Node3D
	if platform_root != null:
		_woodpecker_target_visual = platform_root.get_node_or_null("Mesh") as Node3D
		if _woodpecker_target_visual != null:
			_woodpecker_target_base_rotation = _woodpecker_target_visual.rotation
	_build_wood_chip_multimesh(perch)

func _build_wood_chip_multimesh(perch: Vector3) -> void:
	_wood_chips = MultiMeshInstance3D.new()
	_wood_chips.name = "WoodpeckerWoodChips"
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var chip_mesh := BoxMesh.new()
	chip_mesh.size = Vector3(0.18, 0.08, 0.34)
	chip_mesh.material = _make_material(Color(0.58, 0.34, 0.12), 0.90)
	multimesh.mesh = chip_mesh
	multimesh.instance_count = 8
	for i: int in range(multimesh.instance_count):
		multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3.ZERO))
	_wood_chips.multimesh = multimesh
	_wood_chips.position = _world_local(perch + Vector3.UP * 2.0)
	_wood_chips.visible = false
	_world.add_child(_wood_chips)

func _build_squirrel_stampede() -> void:
	_squirrel_base = _platform_position(&"Z5_APPROACH_02") + Vector3.UP * 1.1
	var forward: Vector3 = _platform_forward(&"Z5_APPROACH_02")
	_squirrel_right = Vector3(-forward.z, 0.0, forward.x).normalized()
	_squirrel_root = Node3D.new()
	_squirrel_root.name = "SquirrelStampedeSwarm"
	_squirrel_root.position = _world_local(_squirrel_base - _squirrel_right * 10.0)
	_world.add_child(_squirrel_root)

	var multimesh_instance := MultiMeshInstance3D.new()
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var squirrel_mesh := SphereMesh.new()
	squirrel_mesh.radius = 0.34
	squirrel_mesh.height = 0.62
	squirrel_mesh.material = _make_material(Color(0.48, 0.27, 0.10), 0.88)
	multimesh.mesh = squirrel_mesh
	multimesh.instance_count = 12
	for i: int in range(multimesh.instance_count):
		var row: int = i / 4
		var column: int = i % 4
		var local := Vector3(float(column) * 0.65, 0.15 + float((i + 1) % 2) * 0.18, float(row) * 0.75)
		multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, local))
	multimesh_instance.multimesh = multimesh
	_squirrel_root.add_child(multimesh_instance)

	_squirrel_area = Area3D.new()
	_squirrel_area.name = "SquirrelPushArea"
	_squirrel_area.collision_layer = 0
	_squirrel_area.collision_mask = 2
	_squirrel_area.monitoring = true
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(5.0, 3.0, 4.0)
	collision.shape = shape
	_squirrel_area.add_child(collision)
	_squirrel_root.add_child(_squirrel_area)
	_squirrel_root.visible = false

func _build_finale_rolling_log() -> void:
	var platform_id: StringName = &"Z6_01"
	var global_position: Vector3 = _platform_position(platform_id) + Vector3.UP * 1.25
	var forward: Vector3 = _platform_forward(platform_id)
	_finale_roll_right = Vector3(-forward.z, 0.0, forward.x).normalized()
	_finale_roll_visual = Node3D.new()
	_finale_roll_visual.name = "SkyFinaleRollingLog"
	_finale_roll_visual.position = _world_local(global_position)
	_finale_roll_visual.rotation.y = atan2(-forward.x, -forward.z)
	_world.add_child(_finale_roll_visual)
	var mesh_instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 2.15
	mesh.bottom_radius = 2.15
	mesh.height = 10.5
	mesh.material = _make_material(Color(0.54, 0.34, 0.12), 0.92)
	mesh_instance.mesh = mesh
	mesh_instance.rotation.x = deg_to_rad(90.0)
	_finale_roll_visual.add_child(mesh_instance)

	_finale_roll_area = Area3D.new()
	_finale_roll_area.name = "SkyFinaleRollInfluence"
	_finale_roll_area.position = _world_local(global_position)
	_finale_roll_area.collision_layer = 0
	_finale_roll_area.collision_mask = 2
	_finale_roll_area.monitoring = true
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(11.0, 4.0, 12.0)
	collision.shape = shape
	_finale_roll_area.add_child(collision)
	_world.add_child(_finale_roll_area)

func _build_finale_mushroom() -> void:
	var platform_id: StringName = &"Z6_02"
	var top: Vector3 = _platform_position(platform_id) + Vector3.UP * 0.8
	_finale_mushroom_area = Area3D.new()
	_finale_mushroom_area.name = "SkyFinaleMushroomArea"
	_finale_mushroom_area.position = _world_local(top + Vector3.UP * 1.2)
	_finale_mushroom_area.collision_layer = 0
	_finale_mushroom_area.collision_mask = 2
	_finale_mushroom_area.monitoring = true
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 3.0
	shape.height = 2.6
	collision.shape = shape
	_finale_mushroom_area.add_child(collision)
	_world.add_child(_finale_mushroom_area)
	_finale_mushroom_area.body_entered.connect(_on_finale_mushroom_body_entered)

	_finale_mushroom_visual = Node3D.new()
	_finale_mushroom_visual.name = "SkyFinaleMushroomVisual"
	_finale_mushroom_visual.position = _world_local(top + Vector3.UP * 0.5)
	_world.add_child(_finale_mushroom_visual)
	var cap := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 3.1
	mesh.height = 1.9
	mesh.material = _make_material(Color(0.94, 0.28, 0.19), 0.82)
	cap.mesh = mesh
	cap.scale = Vector3(1.0, 0.46, 1.0)
	_finale_mushroom_visual.add_child(cap)

func _build_finale_moving_branch() -> void:
	var platform_id: StringName = &"Z6_04"
	var base: Vector3 = _platform_position(platform_id) + Vector3.UP * 0.65
	var forward: Vector3 = _platform_forward(platform_id)
	_finale_moving_branch_right = Vector3(-forward.z, 0.0, forward.x).normalized()
	_finale_moving_branch = AnimatableBody3D.new()
	_finale_moving_branch.name = "SkyFinaleMovingBranch"
	_finale_moving_branch.sync_to_physics = true
	_finale_moving_branch.position = _world_local(base)
	_finale_moving_branch.rotation.y = atan2(-forward.x, -forward.z)
	_finale_moving_branch.collision_layer = 1
	_finale_moving_branch.collision_mask = 2
	var mesh := BoxMesh.new()
	mesh.size = Vector3(8.6, 0.65, 10.5)
	mesh.material = _make_material(Color(0.52, 0.33, 0.11), 0.92)
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	_finale_moving_branch.add_child(visual)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = mesh.size
	collision.shape = shape
	_finale_moving_branch.add_child(collision)
	_world.add_child(_finale_moving_branch)
	_finale_moving_branch_base = base

func _build_last_tree_bridge() -> void:
	var start: Vector3 = _platform_position(&"Z6_07") + Vector3.UP * 0.8
	var crown: Vector3 = _platform_position(&"CROWN_NEST") + Vector3.UP * 0.9
	var direction := crown - start
	direction.y = 0.0
	if direction.length_squared() <= 0.001:
		direction = Vector3.FORWARD
	else:
		direction = direction.normalized()
	var end: Vector3 = crown - direction * 5.0
	var bridge_data: Dictionary = _make_animatable_bridge("LastFallingTree", start, end, 4.1, 1.2, Color(0.40, 0.23, 0.07))
	_last_tree = bridge_data.get("body") as AnimatableBody3D
	if _last_tree == null:
		return
	_last_tree_final_position = bridge_data.get("final_position", _last_tree.global_position)
	_last_tree_yaw = float(bridge_data.get("yaw", _last_tree.rotation.y))
	_last_tree_start_position = _last_tree_final_position + Vector3.UP * 13.0 - direction * 2.5
	_last_tree.global_position = _last_tree_start_position
	_last_tree.rotation = Vector3(deg_to_rad(-72.0), _last_tree_yaw, deg_to_rad(8.0))
	_last_tree.collision_layer = 0

	_final_jump_forward = direction
	_final_jump_area = Area3D.new()
	_final_jump_area.name = "FinalJumpLaunchArea"
	_final_jump_area.position = _world_local(end + Vector3.UP * 1.3)
	_final_jump_area.collision_layer = 0
	_final_jump_area.collision_mask = 2
	_final_jump_area.monitoring = false
	var launch_collision := CollisionShape3D.new()
	var launch_shape := BoxShape3D.new()
	launch_shape.size = Vector3(7.0, 3.5, 5.0)
	launch_collision.shape = launch_shape
	_final_jump_area.add_child(launch_collision)
	_world.add_child(_final_jump_area)
	_final_jump_area.body_entered.connect(_on_final_jump_body_entered)

func _build_final_recovery_area() -> void:
	if _final_recovery_area != null and is_instance_valid(_final_recovery_area):
		_final_recovery_area.queue_free()
	var start: Vector3 = _platform_position(&"Z6_07")
	var crown: Vector3 = _platform_position(&"CROWN_NEST")
	_final_recovery_area = Area3D.new()
	_final_recovery_area.name = "FinalJumpRecoveryBranch"
	_final_recovery_area.position = _world_local((start + crown) * 0.5 + Vector3.DOWN * 4.6)
	_final_recovery_area.collision_layer = 0
	_final_recovery_area.collision_mask = 2
	_final_recovery_area.monitoring = true
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(38.0, 4.5, 30.0)
	collision.shape = shape
	_final_recovery_area.add_child(collision)
	_world.add_child(_final_recovery_area)
	_final_recovery_area.body_entered.connect(_on_final_recovery_body_entered)

func _build_crown_nest_polish() -> void:
	var center: Vector3 = _platform_position(&"CROWN_NEST") + Vector3.UP * 1.0
	var root := Node3D.new()
	root.name = "CrownNestProduction"
	root.position = _world_local(center)
	_world.add_child(root)
	var nest_material := _make_material(Color(0.58, 0.37, 0.12), 0.94)
	var feather_material := _make_material(Color(0.94, 0.92, 0.78), 0.72)
	for i: int in range(14):
		var angle: float = TAU * float(i) / 14.0
		var position := Vector3(sin(angle) * 10.5, 0.45 + float(i % 2) * 0.18, cos(angle) * 8.0)
		var log := _make_box_visual(Vector3(1.15, 0.8, 8.0), nest_material, position, angle)
		log.name = "NestLog_%02d" % i
		root.add_child(log)
	for i: int in range(10):
		var feather := _make_box_visual(
			Vector3(0.20, 0.05, 1.05),
			feather_material,
			Vector3(-4.5 + float(i) * 0.95, 1.2 + float(i % 3) * 0.35, sin(float(i)) * 3.0),
			float(i) * 0.55
		)
		feather.rotation.x = deg_to_rad(18.0 + float(i % 4) * 6.0)
		feather.name = "Feather_%02d" % i
		root.add_child(feather)
	for side: float in [-1.0, 1.0]:
		var pole := MeshInstance3D.new()
		var pole_mesh := CylinderMesh.new()
		pole_mesh.top_radius = 0.12
		pole_mesh.bottom_radius = 0.15
		pole_mesh.height = 5.0
		pole_mesh.material = nest_material
		pole.mesh = pole_mesh
		pole.position = Vector3(side * 12.5, 2.5, 7.5)
		root.add_child(pole)
		var flag := _make_box_visual(Vector3(2.2, 1.2, 0.08), _make_material(Color(0.95, 0.58, 0.10), 0.74), Vector3(side * 11.4, 3.6, 7.5), 0.0)
		root.add_child(flag)
	var finish_light := OmniLight3D.new()
	finish_light.name = "CrownNestSunlight"
	finish_light.position = Vector3(0.0, 8.0, 0.0)
	finish_light.light_color = Color(1.0, 0.88, 0.58)
	finish_light.light_energy = 2.2
	finish_light.omni_range = 28.0
	root.add_child(finish_light)
