extends "res://modes/push_out/wild_rumble_round4_brace_balance.gd"

## Round 4 species expansion.
## - Q / Gamepad B: mode-local Fart Ability for Boar/Bear/Raccoon/Monkey.
## - Crocodile F tap: Bite Lunge.
## - Crocodile F hold: Tail Sweep follow-up.
## Existing Recovery Brake still wins while the player is already launched.

const CROCODILE_BITE_RANGE := 4.05
const CROCODILE_BITE_LUNGE := 1.55
const CROCODILE_TAIL_RADIUS := 4.35
const ROUND4_SPECIAL_AI_CHECK := 0.58

var _round4_special_cooldown_by_id: Dictionary = {}
var _round4_special_slow_remaining_by_id: Dictionary = {}
var _round4_special_slow_scale_by_id: Dictionary = {}
var _round4_special_ai_elapsed := 0.0

func _physics_process(delta: float) -> void:
	super(delta)
	if mode_finished or not GameManager.round_active:
		return
	_update_round4_special_timers(delta)
	if InputManager.consume_item():
		_try_use_round4_special(player)
	_round4_special_ai_elapsed += delta
	if _round4_special_ai_elapsed >= ROUND4_SPECIAL_AI_CHECK:
		_round4_special_ai_elapsed = 0.0
		_update_round4_ai_specials()

func _on_phase1_combat_action(action: Dictionary) -> void:
	if player == null or player.animal_id != &"crocodile":
		super(action)
		return
	if _round4_brace_consumed_press or _round4_brace_signal_suppress_remaining > 0.0:
		return
	var kind := StringName(action.get("kind", &"tap"))
	if kind == &"hold":
		_do_round4_crocodile_tail_sweep()
	else:
		_do_round4_crocodile_bite()

func _do_round4_crocodile_bite() -> void:
	if player == null or _combat_core == null or not _is_combatant_active(player):
		return
	if not _combat_core.try_begin_attack(player, &"tap"):
		return
	var forward := -player.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.001:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	player.apply_knockback(forward, CROCODILE_BITE_LUNGE)
	var target := _round4_crocodile_front_target(CROCODILE_BITE_RANGE)
	if target == null:
		if hud != null:
			hud.set_message("BITE LUNGE · NO TARGET")
		return
	var offset := target.global_position - player.global_position
	offset.y = 0.0
	var result := _combat_core.apply_hit(player, target, offset, &"tap", 0)
	if bool(result.get("applied", false)):
		_record_phase2_hit_credit(player, target)
		_round4_camera_shake_remaining = maxf(_round4_camera_shake_remaining, 0.10)
		if hud != null:
			hud.set_message("BITE LUNGE! · STAGGER %.0f/100 · KB %.1f" % [
				_combat_core.get_stagger(target), float(result.get("knockback", 0.0)),
			])
		print("CROCODILE BITE LUNGE mode=push_out target=%s kb=%.2f" % [String(target.animal_id), float(result.get("knockback", 0.0))])

func _do_round4_crocodile_tail_sweep() -> void:
	if player == null or _combat_core == null or not _is_combatant_active(player):
		return
	if not _combat_core.try_begin_attack(player, &"hold"):
		return
	var targets_hit := 0
	for target: WildDashCharacterController in racers:
		if target == player or not _is_combatant_active(target):
			continue
		var offset := target.global_position - player.global_position
		offset.y = 0.0
		if offset.length_squared() <= 0.001 or offset.length() > CROCODILE_TAIL_RADIUS:
			continue
		var result := _combat_core.apply_hit(player, target, offset, &"tap", 0)
		if not bool(result.get("applied", false)):
			continue
		target.apply_knockback(offset.normalized(), 1.15)
		_record_phase2_hit_credit(player, target)
		targets_hit += 1
	if targets_hit > 0:
		_round4_camera_shake_remaining = maxf(_round4_camera_shake_remaining, 0.12)
		if hud != null:
			hud.set_message("TAIL SWEEP! · TARGETS %d" % targets_hit)
		print("CROCODILE TAIL SWEEP mode=push_out targets=%d" % targets_hit)

func _round4_crocodile_front_target(radius: float) -> WildDashCharacterController:
	var forward := -player.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var best: WildDashCharacterController = null
	var best_distance := INF
	for target: WildDashCharacterController in racers:
		if target == player or not _is_combatant_active(target):
			continue
		var offset := target.global_position - player.global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance <= 0.01 or distance > radius:
			continue
		if forward.dot(offset.normalized()) < 0.22:
			continue
		if distance < best_distance:
			best_distance = distance
			best = target
	return best

func _update_round4_special_timers(delta: float) -> void:
	for racer: WildDashCharacterController in racers:
		if racer == null:
			continue
		var id := racer.get_instance_id()
		_round4_special_cooldown_by_id[id] = maxf(0.0, float(_round4_special_cooldown_by_id.get(id, 0.0)) - delta)
		_round4_special_slow_remaining_by_id[id] = maxf(0.0, float(_round4_special_slow_remaining_by_id.get(id, 0.0)) - delta)
		if float(_round4_special_slow_remaining_by_id[id]) <= 0.0:
			_round4_special_slow_scale_by_id[id] = 1.0

func _round4_objective_speed_multiplier(racer: WildDashCharacterController) -> float:
	var multiplier := super(racer)
	if racer == null:
		return multiplier
	var id := racer.get_instance_id()
	if float(_round4_special_slow_remaining_by_id.get(id, 0.0)) > 0.0:
		multiplier *= float(_round4_special_slow_scale_by_id.get(id, 1.0))
	return multiplier

func _try_use_round4_special(source: WildDashCharacterController) -> bool:
	if source == null or not _is_combatant_active(source):
		return false
	if not WildDashAnimalSpecialAbilitySystem.can_use_special(source.animal_id, &"push_out"):
		if source == player and hud != null:
			hud.set_message("NO Q SPECIAL · %s USES NORMAL KIT" % source.get_display_name().to_upper())
		return false
	var id := source.get_instance_id()
	if float(_round4_special_cooldown_by_id.get(id, 0.0)) > 0.0:
		if source == player and hud != null:
			hud.set_message("%s COOLDOWN %.1fs" % [
				WildDashAnimalSpecialAbilitySystem.get_special_name(source.animal_id),
				float(_round4_special_cooldown_by_id[id]),
			])
		return false
	var spec := WildDashAnimalSpecialAbilitySystem.get_special(source.animal_id)
	_round4_special_cooldown_by_id[id] = float(spec.get("cooldown", 6.0))
	_spawn_round4_cartoon_gas(source, StringName(spec.get("id", &"special")))
	_apply_round4_special_effect(source, spec)
	AudioManager.play_sfx_id("fart", 0.70)
	if source == player and hud != null:
		hud.set_message("%s! · Q SPECIAL" % str(spec.get("name", "SPECIAL")))
	print("ANIMAL SPECIAL animal=%s ability=%s mode=push_out cooldown=%.1f" % [
		String(source.animal_id), String(spec.get("id", &"")), float(spec.get("cooldown", 0.0)),
	])
	return true

func _apply_round4_special_effect(source: WildDashCharacterController, spec: Dictionary) -> void:
	var special_id := StringName(spec.get("id", &""))
	var radius := float(spec.get("radius", 4.0))
	var base_knockback := float(spec.get("knockback", 2.0))
	var stagger := float(spec.get("stagger", 5.0))
	var slow := float(spec.get("slow", 1.0))
	var duration := float(spec.get("duration", 0.6))
	var rear := source.global_transform.basis.z
	rear.y = 0.0
	rear = rear.normalized()

	for target: WildDashCharacterController in racers:
		if target == source or not _is_combatant_active(target):
			continue
		var offset := target.global_position - source.global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance <= 0.01 or distance > radius:
			continue
		var direction := offset.normalized()
		if special_id in [&"mud_gas", &"jet_fart"] and rear.dot(direction) < 0.12:
			continue
		var falloff := lerpf(1.0, 0.52, distance / radius)
		target.apply_knockback(direction, base_knockback * falloff)
		if _combat_core != null:
			_combat_core.add_environment_stagger(target, stagger * falloff)
		if slow < 0.999:
			var target_id := target.get_instance_id()
			_round4_special_slow_remaining_by_id[target_id] = maxf(float(_round4_special_slow_remaining_by_id.get(target_id, 0.0)), duration)
			_round4_special_slow_scale_by_id[target_id] = minf(float(_round4_special_slow_scale_by_id.get(target_id, 1.0)), slow)

	if special_id == &"jet_fart":
		source.apply_knockback(-source.global_transform.basis.z, float(spec.get("forward_impulse", 3.0)))

func _update_round4_ai_specials() -> void:
	var budget := 1
	for source: WildDashCharacterController in ai_racers:
		if budget <= 0:
			break
		if source == null or not _is_combatant_active(source):
			continue
		if not WildDashAnimalSpecialAbilitySystem.can_use_special(source.animal_id, &"push_out"):
			continue
		if float(_round4_special_cooldown_by_id.get(source.get_instance_id(), 0.0)) > 0.0:
			continue
		var spec := WildDashAnimalSpecialAbilitySystem.get_special(source.animal_id)
		var target := _nearest_round4_special_target(source, float(spec.get("radius", 4.0)) * 0.90)
		if target != null:
			_try_use_round4_special(source)
			budget -= 1

func _nearest_round4_special_target(source: WildDashCharacterController, radius: float) -> WildDashCharacterController:
	var best: WildDashCharacterController = null
	var best_distance := radius * radius
	for target: WildDashCharacterController in racers:
		if target == source or not _is_combatant_active(target):
			continue
		var distance := source.global_position.distance_squared_to(target.global_position)
		if distance < best_distance:
			best_distance = distance
			best = target
	return best

func _spawn_round4_cartoon_gas(source: WildDashCharacterController, special_id: StringName) -> void:
	var root := Node3D.new()
	root.name = "Round4Gas_%s_%d" % [String(special_id), Time.get_ticks_msec()]
	add_child(root)
	root.global_position = source.global_position + source.global_transform.basis.z * 0.85 + Vector3.UP * 0.65
	var gas_color := Color(0.57, 0.74, 0.28, 0.54) if special_id != &"heavy_gas" else Color(0.55, 0.58, 0.48, 0.50)
	for i in range(4):
		var puff := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.42 + float(i) * 0.08
		mesh.height = mesh.radius * 2.0
		mesh.radial_segments = 6
		mesh.rings = 3
		puff.mesh = mesh
		puff.position = Vector3((float(i % 2) - 0.5) * 0.52, float(i) * 0.17, float(i) * 0.31)
		var material := StandardMaterial3D.new()
		material.albedo_color = gas_color
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		puff.material_override = material
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(puff)
	var lifetime := 2.0 if special_id == &"stink_cloud" else 0.72
	_expire_round4_effect_node(root, lifetime)

func _expire_round4_effect_node(node: Node, seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
	if is_instance_valid(node):
		node.queue_free()
