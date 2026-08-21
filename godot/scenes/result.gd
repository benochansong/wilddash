extends Control

const MAX_LEADERBOARD_ENTRIES := 100
const VISIBLE_LEADERBOARD_ENTRIES := 5

var _final_score := 0
var _clears := 0
var _name_input: LineEdit
var _register_button: Button
var _rank_label: Label
var _leaderboard_label: Label
var _status_label: Label
var _score_registered := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	GameManager.set_state(GameManager.GameState.RESULT)
	AudioManager.play_theme("result")
	var lines: Array[String] = ResultManager.get_summary_lines()
	_clears = ResultManager.get_success_count()
	_final_score = _calculate_campaign_score()
	var saved := SaveManager.record_campaign_result(ResultManager.round_results, GameManager.selected_animal)
	print("RC_FLOW Result")
	print("RC_SAVE result_saved=%s campaigns=%d" % [
		str(saved), int((SaveManager.current_data.get("profile", {}) as Dictionary).get("campaigns", 0)),
	])
	print("HEADLESS RESULT rounds=%d clears=%d final_score=%d" % [ResultManager.round_results.size(), _clears, _final_score])
	for line: String in lines:
		print("RESULT " + line)
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0)
		return
	_build_ui()

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = SettingsManager.get_background_color()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 110)
	margin.add_theme_constant_override("margin_right", 110)
	margin.add_theme_constant_override("margin_top", 55)
	margin.add_theme_constant_override("margin_bottom", 55)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var eyebrow := Label.new()
	eyebrow.text = "CAMPAIGN COMPLETE"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.add_theme_font_size_override("font_size", 18)
	eyebrow.add_theme_color_override("font_color", SettingsManager.get_accent_color())
	root.add_child(eyebrow)

	var title := Label.new()
	title.text = "WILD DASH — FINAL RESULT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	root.add_child(title)

	var hero := Label.new()
	hero.text = "%d PTS   ·   %d / %d CLEARS" % [_final_score, _clears, ResultManager.round_results.size()]
	hero.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero.add_theme_font_size_override("font_size", 26)
	hero.add_theme_color_override("font_color", SettingsManager.get_accent_color())
	root.add_child(hero)

	var separator := HSeparator.new()
	root.add_child(separator)

	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 22)
	root.add_child(content)

	_build_run_panel(content)
	_build_ranking_panel(content)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 14)
	root.add_child(footer)

	var replay := Button.new()
	replay.text = "PLAY AGAIN"
	replay.custom_minimum_size = Vector2(205, 54)
	replay.pressed.connect(_on_replay)
	footer.add_child(replay)

	var lobby := Button.new()
	lobby.text = "RETURN TO LOBBY"
	lobby.custom_minimum_size = Vector2(205, 54)
	lobby.pressed.connect(_on_lobby)
	footer.add_child(lobby)

	var quit := Button.new()
	quit.text = "QUIT"
	quit.custom_minimum_size = Vector2(150, 54)
	quit.pressed.connect(_on_quit)
	footer.add_child(quit)

	var saved_name := _get_saved_player_name()
	if not saved_name.is_empty():
		_name_input.text = saved_name
	_name_input.grab_focus()
	_name_input.select_all()

func _build_run_panel(parent: HBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.1
	parent.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	var header := Label.new()
	header.text = "YOUR RUN"
	header.add_theme_font_size_override("font_size", 25)
	header.add_theme_color_override("font_color", SettingsManager.get_accent_color())
	box.add_child(header)

	var profile := Label.new()
	profile.text = "%s   ·   %s" % [_animal_display_name(GameManager.selected_animal), _difficulty_display_name(GameManager.difficulty)]
	profile.add_theme_font_size_override("font_size", 18)
	box.add_child(profile)

	var round_header := Label.new()
	round_header.text = "ROUND RESULTS"
	round_header.add_theme_font_size_override("font_size", 17)
	box.add_child(round_header)

	for entry: Dictionary in ResultManager.round_results:
		var row := Label.new()
		row.text = _format_round_result(entry)
		row.add_theme_font_size_override("font_size", 17)
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(row)

	var note := Label.new()
	note.text = "Score combines round clears and normalized performance. Better finishes and stronger arena results raise your ranking."
	note.add_theme_font_size_override("font_size", 14)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note)

func _build_ranking_panel(parent: HBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 0.9
	parent.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 9)
	margin.add_child(box)

	var header := Label.new()
	header.text = "LOCAL RANKING"
	header.add_theme_font_size_override("font_size", 25)
	header.add_theme_color_override("font_color", SettingsManager.get_accent_color())
	box.add_child(header)

	_rank_label = Label.new()
	_rank_label.text = "ENTER YOUR NAME TO REGISTER THIS RUN"
	_rank_label.add_theme_font_size_override("font_size", 19)
	_rank_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_rank_label)

	_name_input = LineEdit.new()
	_name_input.placeholder_text = "PLAYER NAME"
	_name_input.max_length = 16
	_name_input.custom_minimum_size = Vector2(0, 46)
	_name_input.text_submitted.connect(_on_name_submitted)
	box.add_child(_name_input)

	_register_button = Button.new()
	_register_button.text = "REGISTER SCORE"
	_register_button.custom_minimum_size = Vector2(0, 50)
	_register_button.pressed.connect(_register_score)
	box.add_child(_register_button)

	_status_label = Label.new()
	_status_label.text = "Your name and leaderboard are saved only on this device."
	_status_label.add_theme_font_size_override("font_size", 13)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status_label)

	var top_header := Label.new()
	top_header.text = "TOP %d" % VISIBLE_LEADERBOARD_ENTRIES
	top_header.add_theme_font_size_override("font_size", 17)
	box.add_child(top_header)

	_leaderboard_label = Label.new()
	_leaderboard_label.add_theme_font_size_override("font_size", 17)
	_leaderboard_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_leaderboard_label)
	_refresh_leaderboard_display()

func _on_name_submitted(_value: String) -> void:
	_register_score()

func _register_score() -> void:
	if _score_registered:
		return
	var player_name := _sanitize_player_name(_name_input.text)
	if player_name.is_empty():
		_status_label.text = "Please enter a name before registering your score."
		_name_input.grab_focus()
		return

	var records: Dictionary = SaveManager.current_data.get("records", {})
	var leaderboard := _leaderboard_from_records(records)
	var run_key := "%d-%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_msec()]
	var entry := {
		"run_key": run_key,
		"name": player_name,
		"score": _final_score,
		"clears": _clears,
		"character": String(GameManager.selected_animal),
		"difficulty": String(GameManager.difficulty),
		"grand_prix_rank": _get_race_rank(&"grand_prix"),
		"recorded_at": int(Time.get_unix_time_from_system()),
	}
	leaderboard.append(entry)
	leaderboard.sort_custom(_leaderboard_sort)

	var rank := 0
	for i in range(leaderboard.size()):
		var candidate_value: Variant = leaderboard[i]
		if typeof(candidate_value) != TYPE_DICTIONARY:
			continue
		var candidate := candidate_value as Dictionary
		if String(candidate.get("run_key", "")) == run_key:
			rank = i + 1
			break
	var total_entries := leaderboard.size()
	if leaderboard.size() > MAX_LEADERBOARD_ENTRIES:
		leaderboard.resize(MAX_LEADERBOARD_ENTRIES)

	records["player_name"] = player_name
	records["leaderboard"] = leaderboard
	records["last_campaign_score"] = _final_score
	records["last_local_rank"] = rank
	SaveManager.current_data["records"] = records
	var saved := SaveManager.save_current()

	_score_registered = true
	_name_input.editable = false
	_register_button.disabled = true
	_register_button.text = "SCORE REGISTERED"
	_rank_label.text = "%s   ·   LOCAL RANK #%d / %d" % [player_name.to_upper(), rank, total_entries]
	_rank_label.add_theme_color_override("font_color", SettingsManager.get_accent_color())
	_status_label.text = "Saved locally." if saved else "Ranking calculated, but local save failed."
	_refresh_leaderboard_display()
	AudioManager.play_sfx_id("finish")
	print("RESULT RANKING name=%s score=%d rank=%d/%d saved=%s" % [player_name, _final_score, rank, total_entries, str(saved)])

func _calculate_campaign_score() -> int:
	var total := 0
	for entry: Dictionary in ResultManager.round_results:
		var success := bool(entry.get("success", false))
		if success:
			total += 1000
		var mode_id := StringName(entry.get("mode_id", &"unknown"))
		var raw_score := int(entry.get("score", 0))
		var details_value: Variant = entry.get("details", {})
		var details: Dictionary = details_value as Dictionary if typeof(details_value) == TYPE_DICTIONARY else {}
		match mode_id:
			&"grand_prix", &"neon_harbor_race", &"snowpeak_winter_rally":
				var rank := int(details.get("rank", raw_score))
				var racers := maxi(1, int(details.get("racers", GameManager.ai_count + 1)))
				if rank > 0 and rank <= racers:
					total += int(round((float(racers - rank + 1) / float(racers)) * 1000.0))
			&"fruit_collection":
				var target := maxi(1, int(details.get("target", 8)))
				total += int(round(clampf(float(raw_score) / float(target), 0.0, 1.0) * 1000.0))
			&"push_out":
				var rivals_total := maxi(1, GameManager.ai_count)
				var remaining := clampi(int(details.get("rivals_remaining", rivals_total)), 0, rivals_total)
				var eliminated := rivals_total - remaining
				total += int(round((float(eliminated) / float(rivals_total)) * 1000.0))
			_:
				total += clampi(raw_score, 0, 1000)
	return total

func _format_round_result(entry: Dictionary) -> String:
	var mode_id := StringName(entry.get("mode_id", &"unknown"))
	var success := bool(entry.get("success", false))
	var raw_score := int(entry.get("score", 0))
	var details_value: Variant = entry.get("details", {})
	var details: Dictionary = details_value as Dictionary if typeof(details_value) == TYPE_DICTIONARY else {}
	var status := "CLEAR" if success else "MISS"
	match mode_id:
		&"grand_prix":
			return "WILD WORLD GRAND PRIX   ·   #%d / %d   ·   %s" % [int(details.get("rank", raw_score)), int(details.get("racers", GameManager.ai_count + 1)), status]
		&"fruit_collection":
			return "FRUIT COLLECTION   ·   %d / %d FRUITS   ·   %s" % [raw_score, int(details.get("target", 8)), status]
		&"neon_harbor_race":
			return "NEON HARBOR   ·   #%d / %d   ·   %s" % [int(details.get("rank", raw_score)), int(details.get("racers", GameManager.ai_count + 1)), status]
		&"push_out":
			var rivals_total := maxi(1, GameManager.ai_count)
			var remaining := clampi(int(details.get("rivals_remaining", rivals_total)), 0, rivals_total)
			return "PUSH OUT   ·   %d / %d RIVALS OUT   ·   %s" % [rivals_total - remaining, rivals_total, status]
		&"snowpeak_winter_rally":
			return "SNOWPEAK RALLY   ·   #%d / %d   ·   %s" % [int(details.get("rank", raw_score)), int(details.get("racers", GameManager.ai_count + 1)), status]
		_:
			return "%s   ·   %d   ·   %s" % [String(mode_id).to_upper(), raw_score, status]

func _leaderboard_from_records(records: Dictionary) -> Array:
	var value: Variant = records.get("leaderboard", [])
	if typeof(value) != TYPE_ARRAY:
		return []
	var leaderboard: Array = []
	for item: Variant in value as Array:
		if typeof(item) == TYPE_DICTIONARY:
			leaderboard.append((item as Dictionary).duplicate(true))
	leaderboard.sort_custom(_leaderboard_sort)
	return leaderboard

func _leaderboard_sort(a: Variant, b: Variant) -> bool:
	if typeof(a) != TYPE_DICTIONARY:
		return false
	if typeof(b) != TYPE_DICTIONARY:
		return true
	var left := a as Dictionary
	var right := b as Dictionary
	var left_score := int(left.get("score", 0))
	var right_score := int(right.get("score", 0))
	if left_score != right_score:
		return left_score > right_score
	var left_clears := int(left.get("clears", 0))
	var right_clears := int(right.get("clears", 0))
	if left_clears != right_clears:
		return left_clears > right_clears
	return int(left.get("recorded_at", 0)) < int(right.get("recorded_at", 0))

func _refresh_leaderboard_display() -> void:
	if _leaderboard_label == null:
		return
	var records: Dictionary = SaveManager.current_data.get("records", {})
	var leaderboard := _leaderboard_from_records(records)
	if leaderboard.is_empty():
		_leaderboard_label.text = "No registered runs yet.\nBe the first name on the board."
		return
	var rows: Array[String] = []
	var visible_count := mini(VISIBLE_LEADERBOARD_ENTRIES, leaderboard.size())
	for i in range(visible_count):
		var entry := leaderboard[i] as Dictionary
		rows.append("%d. %s   ·   %d PTS   ·   %d CLEARS" % [
			i + 1,
			String(entry.get("name", "PLAYER")).to_upper(),
			int(entry.get("score", 0)),
			int(entry.get("clears", 0)),
		])
	_leaderboard_label.text = "\n".join(rows)

func _get_saved_player_name() -> String:
	var records: Dictionary = SaveManager.current_data.get("records", {})
	return _sanitize_player_name(String(records.get("player_name", "")))

func _sanitize_player_name(value: String) -> String:
	var clean := value.strip_edges()
	if clean.length() > 16:
		clean = clean.substr(0, 16)
	return clean

func _get_race_rank(mode_id: StringName) -> int:
	for entry: Dictionary in ResultManager.round_results:
		if StringName(entry.get("mode_id", &"")) != mode_id:
			continue
		var details_value: Variant = entry.get("details", {})
		if typeof(details_value) == TYPE_DICTIONARY:
			return int((details_value as Dictionary).get("rank", entry.get("score", 0)))
		return int(entry.get("score", 0))
	return 0

func _animal_display_name(animal: StringName) -> String:
	match animal:
		&"rabbit":
			return "RABBIT"
		&"elephant":
			return "ELEPHANT"
		&"cat":
			return "CAT"
		_:
			return "DOG"

func _difficulty_display_name(value: StringName) -> String:
	match value:
		&"wild":
			return "CASUAL · 10 RACERS"
		&"nightmare":
			return "HARD · 18 RACERS"
		_:
			return "NORMAL · 15 RACERS"

func _on_replay() -> void:
	AudioManager.play_sfx_id("ui")
	ResultManager.reset_campaign()
	GameManager.show_character_select()

func _on_lobby() -> void:
	AudioManager.play_sfx_id("ui")
	GameManager.return_to_lobby()

func _on_quit() -> void:
	SaveManager.save_current()
	get_tree().quit(0)
