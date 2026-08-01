class_name Autopilot
## Demo/soak-test pilot (--autodive / --test-keeper=N). Not used in normal
## play. "loot" mode plays the real loop: seek pickups (logs and the corpse
## net are worth detours), reel for the surface when the return budget gets
## tight. "fight" mode plays a keeper arena: lure the charge across an armed
## stunner, then dash the exposed weakpoint.

var player: Player
var reel := false
var _drift := 0.0
var _stuck_t := 0.0
var _unstick_until := 0.0
var _unstick_dir := Vector2.ZERO
var _valve_pressed := false

func _init(p: Player) -> void:
	player = p

func dir(delta: float) -> Vector2:
	if player.auto_mode == "fight":
		return _fight(delta)
	if player.auto_mode == "finale":
		return _finale(delta)
	return _loot(delta)

# ---------- finale ----------
func _finale(delta: float) -> Vector2:
	# same corner-blundering escape the fight bot uses
	_stuck_t = _stuck_t + delta if player.velocity.length() < 14.0 else 0.0
	if _unstick_until > 0.0:
		_unstick_until -= delta
		return _unstick_dir
	if _stuck_t > 1.2:
		_stuck_t = 0.0
		_unstick_until = 0.55
		_unstick_dir = Vector2(randf_range(-1, 1), randf_range(-0.4, 1)).normalized()
		return _unstick_dir
	if _valve_pressed:
		Input.action_release("interact")
		_valve_pressed = false
	var finale := player.get_parent()
	var target: Vector2
	match Game.test_finale:
		"cut":
			target = finale.line_pos
		"relight":
			target = finale.anchor_pos
		_:
			target = finale.maw_pos
	if target == Vector2.ZERO:
		return Vector2(0, 1)
	var to_target := target - player.global_position
	if to_target.length() < 40.0 and Game.test_finale in ["cut", "relight"]:
		Input.action_press("interact")
		_valve_pressed = true
		return to_target.normalized() * 0.3
	return to_target.normalized()

# ---------- loot ----------
func _loot(delta: float) -> Vector2:
	_drift += delta
	if Game.ability_rank("sonar") > 0 and player.ability_cd.get("sonar", 0.0) <= 0.0 \
			and player.depth_m() > 30.0 and "sonar" in Game.equipped:
		player.use_ability(Game.equipped.find("sonar"))
	# don't dive below the suit rating (greedy mode ignores even this)
	var dive := player.get_parent()
	if not Game.greedy and player.global_position.y > dive.rated_max_y - 100.0:
		reel = true
	# bank when the margin closes (greedy mode never turns back, on purpose)
	if Game.greedy:
		reel = false
	elif reel or player.return_cost_s() > player.light - 14.0:
		reel = true
		return Vector2(sin(_drift * 2.0) * 0.3, -1.0)
	var target: Node2D = null
	if dive.net_pickup != null and is_instance_valid(dive.net_pickup):
		target = dive.net_pickup
	else:
		var best := 320.0
		for node in player.get_tree().get_nodes_in_group("pickups"):
			var p := node as Node2D
			if p == null or not is_instance_valid(p):
				continue
			var d := player.global_position.distance_to(p.global_position)
			if p.is_in_group("logs"):
				d *= 0.35  # a recording is worth a detour
			if d < best:
				best = d
				target = p
	if target:
		return (target.global_position - player.global_position).normalized()
	return Vector2(sin(_drift * 1.4) * 0.8, 1.0).normalized()

# ---------- fight ----------
func _fight(delta: float) -> Vector2:
	_drift += delta
	# blunder out of corners when wedged against geometry
	_stuck_t = _stuck_t + delta if player.velocity.length() < 14.0 else 0.0
	if _unstick_until > 0.0:
		_unstick_until -= delta
		return _unstick_dir
	if _stuck_t > 1.4:
		_stuck_t = 0.0
		_unstick_until = 0.6
		_unstick_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		return _unstick_dir
	if _valve_pressed:
		Input.action_release("interact")
		_valve_pressed = false
	# occasionally ping to exercise sonar in fight tests too
	if Game.ability_rank("sonar") > 0 and player.ability_cd.get("sonar", 0.0) <= 0.0:
		player.use_ability(Game.equipped.find("sonar"))

	var keeper: Keeper = null
	var keeper_d := 1e12
	for k in player.get_tree().get_nodes_in_group("keepers"):
		var d: float = player.global_position.distance_to((k as Node2D).global_position)
		if d < keeper_d:
			keeper_d = d
			keeper = k
	if keeper == null:
		reel = true
		return Vector2(0, -1)

	if keeper.state == "stunned":
		var to_boss := keeper.global_position - player.global_position
		if to_boss.length() < 130.0:
			player.try_dash(to_boss.normalized(), 1.2)
		return to_boss.normalized()

	# find an armed stunner in THIS keeper's arena; if none (bellringer), go
	# work a valve
	var prop: Node2D = null
	var best := 1e9
	for s in player.get_tree().get_nodes_in_group("stunners"):
		if not s.armed:
			continue
		if not keeper.arena.grow(80.0).has_point((s as Node2D).global_position):
			continue
		var d: float = keeper.global_position.distance_to(s.global_position)
		if d < best:
			best = d
			prop = s
	if prop == null:
		var dive := player.get_parent()
		# the Gardener's blooms answer to a flare
		if dive.valves.is_empty() and Game.ability_rank("flare") > 0 \
				and player.ability_cd.get("flare", 0.0) <= 0.0 and "flare" in Game.equipped:
			player.use_ability(Game.equipped.find("flare"))
		if not dive.valves.is_empty():
			var valve: Node2D = null
			var vd := 1e12
			for v in dive.valves:
				var d: float = player.global_position.distance_to((v.node as Node2D).position)
				if d < vd:
					vd = d
					valve = v.node
			var to_valve := valve.position - player.global_position
			if to_valve.length() < 32.0:
				Input.action_press("interact")
				_valve_pressed = true
				return Vector2.ZERO
			return to_valve.normalized()
		return Vector2(sin(_drift * 2.0), cos(_drift * 1.7)).normalized() * 0.6

	# hover just past the prop so the charge crosses it
	var lure_pos: Vector2 = prop.global_position \
			+ (prop.global_position - keeper.global_position).normalized() * 46.0
	var to_lure := lure_pos - player.global_position
	if to_lure.length() <= 14.0:
		# the Cantor hunts noise: kick up a burst right here by the pipe
		if Keeper.CONFIG[keeper.id].target == "noise" and keeper.state == "idle":
			player.try_dash((player.global_position - keeper.global_position).normalized(), 1.0)
		return Vector2.ZERO
	return to_lure.normalized()
