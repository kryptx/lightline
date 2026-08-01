extends Node
## Sound bank + music director. Sfx.play("pickup"), Sfx.play_music("music_band3").
## Three buses: Master <- Music, SFX. Volumes come from Game.settings.

const MUSIC_FADE := 2.0

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _ambience: AudioStreamPlayer
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_current := ""
var _music_front := true  # which of a/b is the live one

func _ready() -> void:
	_make_buses()
	for name in [
			"pickup", "relic", "hurt", "air", "bank", "death", "warn", "ui",
			"dash", "splash", "drop", "upgrade", "ambience",
			"sonar", "flare", "scan_tick", "scan_done", "roar", "stun", "bell",
			"core", "log", "creak", "eel", "choir", "gate", "douse", "relight",
			"deposit",
			"parasite_on", "parasite_off", "crush_warn", "crush_hit",
			"warden_heart", "warden_hit", "bloom",
			"music_band1", "music_band2", "music_band3", "music_band4",
			"music_band5", "music_hub", "music_finale", "music_credits",
			"ending_relight", "ending_cut", "ending_descend"]:
		var path := "res://assets/sfx/%s.wav" % name
		if ResourceLoader.exists(path):
			_streams[name] = load(path)
	for i in range(8):
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	_ambience = AudioStreamPlayer.new()
	_ambience.volume_db = -10.0
	_ambience.bus = "SFX"
	add_child(_ambience)
	_music_a = AudioStreamPlayer.new()
	_music_a.bus = "Music"
	add_child(_music_a)
	_music_b = AudioStreamPlayer.new()
	_music_b.bus = "Music"
	add_child(_music_b)
	apply_volumes()

func _make_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")

func apply_volumes() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.001, Game.settings.vol_master)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"),
			linear_to_db(maxf(0.001, Game.settings.vol_music)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"),
			linear_to_db(maxf(0.001, Game.settings.vol_sfx)))

# ---------- one-shots ----------
func play(name: String, volume_db: float = 0.0, pitch_jitter: float = 0.06) -> void:
	if not _streams.has(name):
		return
	for p in _players:
		if not p.playing:
			p.stream = _streams[name]
			p.volume_db = volume_db
			p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
			p.play()
			return

# ---------- music ----------
func _looped(name: String) -> AudioStreamWAV:
	var stream: AudioStreamWAV = _streams[name]
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	# loop_end is in SAMPLES. data.size()/2 only works for uncompressed PCM16;
	# Godot imports WAVs QOA-compressed by default, which made loops restart
	# ~1.6s in with a hard mid-waveform cut (an audible periodic click).
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	return stream

## Crossfade to a loop; no-op if it is already playing.
func play_music(name: String) -> void:
	if name == _music_current or not _streams.has(name):
		return
	_music_current = name
	var incoming := _music_b if _music_front else _music_a
	var outgoing := _music_a if _music_front else _music_b
	_music_front = not _music_front
	incoming.stream = _looped(name)
	incoming.volume_db = -40.0
	incoming.play()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(incoming, "volume_db", 0.0, MUSIC_FADE)
	if outgoing.playing:
		tween.tween_property(outgoing, "volume_db", -40.0, MUSIC_FADE)
		tween.chain().tween_callback(outgoing.stop)

func stop_music(fade := 1.0) -> void:
	_music_current = ""
	for p in [_music_a, _music_b]:
		if p.playing:
			var tween := create_tween()
			tween.tween_property(p, "volume_db", -40.0, fade)
			tween.tween_callback(p.stop)

# ---------- underwater bed ----------
func start_ambience() -> void:
	if not _streams.has("ambience") or _ambience.playing:
		return
	_ambience.stream = _looped("ambience")
	_ambience.play()

func stop_ambience() -> void:
	_ambience.stop()
