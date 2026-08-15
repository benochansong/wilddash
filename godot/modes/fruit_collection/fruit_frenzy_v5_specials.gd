extends "res://modes/fruit_collection/fruit_frenzy_v4_vertical_species.gd"

## Round 2 V5: character party specials + Crocodile combat identity.
## Q / Gamepad B is intentionally mode-local here; Round 1 keeps Q for items.

const SPECIAL_AI_CHECK_SECONDS := 0.42
const CROCODILE_BITE_RANGE := 3.45
const CROCODILE_BITE_WATER_RANGE := 3.95
const CROCODILE_BITE_IMPULSE := 6.2
const CROCODILE_TAIL_RADIUS := 4.2
const CROCODILE_TAIL_IMPULSE := 3.4

var _special_cooldown_by_id: Dictionary = {}
var _special_slow_remaining_by_id: Dictionary = {}
var _special_slow_scale_by_id: Dictionary = {}
var _special_ai_elapsed := 0.0

func _ready() -> void:
	await super()
	if not InputManager.race_combat_action_resolved.is_connected(_on_round2_combat_gesture):
		InputManager.race_combat_action_resolved.connect(_on_round2_combat_gesture)
	print("FRUIT FRENZY V5 SPECIALS READY Q_mode_local=true boar=6.0 bear=7.0 raccoon=7.0 monkey=5.5 crocodile_bite=true tail_sweep=true")

func _exit_tree() -> void:
	if InputManager.race_combat_action_resolved.is_connected(_on_round2_combat_gesture):
		InputManager.race_combat_action_resolved.disconnect(_on_round2_combat_gesture)

func _register_racer_state(racer: WildDashCharacterController) -> void:
	super(racer)
	if racer == null:
		return
	var id := racer.get_instance_id()
	_special_cooldown_by_id[id] = 0.0
	_special_slow_remaining_by_id[id] = 0.0
	_special_slow_scale_by_id[id] = 1.0

func _update_runtime_cooldowns(delta: float) -> void:
	super(delta)
	for racer: WildDashCharacterController in racers:
		if racer == null:
			continue
		var id := racer.get_instance_id()
		_special_cooldown_by_id[id] = maxf(0.0, float(_special_cooldown_by_id.get(id, 0.0)) - delta)
		_special_slow_remaining_by_id[id] = maxf(0.0, float(_special_slow_remaining_by_id.get(id, 0.0)) - delta)
		if float(_special_slow_remaining_by_id[id]) <= 0.0:
			_special_slow_scale_by_id[id] = 1.0

func _physics_process(delta: float) -> void:
	super(delta)
	if mode_finished or not GameManager.round_active:
		return
	if InputManager.consume_item():
		_try_use_round2_special(player)
	_special_ai_elapsed += delta
	if _special_ai_elapsed >= SPECIAL_AI_CHECK_SECONDS:
		_special_ai_elapsed = 0.0
		_update_ai_specials()

func _update_speed_profiles() -> void:
	super()
	for racer: WildDashCharacterController in racers:
		if racer == null:
			continue
		var id := racer.get_instance_id()
		if float(_special_slow_remaining_by_id.get(id, 0.0)) > 0.0:
			racer.arena_move_speed *= float(_special_slow_scale_by_id.get(id, 1.0))
	for i in range(ai_racers.size()):
		if i >= ai_drivers.size():
			continue
		var racer := ai_racers[i]
		if racer == null:
			continue
		var id := racer.get_instance_id()
		if float(_special_slow_remaining_by_id.get(id, 0.0)) > 0.0:
			ai_drivers[i].target_speed *= float(_special_slow_scale_by_id.get(id, 1.0))

func _try_player_body_check() -> void:
	if player == null or player.animal_id != &"crocodile":
		super()
		return
	if _player_body_check_cooldown > 0.0 or _is_stunned(player):
		return
	var target := _find_crocodile_bite_target(player)
	if target == null:
		# Bite still gives a tiny forward lunge, so the character feels distinct
		# without granting free long-distance mobility.
		player.apply_knockback(-player.global_transform.basis.z, 1.15)
		hud.set_message("BITE LUNGE · NO TARGET")
		_player_body_check_cooldown = 0.62
		return
	var offset := target.global_position - player.global_position
	offset.y = 0.0
	var water_bonus := _is_river_position(player.global_position)
	var impulse := CROCODILE_BITE_IMPULSE * (1.10 if water_bonus else 1.0)
	target.apply_knockback(offset.normalized(), impulse)
	player.apply_knockback(-player.global_transform.basis.z, 1.65 if water_bonus else 1.35)
	_player_body_check_cooldown = PLAYER_BODY_CHECK_COOLDOWN
	_spill_racer(target, 2 if _get_carry(target) >= 2 else 1, "CROCODILE BITE LUNGE")
	spill_hit_cooldown_by_id[target.get_instance_id()] = COMBAT_SPILL_COOLDOWN
	_apply_power_stun(player, target)
	AudioManager.play_sfx_id("hit", 1.0)
	hud.set_message("BITE LUNGE! · %s%s" % [target.get_display_name().to_upper(), " · WATER +15%" if water_bonus else ""])
	print("CROCODILE BITE LUNGE mode=fruit_collection water=%s impulse=%.2f" % [str(water_bonus), impulse])

func _find_crocodile_bite_target(source: WildDashCharacterController) -> WildDashCharacterController:
	var range := CROCODILE_BITE_WATER_RANGE if _is_river_position(source.global_position) else CROCODILE_BITE_RANGE
	var forward := -source.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var best: WildDashCharacterController = null
	var best_distance := INF
	for candidate: WildDashCharacterController in racers:
		if candidate == null or candidate == source or candidate.finished:
			continue
		var offset := candidate.global_position - source.global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance <= 0.01 or distance > range:
			continue
		if forward.dot(offset.normalized()) < 0.28:
			continue
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best

func _on_round2_combat_gesture(action: Dictionary) -> void:
	if player == null or player.animal_id != &"crocodile" or mode_finished or not GameManager.round_active:
		return
	if StringName(action.get("kind", &"")) != &"hold":
		return
	_do_crocodile_tail_sweep()

func _do_crocodile_tail_sweep() -> void:
	var hit_count := 0
	for target: WildDashCharacterController in racers:
		if target == null or target == player or target.finished:
			continue
		var offset := target.global_position - player.global_position
		offset.y = 0.0
		if offset.length_squared() <= 0.01 or offset.length() > CROCODILE_TAIL_RADIUS:
			continue
		target.apply_knockback(offset.normalized(), CROCODILE_TAIL_IMPULSE)
		if _get_carry(target) > 0 and hit_count == 0:
			_spill_racer(target, 1, "CROCODILE TAIL SWEEP")
		hit_count += 1
	if hit_count > 0:
		AudioManager.play_sfx_id("hit", 0.86)
		hud.set_message("TAIL SWEEP! · TARGETS %d" % hit_count)
		print("CROCODILE TAIL SWEEP mode=fruit_collection targets=%d" % hit_count)

func _try_use_round2_special(racer: WildDashCharacterController) -> bool:
	if racer == null or not is_instance_valid(racer):
		return false
	if not WildDashAnimalSpecialAbilitySystem.can_use_special(racer.animal_id, &"fruit_collection"):
		if racer.is_player:
			hud.set_message("NO Q SPECIAL · %s USES NORMAL KIT" % racer.get_display_name().to_upper())
		return false
	var id := racer.get_instance_id()
	if float(_special_cooldown_by_id.get(id, 0.0)) > 0.0:
		if racer.is_player:
			hud.set_message("%s COOLDOWN %.1fs" % [WildDashAnimalSpecialAbilitySystem.get_special_name(racer.animal_id), float(_special_cooldown_by_id[id])])
		return false
	var spec := WildDashAnimalSpecialAbilitySystem.get_special(racer.animal_id)
	_special_cooldown_by_id[id] = float(spec.get("cooldown", 6.0))
	_spawn_cartoon_gas(racer, StringName(spec.get("id", &"special")))
	_apply_round2_special_effect(racer, spec)
	AudioManager.play_sfx_id("skill", 0.72)
	if racer.is_player:
		hud.set_message("%s! · Q SPECIAL" % str(spec.get("name", "SPECIAL")))
	print("ANIMAL SPECIAL animal=%s ability=%s mode=fruit_collection cooldown=%.1f" % [
		String(racer.animal_id), String(spec.get("id", &"")), float(spec.get("cooldown", 0.0)),
	])
	return true

func _apply_round2_special_effect(source: WildDashCharacterController, spec: Dictionary) -> void:
	var special_id := StringName(spec.get("id", &""))
	var radius := float(spec.get("radius", 4.0))
	var knockback := float(spec.get("knockback", 2.0))
	var slow := float(spec.get("slow", 1.0))
	var duration := float(spec.get("duration", 0.6))
	var rear := source.global_transform.basis.z
	rear.y = 0.0
	rear = rear.normalized()
	var spill_budget := 1

	for target: WildDashCharacterController in racers:
		if target == null or target == source or target.finished:
			continue
		var offset := target.global_position - source.global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance <= 0.01 or distance > radius:
			continue
		var direction := offset.normalized()
		if special_id in [&"mud_gas", &"jet_fart"] and rear.dot(direction) < 0.12:
			continue
		if knockback > 0.0:
			target.apply_knockback(direction, knockback * lerpf(1.0, 0.62, distance / radius))
		if slow < 0.999:
			var target_id := target.get_instance_id()
			_special_slow_remaining_by_id[target_id] = maxf(float(_special_slow_remaining_by_id.get(target_id, 0.0)), duration)
			_special_slow_scale_by_id[target_id] = minf(float(_special_slow_scale_by_id.get(target_id, 1.0)), slow)
		if spill_budget > 0 and _get_carry(target) > 0:
			_spill_racer(target, 1, "ANIMAL SPECIAL %s" % String(special_id).to_upper())
			spill_budget -= 1

	if special_id == &"jet_fart":
		source.apply_knockback(-source.global_transform.basis.z, float(spec.get("forward_impulse", 3.0)))

func _update_ai_specials() -> void:
	for racer: WildDashCharacterController in ai_racers:
		if racer == null or racer.finished:
			continue
		if not WildDashAnimalSpecialAbilitySystem.can_use_special(racer.animal_id, &"fruit_collection"):
			continue
		if float(_special_cooldown_by_id.get(racer.get_instance_id(), 0.0)) > 0.0:
			continue
		var spec := WildDashAnimalSpecialAbilitySystem.get_special(racer.animal_id)
		var radius := float(spec.get("radius", 4.0))
		var target := _nearest_special_target(racer, radius * 0.92)
		if target != null and (_get_carry(target) > 0 or _get_carry(racer) >= 3):
			_try_use_round2_special(racer)

func _nearest_special_target(source: WildDashCharacterController, radius: float) -> WildDashCharacterController:
	var best: WildDashCharacterController = null
	var best_distance := radius * radius
	for target: WildDashCharacterController in racers:
		if target == null or target == source or target.finished:
			continue
		var distance := source.global_position.distance_squared_to(target.global_position)
		if distance < best_distance:
			best_distance = distance
			best = target
	return best

func _spawn_cartoon_gas(source: WildDashCharacterController, special_id: StringName) -> void:
	var root := Node3D.new()
	root.name = "GasPuff_%s_%d" % [String(special_id), Time.get_ticks_msec()]
	add_child(root)
	root.global_position = source.global_position + source.global_transform.basis.z * 0.85 + Vector3.UP * 0.65
	var gas_color := Color(0.58, 0.72, 0.30, 0.52) if special_id != &"heavy_gas" else Color(0.55, 0.58, 0.48, 0.48)
	for i in range(4):
		var puff := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.42 + float(i) * 0.08
		mesh.height = mesh.radius * 2.0
		mesh.radial_segments = 6
		mesh.rings = 3
		puff.mesh = mesh
		puff.position = Vector3((float(i % 2) - 0.5) * 0.55, float(i) * 0.18, float(i) * 0.32)
		var material := StandardMaterial3D.new()
		material.albedo_color = gas_color
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		puff.material_override = material
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(puff)
	_expire_effect_node(root, 0.72)

func _expire_effect_node(node: Node, seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
	if is_instance_valid(node):
		node.queue_free()
