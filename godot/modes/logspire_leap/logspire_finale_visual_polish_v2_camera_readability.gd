extends "res://modes/logspire_leap/logspire_finale_visual_polish.gd"

## Camera-facing Sky Log Finale visual correction.
##
## The gameplay water remains the same broad recovery/hazard surface, but the
## visible river is narrowed to a believable canopy channel. Soil/bark shelves
## cover the unused outer water surface, a front bark lip hides the thin sheet
## edge, and a short spillfall visually explains the remaining center opening.

const VISIBLE_RIVER_WIDTH: float = 28.0
const RIVER_SHELF_THICKNESS: float = 1.20
const FRONT_BARK_LIP_HEIGHT: float = 6.0
const FRONT_BARK_LIP_DEPTH: float = 4.2
const FRONT_SPILLFALL_HEIGHT: float = 9.0

func _build_finale_visual_river_banks() -> void:
	super._build_finale_visual_river_banks()
	if _finale_visual_root == null or _finale_visual_root.has_node("CanopyRiverShelfLeft"):
		return

	var soil := _make_visual_material(Color(0.24, 0.18, 0.075), 0.96)
	var bark := _make_visual_material(Color(0.19, 0.095, 0.035), 0.97)
	var water_fall := _make_visual_material(
		Color(0.12, 0.72, 0.78, 0.54),
		0.22,
		Color(0.012, 0.10, 0.12)
	)

	var half_x: float = _river_size.x * 0.5
	var half_z: float = _river_size.y * 0.5
	var corridor_half: float = VISIBLE_RIVER_WIDTH * 0.5
	var shelf_width: float = maxf(4.0, half_x - corridor_half)
	var shelf_center_x: float = corridor_half + shelf_width * 0.5
	var shelf_y: float = _river_center.y - RIVER_SHELF_THICKNESS * 0.5 + 0.08

	# Cover most of the huge rectangular gameplay-water mesh from above. The
	# authored Z6 route stays near X=-3..+3, leaving a very generous 28 m river
	# corridor around every playable platform and jump arc.
	for side: float in [-1.0, 1.0]:
		_add_visual_box(
			"CanopyRiverShelf%s" % ("Left" if side < 0.0 else "Right"),
			Vector3(_river_center.x + shelf_center_x * side, shelf_y, _river_center.z),
			Vector3(shelf_width, RIVER_SHELF_THICKNESS, _river_size.y + 3.0),
			soil
		)

	# This is the edge seen most strongly from the gameplay camera in the user's
	# screenshot. Keep the lip top just below water level so it masks the cyan
	# sheet thickness without hiding the route or the first landing target.
	var near_z: float = _river_center.z + half_z
	_add_visual_box(
		"CanopyRiverFrontBarkLip",
		Vector3(
			_river_center.x,
			_river_center.y - FRONT_BARK_LIP_HEIGHT * 0.5 - 0.04,
			near_z + 0.35
		),
		Vector3(_river_size.x - 2.0, FRONT_BARK_LIP_HEIGHT, FRONT_BARK_LIP_DEPTH),
		bark
	)

	# The central opening is intentionally readable as water spilling down from a
	# root basin rather than as the exposed edge of a floating turquoise board.
	_add_visual_quad(
		"CanopyRiverFrontSpillfall",
		Vector3(
			_river_center.x,
			_river_center.y - FRONT_SPILLFALL_HEIGHT * 0.5,
			near_z + 2.50
		),
		Vector2(VISIBLE_RIVER_WIDTH + 2.0, FRONT_SPILLFALL_HEIGHT),
		water_fall
	)

	print("r3_finale_camera_water_mask_added visible_river_width=%.1f outer_water_covered=true front_sheet_edge_masked=true spillfall=true collision_free=true" % VISIBLE_RIVER_WIDTH)
