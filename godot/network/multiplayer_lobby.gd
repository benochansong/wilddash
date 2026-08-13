extends Control

const LOBBY_SCENE := "res://scenes/lobby.tscn"
const ANIMALS: Array[StringName] = [
	&"dog", &"wolf", &"boar", &"rabbit", &"deer", &"monkey",
	&"elephant", &"bear", &"panda", &"cat", &"fox", &"raccoon",
]

var _name_edit: LineEdit
var _address_edit: LineEdit
var _animal_select: OptionButton
var _ready_button: Button
var _start_button: Button
var _roster_label: Label
var _status_label: Label
var _local_ready := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	NetworkManager.roster_changed.connect(_refresh_roster)
	NetworkManager.connection_status_changed.connect(_set_status)
	NetworkManager.host_left.connect(_on_host_left)
	_refresh_roster(NetworkManager.get_players())

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = SettingsManager.get_background_color()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var panel := VBoxContainer.new()
	panel.position = Vector2(370, 70)
	panel.custom_minimum_size = Vector2(860, 760)
	panel.add_theme_constant_override("separation", 12)
	add_child(panel)

	var title := Label.new()
	title.text = "WILD DASH PARTY · LAN PROTOTYPE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", SettingsManager.get_accent_color())
	panel.add_child(title)

	var note := Label.new()
	note.text = "RC9 prototype · 2–8 humans · Host/Join via ENet · Grand Prix first"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(note)

	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "PLAYER NAME"
	_name_edit.text = "PLAYER"
	_name_edit.max_length = 16
	_name_edit.text_changed.connect(_on_name_changed)
	panel.add_child(_name_edit)

	var animal_row := HBoxContainer.new()
	panel.add_child(animal_row)
	var animal_label := Label.new()
	animal_label.text = "RACER"
	animal_label.custom_minimum_size = Vector2(120, 44)
	animal_row.add_child(animal_label)
	_animal_select = OptionButton.new()
	_animal_select.custom_minimum_size = Vector2(500, 44)
	for animal_id in ANIMALS:
		var definition := WildDashAnimalCatalog.get_definition(animal_id)
		_animal_select.add_item("%s · %s" % [definition.display_name.to_upper(), definition.role])
		_animal_select.set_item_metadata(_animal_select.item_count - 1, String(animal_id))
	var saved := GameManager.selected_animal
	var saved_index := ANIMALS.find(saved)
	_animal_select.select(maxi(0, saved_index))
	_animal_select.item_selected.connect(_on_animal_selected)
	animal_row.add_child(_animal_select)

	var connection_row := HBoxContainer.new()
	panel.add_child(connection_row)
	var host_button := Button.new()
	host_button.text = "CREATE PARTY"
	host_button.custom_minimum_size = Vector2(240, 54)
	host_button.pressed.connect(_create_party)
	connection_row.add_child(host_button)
	_address_edit = LineEdit.new()
	_address_edit.placeholder_text = "HOST IP"
	_address_edit.text = "127.0.0.1"
	_address_edit.custom_minimum_size = Vector2(330, 54)
	connection_row.add_child(_address_edit)
	var join_button := Button.new()
	join_button.text = "JOIN PARTY"
	join_button.custom_minimum_size = Vector2(240, 54)
	join_button.pressed.connect(_join_party)
	connection_row.add_child(join_button)

	_ready_button = Button.new()
	_ready_button.text = "READY: OFF"
	_ready_button.custom_minimum_size = Vector2(0, 52)
	_ready_button.pressed.connect(_toggle_ready)
	panel.add_child(_ready_button)

	_roster_label = Label.new()
	_roster_label.custom_minimum_size = Vector2(0, 260)
	_roster_label.add_theme_font_size_override("font_size", 19)
	_roster_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(_roster_label)

	_start_button = Button.new()
	_start_button.text = "START PARTY GRAND PRIX"
	_start_button.custom_minimum_size = Vector2(0, 66)
	_start_button.add_theme_font_size_override("font_size", 22)
	_start_button.disabled = true
	_start_button.pressed.connect(_start_party)
	panel.add_child(_start_button)

	_status_label = Label.new()
	_status_label.text = "Create a party or join a host on the same LAN."
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(_status_label)

	var back := Button.new()
	back.text = "BACK TO LOBBY"
	back.custom_minimum_size = Vector2(0, 48)
	back.pressed.connect(_back_to_lobby)
	panel.add_child(back)

func _create_party() -> void:
	_local_ready = false
	_ready_button.text = "READY: OFF"
	var animal := _selected_animal()
	NetworkManager.host_party(_name_edit.text, animal)

func _join_party() -> void:
	_local_ready = false
	_ready_button.text = "READY: OFF"
	var animal := _selected_animal()
	NetworkManager.join_party(_address_edit.text, _name_edit.text, animal)

func _toggle_ready() -> void:
	if not NetworkManager.is_party_active():
		_set_status("CREATE OR JOIN A PARTY FIRST")
		return
	_local_ready = not _local_ready
	_ready_button.text = "READY: ON" if _local_ready else "READY: OFF"
	NetworkManager.set_local_ready(_local_ready)

func _start_party() -> void:
	NetworkManager.start_party_grand_prix()

func _on_name_changed(value: String) -> void:
	NetworkManager.set_local_name(value)

func _on_animal_selected(_index: int) -> void:
	NetworkManager.set_local_animal(_selected_animal())

func _selected_animal() -> StringName:
	if _animal_select == null or _animal_select.selected < 0:
		return &"dog"
	return StringName(String(_animal_select.get_item_metadata(_animal_select.selected)))

func _refresh_roster(players: Dictionary) -> void:
	if _roster_label == null:
		return
	if players.is_empty():
		_roster_label.text = "PARTY ROSTER\n\nNo active session"
	else:
		var lines: Array[String] = ["PARTY ROSTER"]
		var peer_ids := players.keys()
		peer_ids.sort()
		for peer_id_value in peer_ids:
			var state := players[peer_id_value] as Dictionary
			var ready_text := "READY" if bool(state.get("ready", false)) else "SELECTING"
			var host_text := " · HOST" if int(state.get("peer_id", 0)) == 1 else ""
			lines.append("P%d%s   %-16s   %-10s   %s" % [
				int(state.get("peer_id", 0)), host_text,
				String(state.get("display_name", "PLAYER")),
				String(state.get("animal_id", "dog")).to_upper(), ready_text,
			])
		_roster_label.text = "\n".join(lines)
	_start_button.visible = NetworkManager.is_host()
	_start_button.disabled = not NetworkManager.can_start_party()

func _set_status(message: String) -> void:
	if _status_label != null:
		_status_label.text = message

func _on_host_left() -> void:
	_set_status("HOST LEFT PARTY · RETURNING TO LOBBY")
	call_deferred("_back_to_lobby")

func _back_to_lobby() -> void:
	NetworkManager.leave_party()
	get_tree().change_scene_to_file(LOBBY_SCENE)
