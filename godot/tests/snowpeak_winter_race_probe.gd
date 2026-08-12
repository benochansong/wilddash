extends Node

const SNOWPEAK_SCENE: PackedScene = preload("res://modes/snowpeak_winter_rally/snowpeak_winter_rally.tscn")
const TIMEOUT_SECONDS := 120.0

var _target_racers := 15
var _elapsed := 0.0
var _reported := false
var _species_seen: Dictionary = {}

func _ready() -> void:
	_target_racers = clampi(
		int(OS.get_environment("WILDDASH_SNOWPEAK_RACERS")) if OS.has_environment("WILDDASH_SNOWPEAK_RACERS") else 15,
		15,
		18,
	)
	var difficulty: StringName = &"nightmare" if _target_racers >= 18 else &"chaos"
	GameManager.reset_run()
	GameManager.configure_run(&"dog", difficulty, {}, _target_racers - 1)
	GameManager.current_round_index = 4
	GameManager.campaign_running = true
	GameManager.chimera_enabled = false

	RaceManager.race_completed.connect(_on_race_completed)
	var mode := SNOWPEAK_SCENE.instantiate()
	if mode == null:
		_fail("Snowpeak race scene did not instantiate")
		return
	add_child(mode)
	await get_tree().physics_frame
	await get_tree().physics_frame
	for racer in RaceManager.racers:
		if racer is WildDashCharacterController:
			var controller := racer as WildDashCharacterController
			if not controller.is_player:
				_species_seen[controller.animal_id] = true
	if RaceManager.racers.size() != _target_racers:
		_fail("Expected %d racers, got %d" % [_target_racers, RaceManager.racers.size()])
		return
	if _species_seen.size() < 12:
		_fail("Expanded NPC roster diversity missing: species=%d" % _species_seen.size())
		return
	var surface_controller := mode.get_node_or_null("WinterSurfaceController") as WildDashWinterSurfaceController
	var feel_controller := mode.get_node_or_null("RacingFeelController") as WildDashRacingFeelController
	var snowfall_controller := mode.get_node_or_null("SnowfallController") as WildDashSnowfallController
	if surface_controller == null or feel_controller == null or snowfall_controller == null:
		_fail("Snowpeak feel/surface/snowfall controllers missing")
		return
	print("SNOWPEAK PROBE START racers=%d ai=%d species=%d checkpoints=%d length=%.1fm winter_systems=true" % [
		_target_racers, _target_racers - 1, _species_seen.size(), RaceManager.get_checkpoint_count(), RaceManager.get_track_length(),
	])

func _physics_process(delta: float) -> void:
	if _reported:
		return
	_elapsed += delta
	if _elapsed <= TIMEOUT_SECONDS:
		return
	_fail("Snowpeak race timeout %.1fs finishers=%d/%d" % [_elapsed, RaceManager.finish_order.size(), _target_racers])

func _on_race_completed() -> void:
	if _reported:
		return
	_reported = true
	var finishers := RaceManager.finish_order.size()
	if finishers != _target_racers:
		push_error("SNOWPEAK PROBE FAIL incomplete field finishers=%d/%d" % [finishers, _target_racers])
		get_tree().quit(2)
		return
	var checkpoint_count := RaceManager.get_checkpoint_count()
	if checkpoint_count != 10:
		push_error("SNOWPEAK PROBE FAIL checkpoint count=%d" % checkpoint_count)
		get_tree().quit(3)
		return
	print("SNOWPEAK ALL FINISH PASS racers=%d finishers=%d" % [_target_racers, finishers])
	print("SNOWPEAK NPC VARIETY PASS species=%d roster=12" % _species_seen.size())
	print("SNOWPEAK PROBE PASS racers=%d checkpoints=%d elapsed=%.2fs" % [_target_racers, checkpoint_count, RaceManager.get_elapsed_seconds()])
	get_tree().quit(0)

func _fail(message: String) -> void:
	if _reported:
		return
	_reported = true
	push_error("SNOWPEAK PROBE FAIL " + message)
	get_tree().quit(1)
