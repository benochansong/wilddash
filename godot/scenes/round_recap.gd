extends Node3D

const RACER_SCENE: PackedScene = preload("res://characters/test_racer.tscn")
const RECAP_TOTAL_SECONDS: float = 9.0
const ROUND_COMPLETE_END: float = 1.2
const ROUND_RESULT_END: float = 3.5
const WILD_MOMENTS_END: float = 7.0
const SKIP_UNLOCK_SECONDS: float = 1.5
const OVERLAY_ALPHA: float = 0.68

var _elapsed: float = 0.0
var _finished: bool = false
var _phase: int = -1
var _wild_moment_slot: int = -1
var _entry: Dictionary = {}
var _round_points: int = 0
var _campaign_total: int = 0
var _previous_total: int = 0
var _summary_lines: Array[String] = []
var _highlights: Array[Dictionary] = []
var _preview_racer: WildDashCharacterController
var _background: ColorRect
var _accent_bar: ColorRect
var _eyebrow: Label
var _title: Label
var _hero: Label
var _details: Label
var _campaign_label: Label
var _next_label: Label
var _skip_label: Label

func _ready() -> void:
	GameManager.set_state(GameManager.GameState.ROUND_RECAP)
	_entry = ResultManager.get_latest_round_result()
	if _entry.is_empty():
		push_error("ROUND RECAP missing latest result; advancing safely")
		call_deferred("_finish_recap")
		return
	_round_points = ResultManager.get_round_points(_entry)
	_campaign_total = ResultManager.get_campaign_total_score()
	_previous_total = maxi(0, _campaign_total - _round_points)
	_summary_lines = ResultManager.get_round_summary_lines(_entry)
	_highlights = ResultManager.get_highlights_for_entry(_entry, 2)
	print("ROUND RECAP START round=%d mode=%s round_points=%d campaign_total=%d highlights=%d next=%s" % [
		GameManager.current_round_index + 1,
		String(_entry.get("mode_id", &"unknown")),
		_round_points,
		_campaign_total,
		_highlights.size(),
		String(GameManager.get_next_round_id()),
	])
	if DisplayServer.get_name() == "headless":
		call_deferred("_headless_finish")
		return
	RenderingServer.set_default_clear_color(Color(0.018, 0.025, 0.055))
	_build_preview_stage()
	_build_ui()
	_refresh_phase(true)
	var audio: Node = get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.call("play_sfx_id", "finish", 0.86)

func _process(delta: float) -> void:
	if _finished or DisplayServer.get_name() == "headless":
		return
	_elapsed += delta
	if _preview_racer != null:
		_preview_racer.rotation.y += delta * 0.42
	if _background != null:
		var pulse: float = 0.025 + sin(_elapsed * 1.45) * 0.008
		_background.color = Color(0.018 + pulse, 0.025 + pulse * 0.55, 0.055 + pulse * 1.3, OVERLAY_ALPHA)
	_refresh_phase(false)
	if _elapsed >= RECAP_TOTAL_SECONDS:
		_finish_recap()

func _unhandled_input(event: InputEvent) -> void:
	if _finished or _elapsed < SKIP_UNLOCK_SECONDS:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_SPACE or key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
		print("ROUND RECAP SKIP round=%d elapsed=%.2f" % [GameManager.current_round_index + 1, _elapsed])
		_finish_recap()

func _headless_finish() -> void:
	await get_tree().process_frame
	print("ROUND RECAP HEADLESS round=%d mode=%s total=%d next=%s immediate=true" % [
		GameManager.current_round_index + 1,
		String(_entry.get("mode_id", &"unknown")),
		_campaign_total,
		String(GameManager.get_next_round_id()),
	])
	_finish_recap()

func _finish_recap() -> void:
	if _finished:
		return
	_finished = true
	print("ROUND RECAP PLAY complete_round=%d duration=%.2f next=%s" % [
		GameManager.current_round_index + 1,
		_elapsed,
		String(GameManager.get_next_round_id()),
	])
	GameManager.advance_from_round_recap()

func _build_preview_stage() -> void:
	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-48.0, -34.0, 0.0)
	key_light.light_energy = 1.45
	key_light.shadow_enabled = true
	add_child(key_light)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-2.8, 4.4, 4.8)
	fill.light_energy = 3.2
	fill.omni_range = 13.0
	fill.light_color = _round_accent(StringName(_entry.get("mode_id", &"unknown")))
	add_child(fill)
	var floor := CSGCylinder3D.new()
	floor.radius = 3.6
	floor.height = 0.38
	floor.sides = 48
	floor.position = Vector3(-3.8, -0.2, 0.0)
	floor.use_collision = true
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.09, 0.13, 0.22)
	floor_material.metallic = 0.18
	floor_material.roughness = 0.58
	floor.material = floor_material
	add_child(floor)
	var camera := Camera3D.new()
	camera.position = Vector3(-3.8, 2.8, 7.2)
	camera.fov = 48.0
	camera.current = true
	add_child(camera)
	camera.look_at(Vector3(-3.8, 1.0, 0.0), Vector3.UP)
	_preview_racer = RACER_SCENE.instantiate() as WildDashCharacterController
	if _preview_racer == null:
		return
	_preview_racer.name = "RecapRacer"
	_preview_racer.is_player = false
	_preview_racer.movement_mode = WildDashCharacterController.MovementMode.ARENA
	_preview_racer.position = Vector3(-3.8, 0.1, 0.0)
	add_child(_preview_racer)
	if GameManager.chimera_enabled:
		_preview_racer.configure_chimera(GameManager.get_chimera_loadout())
	else:
		_preview_racer.configure_animal(GameManager.selected_animal)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_background = ColorRect.new()
	_background.color = Color(0.043, 0.039, 0.088, OVERLAY_ALPHA)
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_background)
	var left_shade := ColorRect.new()
	left_shade.color = Color(0.01, 0.018, 0.038, 0.18)
	left_shade.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	left_shade.offset_right = 555.0
	left_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(left_shade)
	_accent_bar = ColorRect.new()
	_accent_bar.color = _round_accent(StringName(_entry.get("mode_id", &"unknown")))
	_accent_bar.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_accent_bar.offset_left = -10.0
	_accent_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_accent_bar)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 56)
	margin.add_theme_constant_override("margin_right", 72)
	margin.add_theme_constant_override("margin_top", 46)
	margin.add_theme_constant_override("margin_bottom", 42)
	layer.add_child(margin)
	var layout := HBoxContainer.new()
	layout.add_theme_constant_override("separation", 36)
	margin.add_child(layout)
	var portrait_space := VBoxContainer.new()
	portrait_space.custom_minimum_size = Vector2(500, 0)
	portrait_space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(portrait_space)
	portrait_space.add_spacer(false)
	var racer_name := Label.new()
	var definition := WildDashAnimalCatalog.get_definition(GameManager.selected_animal)
	racer_name.text = "YOUR RACER · %s" % definition.display_name.to_upper()
	racer_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	racer_name.add_theme_font_size_override("font_size", 24)
	racer_name.add_theme_color_override("font_color", Color(0.88, 0.94, 1.0))
	portrait_space.add_child(racer_name)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(panel)
	var panel_margin := MarginContainer.new()
	panel_margin.add_theme_constant_override("margin_left", 42)
	panel_margin.add_theme_constant_override("margin_right", 42)
	panel_margin.add_theme_constant_override("margin_top", 34)
	panel_margin.add_theme_constant_override("margin_bottom", 30)
	panel.add_child(panel_margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel_margin.add_child(box)
	_eyebrow = Label.new()
	_eyebrow.add_theme_font_size_override("font_size", 18)
	_eyebrow.add_theme_color_override("font_color", _round_accent(StringName(_entry.get("mode_id", &"unknown"))))
	box.add_child(_eyebrow)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 38)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_title)
	_hero = Label.new()
	_hero.add_theme_font_size_override("font_size", 34)
	_hero.add_theme_color_override("font_color", Color(1.0, 0.84, 0.30))
	_hero.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_hero)
	box.add_child(HSeparator.new())
	_details = Label.new()
	_details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_details.add_theme_font_size_override("font_size", 20)
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_details)
	_campaign_label = Label.new()
	_campaign_label.add_theme_font_size_override("font_size", 22)
	_campaign_label.add_theme_color_override("font_color", Color(0.52, 0.92, 1.0))
	box.add_child(_campaign_label)
	_next_label = Label.new()
	_next_label.add_theme_font_size_override("font_size", 18)
	_next_label.add_theme_color_override("font_color", Color(0.78, 0.86, 0.96))
	_next_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_next_label)
	_skip_label = Label.new()
	_skip_label.text = "SPACE / ENTER  ·  SKIP AFTER %.1fs" % SKIP_UNLOCK_SECONDS
	_skip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_skip_label.add_theme_font_size_override("font_size", 14)
	_skip_label.add_theme_color_override("font_color", Color(0.58, 0.65, 0.76))
	box.add_child(_skip_label)

func _refresh_phase(force: bool) -> void:
	if _finished or _title == null:
		return
	var next_phase: int = 0
	if _elapsed >= WILD_MOMENTS_END:
		next_phase = 3
	elif _elapsed >= ROUND_RESULT_END:
		next_phase = 2
	elif _elapsed >= ROUND_COMPLETE_END:
		next_phase = 1
	if force or next_phase != _phase:
		_phase = next_phase
		_on_phase_changed()
	if _phase == 1:
		_update_score_countup()
	elif _phase == 2:
		_update_wild_moment_slot()
	elif _phase == 3:
		_update_next_round_countdown()
	if _skip_label != null:
		_skip_label.text = "SPACE / ENTER  ·  SKIP" if _elapsed >= SKIP_UNLOCK_SECONDS else "RECAP STARTING..."

func _on_phase_changed() -> void:
	var mode_id: StringName = StringName(_entry.get("mode_id", &"unknown"))
	var round_number: int = GameManager.current_round_index + 1
	match _phase:
		0:
			_eyebrow.text = "ROUND %d COMPLETE" % round_number
			_title.text = ResultManager.get_round_display_name(mode_id)
			_hero.text = "CLEAR!" if bool(_entry.get("success", false)) else "ROUND OVER"
			_details.text = "%s · %s" % [_player_display_name(), ResultManager.get_round_tagline(mode_id)]
			_campaign_label.text = "RESULT INCOMING"
			_next_label.text = ""
		1:
			_eyebrow.text = "ROUND %d RESULT" % round_number
			_title.text = ResultManager.get_round_display_name(mode_id)
			_hero.text = _primary_result_text()
			_details.text = "\n".join(_summary_with_top_three())
			_update_score_countup()
			_next_label.text = "PLAYER · %s" % _player_display_name()
		2:
			_wild_moment_slot = -1
			_title.text = "★ WILD MOMENTS ★"
			_update_wild_moment_slot()
		3:
			_eyebrow.text = "NEXT ROUND"
			_campaign_label.text = "CAMPAIGN TOTAL  %d PTS" % _campaign_total
			_update_next_round_countdown()

func _update_score_countup() -> void:
	var span: float = maxf(0.01, ROUND_RESULT_END - ROUND_COMPLETE_END)
	var t: float = clampf((_elapsed - ROUND_COMPLETE_END) / span, 0.0, 1.0)
	var shown_round: int = roundi(float(_round_points) * t)
	_campaign_label.text = "ROUND SCORE  +%d PTS     CAMPAIGN TOTAL  %d PTS" % [shown_round, _previous_total + shown_round]

func _update_wild_moment_slot() -> void:
	if _highlights.is_empty():
		if _wild_moment_slot == 0:
			return
		_wild_moment_slot = 0
		_eyebrow.text = "WILD MOMENT"
		_hero.text = "SOLID RUN!"
		_details.text = "ROUND COMPLETE · KEEP THE MOMENTUM GOING" if _summary_lines.is_empty() else "ROUND MOMENT\n%s" % _summary_lines[0]
		_campaign_label.text = "CAMPAIGN TOTAL  %d PTS" % _campaign_total
		_next_label.text = "NO MAJOR HIGHLIGHT · CLEAN ROUND"
		print("WILD RECAP PLAY type=solid_run importance=0 round=%d racer=%s slot=1" % [GameManager.current_round_index + 1, _player_display_name()])
		return

	var slot: int = 0
	if _highlights.size() > 1:
		var midpoint: float = (ROUND_RESULT_END + WILD_MOMENTS_END) * 0.5
		slot = 0 if _elapsed < midpoint else 1
	if slot == _wild_moment_slot:
		return
	_wild_moment_slot = slot
	_show_wild_moment(slot)

func _show_wild_moment(index: int) -> void:
	if index < 0 or index >= _highlights.size():
		return
	var moment: Dictionary = _highlights[index]
	var importance: int = int(moment.get("importance", ResultManager.HIGHLIGHT_NORMAL))
	var importance_name: String = _importance_name(importance)
	_eyebrow.text = "WILD MOMENT %d / %d · %s" % [index + 1, _highlights.size(), importance_name]
	_title.text = "★ WILD MOMENTS ★"
	_hero.text = String(moment.get("title", "WILD MOMENT!")).to_upper()
	_details.text = String(moment.get("description", "Great play!"))
	_campaign_label.text = "CAMPAIGN TOTAL  %d PTS" % _campaign_total
	_next_label.text = "REPLAY LITE BUFFER READY" if bool(moment.get("replay_ready", false)) else "HIGHLIGHT EVENT"
	var audio: Node = get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.call("play_sfx_id", "skill" if importance >= ResultManager.HIGHLIGHT_EPIC else "ui", 0.72)
	print("WILD RECAP PLAY type=%s importance=%d round=%d racer=%s slot=%d replay=%s" % [
		String(moment.get("type", &"wild_moment")), importance, GameManager.current_round_index + 1,
		String(moment.get("racer", _player_display_name())), index + 1, str(bool(moment.get("replay_ready", false))),
	])

func _importance_name(importance: int) -> String:
	if importance >= ResultManager.HIGHLIGHT_LEGENDARY:
		return "LEGENDARY"
	if importance >= ResultManager.HIGHLIGHT_EPIC:
		return "EPIC"
	if importance >= ResultManager.HIGHLIGHT_COOL:
		return "COOL"
	return "NORMAL"

func _update_next_round_countdown() -> void:
	var next_id: StringName = GameManager.get_next_round_id()
	if next_id == &"":
		_title.text = "CAMPAIGN RESULT"
		_hero.text = "FINISH!"
		_details.text = "FINAL RESULT INCOMING"
		_next_label.text = ""
		return
	_title.text = "ROUND %d · %s" % [GameManager.current_round_index + 2, ResultManager.get_round_display_name(next_id)]
	_hero.text = ResultManager.get_round_tagline(next_id)
	var remaining: float = maxf(0.0, RECAP_TOTAL_SECONDS - _elapsed)
	var count: int = clampi(int(ceil(remaining)), 1, 3)
	_details.text = "GET READY\n\n%d" % count
	_next_label.text = "Loading next round automatically"
	if _accent_bar != null:
		_accent_bar.color = _round_accent(next_id)

func _primary_result_text() -> String:
	var mode_id: StringName = StringName(_entry.get("mode_id", &"unknown"))
	var raw_score: int = int(_entry.get("score", 0))
	var details_value: Variant = _entry.get("details", {})
	var details: Dictionary = details_value as Dictionary if typeof(details_value) == TYPE_DICTIONARY else {}
	match mode_id:
		&"grand_prix", &"neon_harbor_race", &"tidal_clash", &"logspire_leap":
			if details.has("rank"):
				return "#%d / %d" % [int(details.get("rank", raw_score)), maxi(1, int(details.get("racers", GameManager.ai_count + 1)))]
		&"fruit_collection":
			return "%d PTS" % raw_score
		&"push_out":
			return "#%d / %d" % [int(details.get("placement", GameManager.ai_count + 1)), maxi(1, int(details.get("racers", GameManager.ai_count + 1)))]
	return "%d PTS" % raw_score

func _summary_with_top_three() -> Array[String]:
	var result: Array[String] = _summary_lines.duplicate()
	var details_value: Variant = _entry.get("details", {})
	var details: Dictionary = details_value as Dictionary if typeof(details_value) == TYPE_DICTIONARY else {}
	var top_value: Variant = details.get("top3", [])
	if top_value is Array and not (top_value as Array).is_empty():
		result.append("")
		result.append("TOP 3")
		var top: Array = top_value as Array
		for i: int in range(mini(3, top.size())):
			var candidate: Variant = top[i]
			if candidate is Dictionary:
				var row: Dictionary = candidate
				result.append("%d. %s" % [i + 1, String(row.get("name", "RACER")).to_upper()])
			else:
				result.append("%d. %s" % [i + 1, String(candidate).to_upper()])
	return result

func _player_display_name() -> String:
	if GameManager.chimera_enabled:
		return "CHIMERA"
	var definition := WildDashAnimalCatalog.get_definition(GameManager.selected_animal)
	return definition.display_name.to_upper()

func _round_accent(mode_id: StringName) -> Color:
	match mode_id:
		&"grand_prix": return Color(0.20, 0.86, 1.0)
		&"fruit_collection": return Color(1.0, 0.55, 0.18)
		&"logspire_leap": return Color(0.35, 0.94, 0.45)
		&"push_out": return Color(1.0, 0.24, 0.18)
		&"neon_harbor_race": return Color(0.86, 0.32, 1.0)
		_: return Color(0.45, 0.82, 1.0)
