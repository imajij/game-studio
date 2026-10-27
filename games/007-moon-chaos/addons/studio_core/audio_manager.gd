extends Node
## Central audio playback. Creates "Music" and "SFX" buses at runtime (no
## .tres bus layout to keep in sync across games), pools SFX players so
## rapid sounds never allocate, and mutes buses from Settings.

const BUS_MUSIC: String = "Music"
const BUS_SFX: String = "SFX"
const SFX_POOL_SIZE: int = 8
const MUSIC_FADE_SEC: float = 0.6
const MUSIC_FADE_FROM_DB: float = -40.0

var _music_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _next_sfx: int = 0

func _ready() -> void:
	# Sounds keep playing through pause overlays (discovery cards, ads).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_bus(BUS_MUSIC)
	_make_bus(BUS_SFX)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = BUS_MUSIC
	add_child(_music_player)
	for i in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = BUS_SFX
		add_child(player)
		_sfx_players.append(player)
	Settings.setting_changed.connect(_on_setting_changed)
	_apply_settings()


func play_music(stream: AudioStream, fade_in: bool = true) -> void:
	if _music_player.stream == stream and _music_player.playing:
		return
	_music_player.stream = stream
	_music_player.volume_db = MUSIC_FADE_FROM_DB if fade_in else 0.0
	_music_player.play()
	if fade_in:
		var tween := create_tween()
		tween.tween_property(_music_player, "volume_db", 0.0, MUSIC_FADE_SEC)


func stop_music() -> void:
	_music_player.stop()


## pitch_jitter (0.0–0.3) randomises pitch a little so repeated sounds
## don't grate; pitch_base shifts the whole sound (e.g. deeper per tier).
func play_sfx(stream: AudioStream, pitch_jitter: float = 0.0, pitch_base: float = 1.0) -> void:
	if stream == null:
		return
	var player := _sfx_players[_next_sfx]
	_next_sfx = (_next_sfx + 1) % SFX_POOL_SIZE
	player.stream = stream
	player.pitch_scale = pitch_base + randf_range(-pitch_jitter, pitch_jitter)
	player.play()


func _make_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")


func _apply_settings() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index(BUS_MUSIC), not Settings.music_on)
	AudioServer.set_bus_mute(AudioServer.get_bus_index(BUS_SFX), not Settings.sfx_on)


func _on_setting_changed(_key: String, _enabled: bool) -> void:
	_apply_settings()
