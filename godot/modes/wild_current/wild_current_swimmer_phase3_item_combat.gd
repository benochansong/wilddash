class_name WildCurrentSwimmerPhase3
extends "res://modes/wild_current/wild_current_swimmer_phase2.gd"

## Round 5 Phase 3 item/combat bridge.
## The shared ItemSystem remains authoritative; this adapter makes its effects
## meaningful while the land CharacterController physics loop is disabled.

const WATER_ITEM_KNOCKBACK_TRANSFER: float = 0.28
const WATER_ITEM_DASH_SCALE: float = 1.24
const WATER_ITEM_CARROT_SCALE: float = 1.12
const WATER_ITEM_TURBO_SCALE: float = 1.28
const WATER_ITEM_SLOW_SCALE: float = 0.74
const WATER_ITEM_SPIN_SCALE: float = 0.62
const AI_ITEM_DECISION_INTERVAL: float = 0.32

var _ai_item_timer: float = 0.0

func _process_player_swim(delta: float) -> void:
	super(delta)
	if InputManager.consume_item():
		var item_before := racer.get_held_item() if racer != null else &""
		if racer != null and ItemSystem.use_held_item(racer):
			print("r5_water_item_use racer=%s source=PLAYER item=%s q_b=true" % [
				RaceManager.get_racer_label(racer), String(item_before),
			])

func _process_ai_swim(delta: float) -> void:
	super(delta)
	if racer == null or racer.finished:
		return
	_ai_item_timer = maxf(0.0, _ai_item_timer - delta)
	if _ai_item_timer > 0.0 or racer.get_held_item() == &"":
		return
	if provider != null and provider.has_method("should_ai_use_item_phase3"):
		if not bool(provider.call("should_ai_use_item_phase3", racer)):
			return
	var item_before := racer.get_held_item()
	if ItemSystem.use_held_item(racer):
		_ai_item_timer = AI_ITEM_DECISION_INTERVAL + float(maxi(0, ai_slot) % 4) * 0.07
		print("r5_water_item_use racer=%s source=AI item=%s rank=%d" % [
			RaceManager.get_racer_label(racer), String(item_before), RaceManager.get_rank(racer),
		])

func _apply_swim_motion(delta: float, requested_speed: float) -> void:
	if racer == null:
		return
	var shared_knockback := racer.get_knockback_velocity()
	if shared_knockback.length_squared() > 0.0001:
		_water_combat_push_velocity += shared_knockback * WATER_ITEM_KNOCKBACK_TRANSFER
		if _water_combat_push_velocity.length() > WATER_COMBAT_PUSH_MAX:
			_water_combat_push_velocity = _water_combat_push_velocity.normalized() * WATER_COMBAT_PUSH_MAX
		racer.decay_knockback(delta)

	var tuned_speed := requested_speed
	if ItemSystem.has_effect(racer, &"dash"):
		tuned_speed = maxf(tuned_speed, max_swim_speed * WATER_ITEM_DASH_SCALE)
	if ItemSystem.has_effect(racer, &"super_carrot"):
		tuned_speed = maxf(tuned_speed, max_swim_speed * WATER_ITEM_CARROT_SCALE)
	if ItemSystem.has_effect(racer, &"wild_turbo"):
		tuned_speed = maxf(tuned_speed, max_swim_speed * WATER_ITEM_TURBO_SCALE)
	if ItemSystem.has_effect(racer, &"slow"):
		tuned_speed *= WATER_ITEM_SLOW_SCALE
	if ItemSystem.has_effect(racer, &"spin"):
		tuned_speed *= WATER_ITEM_SPIN_SCALE

	super(delta, tuned_speed)
