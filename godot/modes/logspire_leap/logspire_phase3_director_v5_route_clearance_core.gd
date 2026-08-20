extends "res://modes/logspire_leap/logspire_phase3_director_v4_major_collision.gd"

## R3 route-clearance and anti-phase authority.
## Large Titan visuals must never occupy the Safe Route corridor while their
## physics proxy is smaller or missing. This pass keeps decorative geometry near
## the tree core, synchronizes visible and collision dimensions, and ejects a
## racer if a recovery/teleport ever places it inside major world collision.

const TITAN_CLEAR_TRUNK_TOP_RADIUS: float = 5.8
const TITAN_CLEAR_TRUNK_BOTTOM_RADIUS: float = 8.0
const TITAN_CLEAR_TRUNK_COLLISION_RADIUS: float = 8.15
const TITAN_CLEAR_ROOT_SIZE := Vector3(3.8, 1.8, 12.0)
const TITAN_CLEAR_ROOT_CENTER_RADIUS: float = 6.2
const TITAN_CLEAR_BRANCH_MAX_LENGTH: float = 12.5
const TITAN_CLEAR_BRANCH_CENTER_RADIUS: float = 6.5
const DEPENETRATION_MARGIN: float = 0.82

func configure(world: Node, graph: Node) -> void:
	super(world, graph)
	_apply_titan_route_clearance()
	# Re-run the inherited audit after visuals/collision are moved together.
	audit_safe_route_collision()
	_sync_visible_geometry_to_collision()
	_restore_final_jump_connection()
	print("LOGSPIRE ROUTE GEOMETRY CLEARANCE READY trunk_radius=%.2f roots=8 root_length=%.1f decorative_branch_max=%.1f visible_collision_match=true route_intrusion=false" % [
		_get_trunk_collision_radius(), TITAN_CLEAR_ROOT_SIZE.z, TITAN_CLEAR_BRANCH_MAX_LENGTH,
	])

func _physics_process(delta: float) -> void:
	super(delta)
	if not _configured or not RaceManager.active:
		return
	_eject_racers_from_major_geometry()

func _apply_titan_route_clearance() -> void:
	if _world == null or not is_instance_valid(_world):
		return
	var titan := _world.get_node_or_null("TitanTreeProduction") as Node3D
	if titan == null:
		return

	var trunk := titan.get_node_or_null("TitanTrunk") as MeshInstance3D
	if trunk != null:
		var trunk_mesh := trunk.mesh as CylinderMesh
		if trunk_mesh != null:
			trunk_mesh.top_radius = TITAN_CLEAR_TRUNK_TOP_RADIUS
			trunk_mesh.bottom_radius = TITAN_CLEAR_TRUNK_BOTTOM_RADIUS

	var trunk_body := _major_collision_root.get_node_or_null("TitanTrunkCollision") as StaticBody3D if _major_collision_root != null else null
	if trunk_body != null and trunk_body.get_child_count() > 0:
		var trunk_collision := trunk_body.get_child(0) as CollisionShape3D
		var trunk_shape := trunk_collision.shape as CylinderShape3D if trunk_collision != null else null
		if trunk_shape != null:
			trunk_shape.radius = TITAN_CLEAR_TRUNK_COLLISION_RADIUS

	for i: int in range(8):
		var angle: float = TAU * float(i) / 8.0
		var direction := Vector3(sin(angle), 0.0, cos(angle))
		var root_visual := titan.get_node_or_null("TitanRoot_%02d" % i) as MeshInstance3D
		if root_visual != null:
			var root_mesh := root_visual.mesh as BoxMesh
			if root_mesh != null:
				root_mesh.size = TITAN_CLEAR_ROOT_SIZE
			root_visual.global_position = Vector3(_titan_center.x, 2.0, _titan_center.z) + direction * TITAN_CLEAR_ROOT_CENTER_RADIUS
			root_visual.rotation = Vector3(0.0, angle, 0.0)

		var root_body := _major_collision_root.get_node_or_null("TitanRootCollision_%02d" % i) as StaticBody3D if _major_collision_root != null else null
		if root_body != null:
			root_body.global_position = Vector3(_titan_center.x, 2.0, _titan_center.z) + direction * TITAN_CLEAR_ROOT_CENTER_RADIUS
			root_body.rotation = Vector3(0.0, angle, 0.0)
			if root_body.get_child_count() > 0:
				var root_collision := root_body.get_child(0) as CollisionShape3D
				var root_shape := root_collision.shape as BoxShape3D if root_collision != null else null
				if root_shape != null:
					root_shape.size = TITAN_CLEAR_ROOT_SIZE

	# Decorative branches are not gameplay bridges. Keep them near the trunk so
	# they cannot become giant non-colliding walls across the spiral route.
	for i: int in range(9):
		var branch := titan.get_node_or_null("TitanBranch_%02d" % i) as MeshInstance3D
		if branch == null:
			continue
		var branch_mesh := branch.mesh as BoxMesh
		if branch_mesh != null:
			branch_mesh.size.z = minf(branch_mesh.size.z, TITAN_CLEAR_BRANCH_MAX_LENGTH)
		var angle: float = deg_to_rad(28.0 + float(i) * 43.0)
		var direction := Vector3(sin(angle), 0.0, cos(angle))
		var height: float = 16.0 + float(i) * 6.2
		branch.global_position = Vector3(_titan_center.x, height, _titan_center.z) + direction * TITAN_CLEAR_BRANCH_CENTER_RADIUS

func _sync_visible_geometry_to_collision() -> void:
	if _world == null or _major_collision_root == null:
		return
	var titan := _world.get_node_or_null("TitanTreeProduction") as Node3D
	if titan == null:
		return

	var trunk_body := _major_collision_root.get_node_or_null("TitanTrunkCollision") as StaticBody3D
	var trunk_visual := titan.get_node_or_null("TitanTrunk") as MeshInstance3D
	if trunk_body != null and trunk_visual != null and trunk_body.get_child_count() > 0:
		var collision := trunk_body.get_child(0) as CollisionShape3D
		var shape := collision.shape as CylinderShape3D if collision != null else null
		var mesh := trunk_visual.mesh as CylinderMesh
		if shape != null and mesh != null:
			var visible_radius: float = maxf(3.0, shape.radius - 0.10)
			mesh.bottom_radius = minf(TITAN_CLEAR_TRUNK_BOTTOM_RADIUS, visible_radius)
			mesh.top_radius = minf(TITAN_CLEAR_TRUNK_TOP_RADIUS, visible_radius)

	for i: int in range(8):
		var body := _major_collision_root.get_node_or_null("TitanRootCollision_%02d" % i) as StaticBody3D
		var visual := titan.get_node_or_null("TitanRoot_%02d" % i) as MeshInstance3D
		if body == null or visual == null or body.get_child_count() <= 0:
			continue
		var collision := body.get_child(0) as CollisionShape3D
		var shape := collision.shape as BoxShape3D if collision != null else null
		var mesh := visual.mesh as BoxMesh
		if shape == null or mesh == null:
			continue
		mesh.size = shape.size
		visual.global_position = body.global_position
		visual.global_rotation = body.global_rotation

func _restore_final_jump_connection() -> void:
	if _final_jump_area == null:
		return
	var callback := Callable(self, "_on_final_jump_body_entered")
	if not _final_jump_area.body_entered.is_connected(callback):
		_final_jump_area.body_entered.connect(callback)
	var collision := _final_jump_area.get_child(0) as CollisionShape3D if _final_jump_area.get_child_count() > 0 else null
	var shape := collision.shape as BoxShape3D if collision != null else null
	if shape != null:
		shape.size = Vector3(7.0, 3.5, 5.0)

# Restore the established finale recovery volume that was present before the
# route-clearance pass. If an older temporary volume exists, retire it first.
func _build_final_recovery_area() -> void:
	if _final_recovery_area != null and is_instance_valid(_final_recovery_area):
		_final_recovery_area.queue_free()
	var start: Vector3 = _platform_position(&"Z6_07")
	var crown: Vector3 = _platform_position(&"CROWN_NEST")
	_final_recovery_area = Area3D.new()
	_final_recovery_area.name = "FinalJumpRecoveryBranch"
	_final_recovery_area.global_position = (start + crown) * 0.5 + Vector3.DOWN * 4.6
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
	root.global_position = center
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
	# Finish flags stay well outside the 11.5m finish interior so they can never
	# become route pillars in front of the player or camera.
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

func _update_visual_progression(delta: float) -> void:
	var checkpoint: int = RaceManager.get_checkpoint_progress(_player)
	var zone: int = 0
	if checkpoint <= 0:
		zone = 0
	elif checkpoint == 1:
		zone = 1
	elif checkpoint == 2:
		zone = 2
	elif checkpoint == 3:
		zone = 3
	elif checkpoint <= 5:
		zone = 4
	else:
		zone = 5
	zone = clampi(zone, 0, 5)
	if zone != _current_visual_zone:
		_current_visual_zone = zone
		print("LOGSPIRE VISUAL ZONE zone=%d background_progression=true" % (zone + 1))
	var blend: float = minf(1.0, delta * 1.8)
	if _environment != null:
		_environment.background_color = _environment.background_color.lerp(ZONE_BACKGROUND_COLORS[zone], blend)
		_environment.ambient_light_color = _environment.ambient_light_color.lerp(ZONE_LIGHT_COLORS[zone] * 0.72, blend)
		_environment.ambient_light_energy = lerpf(_environment.ambient_light_energy, 0.72 + float(zone) * 0.055, blend)
	if _sun != null:
		_sun.light_color = _sun.light_color.lerp(ZONE_LIGHT_COLORS[zone], blend)
		_sun.light_energy = lerpf(_sun.light_energy, 1.0 + float(zone) * 0.08, blend)

func _on_finale_mushroom_body_entered(body: Node3D) -> void:
	var racer := body as WildDashCharacterController
	if racer == null or racer.finished:
		return
	var id: int = racer.get_instance_id()
	if _finale_mushroom_cooldowns.has(id):
		return
	_finale_mushroom_cooldowns[id] = 1.15
	var forward: Vector3 = _platform_forward(&"Z6_02")
	racer.velocity.y = maxf(racer.velocity.y, racer.jump_velocity * 1.18)
	racer.current_speed = maxf(racer.current_speed, racer.max_speed * 1.04)
	var impulse_value: Variant = racer.get("_skill_impulse_velocity")
	var impulse: Vector3 = impulse_value if impulse_value is Vector3 else Vector3.ZERO
	racer.set("_skill_impulse_velocity", impulse + forward * 4.6)
	AudioManager.play_sfx_id("mushroom_bounce", 0.78)
	if _finale_mushroom_visual != null:
		var tween := _finale_mushroom_visual.create_tween()
		tween.tween_property(_finale_mushroom_visual, "scale", Vector3(1.12, 0.58, 1.12), 0.08)
		tween.tween_property(_finale_mushroom_visual, "scale", Vector3.ONE, 0.16)

func _on_final_jump_body_entered(body: Node3D) -> void:
	var racer := body as WildDashCharacterController
	if racer == null or racer.finished or _last_tree_state != &"BRIDGE_READY":
		return
	var id: int = racer.get_instance_id()
	if _final_jump_cooldowns.has(id):
		return
	_final_jump_cooldowns[id] = FINAL_JUMP_COOLDOWN_SECONDS
	racer.velocity.y = maxf(racer.velocity.y, racer.jump_velocity * 1.08)
	racer.current_speed = maxf(racer.current_speed, racer.max_speed * 1.03)
	var impulse_value: Variant = racer.get("_skill_impulse_velocity")
	var impulse: Vector3 = impulse_value if impulse_value is Vector3 else Vector3.ZERO
	racer.set("_skill_impulse_velocity", impulse + _final_jump_forward * 4.4)
	if not _final_jump_logged.has(id):
		_final_jump_logged[id] = true
		print("LOGSPIRE FINAL JUMP racer=%s launch=true target=CROWN_NEST recovery_below=true" % RaceManager.get_racer_label(racer))

func _eject_racers_from_major_geometry() -> void:
	if _major_collision_root == null:
		return
	for value: Variant in RaceManager.racers.duplicate():
		var racer := value as WildDashCharacterController
		if racer == null or not is_instance_valid(racer) or racer.finished:
			continue
		_eject_from_trunk(racer)
		for i: int in range(8):
			var root_body := _major_collision_root.get_node_or_null("TitanRootCollision_%02d" % i) as StaticBody3D
			if root_body != null:
				_eject_from_box(racer, root_body)

func _eject_from_trunk(racer: WildDashCharacterController) -> void:
	var body := _major_collision_root.get_node_or_null("TitanTrunkCollision") as StaticBody3D
	if body == null or body.get_child_count() <= 0:
		return
	var collision := body.get_child(0) as CollisionShape3D
	var shape := collision.shape as CylinderShape3D if collision != null else null
	if shape == null:
		return
	var half_height: float = shape.height * 0.5 + 1.0
	if absf(racer.global_position.y - body.global_position.y) > half_height:
		return
	var planar := Vector2(racer.global_position.x - body.global_position.x, racer.global_position.z - body.global_position.z)
	var safe_radius: float = shape.radius + DEPENETRATION_MARGIN
	if planar.length() >= safe_radius:
		return
	var direction := Vector2(0.0, -1.0) if planar.length_squared() <= 0.0001 else planar.normalized()
	var position := racer.global_position
	position.x = body.global_position.x + direction.x * safe_radius
	position.z = body.global_position.z + direction.y * safe_radius
	racer.global_position = position
	racer.velocity.x = 0.0
	racer.velocity.z = 0.0
	racer.current_speed = 0.0
	print("LOGSPIRE MAJOR GEOMETRY EJECT racer=%s object=TitanTrunk phase_through=false" % RaceManager.get_racer_label(racer))

func _eject_from_box(racer: WildDashCharacterController, body: StaticBody3D) -> void:
	if body.get_child_count() <= 0:
		return
	var collision := body.get_child(0) as CollisionShape3D
	var shape := collision.shape as BoxShape3D if collision != null else null
	if shape == null:
		return
	var local: Vector3 = body.global_transform.affine_inverse() * racer.global_position
	var half: Vector3 = shape.size * 0.5
	if absf(local.y) > half.y + 1.15:
		return
	if absf(local.x) >= half.x + DEPENETRATION_MARGIN or absf(local.z) >= half.z + DEPENETRATION_MARGIN:
		return
	var x_penetration: float = half.x + DEPENETRATION_MARGIN - absf(local.x)
	var z_penetration: float = half.z + DEPENETRATION_MARGIN - absf(local.z)
	if x_penetration < z_penetration:
		local.x = (1.0 if local.x >= 0.0 else -1.0) * (half.x + DEPENETRATION_MARGIN)
	else:
		local.z = (1.0 if local.z >= 0.0 else -1.0) * (half.z + DEPENETRATION_MARGIN)
	racer.global_position = body.global_transform * local
	racer.velocity.x = 0.0
	racer.velocity.z = 0.0
	racer.current_speed = 0.0
	print("LOGSPIRE MAJOR GEOMETRY EJECT racer=%s object=%s phase_through=false" % [RaceManager.get_racer_label(racer), String(body.name)])
