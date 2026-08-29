extends "res://scenes/character_select_crocodile.gd"

## Production Character Select spectator adapter.
## Normal START remains unchanged and always clears spectator state. WATCH AI
## BATTLE uses the same P0 start guard, difficulty and five-round campaign.

const SPECTATOR_MODE = preload("res://scripts/spectator_mode.gd")

var _spectator_button: Button

func _ready() -> void:
	super()
	_install_spectator_button()
	if _start_button != null and not _start_button.button_down.is_connected(_clear_spectator_for_normal_start):
		_start_button.button_down.connect(_clear_spectator_for_normal_start)
	print("CHARACTER SELECT SPECTATOR READY watch_ai_battle=true campaign_rounds=5")

func _start_run() -> void:
	SPECTATOR_MODE.set_enabled(false)
	super._start_run()

func _start_spectator_run() -> void:
	if _start_attempt_in_progress:
		return
	SPECTATOR_MODE.set_enabled(true)
	if _summary_label != null:
		_summary_label.text = "AI BATTLE · 5라운드 관전모드를 시작합니다 · ← → 로 관전 대상 변경"
	print("SPECTATOR MODE START REQUEST difficulty=%s selected_featured_racer=%s" % [
		String(_difficulty),
		String(_loadout.body_id) if _chimera_mode else String(_selected_animal),
	])
	# Call the P0 parent directly so the normal override above does not clear the
	# spectator flag. All production Round 1 validation remains intact.
	super._start_run()

func _clear_spectator_for_normal_start() -> void:
	SPECTATOR_MODE.set_enabled(false)

func _unhandled_key_input(event: InputEvent) -> void:
	if event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		SPECTATOR_MODE.set_enabled(false)
	super(event)

func _install_spectator_button() -> void:
	if _start_button == null or _start_button.get_parent() == null:
		push_warning("CHARACTER SELECT SPECTATOR start button unavailable")
		return
	var parent := _start_button.get_parent()
	_spectator_button = Button.new()
	_spectator_button.name = "WatchAIBattleButton"
	_spectator_button.text = "WATCH AI BATTLE · 관전모드"
	_spectator_button.tooltip_text = "모든 참가자를 AI가 조종합니다. ← → 또는 Tab으로 관전 대상을 바꿀 수 있습니다."
	_spectator_button.custom_minimum_size = Vector2(0, 48)
	_spectator_button.add_theme_font_size_override("font_size", 18)
	_spectator_button.pressed.connect(_start_spectator_run)
	parent.add_child(_spectator_button)
	parent.move_child(_spectator_button, _start_button.get_index())
