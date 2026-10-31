extends Node
## One player survives interface rebuilds. Preferences are separate from campaign saves.
const TRACK_PATH := "res://assets/audio/deep_blue_watch.ogg"
var settings_path: String = "user://audio.cfg"
var enabled: bool = true
var volume: float = 0.35
var player: AudioStreamPlayer
var fade: Tween
var closing: bool = false

func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(settings_path) == OK:
		var stored_enabled: Variant = config.get_value("music","enabled",true)
		var stored_volume: Variant = config.get_value("music","volume",0.35)
		if stored_enabled is bool: enabled = stored_enabled
		if (stored_volume is float or stored_volume is int) and is_finite(float(stored_volume)):
			volume = clampf(float(stored_volume),0.0,1.0)
	player = AudioStreamPlayer.new()
	player.name = "BackgroundMusic"
	var stream := load(TRACK_PATH) as AudioStreamOggVorbis
	if stream == null: return
	stream.loop = true
	player.stream = stream
	player.volume_db = -60.0
	add_child(player)
	player.play()
	_apply()
	# Let the mixer release its decoder before the operating-system window closes.
	get_tree().auto_accept_quit = false
	get_window().close_requested.connect(_close_game)

func set_enabled(value: bool) -> Error:
	enabled = value
	_apply()
	return save_settings()

func set_volume(value: float) -> Error:
	if not is_finite(value): return ERR_INVALID_PARAMETER
	volume = clampf(value,0.0,1.0)
	_apply()
	return save_settings()

func _apply() -> void:
	if not is_instance_valid(player) or not player.is_inside_tree(): return
	if is_instance_valid(fade): fade.kill()
	player.stream_paused = not enabled or volume <= 0.0
	if player.stream_paused:
		player.volume_db = -60.0
		return
	fade = create_tween()
	fade.tween_property(player,"volume_db",linear_to_db(volume),0.6)

func save_settings() -> Error:
	var config := ConfigFile.new()
	config.set_value("music","enabled",enabled)
	config.set_value("music","volume",volume)
	return config.save(settings_path)

func _stop_audio() -> void:
	if is_instance_valid(fade): fade.kill()
	if is_instance_valid(player):
		player.stop()
		player.stream = null

func _close_game() -> void:
	if closing: return
	closing = true
	_stop_audio()
	await get_tree().create_timer(0.12).timeout
	if is_inside_tree(): get_tree().quit()

func _exit_tree() -> void:
	_stop_audio()
