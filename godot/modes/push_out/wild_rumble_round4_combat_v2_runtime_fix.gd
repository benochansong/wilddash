extends "res://modes/push_out/wild_rumble_round4_combat_v2_ai_polish.gd"

## Runtime guard for two final-phase edge cases:
## 1) an AI Monkey can still own disabled CharacterBody physics when its active
##    Vine is removed by Final Three/Final Duel;
## 2) Crocodile land Water Ambush must apply the resolver's 55% land scale once,
##    not multiply the already-scaled result a second time.

func _physics_process(delta: float) -> void:
	super(delta)
	_restore_disabled_ai_canopy_bodies()

func _exit_tree() -> void:
	for racer: WildDashCharacterController in ai_racers:
		if racer == null:
			continue
		var system: WildDashCanopyTraversalSystem = _final_ai_canopy_by_id.get(racer.get_instance_id(), null) as WildDashCanopyTraversalSystem
		if system != null and system.get_active_vine_id() != &"":
			system.cancel_vine(racer)
	super()

func _restore_disabled_ai_canopy_bodies() -> void:
	for racer: WildDashCharacterController in ai_racers:
		if racer == null:
			continue
		var system: WildDashCanopyTraversalSystem = _final_ai_canopy_by_id.get(racer.get_instance_id(), null) as WildDashCanopyTraversalSystem
		if system == null or system.get_active_vine_id() == &"":
			continue
		if not system.is_swinging():
			system.cancel_vine(racer)
			racer.velocity.y = maxf(racer.velocity.y, 1.6)

func _final_crocodile_land_ambush(source: WildDashCharacterController) -> bool:
	if source == null:
		return false
	var id: int = source.get_instance_id()
	if float(_round4_special_cooldown_by_id.get(id, 0.0)) > 0.0:
		return false
	var spec: WildDashCombatAbilitySpec = WildDashCombatAbilitySystem.get_special_attack(&"crocodile")
	if spec == null:
		return false
	_round4_special_cooldown_by_id[id] = spec.cooldown
	var context: Dictionary = {"in_water": false}
	var preview: WildDashCombatResolution = WildDashCombatAbilityResolver.resolve_spec(source, null, spec, &"push_out", context)
	var forward: Vector3 = -source.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.001:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()

	# Mobility is not environment-scaled by the shared resolver, so the land
	# factor is applied here exactly once. Knockback/Stagger below are already
	# scaled by Round4CombatModifier via spec.land_effect_multiplier = 0.55.
	source.apply_knockback(forward, preview.mobility_impulse * spec.land_effect_multiplier)
	var target: WildDashCharacterController = _combat_v2_round4_front_target(spec.range, spec.arc_dot)
	WildDashCombatV2FX.spawn_trail(self, source.global_position + Vector3.UP * 0.55, forward, &"water", 1.0)
	if target == null or _combat_core == null:
		if source == player and hud != null:
			hud.set_message("WATER AMBUSH · LAND POWER 55%")
		return true
	var offset: Vector3 = target.global_position - source.global_position
	offset.y = 0.0
	if offset.length_squared() <= 0.001:
		return true
	target.apply_knockback(offset.normalized(), preview.knockback)
	_combat_core.add_environment_stagger(target, preview.stagger)
	if source == player and hud != null:
		hud.set_message("WATER AMBUSH! · LAND 55% · STAGGER %.0f/100" % _combat_core.get_stagger(target))
	return true
