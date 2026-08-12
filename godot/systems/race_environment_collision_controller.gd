class_name WildDashRaceEnvironmentCollisionController
extends Node

const BARRIER_FACTORY: Script = preload("res://tracks/race_barrier_factory.gd")

const GRAND_PRIX_HARD_SEGMENTS: Array[int] = [0, 1, 2, 3, 4, 5, 7, 8, 9, 12, 14, 18, 19, 25, 26, 27, 28]
const NEON_HARD_SEGMENTS: Array[int] = [6, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 20, 21, 22, 23, 24]

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

func _ready() -> void:
	call_deferred("_install_after_track_ready")

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
	if track is WildDashGrandPrixTrack:
		_barrier_count += _add_segment_containment(track, collision_root, GRAND_PRIX_HARD_SEGMENTS, "GP")
	elif track is WildDashNeonHarborTrack:
		_barrier_count += _add_segment_containment(track, collision_root, NEON_HARD_SEGMENTS, "NH")
		_visual_barrier_count += _add_hard_visual_batch_collisions(track, collision_root, NEON_HARD_BATCHES, "NH")
	elif track is WildDashSnowpeakWinterTrack:
		# Snowpeak already has collision on dangerous winter rails and the Ice
		# Cave. Only visually solid buildings/infrastructure need to be promoted
		# from decoration to hard barriers; snowbanks/route poles remain soft.
		_visual_barrier_count += _add_hard_visual_batch_collisions(track, collision_root, SNOWPEAK_HARD_BATCHES, "SP")

	_installed = true
	print("RACE COLLISION PASS READY track=%s segment_barriers=%d visual_hard_barriers=%d debug=%s" % [
		track.name, _barrier_count, _visual_barrier_count, str(OS.has_environment("WILDDASH_DEBUG_COLLISION")),
	])

func _find_track() -> Node3D:
	var parent := get_parent()
	if parent == null:
		return null
	for child in parent.get_children():
		if child is WildDashGrandPrixTrack or child is WildDashNeonHarborTrack or child is WildDashSnowpeakWinterTrack:
			return child as Node3D
	return null

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
