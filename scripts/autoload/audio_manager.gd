extends Node
## Music and SFX playback. Stub for M0.
## Later: village music stems (one layer per powered villager) and pooled SFX players.

const SFX_POOL_SIZE: int = 8

var _music: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _next_sfx: int = 0


func _ready() -> void:
	_music = AudioStreamPlayer.new()
	add_child(_music)
	for i: int in SFX_POOL_SIZE:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(player)
		_sfx_pool.append(player)


func play_music(stream: AudioStream) -> void:
	if _music.stream == stream and _music.playing:
		return
	_music.stream = stream
	_music.play()


func stop_music() -> void:
	_music.stop()


func play_sfx(stream: AudioStream, pitch_variation: float = 0.0) -> void:
	var player: AudioStreamPlayer = _sfx_pool[_next_sfx]
	_next_sfx = (_next_sfx + 1) % SFX_POOL_SIZE
	player.stream = stream
	player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	player.play()
