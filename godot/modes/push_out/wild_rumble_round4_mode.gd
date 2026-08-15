extends "res://modes/push_out/wild_rumble_phase2_mode.gd"

## Round 4 production/direct-test entry point.
## Normal campaign flow already owns current_round_index=3. When this scene is
## launched directly with F6, bootstrap only the missing round context so the
## inherited begin_mode() can activate movement, AI, timer, combat and BGM.

const ROUND4_INDEX := 3
const ROUND4_ID: StringName = &"push_out"

var _direct_f6_bootstrap := false

func _ready() -> void:
	_bootstrap_direct_f6_context()
	await super._ready()
	_route_round4_audio()
	print("WILD RUMBLE ROUND4 ENTRY READY direct_f6=%s round_index=%d active=%s state=%d" % [
		str(_direct_f6_bootstrap),
		GameManager.current_round_index,
		str(GameManager.round_active),
		int(GameManager.state),
	])

func _bootstrap_direct_f6_context() -> void:
	var valid_campaign_context := (
		GameManager.current_round_index == ROUND4_INDEX
		and GameManager.get_current_round_id() == ROUND4_ID
	)
	if valid_campaign_context:
		return

	# F6/current-scene launches begin with current_round_index=-1. The old
	# GameManager.begin_round() intentionally returns early for that state, which
	# left every ARENA controller frozen and kept the previous/menu BGM playing.
	# Set only the missing Round 4 index; do not reset selected character,
	# difficulty, AI count, scores or normal campaign state.
	if GameManager.current_round_index < 0 and not GameManager.campaign_running:
		GameManager.current_round_index = ROUND4_INDEX
		_direct_f6_bootstrap = true
		print("WILD RUMBLE F6 BOOTSTRAP round_index=%d mode=%s selected=%s" % [
			ROUND4_INDEX,
			String(ROUND4_ID),
			String(GameManager.selected_animal),
		])

func _route_round4_audio() -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio == null:
		return
	# GameManager.begin_round(push_out) already routes this theme once the round
	# context is valid. Calling it here is idempotent and also documents/guards
	# the direct-F6 entry path explicitly.
	audio.call("play_theme", "arena_push_out")
