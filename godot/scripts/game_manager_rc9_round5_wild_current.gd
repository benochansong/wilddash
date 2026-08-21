extends "res://scripts/game_manager.gd"

## RC9 Round 5 campaign-slot adapter.
## Keeps the proven five-round GameManager state machine while replacing only
## the final campaign slot. Legacy Neon Harbor remains available as source/free
## play content but is no longer loaded by the production campaign.

const WILD_CURRENT_ROUND_IDS: Array[StringName] = [
	&"grand_prix",
	&"fruit_collection",
	&"logspire_leap",
	&"push_out",
	&"wild_current",
]
const WILD_CURRENT_ROUND_SCENES: Array[String] = [
	"res://modes/grand_prix/grand_prix.tscn",
	"res://modes/fruit_collection/fruit_collection.tscn",
	"res://modes/logspire_leap/logspire_leap.tscn",
	"res://modes/push_out/push_out.tscn",
	"res://modes/wild_current/wild_current.tscn",
]
const CAMPAIGN_INTRO_SCENE := "res://scenes/campaign_intro.tscn"

var _campaign_intro_pending := false

func start_campaign() -> void:
	# Automated/headless gates must keep their deterministic direct path. Manual
	# campaign starts get one short sandbox montage before Round 1.
	if DisplayServer.get_name() == "headless" or OS.has_environment("WILDDASH_AUTOTEST") or OS.has_environment("WILDDASH_AUTOTEST_LOAD_ONLY") or OS.has_environment("WILDDASH_SKIP_CAMPAIGN_INTRO"):
		super.start_campaign()
		return
	if _campaign_intro_pending:
		print("CAMPAIGN INTRO START IGNORED already_pending=true")
		return
	if campaign_running and state != GameState.CHARACTER_SELECT:
		super.start_campaign()
		return
	_campaign_intro_pending = true
	round_active = false
	_transition_pending = false
	set_state(GameState.COUNTDOWN)
	print("CAMPAIGN INTRO REQUEST rounds=5 sandbox=true animal=%s" % String(selected_animal))
	var error := get_tree().change_scene_to_file(CAMPAIGN_INTRO_SCENE)
	if error != OK:
		_campaign_intro_pending = false
		set_state(GameState.CHARACTER_SELECT)
		push_warning("Campaign intro failed to load; starting Round 1 directly: %s" % error_string(error))
		super.start_campaign()

func continue_campaign_after_intro() -> void:
	# Returning to CHARACTER_SELECT state (without loading that scene) intentionally
	# lets the base manager recover a stale editor campaign if one existed before
	# the montage. In normal play campaign_running is false and this simply starts.
	_campaign_intro_pending = false
	set_state(GameState.CHARACTER_SELECT)
	print("CAMPAIGN INTRO CONTINUE animal=%s next=round1" % String(selected_animal))
	super.start_campaign()

func is_campaign_intro_pending() -> bool:
	return _campaign_intro_pending

func get_current_round_id() -> StringName:
	if current_round_index < 0 or current_round_index >= WILD_CURRENT_ROUND_IDS.size():
		return &""
	return WILD_CURRENT_ROUND_IDS[current_round_index]

func get_next_round_id() -> StringName:
	var next_index := current_round_index + 1
	if next_index < 0 or next_index >= WILD_CURRENT_ROUND_IDS.size():
		return &""
	return WILD_CURRENT_ROUND_IDS[next_index]

func begin_round(mode_id: StringName) -> void:
	if mode_id != &"wild_current":
		super(mode_id)
		return
	if current_round_index < 0 or current_round_index >= WILD_CURRENT_ROUND_IDS.size():
		# Direct/F6 Round 5 is allowed to run without mutating campaign state until
		# the finish gate is crossed.
		set_state(GameState.RACE)
		print("WILD CURRENT DIRECT ROUND 5 state=race campaign_mutation=false")
		return
	if get_current_round_id() != mode_id:
		push_warning("Round scene mismatch: expected %s, got %s" % [get_current_round_id(), mode_id])
	round_active = true
	round_activity_changed.emit(true)
	set_state(GameState.RACE)
	print("CAMPAIGN ROUND 5 WILD CURRENT swim_only=true")
	round_changed.emit(current_round_index, mode_id)

func _load_current_round() -> void:
	if current_round_index < 0 or current_round_index >= WILD_CURRENT_ROUND_SCENES.size():
		return
	var scene_path := WILD_CURRENT_ROUND_SCENES[current_round_index]
	var mode_id := WILD_CURRENT_ROUND_IDS[current_round_index]
	print("LOAD MODE index=%d id=%s ai=%d animal=%s" % [current_round_index + 1, mode_id, ai_count, String(selected_animal)])
	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK:
		campaign_running = false
		current_round_index = -1
		_transition_pending = false
		push_error("Failed to load round scene %s: %s" % [scene_path, error_string(error)])

func _finish_campaign_to_result() -> void:
	_transition_pending = false
	campaign_running = false
	set_state(GameState.RESULT)
	print("r5_campaign_complete rounds=%d clears=%d final_round=wild_current" % [
		ResultManager.round_results.size(), ResultManager.get_success_count(),
	])
	var error := get_tree().change_scene_to_file("res://scenes/result.tscn")
	if error != OK:
		push_error("Failed to load result scene: %s" % error_string(error))
