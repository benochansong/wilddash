extends "res://modes/logspire_leap/logspire_water_recovery_v15_vine_only.gd"

## Round 3 upper-canopy water presentation cleanup.
##
## The previous visual pass only covered portions of the original Z6 100x190 m
## water slab with bark shelves. The underlying turquoise BoxMesh remained huge,
## so camera angles could still reveal a floating rectangular water layer.
##
## Keep the broad Area3D recovery authority for safety, but make the visible Z6
## water geometry a compact canopy channel that fits inside that area. This does
## not change Vine Rescue, checkpoint fallback, water entry authority or any
## lower-zone pool.

const Z6_VISIBLE_WATER_WIDTH: float = 44.0
const Z6_VISIBLE_WATER_LENGTH: float = 162.0
const Z6_VISIBLE_WATER_THICKNESS: float = 0.045
const Z6_VISIBLE_WATER_CENTER_Z: float = -709.0
const Z6_VISIBLE_WATER_ALPHA: float = 0.66

func _build_canopy_river() -> void:
	super._build_canopy_river()
	_compact_upper_canopy_water_visual()

func _compact_upper_canopy_water_visual() -> void:
	var surface := get_node_or_null("CanopyRiver_Z6") as MeshInstance3D
	if surface == null:
		push_warning("R3 UPPER WATER CLEANUP missing CanopyRiver_Z6")
		return
	var old_mesh := surface.mesh as BoxMesh
	if old_mesh == null:
		push_warning("R3 UPPER WATER CLEANUP unexpected Z6 water mesh")
		return

	var old_size: Vector3 = old_mesh.size
	var compact_mesh := BoxMesh.new()
	compact_mesh.size = Vector3(
		Z6_VISIBLE_WATER_WIDTH,
		Z6_VISIBLE_WATER_THICKNESS,
		Z6_VISIBLE_WATER_LENGTH
	)
	if old_mesh.material != null:
		compact_mesh.material = old_mesh.material.duplicate()
		var water_material := compact_mesh.material as StandardMaterial3D
		if water_material != null:
			var water_color := water_material.albedo_color
			water_color.a = Z6_VISIBLE_WATER_ALPHA
			water_material.albedo_color = water_color
			water_material.roughness = 0.18
	surface.mesh = compact_mesh
	var surface_position := surface.position
	surface_position.z = Z6_VISIBLE_WATER_CENTER_Z
	surface.position = surface_position
	surface.set_meta(&"compact_canopy_channel", true)
	surface.set_meta(&"broad_floating_slab", false)

	# Deliberately leave the Area3D untouched. It remains a generous invisible
	# fail-safe beneath the finale, while the visible water now reads as a river.
	var gameplay_width: float = 0.0
	var gameplay_length: float = 0.0
	var area := get_node_or_null("CanopyRiverArea_Z6") as Area3D
	if area != null and area.get_child_count() > 0:
		var collision := area.get_child(0) as CollisionShape3D
		var shape := collision.shape as BoxShape3D if collision != null else null
		if shape != null:
			gameplay_width = shape.size.x
			gameplay_length = shape.size.z
		area.set_meta(&"recovery_authority_unchanged", true)

	print("r3_upper_water_visual_compacted old_width=%.1f old_length=%.1f visible_width=%.1f visible_length=%.1f gameplay_width=%.1f gameplay_length=%.1f recovery_area_unchanged=true broad_floating_slab=false" % [
		old_size.x, old_size.z, Z6_VISIBLE_WATER_WIDTH, Z6_VISIBLE_WATER_LENGTH,
		gameplay_width, gameplay_length,
	])
