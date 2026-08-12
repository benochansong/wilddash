extends Node3D

const SHORTCUT_A := Vector3(96.6, 0.0, -87.4)
const SHORTCUT_B := Vector3(101.2, 0.0, -202.4)
const SAFE_WIDTH := 10.0
const RAIL_OFFSET := 5.25

func _ready() -> void:
	call_deferred("_install_service_lane_safety")

func _install_service_lane_safety() -> void:
	var track := get_parent()
	if track == null:
		return
	var decoration := track.get_node_or_null("DecorationGeometry") as Node3D
	var collision_root := track.get_node_or_null("GameplayCollision") as Node3D
	if decoration == null or collision_root == null:
		push_error("NEON SHORTCUT SAFETY could not resolve track roots")
		return

	var direction := SHORTCUT_B - SHORTCUT_A
	var planar := Vector3(direction.x, 0.0, direction.z).normalized()
	var right := Vector3(-planar.z, 0.0, planar.x)
	var midpoint := (SHORTCUT_A + SHORTCUT_B) * 0.5
	var length := SHORTCUT_A.distance_to(SHORTCUT_B)

	# Overlay a wider visual service lane so the playable path matches the safe
	# collision footprint. This is intentionally industrial concrete, not the
	# stronger asphalt language of the main route.
	var lane_visual := CSGBox3D.new()
	lane_visual.name = "ShortcutAHeavyRacerLaneVisual"
	lane_visual.size = Vector3(SAFE_WIDTH, 0.44, length)
	lane_visual.use_collision = false
	lane_visual.position = midpoint + Vector3.DOWN * 0.16
	var lane_material := StandardMaterial3D.new()
	lane_material.albedo_color = Color(0.20, 0.23, 0.27)
	lane_material.roughness = 0.82
	lane_visual.material = lane_material
	decoration.add_child(lane_visual)
	lane_visual.look_at(SHORTCUT_B + Vector3.DOWN * 0.16, Vector3.UP)

	var lane_collision := CSGBox3D.new()
	lane_collision.name = "ShortcutAHeavyRacerLaneCollision"
	lane_collision.size = Vector3(SAFE_WIDTH, 0.50, length)
	lane_collision.use_collision = true
	lane_collision.visible = false
	lane_collision.position = midpoint + Vector3.DOWN * 0.16
	collision_root.add_child(lane_collision)
	lane_collision.look_at(SHORTCUT_B + Vector3.DOWN * 0.16, Vector3.UP)

	var rail_material := StandardMaterial3D.new()
	rail_material.albedo_color = Color(0.42, 0.52, 0.62)
	rail_material.metallic = 0.72
	rail_material.roughness = 0.34
	for side in [-1.0, 1.0]:
		var rail_position := midpoint + right * RAIL_OFFSET * side + Vector3.UP * 0.72
		var rail_target := SHORTCUT_B + right * RAIL_OFFSET * side + Vector3.UP * 0.72

		var rail_visual := CSGBox3D.new()
		rail_visual.name = "ShortcutAServiceRail_%s_Visual" % ("L" if side < 0.0 else "R")
		rail_visual.size = Vector3(0.34, 1.45, length)
		rail_visual.use_collision = false
		rail_visual.material = rail_material
		rail_visual.position = rail_position
		decoration.add_child(rail_visual)
		rail_visual.look_at(rail_target, Vector3.UP)

		var rail_collision := CSGBox3D.new()
		rail_collision.name = "ShortcutAServiceRail_%s_Collision" % ("L" if side < 0.0 else "R")
		rail_collision.size = Vector3(0.38, 1.55, length)
		rail_collision.use_collision = true
		rail_collision.visible = false
		rail_collision.position = rail_position
		collision_root.add_child(rail_collision)
		rail_collision.look_at(rail_target, Vector3.UP)

	print("NEON HARBOR SHORTCUT SAFETY PASS width=%.1fm rails=true heavy_racers=true" % SAFE_WIDTH)
