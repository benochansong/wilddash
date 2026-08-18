extends "res://scenes/character_select.gd"

## RC9 active-roster adapter. The base Character Select remains intact while the
## ninth basic slot swaps archived Panda for the new Crocodile Water Bruiser.
##
## P0 START FLOW GUARD:
## The canonical GameManager transition always gets first chance. If it fails,
## production Round 1 is reloaded with CACHE_MODE_IGNORE_DEEP so stale editor
## resource-cache entries cannot keep a previously broken dependency alive.
## If the fresh load still fails, the critical Round 1 dependency chain is probed
## one resource at a time and the first failing path is shown in Character Select.
## There is intentionally no stripped gameplay fallback scene.

const ROUND1_SCENE_PATH := "res://modes/grand_prix/grand_prix.tscn"
const ROUND1_CRITICAL_DEPENDENCIES := [
	"res://modes/grand_prix/grand_prix_v7_wild_moments.gd",
	"res://modes/grand_prix/grand_prix_v6_item_fairness.gd",
	"res://modes/grand_prix/grand_prix_mode.gd",
	"res://modes/mode_base.gd",
	"res://characters/test_racer.tscn",
	"res://characters/character_controller.gd",
	"res://ui/mode_hud.gd",
	"res://tracks/grand_prix_track.tscn",
	"res://tracks/grand_prix_v2_track_runtime_safe.gd",
	"res://items/item_box.tscn",
	"res://items/item_box.gd",
	"res://camera/chase_camera.gd",
	"res://items/ai_item_brain.gd",
	"res://characters/ai_pack_tactics.gd",
	"res://systems/racing_feel_controller.gd",
	"res://items/item_combat_expansion_v3_long_bomb.gd",
	"res://tracks/grand_prix_v2_course_guidance.gd",
	"res://modes/grand_prix/grand_prix_rival_pressure.gd",
	"res://network/network_race_sync.gd",
	"res://systems/racing_action_controller.gd",
	"res://systems/elephant_trunk_lunge_controller.gd",
	"res://systems/race_combat_core_v3_power.gd",
	"res://systems/bear_combat_v2_controller.gd",
	"res://systems/terrain_movement_controller.gd",
	"res://tracks/grand_prix_v2_terrain_gameplay.gd",
	"res://tracks/grand_prix_v2_stage3_controller.gd",
	"res://tracks/grand_prix_v2_ai_terrain_strategy.gd",
	"res://tracks/grand_prix_v2_difficulty_controller.gd",
	"res://tracks/grand_prix_v2_terrain_shell.gd",
	"res://tracks/grand_prix_v2_grounding_world.gd",
	"res://tracks/grand_prix_v2_hard_reset_controller.gd",
	"res://tracks/grand_prix_v3_obstacle_recovery.gd",
	"res://modes/grand_prix/grand_prix_v3_combat_accessibility.gd",
	"res://tracks/grand_prix_v3_offroad_controller.gd",
	"res://tracks/grand_prix_v3_mountain_clearance.gd",
	"res://tracks/grand_prix_v3_world_foundation.gd",
	"res://tracks/grand_prix_v3_offroad_stop_guard.gd",
	"res://tracks/grand_prix_v3_water_reentry.gd",
	"res://tracks/grand_prix_v4_landscape_shell.gd",
	"res://tracks/grand_prix_v4_obstacle_expansion.gd",
	"res://modes/grand_prix/grand_prix_v4_combat_frequency.gd",
	"res://tracks/grand_prix_v4_environment_dressing.gd",
	"res://tracks/grand_prix_v4_direction_guidance.gd",
	"res://tracks/grand_prix_v4_route_signage.gd",
	"res://tracks/grand_prix_v5_road_corridor_clearance.gd",
	"res://systems/race_combat_ai_director_party_turbo.gd",
]

var _start_attempt_in_progress := false

func _ready() -> void:
	super()
	_replace_panda_button_with_crocodile()
	print("CHARACTER SELECT RC9 ROSTER active=12 panda_archived=true crocodile_playable=true")
	print("CHARACTER SELECT P0 START GUARD READY active_adapter=true deep_cache_retry=true dependency_probe=true fallback=false")

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

	push_warning("CHARACTER SELECT P0 START stage=verify status=still_on_character_select deep_cache_retry=true")
	_set_start_status("ROUND 1 did not transition · retrying with fresh resources...")
	_force_checked_round1_load()

func _force_checked_round1_load() -> void:
	GameManager.campaign_running = true
	GameManager.current_round_index = 0
	GameManager.round_active = false

	if not ResourceLoader.exists(ROUND1_SCENE_PATH):
		_start_failed("Production Round 1 path is missing")
		return

	print("CHARACTER SELECT P0 START stage=resource_exists path=%s" % ROUND1_SCENE_PATH)
	print("CHARACTER SELECT P0 START stage=deep_cache_reload mode=IGNORE_DEEP")
	var resource: Resource = ResourceLoader.load(
		ROUND1_SCENE_PATH,
		"PackedScene",
		ResourceLoader.CACHE_MODE_IGNORE_DEEP
	)
	var packed := resource as PackedScene
	if packed == null:
		push_error("CHARACTER SELECT P0 production Round 1 fresh PackedScene load failed; probing dependencies")
		_set_start_status("ROUND 1 load failed · checking production dependencies...")
		var dependency_failure: String = _probe_round1_dependencies()
		if dependency_failure.is_empty():
			_start_failed("Round 1 fresh load failed; dependencies individually load. Check first red parser error in Output")
		else:
			_start_failed(dependency_failure)
		return

	print("CHARACTER SELECT P0 START stage=packed_scene_loaded cache=fresh path=%s" % ROUND1_SCENE_PATH)
	var error: Error = get_tree().change_scene_to_packed(packed)
	if error == OK:
		print("CHARACTER SELECT P0 START stage=forced_transition status=success production=true cache=fresh")
		return

	_start_failed("Production Round 1 scene change failed: %s" % error_string(error))

func _probe_round1_dependencies() -> String:
	print("CHARACTER SELECT P0 START stage=dependency_probe count=%d" % ROUND1_CRITICAL_DEPENDENCIES.size())
	for dependency_path: String in ROUND1_CRITICAL_DEPENDENCIES:
		if not ResourceLoader.exists(dependency_path):
			push_error("CHARACTER SELECT P0 DEPENDENCY MISSING path=%s" % dependency_path)
			return "Missing R1 dependency: %s" % dependency_path
		var type_hint: String = "Script" if dependency_path.ends_with(".gd") else "PackedScene"
		var dependency: Resource = ResourceLoader.load(
			dependency_path,
			type_hint,
			ResourceLoader.CACHE_MODE_IGNORE_DEEP
		)
		if dependency == null:
			push_error("CHARACTER SELECT P0 DEPENDENCY FAILED path=%s type=%s" % [dependency_path, type_hint])
			return "R1 dependency failed: %s" % dependency_path
		print("CHARACTER SELECT P0 DEPENDENCY OK path=%s" % dependency_path)
	print("CHARACTER SELECT P0 START stage=dependency_probe status=all_critical_dependencies_load")
	return ""

func _start_failed(message: String) -> void:
	GameManager.campaign_running = false
	GameManager.current_round_index = -1
	GameManager.round_active = false
	_start_attempt_in_progress = false
	push_error("CHARACTER SELECT P0 START FAILED %s" % message)
	_set_start_status("START ERROR · %s" % message)
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
