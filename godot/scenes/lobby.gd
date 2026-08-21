extends Control

const MULTIPLAYER_LOBBY_SCENE := "res://network/multiplayer_lobby.tscn"

const LOBBY_COPY: Dictionary = {
	&"en": {
		"subtitle": "RC9 DEV · 12 RACERS · SINGLE + LAN PARTY PROTOTYPE",
		"profile": "Campaigns %d   Wins %d   Fans %d   Best GP %d",
		"language": "LANGUAGE",
		"single": "SINGLE PLAYER",
		"multiplayer": "MULTIPLAYER · LAN PROTOTYPE",
		"settings": "SETTINGS",
		"controls": "Race: Hold W/↑ OVERDRIVE · S/↓ brake · A/D steer · Space jump · E animal skill · Q item · F body check\nGamepad: Left Stick / D-Pad · A Jump · X Skill · B Item · Y Body Check · Start Pause",
		"quit": "QUIT",
	},
	&"ko": {
		"subtitle": "RC9 개발판 · 12명의 레이서 · 싱글 + LAN 파티 프로토타입",
		"profile": "캠페인 %d   우승 %d   팬 %d   최고 GP %d",
		"language": "언어",
		"single": "싱글 플레이",
		"multiplayer": "멀티플레이 · LAN 프로토타입",
		"settings": "설정",
		"controls": "레이스: W/↑ 길게 눌러 오버드라이브 · S/↓ 브레이크 · A/D 조향 · Space 점프 · E 동물 스킬 · Q 아이템 · F 몸통 공격\n게임패드: 왼쪽 스틱 / D-Pad · A 점프 · X 스킬 · B 아이템 · Y 몸통 공격 · Start 일시정지",
		"quit": "게임 종료",
	},
	&"es": {
		"subtitle": "RC9 DEV · 12 CORREDORES · INDIVIDUAL + PROTOTIPO LAN",
		"profile": "Campañas %d   Victorias %d   Fans %d   Mejor GP %d",
		"language": "IDIOMA",
		"single": "UN JUGADOR",
		"multiplayer": "MULTIJUGADOR · PROTOTIPO LAN",
		"settings": "AJUSTES",
		"controls": "Carrera: Mantén W/↑ para OVERDRIVE · S/↓ frenar · A/D girar · Espacio saltar · E habilidad animal · Q objeto · F embestida\nMando: Stick izquierdo / Cruceta · A Saltar · X Habilidad · B Objeto · Y Embestida · Start Pausa",
		"quit": "SALIR",
	},
}

const LANGUAGE_BUTTONS: Array[Dictionary] = [
	{"code": &"en", "label": "English"},
	{"code": &"ko", "label": "한국어"},
	{"code": &"es", "label": "Español"},
]

var _profile: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	GameManager.set_state(GameManager.GameState.LOBBY)
	AudioManager.play_theme("result")
	print("RC_FLOW Launch")
	print("RC_FLOW Lobby")
	_profile = (SaveManager.current_data.get("profile", {}) as Dictionary).duplicate(true)
	print("RC_SAVE_LOADED launches=%d campaigns=%d last_character=%s" % [
		int(_profile.get("launches", 0)), int(_profile.get("campaigns", 0)), String(_profile.get("last_character", "dog")),
	])
	if DisplayServer.get_name() == "headless" and OS.has_environment("WILDDASH_AUTOTEST_LOAD_ONLY"):
		get_tree().quit(0)
		return
	if DisplayServer.get_name() == "headless" and OS.has_environment("WILDDASH_AUTOTEST"):
		call_deferred("_autotest_continue")
		return
	_build_ui()

func _build_ui() -> void:
	var active_language := SettingsManager.get_language()
	var copy: Dictionary = LOBBY_COPY.get(active_language, LOBBY_COPY[&"en"])

	var background := ColorRect.new()
	background.color = SettingsManager.get_background_color()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var box := VBoxContainer.new()
	box.position = Vector2(420, 72)
	box.custom_minimum_size = Vector2(600, 756)
	box.add_theme_constant_override("separation", 12)
	add_child(box)

	var title := Label.new()
	title.text = "WILD DASH 3D"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 54)
	title.add_theme_color_override("font_color", SettingsManager.get_accent_color())
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = String(copy.get("subtitle", ""))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 17)
	box.add_child(subtitle)

	var profile_label := Label.new()
	profile_label.text = String(copy.get("profile", "")) % [
		int(_profile.get("campaigns", 0)), int(_profile.get("wins", 0)),
		int(_profile.get("fans", 0)), int(_profile.get("best", 50)),
	]
	profile_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(profile_label)

	var language_label := Label.new()
	language_label.text = String(copy.get("language", "LANGUAGE"))
	language_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	language_label.add_theme_font_size_override("font_size", 15)
	language_label.add_theme_color_override("font_color", SettingsManager.get_accent_color())
	box.add_child(language_label)

	var language_row := HBoxContainer.new()
	language_row.add_theme_constant_override("separation", 10)
	box.add_child(language_row)
	var language_group := ButtonGroup.new()
	language_group.allow_unpress = false
	for entry: Dictionary in LANGUAGE_BUTTONS:
		var code := StringName(entry.get("code", &"en"))
		var language_button := Button.new()
		language_button.text = String(entry.get("label", String(code)))
		language_button.custom_minimum_size = Vector2(190, 42)
		language_button.toggle_mode = true
		language_button.button_group = language_group
		language_button.button_pressed = code == active_language
		language_button.add_theme_font_size_override("font_size", 18)
		language_button.pressed.connect(_on_language_selected.bind(code))
		language_row.add_child(language_button)

	var single_player := Button.new()
	single_player.text = String(copy.get("single", "SINGLE PLAYER"))
	single_player.custom_minimum_size = Vector2(0, 70)
	single_player.add_theme_font_size_override("font_size", 25)
	single_player.pressed.connect(_on_play)
	box.add_child(single_player)

	var multiplayer_button := Button.new()
	multiplayer_button.text = String(copy.get("multiplayer", "MULTIPLAYER · LAN PROTOTYPE"))
	multiplayer_button.custom_minimum_size = Vector2(0, 66)
	multiplayer_button.add_theme_font_size_override("font_size", 22)
	multiplayer_button.pressed.connect(_on_multiplayer)
	box.add_child(multiplayer_button)

	var settings_button := Button.new()
	settings_button.text = String(copy.get("settings", "SETTINGS"))
	settings_button.custom_minimum_size = Vector2(0, 54)
	settings_button.add_theme_font_size_override("font_size", 18)
	settings_button.pressed.connect(_on_settings)
	box.add_child(settings_button)

	var controls := Label.new()
	controls.text = String(copy.get("controls", ""))
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.add_theme_font_size_override("font_size", 15)
	box.add_child(controls)

	var quit := Button.new()
	quit.text = String(copy.get("quit", "QUIT"))
	quit.custom_minimum_size = Vector2(0, 48)
	quit.pressed.connect(_on_quit)
	box.add_child(quit)
	single_player.grab_focus()

func _refresh_ui() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_build_ui()

func _on_language_selected(code: StringName) -> void:
	if code == SettingsManager.get_language():
		return
	AudioManager.play_sfx_id("ui")
	SettingsManager.set_language(code)
	_refresh_ui()
	print("RC_LOBBY_LANGUAGE_REFRESH locale=%s" % String(code))

func _on_play() -> void:
	NetworkManager.leave_party(false)
	AudioManager.play_sfx_id("ui")
	GameManager.show_character_select()

func _on_multiplayer() -> void:
	AudioManager.play_sfx_id("ui")
	get_tree().change_scene_to_file(MULTIPLAYER_LOBBY_SCENE)

func _on_settings() -> void:
	AudioManager.play_sfx_id("ui")
	GameManager.show_settings()

func _on_quit() -> void:
	NetworkManager.leave_party(false)
	SaveManager.save_current()
	get_tree().quit(0)

func _autotest_continue() -> void:
	await get_tree().process_frame
	GameManager.show_character_select()
