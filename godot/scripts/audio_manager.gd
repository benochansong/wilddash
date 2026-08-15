extends Node

const BUS_MASTER := "Master"
const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"
const SFX_POOL_SIZE := 8
const GRAND_PRIX_THEME_PATH := "res://audio/music/wild_dash_race_theme.ogg"
const NEON_HARBOR_THEME_PATH := "res://audio/music/wild_dash_race_theme_alt.ogg"
const SNOWPEAK_THEME_PATH := "res://audio/music/wild_dash_snowpeak_theme.ogg"
const PUSH_OUT_THEME_PATH := "res://audio/music/wild_dash_arena_theme_alt.ogg"
const FRUIT_COLLECTION_THEME_PATH := "res://audio/music/wild_dash_fruit_collection_theme.ogg"
const RESULT_THEME_PATH := "res://audio/music/wild_dash_result_theme.ogg"

var muted := false
var master_volume := 0.85
var music_volume := 0.62
var sfx_volume := 0.82
var _music_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_cursor := 0
var _themes: Dictionary = {}
var _sfx_library: Dictionary = {}
var _current_theme := ""

func _ready() -> void:
	_ensure_bus(BUS_MUSIC)
	_ensure_bus(BUS_SFX)
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = BUS_MUSIC
	add_child(_music_player)
	for i in range(SFX_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.name = "SFX_%02d" % i
		player.bus = BUS_SFX
		add_child(player)
		_sfx_players.append(player)
	if DisplayServer.get_name() != "headless":
		_build_procedural_audio()
		_load_external_music()
	apply_settings(SettingsManager.get_audio_settings())
	if DisplayServer.get_name() != "headless":
		play_theme("menu")

func apply_settings(audio: Dictionary) -> void:
	muted = bool(audio.get("muted", false))
	master_volume = clampf(float(audio.get("master_volume", 0.85)), 0.0, 1.0)
	music_volume = clampf(float(audio.get("music_volume", 0.62)), 0.0, 1.0)
	sfx_volume = clampf(float(audio.get("sfx_volume", 0.82)), 0.0, 1.0)
	_set_bus_volume(BUS_MASTER, master_volume)
	_set_bus_volume(BUS_MUSIC, music_volume)
	_set_bus_volume(BUS_SFX, sfx_volume)
	var master_index := AudioServer.get_bus_index(BUS_MASTER)
	if master_index >= 0:
		AudioServer.set_bus_mute(master_index, muted)

# Compatibility setters used by the gameplay prototype API.
func set_muted(value: bool) -> void:
	muted = value
	var audio := {
		"muted": muted,
		"master_volume": master_volume,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
	}
	apply_settings(audio)

func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_set_bus_volume(BUS_SFX, sfx_volume)

func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_set_bus_volume(BUS_MUSIC, music_volume)

func play_theme(theme_id: String) -> void:
	if DisplayServer.get_name() == "headless" or muted:
		return
	if _current_theme == theme_id and _music_player.playing:
		return
	var stream: AudioStream = _themes.get(theme_id, _themes.get("menu"))
	if stream == null:
		return
	_current_theme = theme_id
	_music_player.stop()
	_music_player.stream = stream
	_music_player.play()

func play_music(stream: AudioStream, loop := true) -> void:
	if stream == null or _music_player == null:
		return
	_current_theme = "custom"
	_music_player.stop()
	_music_player.stream = stream
	_set_stream_loop(stream, loop)
	_music_player.play()

func stop_music() -> void:
	_current_theme = ""
	if _music_player != null:
		_music_player.stop()

func play_sfx_id(sfx_id: String, volume_scale := 1.0) -> void:
	if DisplayServer.get_name() == "headless" or muted or _sfx_players.is_empty():
		return
	var stream: AudioStream = _sfx_library.get(sfx_id)
	if stream == null:
		return
	_play_on_pool(stream, volume_scale)

func play_sfx(stream: AudioStream, volume_scale := 1.0) -> void:
	if stream == null or DisplayServer.get_name() == "headless" or muted or _sfx_players.is_empty():
		return
	_play_on_pool(stream, volume_scale)

func _play_on_pool(stream: AudioStream, volume_scale: float) -> void:
	var player := _sfx_players[_sfx_cursor]
	_sfx_cursor = (_sfx_cursor + 1) % _sfx_players.size()
	player.stop()
	player.volume_db = linear_to_db(clampf(volume_scale, 0.01, 1.0))
	player.stream = stream
	player.play()

func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, BUS_MASTER)

func _set_bus_volume(bus_name: String, value: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	AudioServer.set_bus_volume_db(index, -80.0 if value <= 0.0001 else linear_to_db(value))

func _load_external_music() -> void:
	_load_external_theme("race_grand_prix", GRAND_PRIX_THEME_PATH)
	_load_external_theme("race_neon_harbor", NEON_HARBOR_THEME_PATH)
	_load_external_theme("race_snowpeak", SNOWPEAK_THEME_PATH)
	_load_external_theme("arena_push_out", PUSH_OUT_THEME_PATH)
	_load_external_theme("arena_fruit_collection", FRUIT_COLLECTION_THEME_PATH)
	_load_external_theme("result", RESULT_THEME_PATH)

func _load_external_theme(theme_id: String, path: String) -> void:
	if not ResourceLoader.exists(path):
		print("AUDIO external theme missing id=%s; using procedural fallback" % theme_id)
		return
	var stream := ResourceLoader.load(path) as AudioStream
	if stream == null:
		push_warning("Could not load external theme id=%s path=%s" % [theme_id, path])
		return
	_set_stream_loop(stream, true)
	_themes[theme_id] = stream
	print("AUDIO external theme loaded id=%s path=%s" % theme_id)

func _set_stream_loop(stream: AudioStream, loop: bool) -> void:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = loop
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = loop
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED

func _build_procedural_audio() -> void:
	_themes["menu"] = _make_theme([196.0, 246.94, 293.66], 4.0, 0.16)
	_themes["race"] = _make_theme([220.0, 329.63, 440.0], 3.2, 0.18)
	_themes["race_grand_prix"] = _themes["race"]
	_themes["race_neon_harbor"] = _themes["race"]
	_themes["race_snowpeak"] = _themes["race"]
	_themes["arena"] = _make_theme([174.61, 261.63, 349.23], 3.6, 0.18)
	_themes["arena_push_out"] = _themes["arena"]
	_themes["arena_fruit_collection"] = _themes["arena"]
	_themes["result"] = _make_theme([261.63, 329.63, 392.0], 4.4, 0.15)
	_sfx_library["ui"] = _make_tone(660.0, 0.07, 0.32)
	_sfx_library["jump"] = _make_sweep(360.0, 720.0, 0.12, 0.28)
	_sfx_library["skill"] = _make_sweep(520.0, 220.0, 0.16, 0.30)
	_sfx_library["item"] = _make_tone(880.0, 0.10, 0.26)
	_sfx_library["hit"] = _make_sweep(180.0, 95.0, 0.09, 0.30)
	_sfx_library["finish"] = _make_sweep(440.0, 880.0, 0.22, 0.34)
	_sfx_library["fart"] = _make_cartoon_fart()

func _make_theme(frequencies: Array, duration: float, amplitude: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var sample_count := int(duration * float(sample_rate))
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for i in range(sample_count):
		var time := float(i) / float(sample_rate)
		var beat := int(floor(time * 2.0)) % frequencies.size()
		var frequency := float(frequencies[beat])
		var envelope := 0.55 + 0.45 * sin(TAU * 0.5 * time) * sin(TAU * 0.5 * time)
		var sample := sin(TAU * frequency * time) * amplitude * envelope
		_write_sample_16(data, i, sample)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = sample_count
	return stream

func _make_tone(frequency: float, duration: float, amplitude: float) -> AudioStreamWAV:
	return _make_sweep(frequency, frequency, duration, amplitude)

func _make_sweep(start_frequency: float, end_frequency: float, duration: float, amplitude: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var sample_count := maxi(1, int(duration * float(sample_rate)))
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var phase := 0.0
	for i in range(sample_count):
		var ratio := float(i) / float(sample_count)
		var frequency := lerpf(start_frequency, end_frequency, ratio)
		phase += TAU * frequency / float(sample_rate)
		var envelope := 1.0 - ratio
		_write_sample_16(data, i, sin(phase) * amplitude * envelope)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	return stream

func _make_cartoon_fart() -> AudioStreamWAV:
	# Deliberately synthetic/clean: a tiny low buzz + pitch wobble. This keeps the
	# gag readable without adding external assets or creating a realistic sound.
	var sample_rate := 22050
	var duration := 0.22
	var sample_count := maxi(1, int(duration * float(sample_rate)))
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var phase := 0.0
	for i in range(sample_count):
		var ratio := float(i) / float(sample_count)
		var wobble := sin(TAU * 17.0 * ratio) * 18.0
		var frequency := lerpf(128.0, 72.0, ratio) + wobble
		phase += TAU * frequency / float(sample_rate)
		var envelope := pow(1.0 - ratio, 1.35)
		var sample := (sin(phase) * 0.22 + sin(phase * 0.47) * 0.10) * envelope
		_write_sample_16(data, i, sample)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	return stream

func _write_sample_16(data: PackedByteArray, index: int, sample: float) -> void:
	var value := int(clampf(sample, -1.0, 1.0) * 32767.0)
	data[index * 2] = value & 0xff
	data[index * 2 + 1] = (value >> 8) & 0xff
