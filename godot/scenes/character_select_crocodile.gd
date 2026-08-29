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
const LOCALIZATION = preload("res://ui/character_select_localization.gd")
const LOCALIZED_STATS_PANEL_SCRIPT = preload("res://ui/animal_stats_panel_localized.gd")
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
	_replace_stats_panel_with_localized()
	_localize_static_ui()
	_refresh_preview()
	print("CHARACTER SELECT LOCALIZATION READY locales=en,ko,es active=%s" % String(LOCALIZATION.active_language()))
	print("CHARACTER SELECT RC9 ROSTER active=12 panda_archived=true crocodile_playable=true")
	print("CHARACTER SELECT P0 START GUARD READY active_adapter=true deep_cache_retry=true dependency_probe=true fallback=false")

func _refresh_preview() -> void:
	super()
	_localize_dynamic_ui()

func _start_run() -> void:
	if _start_attempt_in_progress:
		return
	_start_attempt_in_progress = true
	get_tree().paused = false

	if _start_button != null:
		_start_button.disabled = true
		_start_button.text = LOCALIZATION.text("starting_round1", "STARTING ROUND 1...")
	_set_start_status(LOCALIZATION.text("validating_transition", "STARTING ROUND 1 · validating campaign transition..."))

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
	# The canonical GameManager transition is also deferred. If it wins the race,
	# this Character Select node can already be detached before this verifier runs.
	# Never dereference get_tree() until we know the node is still attached.
	if not is_inside_tree():
		print("CHARACTER SELECT P0 START stage=verify status=detached_before_wait transition_assumed_success=true")
		return
	var tree: SceneTree = get_tree()
	if tree == null:
		print("CHARACTER SELECT P0 START stage=verify status=no_tree_before_wait transition_assumed_success=true")
		return

	await tree.process_frame
	if not is_inside_tree():
		print("CHARACTER SELECT P0 START stage=normal_transition status=success detached_after_first_frame=true")
		return

	await tree.process_frame
	if not is_inside_tree():
		print("CHARACTER SELECT P0 START stage=normal_transition status=success detached_after_second_frame=true")
		return
	if tree.current_scene != self:
		print("CHARACTER SELECT P0 START stage=normal_transition status=success")
		return

	push_warning("CHARACTER SELECT P0 START stage=verify status=still_on_character_select deep_cache_retry=true")
	_set_start_status(LOCALIZATION.text("retrying_round1", "ROUND 1 did not transition · retrying with fresh resources..."))
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
		_set_start_status(LOCALIZATION.text("checking_dependencies", "ROUND 1 load failed · checking production dependencies..."))
		var dependency_failure: String = _probe_round1_dependencies()
		if dependency_failure.is_empty():
			_start_failed("Round 1 fresh load failed; dependencies compile individually. Check first red scene error in Output")
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
	print("CHARACTER SELECT P0 START stage=dependency_probe count=%d compile_check=true" % ROUND1_CRITICAL_DEPENDENCIES.size())
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
		if dependency is Script:
			var script := dependency as Script
			if script == null or not script.can_instantiate():
				push_error("CHARACTER SELECT P0 SCRIPT PARSE FAILED path=%s can_instantiate=false" % dependency_path)
				return "R1 parser failed: %s" % dependency_path
		elif dependency is PackedScene:
			var scene := dependency as PackedScene
			if scene == null or not scene.can_instantiate():
				push_error("CHARACTER SELECT P0 PACKED SCENE INVALID path=%s can_instantiate=false" % dependency_path)
				return "R1 scene invalid: %s" % dependency_path
		print("CHARACTER SELECT P0 DEPENDENCY OK path=%s compile=true" % dependency_path)
	print("CHARACTER SELECT P0 START stage=dependency_probe status=all_critical_dependencies_compile")
	return ""

func _start_failed(message: String) -> void:
	GameManager.campaign_running = false
	GameManager.current_round_index = -1
	GameManager.round_active = false
	_start_attempt_in_progress = false
	push_error("CHARACTER SELECT P0 START FAILED %s" % message)
	_set_start_status(LOCALIZATION.text("start_error", "START ERROR · %s") % message)
	if _start_button != null:
		_start_button.disabled = false
		_start_button.text = LOCALIZATION.text("retry_start", "RETRY START")

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
	button.text = LOCALIZATION.animal_name(&"crocodile", definition.display_name).to_upper()
	button.tooltip_text = "%s · %s · %s" % [
		LOCALIZATION.animal_name(&"crocodile", definition.display_name),
		LOCALIZATION.identity(&"crocodile", WildDashAnimalSelectionPresentation.get_identity(&"crocodile")),
		LOCALIZATION.skill_name(&"crocodile", definition.skill_name),
	]
	button.custom_minimum_size = Vector2(170, 48)
	button.toggle_mode = true
	button.pressed.connect(select_animal.bind(&"crocodile"))
	grid.add_child(button)
	grid.move_child(button, old_index)
	_animal_buttons[&"crocodile"] = button
	_refresh_animal_button_states()

func _replace_stats_panel_with_localized() -> void:
	if _stats_panel == null:
		return
	var panel_parent := _stats_panel.get_parent()
	if panel_parent == null:
		return
	var old_index := _stats_panel.get_index()
	panel_parent.remove_child(_stats_panel)
	_stats_panel.queue_free()

	var localized_panel := LOCALIZED_STATS_PANEL_SCRIPT.new() as WildDashAnimalStatsPanel
	if localized_panel == null:
		push_error("CHARACTER SELECT LOCALIZATION failed to instantiate localized stats panel")
		return
	localized_panel.name = "AnimalStatsPanel"
	localized_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	localized_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel_parent.add_child(localized_panel)
	panel_parent.move_child(localized_panel, old_index)
	_stats_panel = localized_panel

func _localize_static_ui() -> void:
	for node: Node in find_children("*", "Label", true, false):
		var label := node as Label
		if label == null:
			continue
		match label.text:
			"WILD DASH — CHOOSE YOUR RACER":
				label.text = LOCALIZATION.text("title")
			"12 UNIQUE RACERS · 6개 실제 능력치·체급·스킬을 비교하고 선택하세요.":
				label.text = LOCALIZATION.text("subtitle")
			"CHIMERA CORE PARTS · DOG / RABBIT / ELEPHANT / CAT":
				label.text = LOCALIZATION.text("chimera_parts")
			"HEAD · Active Skill":
				label.text = LOCALIZATION.text("head_caption")
			"BODY · Passive Trait":
				label.text = LOCALIZATION.text("body_caption")
			"TAIL · Utility Bonus":
				label.text = LOCALIZATION.text("tail_caption")
			"동물 선택 → 오른쪽 6능력치 비교 · H/B/T: Chimera · Enter: Start":
				label.text = LOCALIZATION.text("hints")

	for node: Node in find_children("*", "Button", true, false):
		var button := node as Button
		if button == null:
			continue
		match button.text:
			"12 RACERS":
				button.text = LOCALIZATION.text("basic_mode")
			"CHIMERA LAB · CORE 4":
				button.text = LOCALIZATION.text("chimera_mode")
			"COLOR ▶":
				button.text = LOCALIZATION.text("color")
			"PATTERN ▶":
				button.text = LOCALIZATION.text("pattern")

	for node: Node in find_children("*", "OptionButton", true, false):
		var option := node as OptionButton
		if option == null or option.item_count != 3:
			continue
		option.set_item_text(0, LOCALIZATION.text("difficulty_wild"))
		option.set_item_text(1, LOCALIZATION.text("difficulty_chaos"))
		option.set_item_text(2, LOCALIZATION.text("difficulty_nightmare"))

	_localize_animal_buttons()

func _localize_dynamic_ui() -> void:
	if _loadout == null:
		return

	if _chimera_mode:
		_loadout.normalize()
		var head_definition := WildDashAnimalCatalog.get_definition(_loadout.head_id)
		var head_skill_fallback := ""
		if head_definition != null:
			head_skill_fallback = head_definition.skill_name
		var head_name := LOCALIZATION.animal_name(_loadout.head_id, String(_loadout.head_id).capitalize())
		var body_name := LOCALIZATION.animal_name(_loadout.body_id, String(_loadout.body_id).capitalize())
		var tail_name := LOCALIZATION.animal_name(_loadout.tail_id, String(_loadout.tail_id).capitalize())
		var head_skill := LOCALIZATION.skill_name(_loadout.head_id, head_skill_fallback)
		_mode_label.text = LOCALIZATION.text("mode_chimera")
		_summary_label.text = LOCALIZATION.text("summary_chimera") % [
			head_name,
			head_skill,
			body_name,
			tail_name,
			String(_loadout.palette_id).capitalize(),
			String(_loadout.pattern_id).capitalize(),
		]
		_slot_labels[&"head"].text = head_name.to_upper()
		_slot_labels[&"body"].text = body_name.to_upper()
		_slot_labels[&"tail"].text = tail_name.to_upper()
		_start_button.text = LOCALIZATION.text("save_build_start")
	else:
		var definition := WildDashAnimalCatalog.get_definition(_selected_animal)
		if definition == null:
			return
		var localized_name := LOCALIZATION.animal_name(_selected_animal, definition.display_name)
		var localized_identity := LOCALIZATION.identity(_selected_animal, WildDashAnimalSelectionPresentation.get_identity(_selected_animal))
		var localized_skill := LOCALIZATION.skill_name(_selected_animal, definition.skill_name)
		var localized_description := LOCALIZATION.skill_description(_selected_animal, definition.skill_description)
		_mode_label.text = LOCALIZATION.text("mode_animal", "MODE: %s · %s") % [localized_name.to_upper(), localized_identity]
		_summary_label.text = "%s %.1f · %s %.1f · %s %.2f · %s %.1f · %s %.1f\n%s: %s · %s %.1fs\n%s" % [
			LOCALIZATION.text("speed", "Speed"), definition.max_speed,
			LOCALIZATION.text("accel", "Accel"), definition.acceleration,
			LOCALIZATION.text("handling", "Handling"), definition.turn_speed,
			LOCALIZATION.text("jump", "Jump"), definition.jump_velocity,
			LOCALIZATION.text("arena", "Arena"), definition.arena_move_speed,
			LOCALIZATION.text("skill", "Skill"), localized_skill,
			LOCALIZATION.text("cooldown", "Cooldown"), definition.skill_cooldown,
			localized_description,
		]
		_start_button.text = LOCALIZATION.text("start_as", "START AS %s") % localized_name.to_upper()

	_localize_animal_buttons()

func _localize_animal_buttons() -> void:
	for raw_id: Variant in _animal_buttons.keys():
		var animal_id := StringName(raw_id)
		var button := _animal_buttons[raw_id] as Button
		var definition := WildDashAnimalCatalog.get_definition(animal_id)
		if button == null or definition == null:
			continue
		var localized_name := LOCALIZATION.animal_name(animal_id, definition.display_name)
		button.text = localized_name.to_upper()
		button.tooltip_text = "%s · %s · %s" % [
			localized_name,
			LOCALIZATION.identity(animal_id, WildDashAnimalSelectionPresentation.get_identity(animal_id)),
			LOCALIZATION.skill_name(animal_id, definition.skill_name),
		]
