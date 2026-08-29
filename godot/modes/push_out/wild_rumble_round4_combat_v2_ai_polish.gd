extends "res://modes/push_out/wild_rumble_round4_combat_v2_final.gd"

## Final Round 4 AI aerial execution. The existing ArenaCombatCore still owns
## cooldown, Stagger, Break and survival assists; this layer only supplies the
## jump/drop behavior that differentiates agile AI species.

const FINAL_R4_AERIAL_AI_IDS: Array[StringName] = [&"rabbit", &"deer", &"monkey", &"cat"]
const FINAL_R4_AERIAL_REARM: float = 1.20

var _final_r4_ai_aerial_cooldown: Dictionary = {}
var _final_r4_ai_aerial_armed: Dictionary = {}

func _ready() -> void:
	await super()
	for racer: WildDashCharacterController in ai_racers:
		if racer == null:
			continue
		_final_r4_ai_aerial_cooldown[racer.get_instance_id()] = 0.0
		_final_r4_ai_aerial_armed[racer.get_instance_id()] = false
	print("WILD RUMBLE FINAL AI AERIAL READY rabbit=true deer=true monkey=true cat=true arena_core_authority=true")

func _physics_process(delta: float) -> void:
	super(delta)
	for racer: WildDashCharacterController in ai_racers:
		if racer == null:
			continue
		var id: int = racer.get_instance_id()
		_final_r4_ai_aerial_cooldown[id] = maxf(0.0, float(_final_r4_ai_aerial_cooldown.get(id, 0.0)) - delta)
	_update_final_r4_ai_aerial_combat()

func _update_final_r4_ai_aerial_combat() -> void:
	if _combat_core == null:
		return
	for racer: WildDashCharacterController in ai_racers:
		if racer == null or not _is_combatant_active(racer) or not FINAL_R4_AERIAL_AI_IDS.has(racer.animal_id):
			continue
		var id: int = racer.get_instance_id()
		var canopy: WildDashCanopyTraversalSystem = _final_ai_canopy_by_id.get(id, null) as WildDashCanopyTraversalSystem
		if canopy != null and canopy.is_swinging():
			continue
		var target: WildDashCharacterController = _phase2_ai_targets.get(id, null) as WildDashCharacterController
		if target == null or not _is_combatant_active(target):
			_final_r4_ai_aerial_armed[id] = false
			continue
		var planar_distance: float = Vector2(
			target.global_position.x - racer.global_position.x,
			target.global_position.z - racer.global_position.z
		).length()
		if racer.is_on_floor():
			if float(_final_r4_ai_aerial_cooldown.get(id, 0.0)) > 0.0 or not _combat_core.can_attack(racer):
				continue
			if planar_distance >= 2.0 and planar_distance <= 4.9:
				var phase: int = int(Time.get_ticks_msec() / 440) + id
				if phase % 5 == 0:
					racer.velocity.y = maxf(racer.velocity.y, racer.jump_velocity * _r4_ai_jump_scale(racer.animal_id))
					_final_r4_ai_aerial_armed[id] = true
			continue
		if not bool(_final_r4_ai_aerial_armed.get(id, false)) or racer.velocity.y > -0.30:
			continue
		var height_difference: float = racer.global_position.y - target.global_position.y
		if height_difference < 0.38 or height_difference > 2.9 or planar_distance > 2.25:
			continue
		if not _combat_core.can_attack(racer) or not _combat_core.try_begin_attack(racer, &"stomp"):
			continue
		var offset: Vector3 = target.global_position - racer.global_position
		offset.y = 0.0
		if offset.length_squared() <= 0.001:
			offset = Vector3.FORWARD
		var result: Dictionary = _combat_core.apply_hit(racer, target, offset, &"stomp", 0)
		if not bool(result.get("applied", false)):
			continue
		_record_phase2_hit_credit(racer, target)
		var bounce: float = WildDashAerialCombatSystem.get_bounce_scale(racer.animal_id)
		racer.velocity.y = maxf(racer.velocity.y, racer.jump_velocity * bounce)
		match racer.animal_id:
			&"rabbit":
				_combat_core.add_environment_stagger(target, 5.0)
			&"deer":
				var speed_ratio: float = clampf(Vector2(racer.velocity.x, racer.velocity.z).length() / maxf(1.0, racer.arena_move_speed), 0.0, 1.0)
				target.apply_knockback(offset.normalized(), 0.65 + speed_ratio * 0.75)
			&"cat":
				if WildDashCombatV2AIBrain.is_behind_target(racer, target):
					_combat_core.add_environment_stagger(target, 4.0)
			&"monkey":
				_combat_core.add_environment_stagger(target, 3.5)
			_:
				pass
		_final_r4_ai_aerial_armed[id] = false
		_final_r4_ai_aerial_cooldown[id] = FINAL_R4_AERIAL_REARM
		WildDashCombatV2FX.spawn_impact(self, target.global_position + Vector3.UP * 0.45, &"stomp", 0.95)

func _r4_ai_jump_scale(animal_id: StringName) -> float:
	match animal_id:
		&"rabbit": return 0.82
		&"monkey": return 0.78
		&"deer": return 0.70
		&"cat": return 0.72
		_: return 0.68
