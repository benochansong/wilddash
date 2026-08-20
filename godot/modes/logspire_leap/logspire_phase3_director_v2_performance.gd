extends "res://modes/logspire_leap/logspire_phase3_director.gd"

## Titan Tree performance pass.
## Keep landmark/event gameplay intact while reducing expensive rendering and
## decorative per-frame updates observed around 75-80% race progress.

const LEAF_UPDATE_INTERVAL_MSEC: int = 50
const CHIP_UPDATE_INTERVAL_MSEC: int = 40

var _last_leaf_perf_update_msec: int = 0
var _last_chip_perf_update_msec: int = 0

func configure(world: Node, graph: Node) -> void:
	super(world, graph)
	_apply_titan_performance_budget()

func _apply_titan_performance_budget() -> void:
	# Dynamic directional shadows over the giant tree, 15 racers, water and many
	# recovery decks were the largest avoidable GPU cost in this graybox pass.
	if _sun != null:
		_sun.shadow_enabled = false

	var titan := _world.get_node_or_null("TitanTreeProduction") as Node3D
	var canopy_kept: int = 0
	var canopy_hidden: int = 0
	if titan != null:
		for child_value: Variant in titan.get_children():
			var child := child_value as MeshInstance3D
			if child == null:
				continue
			child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if child.mesh is SphereMesh:
				var sphere := child.mesh as SphereMesh
				sphere.radial_segments = 18
				sphere.rings = 9
				if String(child.name).begins_with("TitanCanopy_"):
					var index_text: String = String(child.name).trim_prefix("TitanCanopy_")
					var index: int = int(index_text)
					# Retain 8 of 14 large overlapping canopy blobs.
					if index % 2 == 1 and index < 12:
						child.visible = false
						canopy_hidden += 1
					else:
						canopy_kept += 1
			elif child.mesh is CylinderMesh:
				var cylinder := child.mesh as CylinderMesh
				cylinder.radial_segments = 18
				cylinder.rings = 3

	if _living_leaves != null and _living_leaves.multimesh != null:
		_living_leaves.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# 14 leaves still read clearly during the event and cut transform writes.
		if _living_leaf_seed.size() > 14:
			_living_leaf_seed.resize(14)
		_living_leaves.multimesh.instance_count = mini(14, _living_leaf_seed.size())
	if _wood_chips != null and _wood_chips.multimesh != null:
		_wood_chips.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_wood_chips.multimesh.instance_count = mini(6, _wood_chips.multimesh.instance_count)

	_reduce_squirrel_mesh_cost()
	_reduce_simple_sphere_cost(_woodpecker_root, 12, 6)
	_reduce_simple_sphere_cost(_finale_mushroom_visual, 14, 7)

	print("LOGSPIRE TITAN PERFORMANCE READY sun_shadows=false sphere_segments=18x9 canopy_kept=%d canopy_hidden=%d leaves=14 leaf_hz=20 chips_hz=25 gameplay_preserved=true" % [
		canopy_kept, canopy_hidden,
	])

func _update_living_leaves() -> void:
	var now: int = Time.get_ticks_msec()
	if now - _last_leaf_perf_update_msec < LEAF_UPDATE_INTERVAL_MSEC:
		return
	_last_leaf_perf_update_msec = now
	super()

func _update_wood_chips() -> void:
	var now: int = Time.get_ticks_msec()
	if now - _last_chip_perf_update_msec < CHIP_UPDATE_INTERVAL_MSEC:
		return
	_last_chip_perf_update_msec = now
	super()

func _reduce_squirrel_mesh_cost() -> void:
	if _squirrel_root == null:
		return
	for child_value: Variant in _squirrel_root.get_children():
		var multi := child_value as MultiMeshInstance3D
		if multi == null or multi.multimesh == null:
			continue
		multi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if multi.multimesh.mesh is SphereMesh:
			var sphere := multi.multimesh.mesh as SphereMesh
			sphere.radial_segments = 10
			sphere.rings = 5

func _reduce_simple_sphere_cost(root: Node3D, radial: int, rings: int) -> void:
	if root == null:
		return
	for child_value: Variant in root.get_children():
		var mesh_instance := child_value as MeshInstance3D
		if mesh_instance == null:
			continue
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mesh_instance.mesh is SphereMesh:
			var sphere := mesh_instance.mesh as SphereMesh
			sphere.radial_segments = radial
			sphere.rings = rings
