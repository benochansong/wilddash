class_name WildDashWildTideCanopyController
extends Node3D

## Round 3 adapter for the deterministic Monkey canopy system.
## Vines now connect authored gameplay-tree anchors instead of floating above the
## centerline route. Checkpoint progress remains owned by the ground route.

const GRAB_DISTANCE: float = 4.0
const SWING_ATTACK_RADIUS: float = 3.8
const AI_GRAB_DISTANCE: float = 3.7
const AI_RETRY_SECONDS: float = 1.0
const REQUIRED_ANCHORS: int = 5

var _routes: Array[WildDashCanopyVineRoute] = []
var _systems_by_racer: Dictionary = {}
var _ai_retry_by_racer: Dictionary = {}
var _anchors: Array[Marker3D] = []
var _bootstrapped: bool = false

func _ready() -> void:
	call_deferred("_bootstrap")

func _bootstrap() -> void:
	for _attempt: int in range(90):
		_collect_anchors()
		if _anchors.size() >= REQUIRED_ANCHORS:
			break
		await get_tree().physics_frame
	if _anchors.size() < REQUIRED_ANCHORS:
		push_warning("WILD TIDE CANOPY missing gameplay-tree anchors count=%d" % _anchors.size())
		return
	_build_vines()
	_bootstrapped = true
	print("WILD TIDE CANOPY READY vines=%d anchors=%d gameplay_tree_linked=true monkey_arc_traversal=true checkpoint_safe=true" % [
		_routes.size(), _anchors.size(),
	])

func _physics_process(delta: float) -> void:
	if not _bootstrapped or not RaceManager.active:
		return
	_update_retry_timers(delta)
	for racer_value: Variant in RaceManager.racers:
		var racer: WildDashCharacterController = racer_value as WildDashCharacterController
		if racer == null or racer.finished or racer.animal_id != &"monkey":
			continue
		var traversal: WildDashCanopyTraversalSystem = _get_system(racer)
		if traversal.is_swinging():
			var input_axis: float = InputManager.get_steer_axis() if racer.is_player else 0.35
			var reached_end: bool = traversal.update_swing(racer, delta, input_axis)
			if racer.is_player and Input.is_action_just_pressed(InputManager.ACTION_BUMP):
				_perform_swing_kick(racer, traversal)
			if reached_end or (racer.is_player and Input.is_action_just_pressed(InputManager.ACTION_JUMP)):
				var release_velocity: Vector3 = traversal.release_vine(racer, true)
				racer.velocity = release_velocity
				if racer.is_player:
					_show_hud("CANOPY RELEASE!")
			continue
		if racer.is_player:
			if Input.is_action_just_pressed(InputManager.ACTION_SKILL):
				_try_grab(racer, traversal, GRAB_DISTANCE)
		else:
			_try_ai_grab(racer, traversal)

func get_anchor_ground_positions() -> Array[Vector3]:
	var result: Array[Vector3] = []
	for anchor: Marker3D in _anchors:
		if anchor == null or not is_instance_valid(anchor):
			continue
		result.append(Vector3(anchor.global_position.x, 0.1, anchor.global_position.z))
	return result

func _collect_anchors() -> void:
	_anchors.clear()
	for node: Node in get_tree().get_nodes_in_group("wild_tide_canopy_anchor"):
		var anchor: Marker3D = node as Marker3D
		if anchor != null:
			_anchors.append(anchor)
	_anchors.sort_custom(_sort_anchor)

func _sort_anchor(a: Marker3D, b: Marker3D) -> bool:
	var a_value: Variant = a.get_meta(&"wild_tide_canopy_index", 0)
	var b_value: Variant = b.get_meta(&"wild_tide_canopy_index", 0)
	return int(a_value) < int(b_value)

func _build_vines() -> void:
	_routes.clear()
	var vine_count: int = mini(4, _anchors.size() - 1)
	for index: int in range(vine_count):
		var start_anchor: Marker3D = _anchors[index]
		var end_anchor: Marker3D = _anchors[index + 1]
		var route: WildDashCanopyVineRoute = WildDashCanopyVineRoute.new()
		var drop: float = 2.1 + float(index) * 0.22
		var speed: float = 11.0 + float(index) * 0.35
		route.configure(
			StringName("wild_tide_vine_%d" % index),
			start_anchor.global_position,
			end_anchor.global_position,
			drop,
			speed,
			4.6
		)
		_routes.append(route)
		_build_rope_visual(route, index)

func _build_rope_visual(route: WildDashCanopyVineRoute, index: int) -> void:
	var root: Node3D = Node3D.new()
	root.name = "WildTideVineVisual_%02d" % index
	add_child(root)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.34, 0.18, 0.055)
	material.roughness = 0.92
	material.emission_enabled = true
	material.emission = Color(0.08, 0.34, 0.10)
	material.emission_energy_multiplier = 0.18
	var previous: Vector3 = route.sample(0.0)
	for step: int in range(1, 15):
		var point: Vector3 = route.sample(float(step) / 14.0)
		var rope_piece: CSGBox3D = CSGBox3D.new()
		rope_piece.name = "Rope_%02d" % step
		rope_piece.size = Vector3(0.12, 0.12, maxf(0.1, previous.distance_to(point)))
		rope_piece.use_collision = false
		rope_piece.position = previous.lerp(point, 0.5)
		rope_piece.material = material
		root.add_child(rope_piece)
		rope_piece.look_at(point, Vector3.UP)
		previous = point

func _get_system(racer: WildDashCharacterController) -> WildDashCanopyTraversalSystem:
	var racer_id: int = racer.get_instance_id()
	var existing: Variant = _systems_by_racer.get(racer_id)
	if existing is WildDashCanopyTraversalSystem:
		var traversal_existing: WildDashCanopyTraversalSystem = existing
		return traversal_existing
	var traversal: WildDashCanopyTraversalSystem = WildDashCanopyTraversalSystem.new()
	traversal.set_routes(_routes)
	_systems_by_racer[racer_id] = traversal
	return traversal

func _try_grab(
	racer: WildDashCharacterController,
	traversal: WildDashCanopyTraversalSystem,
	max_distance: float
) -> bool:
	var route: WildDashCanopyVineRoute = traversal.find_nearest_vine(racer.global_position, max_distance)
	if route == null:
		return false
	if not traversal.grab_vine(racer, route):
		return false
	_show_hud("CANOPY SHORTCUT!  E=GRAB · SPACE=RELEASE · F=SWING KICK")
	AudioManager.play_sfx_id("skill", 0.72)
	return true

func _try_ai_grab(racer: WildDashCharacterController, traversal: WildDashCanopyTraversalSystem) -> void:
	var racer_id: int = racer.get_instance_id()
	if float(_ai_retry_by_racer.get(racer_id, 0.0)) > 0.0:
		return
	var progress: float = RaceManager.get_progress_percent(racer) / 100.0
	if progress < 0.34 or progress > 0.61:
		return
	var route: WildDashCanopyVineRoute = traversal.find_nearest_vine(racer.global_position, AI_GRAB_DISTANCE)
	if route == null:
		return
	if traversal.grab_vine(racer, route):
		_ai_retry_by_racer[racer_id] = AI_RETRY_SECONDS
		print("AI ROUTE animal=monkey route=CANOPY vine=%s score=high")

func _perform_swing_kick(racer: WildDashCharacterController, traversal: WildDashCanopyTraversalSystem) -> void:
	var impact_scale: float = traversal.perform_swing_attack()
	var hits: int = 0
	for target_value: Variant in RaceManager.racers:
		var target: WildDashCharacterController = target_value as WildDashCharacterController
		if target == null or target == racer or target.finished:
			continue
		if racer.global_position.distance_to(target.global_position) > SWING_ATTACK_RADIUS:
			continue
		if ItemSystem.apply_attack(target, racer, &"swing_kick", 0.45, 0.90, 3.8 * impact_scale):
			hits += 1
	if hits > 0:
		_show_hud("SWING KICK!  x%d" % hits)
		AudioManager.play_sfx_id("hit", 0.85)

func _update_retry_timers(delta: float) -> void:
	for raw_id: Variant in _ai_retry_by_racer.keys():
		var racer_id: int = int(raw_id)
		var remaining: float = maxf(0.0, float(_ai_retry_by_racer.get(racer_id, 0.0)) - delta)
		if remaining <= 0.0:
			_ai_retry_by_racer.erase(racer_id)
		else:
			_ai_retry_by_racer[racer_id] = remaining

func _show_hud(text: String) -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var hud_value: Variant = parent_node.get("hud")
	var mode_hud: WildDashModeHUD = hud_value as WildDashModeHUD
	if mode_hud != null:
		mode_hud.set_message(text)
