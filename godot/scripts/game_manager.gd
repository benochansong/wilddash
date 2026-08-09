extends Node

signal game_state_changed(previous_state: GameState, next_state: GameState)

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

var state: GameState = GameState.BOOT
var selected_animal: StringName = &"dog"
var difficulty: StringName = &"chaos"
var chimera_parts := {"head": 0, "body": 0, "tail": 0}

func _ready() -> void:
	set_state(GameState.LOBBY)

func set_state(next_state: GameState) -> void:
	if state == next_state:
		return
	var previous_state := state
	state = next_state
	game_state_changed.emit(previous_state, next_state)

func configure_run(animal: StringName, difficulty_id: StringName, parts: Dictionary) -> void:
	selected_animal = animal
	difficulty = difficulty_id
	chimera_parts = parts.duplicate(true)

func reset_run() -> void:
	set_state(GameState.LOBBY)
