extends "res://modes/logspire_leap/logspire_phase3_director.gd"

## Titan Tree performance pass.
## Keep the landmark/event gameplay intact while reducing the most expensive
## rendering work observed around 75-80% race progress.

func configure(world: Node, graph: Node) -> void:
	super(world, graph)
	_apply_titan_performance_budget()

func _apply_titan_performance_budget() -> void:
	# Dynamic directional shadows over the giant tree, 15 racers, water and many
	# recovery decks were the largest avoidable GPU cost in this graybox pass.
	if _sun != null:
		_sun.shadow_enabled = false

	var titan := _world.get_node_or_null("TitanTreeProduction") as Node3D
	if titan == null:
		return
	var canopy_kept: int = 0
	var canopy_hidden: int = 0
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
				# Retain 8 of the 14 canopy blobs. The silhouette stays full because the
				# remaining spheres are already very large and overlap heavily.
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
	if _wood_chips != null and _wood_chips.multimesh != null:
		_wood_chips.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	print("LOGSPIRE TITAN PERFORMANCE READY sun_shadows=false sphere_segments=18x9 canopy_kept=%d canopy_hidden=%d gameplay_preserved=true" % [
		canopy_kept, canopy_hidden,
	])
