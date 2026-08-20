extends "res://modes/logspire_leap/logspire_phase3_director_v6_titan_tree_safe.gd"

## Round 3 Sky Log Finale collision authority.
##
## The production rolling log used to be a visual-only Node3D. Its CylinderMesh
## had no PhysicsBody3D or CollisionShape3D, while a large world-axis Box Area3D
## applied lateral influence around it. A racer could therefore pass through the
## rendered cylinder and become visibly embedded inside the log.
##
## V7 makes the rendered log and the physical obstacle the same AnimatableBody3D.
## The collision cylinder matches the visual radius/length and shares its axis.
## The influence zone is also cylinder-shaped and parented to the log so it can
## never drift out of alignment. A smaller interior-only overlap guard repairs a
## rare tunnelling/deep-penetration state without resetting race progress/speed.

const FINALE_LOG_RADIUS: float = 2.15
const FINALE_LOG_LENGTH: float = 10.5
const FINALE_LOG_INFLUENCE_RADIUS: float = 2.95
const FINALE_LOG_INFLUENCE_LENGTH: float = 11.4
const FINALE_LOG_INTERIOR_RADIUS: float = 1.92
const FINALE_LOG_INTERIOR_LENGTH: float = 9.9
const FINALE_LOG_RACER_CLEARANCE: float = 0.72
const FINALE_LOG_PENETRATION_EPSILON: float = 0.04

var _finale_roll_penetration_area: Area3D
var _finale_roll_penetration_log_once: Dictionary = {}

func configure(world: Node, graph: Node) -> void:
	super(world, graph)
	print("LOGSPIRE FINALE LOG COLLISION READY body=AnimatableBody3D radius=%.2f length=%.2f aligned_influence=true penetration_guard=true" % [
		FINALE_LOG_RADIUS,
		FINALE_LOG_LENGTH,
	])

func _build_finale_rolling_log() -> void:
	var platform_id: StringName = &"Z6_01"
	var global_position: Vector3 = _platform_position(platform_id) + Vector3.UP * 1.25
	var forward: Vector3 = _platform_forward(platform_id)
	_finale_roll_right = Vector3(-forward.z, 0.0, forward.x).normalized()

	var body := AnimatableBody3D.new()
	body.name = "SkyFinaleRollingLog"
	body.sync_to_physics = true
	body.collision_layer = 1
	body.collision_mask = 2
	body.add_to_group("logspire_finale_rolling_log")
	body.position = _world_local(global_position)
	body.rotation.y = atan2(-forward.x, -forward.z)
	_finale_roll_visual = body

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	var mesh := CylinderMesh.new()
	mesh.top_radius = FINALE_LOG_RADIUS
	mesh.bottom_radius = FINALE_LOG_RADIUS
	mesh.height = FINALE_LOG_LENGTH
	mesh.material = _make_material(Color(0.54, 0.34, 0.12), 0.92)
	mesh_instance.mesh = mesh
	mesh_instance.rotation.x = deg_to_rad(90.0)
	body.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	var shape := CylinderShape3D.new()
	shape.radius = FINALE_LOG_RADIUS
	shape.height = FINALE_LOG_LENGTH
	collision.shape = shape
	collision.rotation.x = deg_to_rad(90.0)
	body.add_child(collision)

	# The rolling influence follows the same local axis as the physical cylinder.
	# It is intentionally only slightly larger than the log instead of the old
	# oversized world-axis 11 x 4 x 12 box.
	_finale_roll_area = Area3D.new()
	_finale_roll_area.name = "SkyFinaleRollInfluence"
	_finale_roll_area.collision_layer = 0
	_finale_roll_area.collision_mask = 2
	_finale_roll_area.monitoring = true
	var influence_collision := CollisionShape3D.new()
	influence_collision.name = "InfluenceCollision"
	var influence_shape := CylinderShape3D.new()
	influence_shape.radius = FINALE_LOG_INFLUENCE_RADIUS
	influence_shape.height = FINALE_LOG_INFLUENCE_LENGTH
	influence_collision.shape = influence_shape
	influence_collision.rotation.x = deg_to_rad(90.0)
	_finale_roll_area.add_child(influence_collision)
	body.add_child(_finale_roll_area)

	# This smaller area should never overlap a healthy CharacterBody3D because the
	# solid cylinder blocks it first. If it does overlap, physics tunnelling or an
	# external transform correction has produced a real penetration and we eject.
	_finale_roll_penetration_area = Area3D.new()
	_finale_roll_penetration_area.name = "SkyFinaleLogInteriorGuard"
	_finale_roll_penetration_area.collision_layer = 0
	_finale_roll_penetration_area.collision_mask = 2
	_finale_roll_penetration_area.monitoring = true
	var interior_collision := CollisionShape3D.new()
	interior_collision.name = "InteriorCollision"
	var interior_shape := CylinderShape3D.new()
	interior_shape.radius = FINALE_LOG_INTERIOR_RADIUS
	interior_shape.height = FINALE_LOG_INTERIOR_LENGTH
	interior_collision.shape = interior_shape
	interior_collision.rotation.x = deg_to_rad(90.0)
	_finale_roll_penetration_area.add_child(interior_collision)
	body.add_child(_finale_roll_penetration_area)

	# Register the complete body only after its authored local transform and all
	# collision children are ready, avoiding a first-physics-frame origin hazard.
	_world.add_child(body)

func _update_finale_obstacles(delta: float) -> void:
	super(delta)
	_guard_finale_log_penetration()

func _guard_finale_log_penetration() -> void:
	var body := _finale_roll_visual as AnimatableBody3D
	if body == null or not is_instance_valid(body):
		return
	if _finale_roll_penetration_area == null or not is_instance_valid(_finale_roll_penetration_area):
		return

	for body_value: Node3D in _finale_roll_penetration_area.get_overlapping_bodies():
		var racer := body_value as WildDashCharacterController
		if racer == null or not is_instance_valid(racer) or racer.finished:
			continue

		var local: Vector3 = body.to_local(racer.global_position)
		var radial := Vector2(local.x, local.y)
		if radial.length_squared() <= 0.0001:
			radial = Vector2.UP
		var outward_2d: Vector2 = radial.normalized()
		var safe_radius: float = FINALE_LOG_RADIUS + FINALE_LOG_RACER_CLEARANCE + FINALE_LOG_PENETRATION_EPSILON
		var safe_local := Vector3(
			outward_2d.x * safe_radius,
			outward_2d.y * safe_radius,
			clampf(local.z, -FINALE_LOG_LENGTH * 0.5, FINALE_LOG_LENGTH * 0.5)
		)
		var safe_global: Vector3 = body.to_global(safe_local)
		var outward_local := Vector3(outward_2d.x, outward_2d.y, 0.0)
		var outward_global: Vector3 = (body.global_transform.basis * outward_local).normalized()

		# Preserve forward race momentum. Only remove velocity and knockback that
		# points deeper into the log, then apply the smallest positional correction.
		var inward_velocity: float = racer.velocity.dot(outward_global)
		if inward_velocity < 0.0:
			racer.velocity -= outward_global * inward_velocity
		var knockback: Vector3 = racer.get_knockback_velocity()
		var inward_knockback: float = knockback.dot(outward_global)
		if inward_knockback < 0.0:
			racer.set("_knockback_velocity", knockback - outward_global * inward_knockback)
		racer.global_position = safe_global

		var racer_id: int = racer.get_instance_id()
		if not _finale_roll_penetration_log_once.has(racer_id):
			_finale_roll_penetration_log_once[racer_id] = true
			print("LOGSPIRE FINALE LOG PENETRATION REPAIRED racer=%s local=(%.2f,%.2f,%.2f) correction=surface_eject progress_preserved=true speed_reset=false" % [
				RaceManager.get_racer_label(racer),
				local.x,
				local.y,
				local.z,
			])
