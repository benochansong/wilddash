extends "res://modes/push_out/wild_rumble_phase2_mode.gd"

## Round 4 production/direct-test entry point.
## Normal campaign flow arrives with current_round_index=3. Direct F6 may start
## from any editor/debug context, so this entry validates and repairs Round 4
## context before and after the inherited mode setup. The post-ready fail-safe
## guarantees round_active, ARENA state, unpaused tree and enabled arena AI.

const ROUND4_ID: StringName = &"push_out"

var _direct_f6_bootstrap := false
var _runtime_recovered := false

func _ready() -> void:
	_prepare_round4_context()
	await super()
	_ensure_round4_runtime_active()
	_route_round4_audio()
	print("WILD RUMBLE ROUND4 ENTRY READY direct_f6=%s recovered=%s round_index=%d active=%s state=%d paused=%s racers=%d ai=%d" % [
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

func _route_round4_audio() -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio == null:
		return
	# ARENA state routes arena_push_out through GameManager. Repeat explicitly for
	# direct F6 so stale editor music can never survive the Round 4 bootstrap.
	audio.call("play_theme", "arena_push_out")
