class_name WildDashWildTideCanopyController
extends Node3D

## Round 3 adapter for the proven deterministic Monkey canopy traversal.
## Vines cross the mangrove route rather than replacing checkpoints, so a swing
## is a mobility/attack shortcut while race progress remains authoritative.

const GRAB_DISTANCE: float = 3.6
const SWING_ATTACK_RADIUS: float = 3.8
const AI_GRAB_DISTANCE: float = 3.0
const AI_RETRY_SECONDS: float = 1.1

var _routes: Array[WildDashCanopyVineRoute] = []
var _systems_by_racer: Dictionary = {}
var _ai_retry_by_racer: Dictionary = {}
var _route_points: Array[Vector3] = []
var _bootstrapped: bool = false

func _ready() -> void:
	call_deferred("_bootstrap")

func _bootstrap() -> void:
	var track: Node = null
	for _attempt: int in range(40):
		var parent_node: Node = get_parent()
		if parent_node != null:
			track = parent_node.get_node_or_null("NeonHarborWorldTrack")
		if track != null and track.has_method("get_route_points"):
			break
		await get_tree().physics_frame
	if track == null or not track.has_method("get_route_points"):
		return
	var route_value: Variant = track.call("get_route_points")
	if route_value is Array:
		for value: Variant in route_value:
			if value is Vector3:
				_route_points.append(value)
	if _route_points.size() < 14:
		return
	_build_vines()
	_bootstrapped = true
	print("WILD TIDE CANOPY READY vines=%d monkey_arc_traversal=true checkpoint_safe=true" % _routes.size())

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

func _build_vines() -> void:
	var specs: Array[Dictionary] = [
		{"a": 9, "b": 10, "height": 4.8, "drop": 2.25, "speed": 11.0},
		{"a": 10, "b": 11, "height": 5.3, "drop": 2.55, "speed": 11.4},
		{"a": 11, "b": 12, "height": 5.8, "drop": 2.80, "speed": 11.8},
		{"a": 12, "b": 13, "height": 6.2, "drop": 3.10, "speed": 12.1},
	]
	for i: int in range(specs.size()):
		var spec: Dictionary = specs[i]
		var a_index: int = int(spec.get("a", 9))
		var b_index: int = int(spec.get("b", 10))
		var height: float = float(spec.get("height", 5.0))
		var route: WildDashCanopyVineRoute = WildDashCanopyVineRoute.new()
		route.configure(
			StringName("wild_tide_vine_%d" % i),
			_route_points[a_index] + Vector3.UP * height,
			_route_points[b_index] + Vector3.UP * height,
			float(spec.get("drop", 2.4)),
			float(spec.get("speed", 11.0)),
			4.6
		)
		_routes.append(route)
		_build_rope_visual(route, i)

func _build_rope_visual(route: WildDashCanopyVineRoute, index: int) -> void:
	var root: Node3D = Node3D.new()
	root.name = "WildTideVineVisual_%02d" % index
	add_child(root)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.25, 0.14, 0.055)
	material.roughness = 0.92
	material.emission_enabled = true
	material.emission = Color(0.12, 0.48, 0.16) * 0.24
	var previous: Vector3 = route.sample(0.0)
	for step: int in range(1, 13):
		var point: Vector3 = route.sample(float(step) / 12.0)
		var rope_piece: CSGBox3D = CSGBox3D.new()
		rope_piece.name = "Rope_%02d" % step
		rope_piece.size = Vector3(0.10, 0.10, maxf(0.1, previous.distance_to(point)))
		rope_piece.use_collision = false
		rope_piece.position = previous.lerp(point, 0.5)
		rope_piece.material = material
		rope_piece.look_at(point, Vector3.UP)
		root.add_child(rope_piece)
		previous = point

func _get_system(racer: WildDashCharacterController) -> WildDashCanopyTraversalSystem:
	var racer_id: int = racer.get_instance_id()
	var existing: Variant = _systems_by_racer.get(racer_id)
	if existing is WildDashCanopyTraversalSystem:
		return existing
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
	if progress < 0.32 or progress > 0.58:
		return
	var route: WildDashCanopyVineRoute = traversal.find_nearest_vine(racer.global_position, AI_GRAB_DISTANCE)
	if route == null:
		return
	if traversal.grab_vine(racer, route):
		_ai_retry_by_racer[racer_id] = AI_RETRY_SECONDS
		print("AI ROUTE animal=monkey route=CANOPY vine=%s score=high" % String(route.vine_id))

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
