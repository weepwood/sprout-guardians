extends Node
class_name ProceduralAudioManager

const SAMPLE_RATE: int = 22050
const SFX_PLAYER_COUNT: int = 6

var music_enabled: bool = true
var sfx_enabled: bool = true
var music_volume_db: float = -20.0
var sfx_volume_db: float = -9.0

var _music_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _tone_cache: Dictionary = {}


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _ensure_bus("Music")
    _ensure_bus("SFX")

    _music_player = AudioStreamPlayer.new()
    _music_player.name = "MusicPlayer"
    _music_player.bus = "Music"
    _music_player.volume_db = music_volume_db
    add_child(_music_player)

    for index: int in range(SFX_PLAYER_COUNT):
        var player: AudioStreamPlayer = AudioStreamPlayer.new()
        player.name = "SfxPlayer%d" % index
        player.bus = "SFX"
        player.volume_db = sfx_volume_db
        add_child(player)
        _sfx_players.append(player)

    play_music()


func play_music() -> void:
    if not music_enabled or _music_player == null:
        return
    if _music_player.stream == null:
        _music_player.stream = _make_music_loop()
    if not _music_player.playing:
        _music_player.play()


func stop_music() -> void:
    if _music_player != null:
        _music_player.stop()


func play_event(event_id: StringName) -> void:
    if not sfx_enabled:
        return
    var config: Dictionary = _event_config(event_id)
    var cache_key: String = "%s:%s:%s" % [event_id, config["frequency"], config["duration"]]
    var stream: AudioStreamWAV = _tone_cache.get(cache_key) as AudioStreamWAV
    if stream == null:
        stream = _make_tone(float(config["frequency"]), float(config["duration"]), float(config["gain"]))
        _tone_cache[cache_key] = stream

    var player: AudioStreamPlayer = _next_sfx_player()
    if player == null:
        return
    player.pitch_scale = float(config.get("pitch", 1.0))
    player.stream = stream
    player.play()


func set_music_enabled(value: bool) -> void:
    music_enabled = value
    if music_enabled:
        play_music()
    else:
        stop_music()


func set_sfx_enabled(value: bool) -> void:
    sfx_enabled = value


func _next_sfx_player() -> AudioStreamPlayer:
    for player: AudioStreamPlayer in _sfx_players:
        if not player.playing:
            return player
    return _sfx_players[0] if not _sfx_players.is_empty() else null


func _event_config(event_id: StringName) -> Dictionary:
    match event_id:
        &"ui_click":
            return {"frequency": 520.0, "duration": 0.045, "gain": 0.24, "pitch": 1.0}
        &"build":
            return {"frequency": 660.0, "duration": 0.11, "gain": 0.30, "pitch": 1.0}
        &"upgrade":
            return {"frequency": 880.0, "duration": 0.14, "gain": 0.28, "pitch": 1.0}
        &"sell":
            return {"frequency": 390.0, "duration": 0.10, "gain": 0.24, "pitch": 0.92}
        &"wave_start":
            return {"frequency": 440.0, "duration": 0.18, "gain": 0.28, "pitch": 1.0}
        &"wave_clear":
            return {"frequency": 720.0, "duration": 0.20, "gain": 0.26, "pitch": 1.0}
        &"base_hit":
            return {"frequency": 150.0, "duration": 0.22, "gain": 0.34, "pitch": 0.85}
        &"boss_phase":
            return {"frequency": 115.0, "duration": 0.38, "gain": 0.38, "pitch": 1.0}
        &"victory":
            return {"frequency": 784.0, "duration": 0.42, "gain": 0.30, "pitch": 1.0}
        &"defeat":
            return {"frequency": 164.0, "duration": 0.52, "gain": 0.32, "pitch": 0.88}
        _:
            return {"frequency": 460.0, "duration": 0.07, "gain": 0.22, "pitch": 1.0}


func _make_tone(frequency: float, duration: float, gain: float) -> AudioStreamWAV:
    var frame_count: int = maxi(1, int(duration * float(SAMPLE_RATE)))
    var bytes: PackedByteArray = PackedByteArray()
    bytes.resize(frame_count * 2)

    for frame: int in range(frame_count):
        var time: float = float(frame) / float(SAMPLE_RATE)
        var attack: float = minf(1.0, time / 0.008)
        var release_time: float = float(frame_count - frame) / float(SAMPLE_RATE)
        var release: float = minf(1.0, release_time / 0.035)
        var envelope: float = attack * release
        var square_wave: float = 1.0 if sin(TAU * frequency * time) >= 0.0 else -1.0
        var sample: int = int(clampf(square_wave * envelope * gain, -1.0, 1.0) * 32767.0)
        bytes.encode_s16(frame * 2, sample)

    var stream: AudioStreamWAV = AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = SAMPLE_RATE
    stream.stereo = false
    stream.data = bytes
    return stream


func _make_music_loop() -> AudioStreamWAV:
    var note_frequencies: PackedFloat32Array = PackedFloat32Array([
        261.63, 329.63, 392.0, 329.63,
        293.66, 349.23, 440.0, 349.23,
        261.63, 329.63, 392.0, 523.25,
        293.66, 392.0, 349.23, 329.63,
    ])
    var note_duration: float = 0.32
    var frame_count: int = int(float(note_frequencies.size()) * note_duration * float(SAMPLE_RATE))
    var bytes: PackedByteArray = PackedByteArray()
    bytes.resize(frame_count * 2)

    for frame: int in range(frame_count):
        var time: float = float(frame) / float(SAMPLE_RATE)
        var note_index: int = mini(note_frequencies.size() - 1, int(time / note_duration))
        var note_time: float = fmod(time, note_duration)
        var frequency: float = note_frequencies[note_index]
        var envelope: float = minf(1.0, note_time / 0.025) * minf(1.0, (note_duration - note_time) / 0.06)
        var fundamental: float = sin(TAU * frequency * time)
        var harmonic: float = sin(TAU * frequency * 2.0 * time) * 0.18
        var sample_value: float = (fundamental + harmonic) * envelope * 0.10
        bytes.encode_s16(frame * 2, int(clampf(sample_value, -1.0, 1.0) * 32767.0))

    var stream: AudioStreamWAV = AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = SAMPLE_RATE
    stream.stereo = false
    stream.data = bytes
    stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
    stream.loop_begin = 0
    stream.loop_end = frame_count
    return stream


func _ensure_bus(bus_name: String) -> void:
    if AudioServer.get_bus_index(bus_name) >= 0:
        return
    AudioServer.add_bus()
    AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
