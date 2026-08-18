extends "res://scenes/character_select.gd"

## RC9 active-roster adapter. The base Character Select remains intact while the
## ninth basic slot swaps archived Panda for the new Crocodile Water Bruiser.
##
## P0 START FLOW GUARD:
## The active Character Select scene uses this adapter, not character_select.gd
## directly. Start is guarded here. The normal GameManager path gets first chance
## to transition. If the scene is still Character Select two frames later, the
## production Round 1 scene is checked and loaded explicitly. There is no visual
## fallback scene: production failure stays visible and retryable here.

const ROUND1_SCENE_PATH := "res://modes/grand_prix/grand_prix.tscn"

var _start_attempt_in_progress := false

func _ready() -> void:
	super()
	_replace_panda_button_with_crocodile()
	print("CHARACTER SELECT RC9 ROSTER active=12 panda_archived=true crocodile_playable=true")
	print("CHARACTER SELECT P0 START GUARD READY active_adapter=true round1_checked_load=true fallback=false")

func _start_run() -> void:
	if _start_attempt_in_progress:
		return
	_start_attempt_in_progress = true
	get_tree().paused = false

	if _start_button != null:
		_start_button.disabled = true
		_start_button.text = "STARTING ROUND 1..."
	_set_start_status("STARTING ROUND 1 · validating campaign transition...")

	var requested_ai: int = -1
	if OS.has_environment("WILDDASH_AI_COUNT"):
		requested_ai = int(OS.get_environment("WILDDASH_AI_COUNT"))

	if _chimera_mode:
		var saved := save_current_selection()
		if not saved:
			push_warning("CHARACTER SELECT P0 chimera save failed; continuing with in-memory loadout")
		GameManager.configure_run(_loadout.body_id, _difficulty, _loadout.to_dictionary(), requested_ai)
		print("CHARACTER SELECT P0 START stage=button mode=chimera head=%s body=%s tail=%s" % [
			_loadout.head_id,
			_loadout.body_id,
			_loadout.tail_id,
		])
	else:
		GameManager.disable_chimera()
		GameManager.configure_run(_selected_animal, _difficulty, {}, requested_ai)
		print("CHARACTER SELECT P0 START stage=button mode=animal animal=%s difficulty=%s" % [
			String(_selected_animal),
			String(_difficulty),
		])

	GameManager.start_campaign()
	call_deferred("_verify_start_transition")

func _verify_start_transition() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree():
		return
	if get_tree().current_scene != self:
		print("CHARACTER SELECT P0 START stage=normal_transition status=success")
		return

	push_warning("CHARACTER SELECT P0 START stage=verify status=still_on_character_select forcing_checked_round1_load=true")
	_set_start_status("ROUND 1 did not transition · validating production scene...")
	_force_checked_round1_load()

func _force_checked_round1_load() -> void:
	GameManager.campaign_running = true
	GameManager.current_round_index = 0
	GameManager.round_active = false

	if not ResourceLoader.exists(ROUND1_SCENE_PATH):
		_start_failed("Production Round 1 path is missing")
		return

	print("CHARACTER SELECT P0 START stage=resource_exists path=%s" % ROUND1_SCENE_PATH)
	var resource: Resource = ResourceLoader.load(ROUND1_SCENE_PATH)
	var packed := resource as PackedScene
	if packed == null:
		_start_failed("Production Round 1 PackedScene failed to load")
		return

	print("CHARACTER SELECT P0 START stage=packed_scene_loaded path=%s" % ROUND1_SCENE_PATH)
	var error: Error = get_tree().change_scene_to_packed(packed)
	if error == OK:
		print("CHARACTER SELECT P0 START stage=forced_transition status=success production=true")
		return

	_start_failed("Production Round 1 scene change failed: %s" % error_string(error))

func _start_failed(message: String) -> void:
	GameManager.campaign_running = false
	GameManager.current_round_index = -1
	GameManager.round_active = false
	_start_attempt_in_progress = false
	push_error("CHARACTER SELECT P0 START FAILED %s" % message)
	_set_start_status("START ERROR · %s · Output 창의 P0 START 로그를 확인하세요." % message)
	if _start_button != null:
		_start_button.disabled = false
		_start_button.text = "RETRY START"

func _set_start_status(message: String) -> void:
	if _summary_label == null:
		return
	_summary_label.text = message

func _replace_panda_button_with_crocodile() -> void:
	var panda_button: Button = _animal_buttons.get(&"panda", null) as Button
	if panda_button == null:
		return
	var grid := panda_button.get_parent() as GridContainer
	if grid == null:
		return
	var old_index := panda_button.get_index()
	_animal_buttons.erase(&"panda")
	grid.remove_child(panda_button)
	panda_button.queue_free()

	var definition := WildDashAnimalCatalog.get_definition(&"crocodile")
	if definition == null:
		return
	var button := Button.new()
	button.text = definition.display_name.to_upper()
	button.tooltip_text = "%s · %s · %s" % [
		definition.display_name,
		WildDashAnimalSelectionPresentation.get_identity(&"crocodile"),
		definition.skill_name,
	]
	button.custom_minimum_size = Vector2(170, 48)
	button.toggle_mode = true
	button.pressed.connect(select_animal.bind(&"crocodile"))
	grid.add_child(button)
	grid.move_child(button, old_index)
	_animal_buttons[&"crocodile"] = button
	_refresh_animal_button_states()
