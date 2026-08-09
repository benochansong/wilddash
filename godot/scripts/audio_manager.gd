extends Node

var muted := false
var sfx_volume := 1.0
var music_volume := 0.65
var _music_player: AudioStreamPlayer

func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	add_child(_music_player)
	_apply_music_volume()

func set_muted(value: bool) -> void:
	muted = value
	_apply_music_volume()

func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)

func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_music_volume()

func play_sfx(stream: AudioStream, volume_scale := 1.0) -> void:
	if muted or stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = _volume_db(sfx_volume * volume_scale)
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func play_music(stream: AudioStream, loop := true) -> void:
	if stream == null:
		return
	_music_player.stop()
	_music_player.stream = stream
	if stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
	_apply_music_volume()
	_music_player.play()

func stop_music() -> void:
	_music_player.stop()

func _apply_music_volume() -> void:
	if _music_player == null:
		return
	_music_player.volume_db = -80.0 if muted else _volume_db(music_volume)

func _volume_db(value: float) -> float:
	return -80.0 if value <= 0.0001 else linear_to_db(clampf(value, 0.0001, 1.0))
