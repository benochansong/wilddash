extends "res://modes/fruit_collection/fruit_collection_mode.gd"

## Round 2 V2 polish layer.
## Keeps the Harvest Heist rules intact while making fruit readable as fruit and
## giving POWER / DEFENSE a clear arena-combat payoff.

const POWER_STUN_MIN_POWER: float = 7.5
const POWER_STUN_MIN_GAP: float = 2.0
const POWER_STUN_MAX_SECONDS: float = 0.55
const POWER_STUN_IMMUNITY_SECONDS: float = 1.10
const HEAVY_CARRY_BONUS_MAX: float = 1.05

var stun_remaining_by_id: Dictionary = {}
var stun_immunity_by_id: Dictionary = {}

func _ready() -> void:
	super()
	print("FRUIT FRENZY V2 POLISH READY fruit_shapes=true power_stun=true defense_resists=true heavy_carry=true max_stun=%.2fs" % POWER_STUN_MAX_SECONDS)

func _register_racer_state(racer: WildDashCharacterController) -> void:
	super(racer)
	if racer == null:
		return
	var key: int = racer.get_instance_id()
	stun_remaining_by_id[key] = 0.0
	stun_immunity_by_id[key] = 0.0

func _update_runtime_cooldowns(delta: float) -> void:
	super(delta)
	for racer: WildDashCharacterController in racers:
		if racer == null:
			continue
		var key: int = racer.get_instance_id()
		stun_remaining_by_id[key] = maxf(0.0, float(stun_remaining_by_id.get(key, 0.0)) - delta)
		stun_immunity_by_id[key] = maxf(0.0, float(stun_immunity_by_id.get(key, 0.0)) - delta)

func _update_speed_profiles() -> void:
	super()

	# Strong characters carry a full bag with less of the normal movement tax.
	# This is deliberately modest: power creates a Round 2 advantage without
	# turning Elephant/Bear/Boar into the fastest arena racers.
	for racer: WildDashCharacterController in racers:
		if racer == null:
			continue
		var key: int = racer.get_instance_id()
		if float(stun_remaining_by_id.get(key, 0.0)) > 0.0:
			racer.arena_move_speed = 0.0
			racer.skill_cooldown_remaining = maxf(racer.skill_cooldown_remaining, float(stun_remaining_by_id.get(key, 0.0)))
			continue
		if _get_carry(racer) >= 3:
			var power: float = WildDashAnimalAbilityProfile.get_stat(racer.animal_id, &"power")
			var t: float = clampf((power - 7.0) / 3.0, 0.0, 1.0)
			racer.arena_move_speed *= lerpf(1.0, HEAVY_CARRY_BONUS_MAX, t)

	for i in range(ai_drivers.size()):
		if i >= ai_racers.size():
			continue
		var racer: WildDashCharacterController = ai_racers[i]
		var key: int = racer.get_instance_id()
		if float(stun_remaining_by_id.get(key, 0.0)) > 0.0:
			ai_drivers[i].target_speed = 0.0
			continue
		if _get_carry(racer) >= 3:
			var power: float = WildDashAnimalAbilityProfile.get_stat(racer.animal_id, &"power")
			var t: float = clampf((power - 7.0) / 3.0, 0.0, 1.0)
			ai_drivers[i].target_speed *= lerpf(1.0, HEAVY_CARRY_BONUS_MAX, t)

func _try_player_body_check() -> void:
	if player == null or _player_body_check_cooldown > 0.0:
		return
	if _is_stunned(player):
		hud.set_message("STUNNED · RECOVERING")
		return
	var target := _find_body_check_target(player)
	if target == null:
		hud.set_message("BODY CHECK · NO TARGET")
		return
	var offset := target.global_position - player.global_position
	offset.y = 0.0
	if offset.length_squared() <= 0.001:
		return

	var impulse: float = WildDashRacingActionController.calculate_body_check_impulse(player.animal_id, target.animal_id)
	target.apply_knockback(offset.normalized(), impulse)
	_player_body_check_cooldown = PLAYER_BODY_CHECK_COOLDOWN

	var power: float = WildDashAnimalAbilityProfile.get_stat(player.animal_id, &"power")
	var spill_amount: int = 1
	if power >= 9.5 and _get_carry(target) >= 3:
		spill_amount = 3
	elif power >= 8.0 or impulse >= KNOCKBACK_STRONG_THRESHOLD:
		spill_amount = 2
	_spill_racer(target, spill_amount, "PLAYER POWER BODY CHECK")
	spill_hit_cooldown_by_id[target.get_instance_id()] = COMBAT_SPILL_COOLDOWN

	var stun_seconds: float = _apply_power_stun(player, target)
	AudioManager.play_sfx_id("hit", 1.0 if power >= 9.0 else 0.92)
	if stun_seconds > 0.0:
		hud.set_message("HEAVY HIT! %s · STUN %.1fs · FRUIT -%d" % [target.get_display_name().to_upper(), stun_seconds, spill_amount])
	else:
		hud.set_message("BODY CHECK! %s · FRUIT -%d" % [target.get_display_name().to_upper(), spill_amount])

func _try_ai_attack(attacker: WildDashCharacterController, target: WildDashCharacterController, personality: StringName) -> void:
	if attacker == null or target == null or _is_stunned(attacker):
		return
	var key: int = attacker.get_instance_id()
	if float(ai_attack_cooldown_by_id.get(key, 0.0)) > 0.0:
		return
	var offset := target.global_position - attacker.global_position
	offset.y = 0.0
	if offset.length_squared() > 2.65 * 2.65 or offset.length_squared() <= 0.001:
		return

	var raw_impulse: float = WildDashRacingActionController.calculate_body_check_impulse(attacker.animal_id, target.animal_id)
	var personality_scale: float = 0.86 if personality == PERSONALITY_THIEF else 0.74
	var strength: float = clampf(raw_impulse * personality_scale, 3.6, 7.8)
	target.apply_knockback(offset.normalized(), strength)

	var power: float = WildDashAnimalAbilityProfile.get_stat(attacker.animal_id, &"power")
	var amount: int = 1
	if power >= 9.5 and _get_carry(target) >= 4:
		amount = 3
	elif power >= 8.0 or (personality == PERSONALITY_THIEF and _get_carry(target) >= 4):
		amount = 2
	_spill_racer(target, amount, "AI POWER BODY CHECK")
	_apply_power_stun(attacker, target)

	spill_hit_cooldown_by_id[target.get_instance_id()] = COMBAT_SPILL_COOLDOWN
	ai_attack_cooldown_by_id[key] = AI_ATTACK_COOLDOWN
	AudioManager.play_sfx_id("hit", 0.78 if power >= 8.0 else 0.66)

func _apply_power_stun(attacker: WildDashCharacterController, target: WildDashCharacterController) -> float:
	if attacker == null or target == null:
		return 0.0
	var target_key: int = target.get_instance_id()
	if float(stun_immunity_by_id.get(target_key, 0.0)) > 0.0:
		return 0.0

	var power: float = WildDashAnimalAbilityProfile.get_stat(attacker.animal_id, &"power")
	var defense: float = WildDashAnimalAbilityProfile.get_stat(target.animal_id, &"defense")
	var gap: float = power - defense
	if power < POWER_STUN_MIN_POWER or gap < POWER_STUN_MIN_GAP:
		return 0.0

	var duration: float = clampf(0.20 + (gap - POWER_STUN_MIN_GAP) * 0.075, 0.18, POWER_STUN_MAX_SECONDS)
	if attacker.animal_id == &"elephant" and defense <= 5.5:
		duration = maxf(duration, 0.50)
	elif power >= 9.0 and defense <= 5.0:
		duration = maxf(duration, 0.45)

	stun_remaining_by_id[target_key] = duration
	stun_immunity_by_id[target_key] = duration + POWER_STUN_IMMUNITY_SECONDS
	target.skill_cooldown_remaining = maxf(target.skill_cooldown_remaining, duration)
	var visual: WildDashCharacterVisual = target.get_visual()
	if visual != null:
		visual.play_action(&"Hit", duration)

	if target.is_player:
		_show_event("STUNNED %.1fs · POWER %.1f vs DEF %.1f" % [duration, power, defense], minf(1.0, duration + 0.35))
		hud.set_message("HEAVY HIT · MOVE LOCK %.1fs" % duration)
	elif attacker.is_player:
		_show_event("POWER STUN! %.1fs" % duration, 0.72)

	print("FRUIT FRENZY POWER STUN attacker=%s power=%.1f target=%s defense=%.1f duration=%.2f immunity=%.2f" % [
		String(attacker.animal_id), power, String(target.animal_id), defense, duration, duration + POWER_STUN_IMMUNITY_SECONDS,
	])
	return duration

func _is_stunned(racer: WildDashCharacterController) -> bool:
	if racer == null:
		return false
	return float(stun_remaining_by_id.get(racer.get_instance_id(), 0.0)) > 0.0

# -----------------------------------------------------------------------------
# Fruit visual pass: readable low-poly fruit silhouettes, no physics overhead.
# -----------------------------------------------------------------------------

func _configure_fruit_visual(fruit: MeshInstance3D, fruit_type: StringName) -> void:
	if fruit == null:
		return
	var previous_type := StringName(str(fruit.get_meta("fruit_visual_v2_type", "")))
	if previous_type == fruit_type and fruit.get_child_count() > 0:
		return
	fruit.set_meta("fruit_visual_v2_type", String(fruit_type))
	fruit.mesh = null
	fruit.scale = Vector3.ONE
	fruit.rotation = Vector3.ZERO
	for child: Node in fruit.get_children():
		child.visible = false
		child.queue_free()

	match fruit_type:
		FRUIT_BANANA:
			_build_banana(fruit)
		FRUIT_BERRY:
			_build_berry(fruit)
		FRUIT_WILD:
			_build_wild_fruit(fruit)
		FRUIT_GOLDEN:
			_build_apple(fruit, Color(1.0, 0.66, 0.03), true)
		_:
			_build_apple(fruit, Color(0.96, 0.16, 0.12), false)

func _build_apple(parent: MeshInstance3D, body_color: Color, golden: bool) -> void:
	var body := SphereMesh.new()
	body.radius = 0.44 if not golden else 0.58
	body.height = 0.88 if not golden else 1.16
	_add_fruit_part(parent, "AppleBody", body, body_color, Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 0.88, 1.0), 1.45 if golden else 0.12)

	var stem := CylinderMesh.new()
	stem.top_radius = 0.045
	stem.bottom_radius = 0.055
	stem.height = 0.30 if not golden else 0.38
	_add_fruit_part(parent, "AppleStem", stem, Color(0.25, 0.12, 0.04), Vector3(0.0, 0.48 if not golden else 0.64, 0.0), Vector3(0.0, 0.0, -0.16))

	var leaf := BoxMesh.new()
	leaf.size = Vector3(0.30 if not golden else 0.38, 0.055, 0.16)
	_add_fruit_part(parent, "AppleLeaf", leaf, Color(0.18, 0.55, 0.14), Vector3(0.16, 0.52 if not golden else 0.68, 0.0), Vector3(0.0, 0.25, -0.42), Vector3.ONE, 0.10 if golden else 0.0)

func _build_banana(parent: MeshInstance3D) -> void:
	var yellow := Color(1.0, 0.80, 0.06)
	for i in range(3):
		var segment := CapsuleMesh.new()
		segment.radius = 0.16
		segment.height = 0.58
		var x: float = -0.26 + float(i) * 0.26
		var y: float = 0.08 - absf(float(i - 1)) * 0.05
		var angle: float = 1.02 + float(i - 1) * 0.24
		_add_fruit_part(parent, "BananaSegment_%d" % i, segment, yellow, Vector3(x, y, 0.0), Vector3(0.0, 0.0, angle), Vector3.ONE, 0.12)
	var tip := SphereMesh.new()
	tip.radius = 0.09
	tip.height = 0.18
	_add_fruit_part(parent, "BananaTip", tip, Color(0.30, 0.18, 0.05), Vector3(0.43, 0.20, 0.0))

func _build_berry(parent: MeshInstance3D) -> void:
	var purple := Color(0.55, 0.16, 0.82)
	var offsets: Array[Vector3] = [
		Vector3(0.0, 0.10, 0.0), Vector3(0.22, 0.0, 0.0), Vector3(-0.22, 0.0, 0.0),
		Vector3(0.0, 0.0, 0.22), Vector3(0.0, 0.0, -0.22),
	]
	for i in range(offsets.size()):
		var orb := SphereMesh.new()
		orb.radius = 0.24
		orb.height = 0.48
		_add_fruit_part(parent, "Berry_%d" % i, orb, purple, offsets[i], Vector3.ZERO, Vector3.ONE, 0.14)
	var crown := CylinderMesh.new()
	crown.top_radius = 0.04
	crown.bottom_radius = 0.16
	crown.height = 0.20
	_add_fruit_part(parent, "BerryCrown", crown, Color(0.18, 0.58, 0.18), Vector3(0.0, 0.40, 0.0))

func _build_wild_fruit(parent: MeshInstance3D) -> void:
	var body := SphereMesh.new()
	body.radius = 0.46
	body.height = 0.92
	_add_fruit_part(parent, "WildBody", body, Color(0.12, 0.88, 0.35), Vector3.ZERO, Vector3.ZERO, Vector3(0.90, 1.12, 0.90), 0.95)
	for i in range(5):
		var spike := CylinderMesh.new()
		spike.top_radius = 0.0
		spike.bottom_radius = 0.10
		spike.height = 0.34
		var angle: float = TAU * float(i) / 5.0
		var pos := Vector3(cos(angle) * 0.33, 0.10, sin(angle) * 0.33)
		var rot := Vector3(sin(angle) * 0.65, 0.0, -cos(angle) * 0.65)
		_add_fruit_part(parent, "WildLeaf_%d" % i, spike, Color(0.95, 0.18, 0.55), pos, rot, Vector3.ONE, 0.35)
	var top_leaf := CylinderMesh.new()
	top_leaf.top_radius = 0.0
	top_leaf.bottom_radius = 0.12
	top_leaf.height = 0.42
	_add_fruit_part(parent, "WildTop", top_leaf, Color(0.20, 0.95, 0.46), Vector3(0.0, 0.55, 0.0), Vector3.ZERO, Vector3.ONE, 0.45)

func _add_fruit_part(
	parent: MeshInstance3D,
	node_name: String,
	mesh: Mesh,
	color: Color,
	local_position: Vector3,
	local_rotation: Vector3 = Vector3.ZERO,
	local_scale: Vector3 = Vector3.ONE,
	emission_strength: float = 0.0
) -> void:
	var part := MeshInstance3D.new()
	part.name = node_name
	part.mesh = mesh
	part.position = local_position
	part.rotation = local_rotation
	part.scale = local_scale
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.52
	if emission_strength > 0.0:
		material.emission_enabled = true
		material.emission = color * emission_strength
	part.material_override = material
	parent.add_child(part)
