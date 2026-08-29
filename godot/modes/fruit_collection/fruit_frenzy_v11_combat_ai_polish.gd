extends "res://modes/fruit_collection/fruit_frenzy_v10_combat_v2_final.gd"

## Final Round 2 AI execution polish for aerial identities. The shared target
## scorer chooses who matters; this thin layer gives Rabbit/Deer/Monkey/Cat a
## readable jump-then-drop attack instead of leaving their aerial kit player-only.

const FINAL_AERIAL_AI_IDS: Array[StringName] = [&"rabbit", &"deer", &"monkey", &"cat"]
const FINAL_AERIAL_AI_REARM: float = 1.15

var _final_ai_aerial_cooldown: Dictionary = {}
var _final_ai_aerial_armed: Dictionary = {}

func _ready() -> void:
	await super()
	for racer: WildDashCharacterController in ai_racers:
		if racer == null:
			continue
		_final_ai_aerial_cooldown[racer.get_instance_id()] = 0.0
		_final_ai_aerial_armed[racer.get_instance_id()] = false
	print("FRUIT FRENZY FINAL AI AERIAL READY rabbit=true deer=true monkey=true cat=true")

func _physics_process(delta: float) -> void:
	super(delta)
	for racer: WildDashCharacterController in ai_racers:
		if racer == null:
			continue
		var id: int = racer.get_instance_id()
		_final_ai_aerial_cooldown[id] = maxf(0.0, float(_final_ai_aerial_cooldown.get(id, 0.0)) - delta)
	_update_final_ai_aerial_combat()

func _update_final_ai_aerial_combat() -> void:
	for racer: WildDashCharacterController in ai_racers:
		if racer == null or racer.finished or not FINAL_AERIAL_AI_IDS.has(racer.animal_id):
			continue
		var id: int = racer.get_instance_id()
		var canopy: WildDashCanopyTraversalSystem = _phase3_ai_canopy_by_id.get(id, null) as WildDashCanopyTraversalSystem
		if canopy != null and canopy.is_swinging():
			continue
		var target: WildDashCharacterController = _final_ai_aerial_target(racer)
		if target == null:
			_final_ai_aerial_armed[id] = false
			continue
		var planar_distance: float = Vector2(
			target.global_position.x - racer.global_position.x,
			target.global_position.z - racer.global_position.z
		).length()
		if racer.is_on_floor():
			if float(_final_ai_aerial_cooldown.get(id, 0.0)) > 0.0:
				continue
			if planar_distance >= 1.9 and planar_distance <= 4.8:
				var phase: int = int(Time.get_ticks_msec() / 420) + id
				if phase % 5 == 0:
					racer.velocity.y = maxf(racer.velocity.y, racer.jump_velocity * _final_ai_jump_scale(racer.animal_id))
					_final_ai_aerial_armed[id] = true
			continue
		if not bool(_final_ai_aerial_armed.get(id, false)) or racer.velocity.y > -0.30:
			continue
		var height_difference: float = racer.global_position.y - target.global_position.y
		if height_difference < 0.38 or height_difference > 2.9 or planar_distance > 2.35:
			continue
		var spec: WildDashCombatAbilitySpec = WildDashCombatAbilitySystem.get_aerial_attack(racer.animal_id)
		if spec == null:
			continue
		var horizontal_speed: float = Vector2(racer.velocity.x, racer.velocity.z).length()
		var aerial_scale: float = WildDashAerialCombatSystem.get_effect_scale(racer, racer.velocity.y, height_difference, horizontal_speed)
		var context: Dictionary = {"airborne": true, "in_water": _is_river_position(racer.global_position), "momentum_multiplier": aerial_scale}
		var result: WildDashCombatResolution = WildDashCombatAbilityResolver.resolve_spec(racer, target, spec, &"fruit_collection", context)
		if not result.applied:
			continue
		var offset: Vector3 = target.global_position - racer.global_position
		offset.y = 0.0
		if offset.length_squared() <= 0.001:
			offset = Vector3.FORWARD
		target.apply_knockback(offset.normalized(), result.knockback)
		_combat_v2_try_spill(target, 1, "AI %s" % spec.display_name)
		racer.velocity.y = maxf(racer.velocity.y, racer.jump_velocity * WildDashAerialCombatSystem.get_bounce_scale(racer.animal_id))
		_final_ai_aerial_armed[id] = false
		_final_ai_aerial_cooldown[id] = FINAL_AERIAL_AI_REARM
		ai_attack_cooldown_by_id[id] = maxf(float(ai_attack_cooldown_by_id.get(id, 0.0)), 0.78)
		WildDashCombatV2FX.spawn_impact(self, target.global_position + Vector3.UP * 0.45, &"stomp", 0.9)

func _final_ai_aerial_target(source: WildDashCharacterController) -> WildDashCharacterController:
	var best: WildDashCharacterController
	var best_score: float = INF
	for target: WildDashCharacterController in racers:
		if target == null or target == source or target.finished or _get_carry(target) <= 0:
			continue
		var distance: float = source.global_position.distance_squared_to(target.global_position)
		if distance > 6.0 * 6.0:
			continue
		var score: float = distance - float(_get_carry(target)) * 7.5
		if score < best_score:
			best_score = score
			best = target
	return best

func _final_ai_jump_scale(animal_id: StringName) -> float:
	match animal_id:
		&"rabbit": return 0.82
		&"monkey": return 0.78
		&"deer": return 0.70
		&"cat": return 0.72
		_: return 0.68
