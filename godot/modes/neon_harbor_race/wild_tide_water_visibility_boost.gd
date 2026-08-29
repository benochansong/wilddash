class_name WildDashWildTideWaterVisibilityBoost
extends Node

## Pure visual adapter for WILD TIDE water readability.
## It does not own terrain detection or collision. It only brightens the already
## authored V2/V3 water surfaces and foam so the chase camera reads flooded road
## sections as water instead of dark pavement/ground.

func _ready() -> void:
	call_deferred("_apply_when_ready")

func _apply_when_ready() -> void:
	var world: Node = null
	for _attempt: int in range(120):
		var parent_node: Node = get_parent()
		if parent_node != null:
			world = parent_node.get_node_or_null("WildTideWorldController")
		if world != null and _count_water_surfaces(world) >= 14:
			break
		await get_tree().physics_frame
	if world == null:
		push_warning("WILD TIDE WATER VISIBILITY BOOST skipped: world unavailable")
		return

	var surface_count: int = 0
	var foam_count: int = 0
	for child: Node in world.get_children():
		if child is CSGBox3D and child.has_meta(&"wild_tide_visual_water"):
			var surface: CSGBox3D = child as CSGBox3D
			var deep: bool = bool(surface.get_meta(&"wild_tide_deep", false))
			surface.material = _water_material(deep)
			surface_count += 1
		elif child is Node3D and String(child.name).begins_with("WildTideFoam_"):
			for foam_child: Node in child.get_children():
				if foam_child is CSGBox3D:
					(foam_child as CSGBox3D).material = _foam_material()
					foam_count += 1

	print("WILD TIDE WATER VISIBILITY READY surfaces=%d foam_edges=%d cyan=true deep_blue=true road_overlay_water=false" % [
		surface_count, foam_count,
	])

func _count_water_surfaces(world: Node) -> int:
	var count: int = 0
	if world == null:
		return count
	for child: Node in world.get_children():
		if child is CSGBox3D and child.has_meta(&"wild_tide_visual_water"):
			count += 1
	return count

func _water_material(deep: bool) -> StandardMaterial3D:
	var color: Color = Color(0.025, 0.47, 0.76) if deep else Color(0.06, 0.76, 0.80)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.18 if deep else 0.24
	material.metallic = 0.04
	material.emission_enabled = true
	material.emission = color.lightened(0.16)
	material.emission_energy_multiplier = 0.31 if deep else 0.27
	return material

func _foam_material() -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.88, 0.985, 1.0)
	material.roughness = 0.30
	material.emission_enabled = true
	material.emission = Color(0.66, 0.95, 1.0)
	material.emission_energy_multiplier = 0.58
	return material
