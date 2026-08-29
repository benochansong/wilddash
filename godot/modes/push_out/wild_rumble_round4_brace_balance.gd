extends "res://modes/push_out/wild_rumble_round4_controls.gd"

## Round 4 launch-balance + recovery-brake pass.
##
## Goals:
## - Keep the satisfying launch/impact feel from the Titan Crown combat pass.
## - Prevent a fresh low-Stagger racer (especially light/agile animals) from
##   crossing half the arena from one ordinary hit.
## - Let F / Gamepad Y act as a short RECOVERY BRAKE while the player is already
##   being launched. Outside a launch, F remains the normal Quick Bash / Hold
##   Heavy Smash combat control inherited from the Round 4 controls layer.
## - Preserve real danger at high Stagger, BREAK, Final Duel and Crown pressure.

const ROUND4_GLOBAL_EXTRA_SHOVE_SCALE := 0.82
const ROUND4_PLAYER_EXTRA_SHOVE_SCALE := 0.48

const ROUND4_BRACE_MIN_KNOCKBACK_SPEED := 4.20
const ROUND4_BRACE_DURATION := 0.36
const ROUND4_BRACE_COOLDOWN := 0.82
const ROUND4_BRACE_HOLD_DECELERATION := 11.5
const ROUND4_BRACE_SIGNAL_RELEASE_GRACE := 0.16

const ROUND4_LAUNCH_CAP_LOW_STAGGER := 10.8
const ROUND4_LAUNCH_CAP_MID_STAGGER := 12.2
const ROUND4_LAUNCH_CAP_HIGH_STAGGER := 14.0
const ROUND4_LAUNCH_CAP_BREAK_STAGGER := 16.8
const ROUND4_FINAL_DUEL_CAP_BONUS := 1.15
const ROUND4_HOT_OBJECTIVE_CAP_BONUS := 0.75

var _round4_brace_remaining := 0.0
var _round4_brace_cooldown_remaining := 0.0
var _round4_brace_consumed_press := false
var _round4_brace_signal_suppress_remaining := 0.0

func _physics_process(delta: float) -> void:
	super(delta)
	_round4_brace_remaining = maxf(0.0, _round4_brace_remaining - delta)
	_round4_brace_cooldown_remaining = maxf(0.0, _round4_brace_cooldown_remaining - delta)
	_round4_brace_signal_suppress_remaining = maxf(0.0, _round4_brace_signal_suppress_remaining - delta)

	if mode_finished or not GameManager.round_active:
		_round4_brace_consumed_press = false
		_round4_brace_remaining = 0.0
		return

	if _round4_brace_remaining > 0.0 and InputManager.is_race_combat_pressed():
		_apply_round4_brace_drag(delta)

func _ensure_round4_player_balance() -> void:
	if _round4_player_balance_ready or player == null or _combat_core == null:
		return
	if not is_instance_valid(player):
		return

	# Light racers already pay for low Defense in the normal Power/Defense formula.
	# Give the human a modest hidden survival curve so Cat/Monkey/Rabbit still feel
	# light without becoming one-hit ring-out liabilities. Heavy racers receive less
	# assist because their normal Defense already protects them.
	var defense := WildDashRaceCombatProfile.get_defense(player.animal_id)
	var agility := WildDashAnimalAbilityProfile.get_stat(player.animal_id, &"agility")
	var incoming_scale := clampf(0.72 + defense * 0.012, 0.75, 0.84)
	var recovery_scale := lerpf(1.18, 1.32, clampf(agility / 10.0, 0.0, 1.0))

	_combat_core.configure_survival_assist(
		player,
		incoming_scale,
		recovery_scale,
		ROUND4_PLAYER_COMBO_GUARD_SECONDS,
		0.56,
		ROUND4_PLAYER_COMBO_STAGGER_SCALE
	)
	_round4_player_balance_ready = true
	print("WILD RUMBLE LAUNCH BALANCE READY animal=%s incoming_kb=%.2f stagger_recovery=%.2f F_recovery_brake=true" % [
		String(player.animal_id), incoming_scale, recovery_scale,
	])

func _update_round4_direct_attack_input() -> void:
	if player == null or not is_instance_valid(player) or not _is_combatant_active(player):
		_round4_attack_was_down = false
		_round4_brace_consumed_press = false
		return

	var attack_down := InputManager.is_race_combat_pressed()
	if attack_down and not _round4_attack_was_down:
		if _try_start_round4_recovery_brake():
			_round4_brace_consumed_press = true
			_round4_brace_signal_suppress_remaining = maxf(
				_round4_brace_signal_suppress_remaining,
				ROUND4_BRACE_DURATION + 0.45
			)
		else:
			_round4_brace_consumed_press = false
			var directional := InputManager.classify_race_combat_direction(InputManager.get_steer_axis())
			_on_phase1_combat_action({
				"kind": &"tap",
				"direction": directional,
				"held_seconds": 0.0,
				"source": &"round4_immediate_press",
			})

	if not attack_down and _round4_attack_was_down and _round4_brace_consumed_press:
		# Keep a tiny grace window because InputManager and the mode can observe the
		# release edge in different physics-process order. This prevents the brace's
		# release from accidentally firing a delayed Quick Bash.
		_round4_brace_consumed_press = false
		_round4_brace_signal_suppress_remaining = maxf(
			_round4_brace_signal_suppress_remaining,
			ROUND4_BRACE_SIGNAL_RELEASE_GRACE
		)

	_round4_attack_was_down = attack_down

func _on_phase1_combat_action(action: Dictionary) -> void:
	if _round4_brace_consumed_press or _round4_brace_signal_suppress_remaining > 0.0:
		return
	super(action)

func _try_start_round4_recovery_brake() -> bool:
	if player == null or _round4_brace_cooldown_remaining > 0.0:
		return false
	var knockback := player.get_knockback_velocity()
	var speed := knockback.length()
	if speed < ROUND4_BRACE_MIN_KNOCKBACK_SPEED:
		return false

	var agility := WildDashAnimalAbilityProfile.get_stat(player.animal_id, &"agility")
	var stagger := _combat_core.get_stagger(player) if _combat_core != null else 0.0
	# Agile racers get better air/recovery control; high Stagger deliberately makes
	# the brake weaker so BREAK and late-round finishers remain dangerous.
	var reduction := lerpf(0.28, 0.42, clampf(agility / 10.0, 0.0, 1.0))
	if stagger >= 90.0:
		reduction *= 0.55
	elif stagger >= 70.0:
		reduction *= 0.76
	elif stagger >= 50.0:
		reduction *= 0.90

	var new_velocity := knockback * (1.0 - reduction)
	_set_round4_player_knockback(new_velocity)
	_round4_brace_remaining = ROUND4_BRACE_DURATION
	_round4_brace_cooldown_remaining = ROUND4_BRACE_COOLDOWN

	var visual := player.get_visual()
	if visual != null:
		visual.play_action(&"Skill", 0.22)
	if hud != null:
		hud.set_message("RECOVERY BRAKE! · KB %.1f → %.1f%s" % [
			speed,
			new_velocity.length(),
			" · HIGH STAGGER!" if stagger >= 70.0 else "",
		])
	print("WILD RUMBLE RECOVERY BRAKE animal=%s kb_before=%.2f kb_after=%.2f stagger=%.1f" % [
		String(player.animal_id), speed, new_velocity.length(), stagger,
	])
	return true

func _apply_round4_brace_drag(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var knockback := player.get_knockback_velocity()
	var speed := knockback.length()
	if speed <= 0.05:
		_round4_brace_remaining = 0.0
		return
	var next_speed := maxf(0.0, speed - ROUND4_BRACE_HOLD_DECELERATION * delta)
	_set_round4_player_knockback(knockback.normalized() * next_speed)

func _record_phase2_hit_credit(source: WildDashCharacterController, target: WildDashCharacterController) -> void:
	if source == null or target == null:
		return

	# The parent layer adds a role/edge/relic bonus shove on top of ArenaCombatCore.
	# Keep that layer, but trim it slightly for everyone so the whole match does not
	# burn through racers too quickly. For the human, trim the bonus more strongly
	# and then cap total launch speed according to current Stagger.
	var before := target.get_knockback_velocity()
	super(source, target)
	if not is_instance_valid(target):
		return
	var after := target.get_knockback_velocity()
	var bonus_delta := after - before
	var bonus_scale := ROUND4_PLAYER_EXTRA_SHOVE_SCALE if target == player else ROUND4_GLOBAL_EXTRA_SHOVE_SCALE
	var adjusted := before + bonus_delta * bonus_scale

	if target == player and _combat_core != null:
		var stagger := _combat_core.get_stagger(player)
		var launch_cap := _round4_player_launch_cap(stagger)
		if adjusted.length() > launch_cap:
			adjusted = adjusted.normalized() * launch_cap

	_set_racer_knockback(target, adjusted)

func _round4_player_launch_cap(stagger: float) -> float:
	var cap := ROUND4_LAUNCH_CAP_LOW_STAGGER
	if stagger >= 90.0:
		cap = ROUND4_LAUNCH_CAP_BREAK_STAGGER
	elif stagger >= 60.0:
		cap = ROUND4_LAUNCH_CAP_HIGH_STAGGER
	elif stagger >= 30.0:
		cap = ROUND4_LAUNCH_CAP_MID_STAGGER

	if _round4_alive_count() <= 2:
		cap += ROUND4_FINAL_DUEL_CAP_BONUS
	if _round4_player_is_hot_objective():
		cap += ROUND4_HOT_OBJECTIVE_CAP_BONUS
	return cap

func _set_round4_player_knockback(value: Vector3) -> void:
	if player == null:
		return
	_set_racer_knockback(player, value)

func _set_racer_knockback(racer: WildDashCharacterController, value: Vector3) -> void:
	if racer == null or not is_instance_valid(racer):
		return
	# CharacterController intentionally exposes a getter but not a setter yet.
	# Godot member variables are still writable through Object.set(); keeping this
	# R4-only avoids changing shared race physics while we validate the mechanic.
	racer.set("_knockback_velocity", Vector3(value.x, 0.0, value.z))
