extends CanvasLayer

@export var player_path: NodePath

var _player: WildDashCharacterController
var _rank_label: Label
var _speed_label: Label
var _fps_label: Label
var _standings_label: Label
var _message_label: Label

func _ready() -> void:
	_player = get_node_or_null(player_path) as WildDashCharacterController
	_build_ui()
	RaceManager.race_started.connect(_on_race_started)
	RaceManager.race_finished.connect(_on_player_finished)
	RaceManager.race_completed.connect(_on_race_completed)

func _process(_delta: float) -> void:
	if _player == null:
		return
	_rank_label.text = "RANK  %d / %d" % [RaceManager.get_rank(_player), RaceManager.racers.size()]
	_speed_label.text = "SPEED  %4.1f" % _player.current_speed
	_fps_label.text = "FPS  %d" % Engine.get_frames_per_second()
	_standings_label.text = _format_standings()

func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(22, 22)
	panel.custom_minimum_size = Vector2(260, 0)
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)

	var title := Label.new()
	title.text = "WILD DASH 3D · VERTICAL SLICE"
	title.add_theme_font_size_override("font_size", 18)
	box.add_child(title)

	_rank_label = Label.new()
	_rank_label.add_theme_font_size_override("font_size", 28)
	box.add_child(_rank_label)

	_speed_label = Label.new()
	box.add_child(_speed_label)
	_fps_label = Label.new()
	box.add_child(_fps_label)

	var separator := HSeparator.new()
	box.add_child(separator)
	_standings_label = Label.new()
	box.add_child(_standings_label)

	_message_label = Label.new()
	_message_label.position = Vector2(350, 36)
	_message_label.add_theme_font_size_override("font_size", 26)
	add_child(_message_label)
	_message_label.text = "Get ready..."

	var controls := Label.new()
	controls.position = Vector2(22, 640)
	controls.text = "W/↑ accelerate · S/↓ brake · A/D steer · Space jump"
	controls.add_theme_font_size_override("font_size", 16)
	add_child(controls)

func _format_standings() -> String:
	var lines: Array[String] = ["STANDINGS"]
	var standings := RaceManager.get_standings()
	for i in range(standings.size()):
		var racer := standings[i]
		var suffix := "  ✓" if RaceManager.finish_order.has(racer) else ""
		lines.append("%d. %s%s" % [i + 1, RaceManager.get_racer_label(racer), suffix])
	return "\n".join(lines)

func _on_race_started() -> void:
	_message_label.text = "GO!"
	var timer := get_tree().create_timer(1.0)
	timer.timeout.connect(func():
		if _message_label != null:
			_message_label.text = ""
	)

func _on_player_finished(rank: int) -> void:
	_message_label.text = "FINISH!  #%d" % rank

func _on_race_completed() -> void:
	if _player != null and _player.finish_rank > 0:
		_message_label.text = "RACE COMPLETE · YOU #%d" % _player.finish_rank
