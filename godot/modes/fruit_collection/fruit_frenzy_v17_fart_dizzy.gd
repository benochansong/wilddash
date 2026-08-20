extends "res://modes/fruit_collection/fruit_frenzy_v16_clear_balance.gd"

## Round 2 V17 — fart hit authority.
## Every valid fart/gas special hit causes a clear 1.0 second dizzy lock for
## players and AI alike. Existing knockback, slow and fruit-spill behavior stays.

const FART_DIZZY_SECONDS: float = 1.0
const FART_DIZZY_IMMUNITY_SECONDS: float = 0.35
const FART_SPECIAL_IDS: Array[StringName] = [
	&"mud_gas",
	&"heavy_gas",
	&"stink_cloud",
	&"jet_fart",
]

func _ready() -> void:
	await super()
	print("ROUND2 FART DIZZY READY duration=1.00s player=true ai=true movement_lock=true skill_lock=true legacy_knockback_slow_spill=true")

func _apply_round2_special_effect(source: WildDashCharacterController, spec: Dictionary) -> void:
	var dizzy_targets: Array[WildDashCharacterController] = _collect_fart_hit_targets(source, spec)
	super(source, spec)
	var special_id := StringName(spec.get("id", &""))
	for target: WildDashCharacterController in dizzy_targets:
		_apply_fart_dizzy(source, target, special_id)

func _collect_fart_hit_targets(source: WildDashCharacterController, spec: Dictionary) -> Array[WildDashCharacterController]:
	var result: Array[WildDashCharacterController] = []
	if source == null or not is_instance_valid(source):
		return result
	var special_id := StringName(spec.get("id", &""))
	if not FART_SPECIAL_IDS.has(special_id):
		return result
	var radius: float = float(spec.get("radius", 4.0))
	var rear: Vector3 = source.global_transform.basis.z
	rear.y = 0.0
	if rear.length_squared() <= 0.001:
		rear = Vector3.BACK
	else:
		rear = rear.normalized()

	for target: WildDashCharacterController in racers:
		if target == null or target == source or target.finished:
			continue
		var offset: Vector3 = target.global_position - source.global_position
		offset.y = 0.0
		var distance: float = offset.length()
		if distance <= 0.01 or distance > radius:
			continue
		var direction: Vector3 = offset.normalized()
		# Mud Gas and Jet Fart are rear-cone attacks in the existing V5 rules.
		if special_id in [&"mud_gas", &"jet_fart"] and rear.dot(direction) < 0.12:
			continue
		result.append(target)
	return result

func _apply_fart_dizzy(
	source: WildDashCharacterController,
	target: WildDashCharacterController,
	special_id: StringName
) -> void:
	if source == null or target == null or not is_instance_valid(target) or target.finished:
		return
	var target_id: int = target.get_instance_id()
	stun_remaining_by_id[target_id] = maxf(
		float(stun_remaining_by_id.get(target_id, 0.0)),
		FART_DIZZY_SECONDS
	)
	stun_immunity_by_id[target_id] = maxf(
		float(stun_immunity_by_id.get(target_id, 0.0)),
		FART_DIZZY_SECONDS + FART_DIZZY_IMMUNITY_SECONDS
	)
	target.skill_cooldown_remaining = maxf(target.skill_cooldown_remaining, FART_DIZZY_SECONDS)
	var visual: WildDashCharacterVisual = target.get_visual()
	if visual != null:
		visual.play_action(&"Hit", FART_DIZZY_SECONDS)

	if target.is_player:
		_show_event("헤롱헤롱! · 방귀 적중 · 1.0초", FART_DIZZY_SECONDS)
		if hud != null:
			hud.set_message("헤롱헤롱! · 1.0초 이동 불가")
	elif source.is_player:
		_show_event("FART HIT! · DIZZY 1.0s", 0.90)

	print("ROUND2 FART DIZZY source=%s ability=%s target=%s duration=1.00 movement_lock=true skill_lock=true" % [
		RaceManager.get_racer_label(source),
		String(special_id),
		RaceManager.get_racer_label(target),
	])
