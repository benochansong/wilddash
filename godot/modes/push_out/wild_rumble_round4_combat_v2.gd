extends "res://modes/push_out/wild_rumble_round4_species_expansion.gd"

## Round 4 Combat V2 adapter.
## ArenaCombatCore remains authoritative for Stagger, Break, Back Attack,
## survival assist and Recovery Brake. Shared Combat V2 data supplies Crocodile
## range/mobility/recovery and directional Tail Sweep identity.

var _combat_v2_tail_recovery_remaining: float = 0.0

func _ready() -> void:
	await super()
	print("WILD RUMBLE COMBAT V2 READY crocodile_shared_profile=true round4_modifier=true arena_core_preserved=true")

func _physics_process(delta: float) -> void:
	super(delta)
	_combat_v2_tail_recovery_remaining = maxf(0.0, _combat_v2_tail_recovery_remaining - delta)

func _on_phase1_combat_action(action: Dictionary) -> void:
	if player == null or player.animal_id != &"crocodile":
		super(action)
		return
	# Recovery Brake / brace owns the press whenever the player is already being
	# launched. Combat V2 must never steal that defensive input.
	if _round4_brace_consumed_press or _round4_brace_signal_suppress_remaining > 0.0:
		return
	var kind: StringName = StringName(action.get("kind", &"tap"))
	if kind == &"hold":
		_do_round4_crocodile_tail_sweep()
	else:
		_do_round4_crocodile_bite()

func _do_round4_crocodile_bite() -> void:
	if player == null or _combat_core == null or not _is_combatant_active(player):
		return
	var spec: WildDashCombatAbilitySpec = WildDashCombatAbilitySystem.get_basic_attack(player.animal_id)
	if spec == null or not _combat_core.try_begin_attack(player, &"tap"):
		return
	var context: Dictionary = {"in_water": false}
	var preview: WildDashCombatResolution = WildDashCombatAbilityResolver.resolve_spec(
		player,
		null,
		spec,
		&"push_out",
		context
	)
	var forward: Vector3 = -player.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.001:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()
	player.apply_knockback(forward, maxf(1.35, preview.mobility_impulse))
	var target: WildDashCharacterController = _combat_v2_round4_front_target(spec.range, spec.arc_dot)
	if target == null:
		if hud != null:
			hud.set_message("BITE LUNGE · NO TARGET")
		return
	var offset: Vector3 = target.global_position - player.global_position
	offset.y = 0.0
	var result: Dictionary = _combat_core.apply_hit(player, target, offset, &"tap", 0)
	if bool(result.get("applied", false)):
		_record_phase2_hit_credit(player, target)
		_round4_camera_shake_remaining = maxf(_round4_camera_shake_remaining, 0.10)
		if hud != null:
			hud.set_message("BITE LUNGE! · STAGGER %.0f/100 · KB %.1f" % [
				_combat_core.get_stagger(target), float(result.get("knockback", 0.0)),
			])
		print("COMBAT V2 CROCODILE BITE mode=push_out target=%s kb=%.2f profile_stagger=%.1f" % [
			String(target.animal_id), float(result.get("knockback", 0.0)), preview.stagger,
		])

func _do_round4_crocodile_tail_sweep() -> void:
	if player == null or _combat_core == null or not _is_combatant_active(player):
		return
	if _combat_v2_tail_recovery_remaining > 0.0:
		return
	var spec: WildDashCombatAbilitySpec = WildDashCombatAbilitySystem.get_heavy_attack(player.animal_id)
	if spec == null or not _combat_core.try_begin_attack(player, &"hold"):
		return
	var targets_hit: int = 0
	for target: WildDashCharacterController in racers:
		if target == player or not _is_combatant_active(target):
			continue
		var offset: Vector3 = target.global_position - player.global_position
		offset.y = 0.0
		var distance: float = offset.length()
		if distance <= 0.001 or distance > spec.range:
			continue
		var directional_multiplier: float = WildDashCombatAbilitySystem.get_tail_direction_multiplier(player, target)
		var context: Dictionary = {
			"in_water": false,
			"directional_multiplier": directional_multiplier,
		}
		var preview: WildDashCombatResolution = WildDashCombatAbilityResolver.resolve_spec(
			player,
			target,
			spec,
			&"push_out",
			context
		)
		var result: Dictionary = _combat_core.apply_hit(player, target, offset, &"tap", 0)
		if not bool(result.get("applied", false)):
			continue
		# ArenaCombatCore handles the real stat-weighted hit. This small directional
		# shove is the Crocodile identity layer: front 1.0x, side 1.15x, rear 1.25x.
		target.apply_knockback(offset.normalized(), 1.15 * preview.directional_multiplier)
		_record_phase2_hit_credit(player, target)
		targets_hit += 1

	_combat_v2_tail_recovery_remaining = spec.recovery
	if targets_hit > 0:
		_round4_camera_shake_remaining = maxf(_round4_camera_shake_remaining, 0.12)
		if hud != null:
			hud.set_message("TAIL SWEEP! · TARGETS %d" % targets_hit)
		print("COMBAT V2 CROCODILE TAIL mode=push_out targets=%d recovery=%.2f" % [targets_hit, spec.recovery])
	elif hud != null:
		hud.set_message("TAIL SWEEP · NO TARGET")

func _combat_v2_round4_front_target(
	attack_range: float,
	arc_dot: float
) -> WildDashCharacterController:
	if player == null:
		return null
	var forward: Vector3 = -player.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.001:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()
	var best: WildDashCharacterController = null
	var best_distance: float = INF
	for target: WildDashCharacterController in racers:
		if target == player or not _is_combatant_active(target):
			continue
		var offset: Vector3 = target.global_position - player.global_position
		offset.y = 0.0
		var distance: float = offset.length()
		if distance <= 0.01 or distance > attack_range:
			continue
		if forward.dot(offset.normalized()) < arc_dot:
			continue
		if distance < best_distance:
			best_distance = distance
			best = target
	return best
