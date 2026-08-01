class_name GravityWell
extends Node2D
## The Throat's bent water: a slow whirl that pulls whatever swims too close.
## Swim the rim, never the eye — or dash across the current.

const RADIUS := 140.0
const PULL := 430.0

var swirl: Sprite2D
var hum: AudioStreamPlayer2D

static func make(at: Vector2) -> GravityWell:
	var w := GravityWell.new()
	w.position = at
	return w

func _ready() -> void:
	z_index = 3
	swirl = Sprite2D.new()
	swirl.texture = load("res://assets/gravity_well.png")
	swirl.scale = Vector2(RADIUS / 48.0, RADIUS / 48.0)
	swirl.modulate = Color(1, 1, 1, 0.75)
	add_child(swirl)
	var dark := PointLight2D.new()
	dark.texture = load("res://assets/halo.png")
	dark.scale = Vector2(0.35, 0.35)
	dark.energy = 0.25
	dark.color = Color(0.5, 0.55, 0.9)
	add_child(dark)
	hum = AudioStreamPlayer2D.new()
	var stream: AudioStreamWAV = load("res://assets/sfx/well_hum.wav")
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = stream.data.size() / 2
	hum.stream = stream
	hum.volume_db = -10.0
	hum.max_distance = 500.0
	hum.bus = "SFX"
	add_child(hum)
	hum.play()

func _process(delta: float) -> void:
	swirl.rotation += delta * 1.4
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null or player.dead:
		return
	var to_center := position - player.global_position
	var dist := to_center.length()
	if dist < RADIUS:
		var strength: float = PULL * (1.0 - dist / RADIUS * 0.55)
		# the pull curls: part inward, part around the eye
		var pull_dir := to_center.normalized()
		var swirl_dir := Vector2(-pull_dir.y, pull_dir.x)
		player.velocity += (pull_dir * strength + swirl_dir * strength * 0.35) * delta
