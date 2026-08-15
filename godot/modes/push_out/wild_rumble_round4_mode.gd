extends "res://modes/push_out/wild_rumble_phase2_mode.gd"

## Round 4 production/direct-test entry point.
## Normal campaign flow arrives with current_round_index=3. Direct F6 may start
## from any editor/debug context, so this entry validates and repairs Round 4
## context before and after the inherited mode setup.
##
## RC9 elimination pass:
## Ring-outs are now permanent in Round 4. The field must visibly collapse from
## many racers to 3, then 2, then 1 survivor. Heavy-vs-light hits also receive a
## small extra outward launch so Power/Defense differences create real ring-outs.

const ROUND4_ID: StringName = &"push_out"
const ROUND4_RING_OUT_RADIUS := 19.12
const ROUND4_FINAL_RING_OUT_RADIUS := 19.02
const ROUND4_SUDDEN_DEATH_RADIUS := 18.92
const ROUND4_EDGE_PRESSURE_RADIUS := 14.0

var _direct_f6_bootstrap := false
var _runtime_recovered := false
var _round4_eliminated: Dictionary = {}
var _round4_obstacles_created := false
var _round4_sudden_death_announced := false

func _ready() -> void:
	_prepare_round4_context()
	await super()
	_ensure_round4_runtime_active()
	_create_round4_combat_obstacles()
	_route_round4_audio()
	print("WILD RUMBLE ROUND4 ENTRY READY direct_f6=%s recovered=%s round_index=%d active=%s state=%d paused=%s racers=%d ai=%d elimination=true obstacles=true" % [
		str(_direct_f6_bootstrap),
		str(_runtime_recovered),
		GameManager.current_round_index,
		str(GameManager.round_active),
		int(GameManager.state),
		str(get_tree().paused),
		racers.size(),
		ai_racers.size(),
	])

func _round4_index() -> int:
	return GameManager.ROUND_IDS.find(ROUND4_ID)

func _prepare_round4_context() -> void:
	var round4_index := _round4_index()
	if round4_index < 0:
		push_error("WILD RUMBLE: push_out missing from GameManager.ROUND_IDS")
		return

	var valid_context := (
		GameManager.current_round_index == round4_index
		and GameManager.get_current_round_id() == ROUND4_ID
	)
	if valid_context:
		return

	# This script is only attached to the Round 4 scene. If the editor launches
	# it directly, repair stale/missing campaign context before begin_mode().
	# Normal campaign entry already has the correct index and never enters here.
	if not GameManager.campaign_running or GameManager.current_round_index < 0:
		ResultManager.reset_campaign()
		GameManager.current_round_index = round4_index
		GameManager.campaign_running = true
		_direct_f6_bootstrap = true
		print("WILD RUMBLE F6 BOOTSTRAP round_index=%d mode=%s selected=%s" % [
			round4_index + 1,
			String(ROUND4_ID),
			String(GameManager.selected_animal),
		])

func _ensure_round4_runtime_active() -> void:
	var round4_index := _round4_index()
	if round4_index < 0:
		return

	# Never let an editor/current-scene launch remain frozen after the inherited
	# begin_mode(). Repair the context and invoke begin_round once more if needed.
	if not GameManager.round_active:
		GameManager.current_round_index = round4_index
		GameManager.campaign_running = true
		GameManager.begin_round(ROUND4_ID)
		_runtime_recovered = true
		print("WILD RUMBLE RUNTIME RECOVERY begin_round_retried=true")

	# Wild Rumble is an arena combat round; FINAL was legacy Push-Out state from
	# before Snowpeak became Round 5. Force the correct gameplay state locally as
	# an additional guard for older/stale editor state.
	if GameManager.state != GameManager.GameState.ARENA:
		GameManager.set_state(GameManager.GameState.ARENA)
		_runtime_recovered = true

	if get_tree().paused:
		get_tree().paused = false
		_runtime_recovered = true

	for driver: WildDashAIController in ai_drivers:
		if driver != null:
			driver.set_arena_enabled(true)

	if not GameManager.round_active:
		push_error("WILD RUMBLE ROUND4 START FAILURE: round_active remained false after recovery")
	elif player == null:
		push_error("WILD RUMBLE ROUND4 START FAILURE: player missing")
	elif racers.is_empty():
		push_error("WILD RUMBLE ROUND4 START FAILURE: racer field empty")
	else:
		print("WILD RUMBLE PLAYABILITY CHECK active=true arena_state=true player=%s racers=%d timer=%.1f" % [
			player.get_display_name(),
			racers.size(),
			time_remaining,
		])

func _create_round4_combat_obstacles() -> void:
	if _round4_obstacles_created:
		return
	_round4_obstacles_created = true

	# Angled stone blockers create lanes and ambush points without closing the
	# center. They use normal static collision so fighters can be pinned, circle
	# around them, or use them to escape a heavy pursuer.
	var barrier_a := create_box(
		"TitanBarrierA",
		Vector3(6.0, 0.55, 4.6),
		Vector3(4.0, 1.10, 1.30),
		Color(0.39, 0.32, 0.27),
		true
	)
	barrier_a.rotation_degrees.y = 32.0

	var barrier_b := create_box(
		"TitanBarrierB",
		Vector3(-6.0, 0.55, -4.6),
		Vector3(4.0, 1.10, 1.30),
		Color(0.39, 0.32, 0.27),
		true
	)
	barrier_b.rotation_degrees.y = 32.0

	var barrier_c := create_box(
		"TitanBarrierC",
		Vector3(-6.7, 0.50, 5.4),
		Vector3(3.4, 1.00, 1.20),
		Color(0.34, 0.29, 0.26),
		true
	)
	barrier_c.rotation_degrees.y = -28.0

	var barrier_d := create_box(
		"TitanBarrierD",
		Vector3(6.7, 0.50, -5.4),
		Vector3(3.4, 1.00, 1.20),
		Color(0.34, 0.29, 0.26),
		true
	)
	barrier_d.rotation_degrees.y = -28.0

	for i in range(2):
		var pillar := CSGCylinder3D.new()
		pillar.name = "TitanCombatPillar%d" % (i + 1)
		pillar.position = Vector3(-9.5 if i == 0 else 9.5, 0.85, 0.0)
		pillar.radius = 1.10
		pillar.height = 1.70
		pillar.sides = 8
		pillar.use_collision = true
		pillar.material = _material(Color(0.31, 0.27, 0.25), 0.94)
		add_child(pillar)

	print("WILD RUMBLE ROUND4 OBSTACLES READY barriers=4 pillars=2")

func _record_phase2_hit_credit(source: WildDashCharacterController, target: WildDashCharacterController) -> void:
	if source == null or target == null:
		return
	var target_id := target.get_instance_id()
	_last_attacker[target_id] = source
	_last_hit_age[target_id] = 0.0

	# Extra launch is intentionally layered on top of the existing combat core,
	# not a replacement for Power/Defense/Stagger. Strong animals now create a
	# visibly greater displacement, especially against light/low-defense targets
	# and opponents already fighting near the edge.
	var direction := target.global_position - source.global_position
	direction.y = 0.0
	if direction.length_squared() <= 0.001:
		return
	var source_power := WildDashRaceCombatProfile.get_attack_power(source.animal_id)
	var target_defense := WildDashRaceCombatProfile.get_defense(target.animal_id)
	var source_role := _phase2_role(source.animal_id)
	var target_role := _phase2_role(target.animal_id)
	var bonus := maxf(0.0, source_power - target_defense) * 0.62
	if source_role == &"heavy":
		bonus += 2.65
	elif source_role == &"mid":
		bonus += 0.90
	elif source_role == &"duelist":
		bonus += 0.55
	if target_role == &"light":
		bonus += 1.15
	var target_radius := Vector2(target.global_position.x, target.global_position.z).length()
	if target_radius >= ROUND4_EDGE_PRESSURE_RADIUS:
		bonus += lerpf(0.8, 2.8, clampf((target_radius - ROUND4_EDGE_PRESSURE_RADIUS) / 5.0, 0.0, 1.0))
	if bonus > 0.10:
		target.apply_knockback(direction.normalized(), bonus)

func _check_ring_outs() -> void:
	var alive := _round4_alive_count()
	var ring_out_radius := ROUND4_RING_OUT_RADIUS
	if alive <= 3:
		ring_out_radius = ROUND4_FINAL_RING_OUT_RADIUS
	if time_remaining <= 0.0:
		ring_out_radius = ROUND4_SUDDEN_DEATH_RADIUS

	for racer in racers:
		if not _is_combatant_active(racer):
			continue
		var planar_radius := Vector2(racer.global_position.x, racer.global_position.z).length()
		if planar_radius > ring_out_radius or racer.global_position.y < -2.6:
			_ring_out(racer)

func _ring_out(victim: WildDashCharacterController) -> void:
	if victim == null or mode_finished or not _is_combatant_active(victim):
		return
	var victim_id := victim.get_instance_id()
	var attacker: WildDashCharacterController = _last_attacker.get(victim_id, null) as WildDashCharacterController
	var credited := attacker != null and is_instance_valid(attacker) and attacker != victim
	credited = credited and float(_last_hit_age.get(victim_id, ATTACK_CREDIT_WINDOW + 1.0)) <= ATTACK_CREDIT_WINDOW
	if credited:
		var attacker_id := attacker.get_instance_id()
		_scores[attacker_id] = int(_scores.get(attacker_id, 0)) + RING_OUT_SCORE
		_ko_counts[attacker_id] = int(_ko_counts.get(attacker_id, 0)) + 1

	_round4_eliminated[victim_id] = true
	_last_attacker.erase(victim_id)
	_last_hit_age[victim_id] = ATTACK_CREDIT_WINDOW + 1.0
	_set_combatant_active(victim, false)

	var alive := _round4_alive_count()
	if victim == player:
		hud.set_message("ELIMINATED! · %d ANIMALS LEFT" % alive)
		print("WILD RUMBLE ELIMINATION player_out=true alive=%d attacker=%s" % [
			alive,
			attacker.get_display_name() if credited else "none",
		])
		finish_mode(false, _score_for(player), {
			"dominance": _score_for(player),
			"kos": _kos_for(player),
			"alive": alive,
			"eliminated": true,
			"last_survivor_mode": true,
		})
		return

	if credited and attacker == player:
		hud.set_message("RING OUT! +%d · %d LEFT" % [RING_OUT_SCORE, alive])
	else:
		hud.set_message("%s ELIMINATED · %d LEFT" % [victim.get_display_name().to_upper(), alive])

	print("WILD RUMBLE ELIMINATION victim=%s attacker=%s credited=%s alive=%d permanent=true" % [
		victim.get_display_name(),
		attacker.get_display_name() if credited else "none",
		str(credited),
		alive,
	])

	if alive <= 1:
		_finish_last_survivor()

func _is_combatant_active(racer: WildDashCharacterController) -> bool:
	if racer == null or not is_instance_valid(racer):
		return false
	var id := racer.get_instance_id()
	if _round4_eliminated.has(id):
		return false
	return not _respawn_remaining.has(id)

func _round4_alive_count() -> int:
	var count := 0
	for racer in racers:
		if _is_combatant_active(racer):
			count += 1
	return count

func _finish_last_survivor() -> void:
	if mode_finished or player == null:
		return
	var player_alive := _is_combatant_active(player)
	var survivor_name := "NONE"
	for racer in racers:
		if _is_combatant_active(racer):
			survivor_name = racer.get_display_name()
			break
	print("WILD RUMBLE LAST SURVIVOR winner=%s player_alive=%s player_score=%d player_kos=%d" % [
		survivor_name,
		str(player_alive),
		_score_for(player),
		_kos_for(player),
	])
	finish_mode(player_alive, _score_for(player) + (10 if player_alive else 0), {
		"dominance": _score_for(player),
		"kos": _kos_for(player),
		"alive": _round4_alive_count(),
		"winner": survivor_name,
		"last_survivor_mode": true,
		"elimination": true,
	})

func _update_hud() -> void:
	_ensure_phase2_core()
	if player == null or hud == null or not _phase2_initialized:
		return
	var profile := _combat_core.get_profile(player)
	var stagger := _combat_core.get_stagger(player)
	var attack_cd := _combat_core.get_attack_cooldown_remaining(player)
	var stun := _combat_core.get_stun_remaining(player)
	hud.set_metrics("TIME %.0f   ALIVE %d/%d   DOM %d   KOs %d   STAGGER %.0f/100   PWR %.1f DEF %.1f%s" % [
		time_remaining,
		_round4_alive_count(),
		racers.size(),
		_score_for(player),
		_kos_for(player),
		stagger,
		float(profile.get("attack_power", 0.0)),
		float(profile.get("defense", 0.0)),
		"   BREAK %.1fs" % stun if stun > 0.0 else ("   ATK CD %.1f" % attack_cd if attack_cd > 0.05 else "   READY"),
	])

func _finish_score_battle() -> void:
	if mode_finished or player == null:
		return
	var alive := _round4_alive_count()
	if alive <= 1:
		_finish_last_survivor()
		return

	# No score-based escape at 0 seconds. Round 4 becomes sudden death and keeps
	# running until the field really reaches one survivor.
	if not _round4_sudden_death_announced:
		_round4_sudden_death_announced = true
		hud.set_message("SUDDEN DEATH · LAST ANIMAL WINS!")
		print("WILD RUMBLE SUDDEN DEATH alive=%d radius=%.2f" % [alive, ROUND4_SUDDEN_DEATH_RADIUS])

func _route_round4_audio() -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio == null:
		return
	# ARENA state routes arena_push_out through GameManager. Repeat explicitly for
	# direct F6 so stale editor music can never survive the Round 4 bootstrap.
	audio.call("play_theme", "arena_push_out")
