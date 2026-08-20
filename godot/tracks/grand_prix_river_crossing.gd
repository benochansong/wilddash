class_name WildDashGrandPrixRiverCrossing
extends Node3D

## First Terrain Adventure prototype.
## Reuses the stable Narrow Bridge route segment as a flooded crossing:
## - centre lane: water terrain using per-animal SWIM affinity
## - left/right: narrow dry deck lanes using normal race movement
## No new road collision is created; the existing track collision remains the
## only floor so this prototype does not add another source of seam/tunnelling bugs.

const ROUTE_SEGMENT_INDEX: int = 5
const WATER_START_T: float = 0.12
const WATER_END_T: float = 0.88
const WATER_ZONE_WIDTH: float = 4.40
const WATER_VISUAL_WIDTH: float = 8.40
const DRY_LANE_WIDTH: float = 1.45
const DRY_LANE_OFFSET: float = 3.05
const WATER_SURFACE_OFFSET: float = 0.08
const DRY_LANE_OFFSET_Y: float = 0.15
const RIVER_CURRENT_STRENGTH: float = 2.20

var _art_root: Node3D

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	call_deferred("_build_when_track_ready")

func _build_when_track_ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var track: Node = _find_track(get_parent())
	if track == null:
		push_warning("GrandPrixRiverCrossing could not find route provider")
		return
	var raw_route: Variant = track.call("get_route_points")
	if not raw_route is Array:
		return
	var route: Array = raw_route
	if route.size() <= ROUTE_SEGMENT_INDEX + 1:
		return
	var a: Vector3 = route[ROUTE_SEGMENT_INDEX]
	var b: Vector3 = route[ROUTE_SEGMENT_INDEX + 1]
	_build_crossing(a, b)

func _build_crossing(a: Vector3, b: Vector3) -> void:
	_art_root = Node3D.new()
	_art_root.name = "RiverCrossingArt"
	add_child(_art_root)

	var palette: Dictionary = WildDashEnvironmentMaterialLibrary.get_palette()
	var water_material: Material = palette[&"water"]
	var wood_material: Material = palette[&"wood"]
	var warning_material: StandardMaterial3D = _make_material(Color(0.96, 0.72, 0.14, 1.0), 0.58, 0.08)

	var water_from: Vector3 = a.lerp(b, WATER_START_T)
	var water_to: Vector3 = a.lerp(b, WATER_END_T)
	_add_route_box(
		_art_root,
		"FloodedWaterSurface",
		water_from + Vector3.UP * WATER_SURFACE_OFFSET,
		water_to + Vector3.UP * WATER_SURFACE_OFFSET,
		WATER_VISUAL_WIDTH,
		0.12,
		water_material
	)

	var planar: Vector3 = b - a
	planar.y = 0.0
	if planar.length_squared() <= 0.001:
		planar = Vector3.FORWARD
	planar = planar.normalized()
	var right: Vector3 = Vector3(-planar.z, 0.0, planar.x).normalized()
	for side: float in [-1.0, 1.0]:
		var lateral: Vector3 = right * DRY_LANE_OFFSET * side
		_add_route_box(
			_art_root,
			"DryDeck_%s" % ("L" if side < 0.0 else "R"),
			water_from + lateral + Vector3.UP * DRY_LANE_OFFSET_Y,
			water_to + lateral + Vector3.UP * DRY_LANE_OFFSET_Y,
			DRY_LANE_WIDTH,
			0.16,
			wood_material
		)

	# Simple visual gate: yellow edge bars make the centre swim lane legible at
	# speed without adding collision or forcing a route choice.
	for t: float in [WATER_START_T, WATER_END_T]:
		var point: Vector3 = a.lerp(b, t)
		_add_route_box(
			_art_root,
			"SwimGate_%03d" % int(round(t * 100.0)),
			point - right * (WATER_ZONE_WIDTH * 0.5) + Vector3.UP * 0.18,
			point + right * (WATER_ZONE_WIDTH * 0.5) + Vector3.UP * 0.18,
			0.18,
			0.20,
			warning_material
		)

	var zone: WildDashTerrainZone = WildDashTerrainZone.new()
	zone.name = "RiverSwimTerrainZone"
	zone.configure_route_box(
		&"grand_prix_narrow_bridge_swim",
		&"water",
		a,
		b,
		WATER_ZONE_WIDTH,
		6.0,
		WATER_START_T,
		WATER_END_T
	)
	zone.configure_current(right, RIVER_CURRENT_STRENGTH)
	add_child(zone)

	print("RC9 RIVER CROSSING READY segment=%d swim_width=%.2f dry_lane=%.2f current=%.2f collision_added=false" % [
		ROUTE_SEGMENT_INDEX,
		WATER_ZONE_WIDTH,
		DRY_LANE_WIDTH,
		RIVER_CURRENT_STRENGTH,
	])

func _find_track(node: Node) -> Node:
	if node != self and node.has_method("get_route_points"):
		return node
	for child: Node in node.get_children():
		var found: Node = _find_track(child)
		if found != null:
			return found
	return null

func _add_route_box(
	parent: Node3D,
	node_name: String,
	from_point: Vector3,
	to_point: Vector3,
	width: float,
	height: float,
	material: Material
) -> void:
	var distance: float = from_point.distance_to(to_point)
	if distance <= 0.001:
		return
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(width, height, distance)
	mesh.material = material
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	var midpoint: Vector3 = (from_point + to_point) * 0.5
	var transform: Transform3D = Transform3D(Basis.IDENTITY, midpoint)
	transform = transform.looking_at(to_point, Vector3.UP)
	instance.transform = transform
	instance.extra_cull_margin = 24.0
	parent.add_child(instance)

func _make_material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material
