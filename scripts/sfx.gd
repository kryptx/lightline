extends Node
## Tiny sound bank. Sfx.play("pickup") from anywhere.

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _ambience: AudioStreamPlayer

func _ready() -> void:
	for name in ["pickup", "relic", "hurt", "air", "bank", "death", "warn", "ui",
			"dash", "splash", "drop", "upgrade", "ambience"]:
		var path := "res://assets/sfx/%s.wav" % name
		if ResourceLoader.exists(path):
			_streams[name] = load(path)
	for i in range(8):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	_ambience = AudioStreamPlayer.new()
	_ambience.volume_db = -10.0
	add_child(_ambience)

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

func start_ambience() -> void:
	if not _streams.has("ambience") or _ambience.playing:
		return
	var stream: AudioStreamWAV = _streams["ambience"]
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = stream.data.size() / 2
	_ambience.stream = stream
	_ambience.play()

func stop_ambience() -> void:
	_ambience.stop()
