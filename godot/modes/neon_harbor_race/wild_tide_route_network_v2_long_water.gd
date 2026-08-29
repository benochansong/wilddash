class_name WildDashWildTideRouteNetworkV2LongWater
extends "res://modes/neon_harbor_race/wild_tide_route_network.gd"

## Extends the existing six-route network across the new 371m water finale.
## The route IDs stay unchanged so V5 species assignment remains compatible.
## Deep-water specialists take the deeper inside line; Elevated/Dry-Dock racers
## get a shallow-edge line; Monkey gets a mild mangrove-channel bias.

const LONG_WATER_START: int = 29
const LONG_WATER_END: int = 35
const LONG_MANGROVE_START: int = 31
const LONG_MANGROVE_END: int = 32

var _long_water_ready: bool = false

func _ready() -> void:
	super._ready()
	call_deferred("_extend_long_water_when_ready")

func is_ready() -> bool:
	return _bootstrapped and _long_water_ready

func _extend_long_water_when_ready() -> void:
	for _attempt: int in range(120):
		if _bootstrapped and _main_route.size() >= 37:
			break
		await get_tree().physics_frame
	if not _bootstrapped or _main_route.size() < 37:
		push_warning("WILD TIDE ROUTE NETWORK V2 long-water extension skipped")
		return

	var deep_route: Array[Vector3] = get_route(ROUTE_DEEP_WATER)
	_routes[ROUTE_DEEP_WATER] = _build_offset_branch(deep_route, LONG_WATER_START, LONG_WATER_END, -7.0, 0.10)

	var dry_route: Array[Vector3] = get_route(ROUTE_DRY_DOCK)
	_routes[ROUTE_DRY_DOCK] = _build_offset_branch(dry_route, LONG_WATER_START, LONG_WATER_END, 6.8, 0.10)

	var elevated_route: Array[Vector3] = get_route(ROUTE_ELEVATED)
	_routes[ROUTE_ELEVATED] = _build_offset_branch(elevated_route, LONG_WATER_START, LONG_WATER_END, 6.2, 0.12)

	var canopy_route: Array[Vector3] = get_route(ROUTE_CANOPY)
	_routes[ROUTE_CANOPY] = _build_offset_branch(canopy_route, LONG_MANGROVE_START, LONG_MANGROVE_END, -4.4, 0.08)

	_build_long_water_split_beacons()
	_long_water_ready = true
	print("WILD TIDE ROUTE NETWORK V2 READY long_water=true deep_route=-7.0 shallow_edge=6.8 elevated_edge=6.2 mangrove_shortcut=-4.4 finish_merge=true routes=%d" % _routes.size())

func _build_long_water_split_beacons() -> void:
	_create_long_split_beacon(29, -7.2, Color(0.06, 0.88, 1.0), "DEEP")
	_create_long_split_beacon(29, 7.2, Color(0.42, 0.96, 1.0), "SHALLOW")
	_create_long_split_beacon(33, 0.0, Color(1.0, 0.72, 0.10), "OPEN WATER")

func _create_long_split_beacon(route_index: int, lateral: float, color: Color, label_text: String) -> void:
	if route_index < 0 or route_index >= _main_route.size() - 1:
		return
	var a: Vector3 = _main_route[route_index]
	var b: Vector3 = _main_route[route_index + 1]
	var direction: Vector3 = b - a
	direction.y = 0.0
	if direction.length_squared() <= 0.001:
		return
	direction = direction.normalized()
	var right: Vector3 = Vector3(-direction.z, 0.0, direction.x)
	var root: Node3D = Node3D.new()
	root.name = "LongWaterBeacon_%s" % label_text.replace(" ", "_")
	root.position = a.lerp(b, 0.16) + right * lateral + Vector3.UP * 1.25
	add_child(root)

	var pillar: CSGCylinder3D = CSGCylinder3D.new()
	pillar.radius = 0.22
	pillar.height = 2.4
	pillar.use_collision = false
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.55
	pillar.material = material
	root.add_child(pillar)

	var label: Label3D = Label3D.new()
	label.text = label_text
	label.font_size = 32
	label.outline_size = 8
	label.modulate = color
	label.position = Vector3.UP * 1.8
	root.add_child(label)
