class_name WildDashRaceEnvironmentCollisionController
extends Node

const BARRIER_FACTORY: Script = preload("res://tracks/race_barrier_factory.gd")

const GRAND_PRIX_HARD_SEGMENTS: Array[int] = [0, 1, 2, 3, 4, 5, 7, 8, 9, 12, 14, 18, 19, 25, 26, 27, 28]
const NEON_HARD_SEGMENTS: Array[int] = [6, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 20, 21, 22, 23, 24]
const GRAND_PRIX_TUNNEL_SEGMENT := 25
const NEON_TUNNEL_SEGMENT := 13
const TUNNEL_SHELL_LENGTH_EXTENSION := 12.0
const TUNNEL_FAILSAFE_END_EXTENSION := 6.0
const TUNNEL_FAILSAFE_EDGE_PADDING := 0.10

const NEON_HARD_BATCHES: PackedStringArray = [
	"ContainersRed", "ContainersBlue", "ContainersTeal",
	"WarehouseBodies", "NeonCityBuildings", "ShipyardChicaneBarriers",
]
const SNOWPEAK_HARD_BATCHES: PackedStringArray = [
	"ResortLodges", "SkiLiftTowers",
]

var _installed := false
var _barrier_count := 0
var _visual_barrier_count := 0
var _protected_visuals_skipped := 0
var _tunnel_shell_barriers := 0
var _tunnel_profiles: Array[Dictionary] = []
var _tunnel_failsafe_corrections := 0

func _ready() -> void:
	# RacingFeelController uses priority 100 for the extra lateral slip move.
	# Run after it so the tunnel failsafe sees the final physics position for the
	# frame rather than allowing a second motion to escape after containment.
	process_priority = 120
	call_deferred("_install_after_track_ready")

func _physics_process(_delta: float) -> void:
	if not _installed or _tunnel_profiles.is_empty():
		return
	for racer in RaceManager.racers:
		if racer is CharacterBody3D:
			_enforce_tunnel_corridor(racer as CharacterBody3D)

func _install_after_track_ready() -> void:
	for _frame in range(3):
		await get_tree().physics_frame
	if _installed or not is_inside_tree():
		return
	var track := _find_track()
	if track == null:
		push_warning("RACE COLLISION PASS: no racing track found under %s" % get_parent().name)
		return
	var collision_root := track.get_node_or_null("GameplayCollision") as Node3D
	if collision_root == null:
		collision_root = Node3D.new()
		collision_root.name = "GameplayCollision"
		track.add_child(collision_root)

	_tag_existing_world_collision(collision_root)
	_configure_racer_collision_safety()
	if track is WildDashGrandPrixTrack:
		_barrier_count += _add_segment_containment(track, collision_root, GRAND_PRIX_HARD_SEGMENTS, "GP")
		_tunnel_shell_barriers += _add_tunnel_hard_shell(track, collision_root, GRAND_PRIX_TUNNEL_SEGMENT, "GP")
	elif track is WildDashNeonHarborTrack:
		_barrier_count += _add_segment_containment(track, collision_root, NEON_HARD_SEGMENTS, "NH")
		_visual_barrier_count += _add_hard_visual_batch_collisions(track, collision_root, NEON_HARD_BATCHES, "NH")
		_tunnel_shell_barriers += _add_tunnel_hard_shell(track, collision_root, NEON_TUNNEL_SEGMENT, "NH")
	elif track is WildDashSnowpeakWinterTrack:
		# Snowpeak already has collision on dangerous winter rails and the Ice
		# Cave. Only visually solid buildings/infrastructure need to be promoted
		# from decoration to hard barriers; snowbanks/route poles remain soft.
		_visual_barrier_count += _add_hard_visual_batch_collisions(track, collision_root, SNOWPEAK_HARD_BATCHES, "SP")

	_installed = true
	print("RACE COLLISION PASS READY track=%s segment_barriers=%d visual_hard_barriers=%d tunnel_shell=%d tunnel_profiles=%d protected_skipped=%d racers=%d safe_margin=0.06 debug=%s" % [
		track.name, _barrier_count, _visual_barrier_count, _tunnel_shell_barriers,
		_tunnel_profiles.size(), _protected_visuals_skipped, RaceManager.racers.size(),
		str(OS.has_environment("WILDDASH_DEBUG_COLLISION")),
	])

func _find_track() -> Node3D:
	var parent := get_parent()
	if parent == null:
		return null
	for child in parent.get_children():
		if child is WildDashGrandPrixTrack or child is WildDashNeonHarborTrack or child is WildDashSnowpeakWinterTrack:
			return child as Node3D
	return null

func _configure_racer_collision_safety() -> void:
	for racer in RaceManager.racers:
		if racer is CharacterBody3D:
			var body := racer as CharacterBody3D
			# A small but deliberate recovery margin keeps the gameplay capsule from
			# visually sinking halfway into thin walls before slide resolution. This
			# is world-contact tolerance only; character stats and route widths stay
			# unchanged.
			body.safe_margin = maxf(body.safe_margin, 0.06)

func _add_segment_containment(track: Node3D, collision_root: Node3D, segments: Array[int], prefix: String) -> int:
	var added := 0
	for segment_index in segments:
		var road := _find_road_collision(collision_root, segment_index)
		if road == null:
			continue
		var width := road.size.x
		var length := road.size.z
		var road_basis := road.global_transform.basis
		var forward := -road_basis.z
		forward.y = 0.0
		if forward.length_squared() <= 0.001:
			continue
		forward = forward.normalized()
		var right := Vector3(-forward.z, 0.0, forward.x)
		var center := road.global_position
		var yaw := atan2(-forward.x, -forward.z)
		# A thicker/taller simple volume sits just outside the visual road edge.
		# It supplements thin guide rails and stops boost/slip tunnelling without
		# narrowing the normal lane.
		for side: float in [-1.0, 1.0]:
			var barrier_center := center + right * side * (width * 0.5 + 0.46) + Vector3.UP * 1.36
			BARRIER_FACTORY.add_box_barrier(
				collision_root,
				"%s_HardContainment_%02d_%s" % [prefix, segment_index, "L" if side < 0.0 else "R"],
				barrier_center,
				Vector3(0.78, 2.8, length + 0.5),
				yaw
			)
			added += 1
	return added

func _add_tunnel_hard_shell(track: Node3D, collision_root: Node3D, segment_index: int, prefix: String) -> int:
	var road := _find_road_collision(collision_root, segment_index)
	if road == null:
		push_warning("%s TUNNEL COLLISION: missing road collision for segment %d" % [prefix, segment_index])
		return 0

	var route: Array[Vector3] = track.get_route_points()
	if segment_index < 0 or segment_index + 1 >= route.size():
		push_warning("%s TUNNEL COLLISION: route index out of range" % prefix)
		return 0

	var added := 0
	var road_center := road.global_position
	var wall_sources: Array[CSGBox3D] = []
	var roof_source: CSGBox3D = null
	for child in collision_root.get_children():
		if not child is CSGBox3D:
			continue
		var csg := child as CSGBox3D
		var lower_name := String(csg.name).to_lower()
		if lower_name.contains("tunnelwall") or lower_name.contains("tunnel_wall"):
			wall_sources.append(csg)
		elif lower_name.contains("tunnelroof") or lower_name.contains("tunnel_roof"):
			roof_source = csg

	# Existing CSG walls are kept, but a StaticBody/BoxShape shell is layered on
	# top because it is more predictable for high-speed CharacterBody sweeps.
	for wall in wall_sources:
		var base_transform := Transform3D(wall.global_transform.basis.orthonormalized(), wall.global_position)
		var shell_size := Vector3(
			maxf(1.25, wall.size.x + 0.70),
			maxf(5.8, wall.size.y + 0.80),
			wall.size.z + TUNNEL_SHELL_LENGTH_EXTENSION
		)
		BARRIER_FACTORY.add_transformed_box_barrier(
			collision_root,
			"%s_TunnelShell_%s" % [prefix, String(wall.name)],
			base_transform,
			shell_size,
			Color(1.0, 0.12, 0.08, 0.26)
		)
		added += 1

		# A second outer backstop overlaps the primary shell. It never narrows the
		# road, but prevents a racer that somehow crosses the first contact plane
		# during a boost/slip frame from escaping into scenery.
		var outward := wall.global_position - road_center
		outward.y = 0.0
		if outward.length_squared() > 0.001:
			outward = outward.normalized()
			var backstop_transform := base_transform
			backstop_transform.origin += outward * 0.72
			BARRIER_FACTORY.add_transformed_box_barrier(
				collision_root,
				"%s_TunnelBackstop_%s" % [prefix, String(wall.name)],
				backstop_transform,
				Vector3(maxf(1.10, wall.size.x + 0.55), shell_size.y + 0.35, shell_size.z + 2.0),
				Color(0.95, 0.04, 0.04, 0.18)
			)
			added += 1

	if roof_source != null:
		var roof_transform := Transform3D(roof_source.global_transform.basis.orthonormalized(), roof_source.global_position)
		BARRIER_FACTORY.add_transformed_box_barrier(
			collision_root,
			"%s_TunnelShell_%s" % [prefix, String(roof_source.name)],
			roof_transform,
			Vector3(roof_source.size.x + 0.8, maxf(1.15, roof_source.size.y + 0.55), roof_source.size.z + TUNNEL_SHELL_LENGTH_EXTENSION),
			Color(1.0, 0.22, 0.05, 0.18)
		)
		added += 1

	# Register a final corridor safety net. Physical walls remain the primary
	# solution; this correction only fires if the character center is already
	# beyond the legal tunnel width after all CharacterBody motions in a frame.
	_tunnel_profiles.append({
		"prefix": prefix,
		"a": route[segment_index],
		"b": route[segment_index + 1],
		"width": road.size.x,
	})
	print("%s TUNNEL HARD SHELL READY walls=%d shell_barriers=%d width=%.2f length=%.2f" % [
		prefix, wall_sources.size(), added, road.size.x, road.size.z,
	])
	return added

func _enforce_tunnel_corridor(racer: CharacterBody3D) -> void:
	for profile in _tunnel_profiles:
		var a: Vector3 = profile.get("a", Vector3.ZERO)
		var b: Vector3 = profile.get("b", Vector3.ZERO)
		var width := float(profile.get("width", 0.0))
		if width <= 0.1:
			continue
		var ab := b - a
		var ab_length_squared := ab.length_squared()
		if ab_length_squared <= 0.001:
			continue
		var raw_t := (racer.global_position - a).dot(ab) / ab_length_squared
		var extension_t := TUNNEL_FAILSAFE_END_EXTENSION / sqrt(ab_length_squared)
		if raw_t < -extension_t or raw_t > 1.0 + extension_t:
			continue
		var t := clampf(raw_t, 0.0, 1.0)
		var centerline := a.lerp(b, t)
		# Ignore racers far above/below the drivable tunnel shell. This keeps the
		# safeguard from affecting unrelated scenery or respawn positions.
		if absf(racer.global_position.y - centerline.y) > 6.5:
			continue
		var planar := b - a
		planar.y = 0.0
		if planar.length_squared() <= 0.001:
			continue
		planar = planar.normalized()
		var right := Vector3(-planar.z, 0.0, planar.x)
		var lateral := (racer.global_position - centerline).dot(right)
		var radius := _get_racer_collision_radius(racer)
		var allowed_center_lateral := maxf(1.0, width * 0.5 - radius - TUNNEL_FAILSAFE_EDGE_PADDING)
		if absf(lateral) <= allowed_center_lateral:
			continue

		var side := signf(lateral)
		var excess := lateral - side * allowed_center_lateral
		racer.global_position -= right * excess
		var outward := right * side
		var outward_velocity := racer.velocity.dot(outward)
		if outward_velocity > 0.0:
			racer.velocity -= outward * outward_velocity
		if racer is WildDashCharacterController:
			var controller := racer as WildDashCharacterController
			controller.current_speed *= 0.90
		_tunnel_failsafe_corrections += 1
		if _tunnel_failsafe_corrections <= 8 or OS.has_environment("WILDDASH_DEBUG_COLLISION"):
			print("%s TUNNEL FAILSAFE BLOCK racer=%s lateral=%.2f allowed=%.2f correction=%.2f" % [
				String(profile.get("prefix", "RACE")), racer.name, lateral, allowed_center_lateral, absf(excess),
			])
		return

func _get_racer_collision_radius(racer: CharacterBody3D) -> float:
	var collision_shape := racer.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision_shape != null and collision_shape.shape is CapsuleShape3D:
		return (collision_shape.shape as CapsuleShape3D).radius
	return 0.62

func _find_road_collision(collision_root: Node3D, segment_index: int) -> CSGBox3D:
	var prefix := "Road_%02d" % segment_index
	for child in collision_root.get_children():
		if child is CSGBox3D and String(child.name).begins_with(prefix):
			return child as CSGBox3D
	return null

func _add_hard_visual_batch_collisions(
	track: Node3D,
	collision_root: Node3D,
	batch_names: PackedStringArray,
	prefix: String
) -> int:
	var decoration_root := track.get_node_or_null("DecorationGeometry") as Node3D
	if decoration_root == null:
		return 0
	var added := 0
	for batch_name in batch_names:
		var node := decoration_root.get_node_or_null(NodePath(batch_name))
		if not node is MultiMeshInstance3D:
			continue
		var instance := node as MultiMeshInstance3D
		var multimesh := instance.multimesh
		if multimesh == null or not multimesh.mesh is BoxMesh:
			continue
		var primitive_size := (multimesh.mesh as BoxMesh).size
		for index in range(multimesh.instance_count):
			var instance_transform := multimesh.get_instance_transform(index)
			var world_transform := instance.global_transform * instance_transform
			var scale := world_transform.basis.get_scale()
			var size := Vector3(
				absf(scale.x * primitive_size.x),
				absf(scale.y * primitive_size.y),
				absf(scale.z * primitive_size.z)
			)
			if _should_preserve_open_corridor(track, batch_name, world_transform.origin, size):
				_protected_visuals_skipped += 1
				continue
			# Strip the visual scale from the body transform; BoxShape owns size.
			var rotation_basis := world_transform.basis.orthonormalized()
			var barrier_transform := Transform3D(rotation_basis, world_transform.origin)
			BARRIER_FACTORY.add_transformed_box_barrier(
				collision_root,
				"%s_%s_Hard_%02d" % [prefix, batch_name, index],
				barrier_transform,
				size
			)
			added += 1
	return added

func _should_preserve_open_corridor(track: Node3D, batch_name: String, origin: Vector3, size: Vector3) -> bool:
	if not track is WildDashNeonHarborTrack or not batch_name.begins_with("Containers"):
		return false
	# Neon Harbor's service-lane shortcut connects route points 3 -> 5 while
	# skipping point 4. Solidify real container stacks, but never generate a new
	# collision volume inside the established shortcut corridor.
	var route := (track as WildDashNeonHarborTrack).get_route_points()
	if route.size() <= 5:
		return false
	var clearance := 4.6 + maxf(size.x, size.z) * 0.5
	return _distance_xz_to_segment(origin, route[3], route[5]) < clearance

func _distance_xz_to_segment(point: Vector3, a: Vector3, b: Vector3) -> float:
	var p := Vector2(point.x, point.z)
	var av := Vector2(a.x, a.z)
	var bv := Vector2(b.x, b.z)
	var segment := bv - av
	var length_squared := segment.length_squared()
	if length_squared <= 0.001:
		return p.distance_to(av)
	var t := clampf((p - av).dot(segment) / length_squared, 0.0, 1.0)
	return p.distance_to(av.lerp(bv, t))

func _tag_existing_world_collision(collision_root: Node3D) -> void:
	for child in collision_root.get_children():
		if child is CollisionObject3D:
			var collision_object := child as CollisionObject3D
			# Existing CSG generated static bodies use the world defaults. Explicit
			# Static/Animatable bodies are normalized to world layer 1 so racer mask
			# behaviour stays predictable across all race tracks.
			if collision_object is StaticBody3D or collision_object is AnimatableBody3D:
				collision_object.collision_layer = 1
				collision_object.add_to_group("wilddash_hard_barrier")
