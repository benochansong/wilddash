extends Node

signal game_state_changed(previous_state: GameState, next_state: GameState)
signal round_changed(round_index: int, mode_id: StringName)
signal round_activity_changed(active: bool)

enum GameState {
	BOOT,
	LOBBY,
	CHARACTER_SELECT,
	COUNTDOWN,
	RACE,
	ROUND_BREAK,
	ARENA,
	FINAL,
	RESULT,
}

const ROUND_IDS: Array[StringName] = [
	&"grand_prix",
	&"fruit_collection",
	&"floor_collapse",
	&"push_out",
]
const ROUND_SCENES: Array[String] = [
	"res://modes/grand_prix/grand_prix.tscn",
	"res://modes/fruit_collection/fruit_collection.tscn",
	"res://modes/floor_collapse/floor_collapse.tscn",
	"res://modes/push_out/push_out.tscn",
]
const LOBBY_SCENE := "res://scenes/lobby.tscn"
const CHARACTER_SELECT_SCENE := "res://scenes/character_select.tscn"
const SETTINGS_SCENE := "res://scenes/settings.tscn"
const RESULT_SCENE := "res://scenes/result.tscn"

const CASUAL_AI_COUNT := 9
const NORMAL_AI_COUNT := 14
const HARD_AI_COUNT := 17
const MIN_AI_COUNT := CASUAL_AI_COUNT
const MAX_AI_COUNT := HARD_AI_COUNT
const DEFAULT_AI_COUNT := NORMAL_AI_COUNT

var state: GameState = GameState.BOOT
var selected_animal: StringName = &"dog"
var difficulty: StringName = &"chaos"
var chimera_enabled := false
var chimera_parts: Dictionary = WildDashChimeraSystem.default_loadout().to_dictionary()
var ai_count := DEFAULT_AI_COUNT
var current_round_index := -1
var round_active := false
var campaign_running := false
var _transition_pending := false

func _ready() -> void:
	selected_animal = SaveManager.get_last_character()
	set_state(GameState.LOBBY)

func set_state(next_state: GameState) -> void:
	if state == next_state:
		_update_audio_for_state(next_state)
		return
	var previous_state: GameState = state
	state = next_state
	game_state_changed.emit(previous_state, next_state)
	_update_audio_for_state(next_state)

func configure_run(
	animal: StringName,
	difficulty_id: StringName,
	parts: Dictionary,
	requested_ai_count: int = -1,
) -> void:
	selected_animal = animal if WildDashAnimalCatalog.is_valid(animal) else &"dog"
	difficulty = difficulty_id
	if not parts.is_empty():
		chimera_parts = WildDashChimeraLoadout.from_dictionary(parts).to_dictionary()
	var resolved_ai := get_recommended_ai_count(difficulty_id) if requested_ai_count < 0 else requested_ai_count
	ai_count = clampi(resolved_ai, MIN_AI_COUNT, MAX_AI_COUNT)
	SaveManager.set_last_character(selected_animal)
	print("RACER CONFIG difficulty=%s ai=%d total=%d" % [difficulty, ai_count, ai_count + 1])

func get_recommended_ai_count(difficulty_id: StringName) -> int:
	match difficulty_id:
		&"wild":
			return CASUAL_AI_COUNT
		&"nightmare":
			return HARD_AI_COUNT
		_:
			return NORMAL_AI_COUNT

func configure_chimera(parts: Dictionary, enabled := true) -> void:
	chimera_parts = WildDashChimeraLoadout.from_dictionary(parts).to_dictionary()
	chimera_enabled = enabled

func disable_chimera() -> void:
	chimera_enabled = false

func get_chimera_loadout() -> WildDashChimeraLoadout:
	return WildDashChimeraLoadout.from_dictionary(chimera_parts)

func set_ai_count(value: int) -> void:
	ai_count = clampi(value, MIN_AI_COUNT, MAX_AI_COUNT)

func show_character_select() -> void:
	set_state(GameState.CHARACTER_SELECT)
	print("RC_FLOW Character Select")
	var error := get_tree().change_scene_to_file(CHARACTER_SELECT_SCENE)
	if error != OK:
		push_error("Failed to load Character Select: %s" % error_string(error))
		return
	if DisplayServer.get_name() == "headless" and OS.has_environment("WILDDASH_AUTOTEST"):
		call_deferred("_autotest_start_character_select")

func show_settings() -> void:
	get_tree().change_scene_to_file(SETTINGS_SCENE)

func start_campaign() -> void:
	if campaign_running:
		return
	ResultManager.reset_campaign()
	campaign_running = true
	current_round_index = 0
	_transition_pending = false
	call_deferred("_load_current_round")

func begin_round(mode_id: StringName) -> void:
	if current_round_index < 0 or current_round_index >= ROUND_IDS.size():
		return
	if ROUND_IDS[current_round_index] != mode_id:
		push_warning("Round scene mismatch: expected %s, got %s" % [ROUND_IDS[current_round_index], mode_id])
	round_active = true
	round_activity_changed.emit(true)
	match mode_id:
		&"grand_prix":
			set_state(GameState.RACE)
			print("RC_FLOW Race")
		&"fruit_collection":
			set_state(GameState.ARENA)
			print("RC_FLOW Round 2")
		&"floor_collapse":
			set_state(GameState.ARENA)
			print("RC_FLOW Round 3")
		&"push_out":
			set_state(GameState.FINAL)
			print("RC_FLOW Final")
		_:
			set_state(GameState.ARENA)
	round_changed.emit(current_round_index, mode_id)

func complete_round(mode_id: StringName, success: bool, score: int, details: Dictionary = {}) -> void:
	if _transition_pending:
		return
	_transition_pending = true
	round_active = false
	round_activity_changed.emit(false)
	ResultManager.record_round_result(mode_id, success, score, details)
	print("MODE COMPLETE id=%s success=%s score=%d" % [mode_id, str(success), score])
	call_deferred("_transition_after_round")

func get_current_round_id() -> StringName:
	if current_round_index < 0 or current_round_index >= ROUND_IDS.size():
		return &""
	return ROUND_IDS[current_round_index]

func is_gameplay_state() -> bool:
	return state in [GameState.COUNTDOWN, GameState.RACE, GameState.ROUND_BREAK, GameState.ARENA, GameState.FINAL]

func return_to_lobby() -> void:
	campaign_running = false
	current_round_index = -1
	_transition_pending = false
	round_active = false
	get_tree().paused = false
	ResultManager.reset_campaign()
	set_state(GameState.LOBBY)
	get_tree().change_scene_to_file(LOBBY_SCENE)

func abort_to_lobby() -> void:
	RaceManager.active = false
	RaceManager.clear_racers()
	RaceManager.clear_track()
	return_to_lobby()

func reset_run() -> void:
	campaign_running = false
	current_round_index = -1
	_transition_pending = false
	round_active = false
	ResultManager.reset_campaign()
	set_state(GameState.LOBBY)

func _load_current_round() -> void:
	if current_round_index < 0 or current_round_index >= ROUND_SCENES.size():
		return
	var scene_path: String = ROUND_SCENES[current_round_index]
	var mode_id: StringName = ROUND_IDS[current_round_index]
	print("LOAD MODE index=%d id=%s ai=%d" % [current_round_index + 1, mode_id, ai_count])
	var error: Error = get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("Failed to load round scene %s: %s" % [scene_path, error_string(error)])

func _transition_after_round() -> void:
	var delay := 0.05 if DisplayServer.get_name() == "headless" else 1.2
	await get_tree().create_timer(delay).timeout
	_transition_pending = false
	if current_round_index + 1 < ROUND_SCENES.size():
		current_round_index += 1
		set_state(GameState.ROUND_BREAK)
		_load_current_round()
		return
	campaign_running = false
	set_state(GameState.RESULT)
	print("CAMPAIGN COMPLETE rounds=%d clears=%d" % [ResultManager.round_results.size(), ResultManager.get_success_count()])
	var error: Error = get_tree().change_scene_to_file(RESULT_SCENE)
	if error != OK:
		push_error("Failed to load result scene: %s" % error_string(error))

func _autotest_start_character_select() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var scene := get_tree().current_scene
	if scene == null or not scene.has_method("_start_run"):
		push_error("RC3 autotest could not start Character Select")
		get_tree().quit(3)
		return
	scene.call("_start_run")

func _update_audio_for_state(next_state: GameState) -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio == null:
		return
	match next_state:
		GameState.LOBBY, GameState.CHARACTER_SELECT:
			audio.call("play_theme", "menu")
		GameState.RACE, GameState.COUNTDOWN:
			audio.call("play_theme", "race")
		GameState.ARENA, GameState.FINAL, GameState.ROUND_BREAK:
			audio.call("play_theme", "arena")
		GameState.RESULT:
			audio.call("play_theme", "result")
		_:
			pass
