extends Node
## Persistent game state: stats, currencies, corpse net, save/load.

const SAVE_PATH := "user://save.json"
const PX_PER_M := 8.0

const STAT_ORDER := ["lungs", "beam", "grip", "fins", "nerve"]
const STAT_INFO := {
	"lungs": {"title": "Lungs", "desc": "Max Lightline — how long a dive can last."},
	"beam": {"title": "Beam", "desc": "Light radius and how far pickups glint."},
	"grip": {"title": "Grip", "desc": "Carry weight before the light-drain penalty."},
	"fins": {"title": "Fins", "desc": "Swim speed and reel-in speed."},
	"nerve": {"title": "Nerve", "desc": "Panic sets in slower and fades faster."},
}
const MAX_RANK := 10

var stats := {"lungs": 0, "beam": 0, "grip": 0, "fins": 0, "nerve": 0}
var salvage := 25
var relics := 0
var dive_count := 0
var best_depth_m := 0.0
var total_banked := 0
## Corpse net: {"x": float, "y": float, "salvage": int, "relics": int, "depth_m": float}
var pending_net := {}
## Ledger for the last dive, shown at the lighthouse.
var last_result := {}
var autoplay := false
var shot_path := ""
var shot_hub_path := ""
var shot_delay := 3.0
var timescale := 1.0
var greedy := false
var _fresh := false

func _ready() -> void:
	_setup_input()
	_parse_args()
	load_game()

# ---------- derived stats ----------
func max_light() -> float:
	return 70.0 + 9.0 * stats.lungs

func beam_radius() -> float:
	return 150.0 + 20.0 * stats.beam

func carry_capacity() -> int:
	return 8 + 3 * stats.grip

func swim_speed() -> float:
	return 200.0 + 13.0 * stats.fins

func reel_speed() -> float:
	return 230.0 + 9.0 * stats.fins

func panic_gain_scale() -> float:
	return 1.0 / (1.0 + 0.18 * stats.nerve)

func stat_cost(stat: String) -> int:
	var rank: int = stats[stat]
	return int(round(18.0 + pow(rank, 2.15) * 14.0))

func can_buy(stat: String) -> bool:
	return stats[stat] < MAX_RANK and salvage >= stat_cost(stat)

func buy_stat(stat: String) -> bool:
	if not can_buy(stat):
		return false
	salvage -= stat_cost(stat)
	stats[stat] += 1
	save_game()
	return true

func respec_cost() -> int:
	return 10

func spent_on_stats() -> int:
	var total := 0
	for stat in STAT_ORDER:
		for rank in range(stats[stat]):
			total += int(round(18.0 + pow(rank, 2.15) * 14.0))
	return total

func respec() -> bool:
	var refund := spent_on_stats()
	if refund == 0 or salvage < respec_cost():
		return false
	salvage += refund - respec_cost()
	for stat in STAT_ORDER:
		stats[stat] = 0
	save_game()
	return true

## The "next time" hint: nearest unpurchased upgrade.
func next_goal_hint() -> String:
	var best_stat := ""
	var best_cost := 1 << 30
	for stat in STAT_ORDER:
		if stats[stat] < MAX_RANK and stat_cost(stat) < best_cost:
			best_cost = stat_cost(stat)
			best_stat = stat
	if best_stat == "":
		return "Every stat is at its capstone. The deep is waiting."
	var need: int = best_cost - salvage
	if need <= 0:
		return "%s rank %d is affordable right now." % [STAT_INFO[best_stat].title, stats[best_stat] + 1]
	return "Next time: %d more salvage buys %s rank %d." % [need, STAT_INFO[best_stat].title, stats[best_stat] + 1]

# ---------- dive outcomes ----------
func bank_dive(salv: int, rel: int, depth_m: float, duration: float, net_recovered: bool) -> void:
	salvage += salv
	relics += rel
	total_banked += salv
	dive_count += 1
	best_depth_m = max(best_depth_m, depth_m)
	last_result = {
		"died": false,
		"salvage": salv,
		"relics": rel,
		"depth_m": depth_m,
		"duration": duration,
		"net_recovered": net_recovered,
	}
	save_game()

func record_death(pos: Vector2, salv: int, rel: int, depth_m: float, duration: float, reason: String) -> void:
	var stipend := maxi(3, int(salv * 0.1))
	salvage += stipend
	dive_count += 1
	best_depth_m = max(best_depth_m, depth_m)
	if salv > 0 or rel > 0:
		pending_net = {
			"x": pos.x, "y": pos.y,
			"salvage": salv, "relics": rel,
			"depth_m": depth_m,
		}
	last_result = {
		"died": true,
		"salvage": stipend,
		"relics": 0,
		"lost_salvage": salv,
		"lost_relics": rel,
		"depth_m": depth_m,
		"duration": duration,
		"reason": reason,
	}
	save_game()

## Called when a dive begins: the net only holds for exactly one dive.
func take_pending_net() -> Dictionary:
	var net := pending_net
	pending_net = {}
	save_game()
	return net

# ---------- persistence ----------
func save_game() -> void:
	var data := {
		"stats": stats,
		"salvage": salvage,
		"relics": relics,
		"dive_count": dive_count,
		"best_depth_m": best_depth_m,
		"total_banked": total_banked,
		"pending_net": pending_net,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))

func load_game() -> void:
	if _fresh or not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	for stat in STAT_ORDER:
		if parsed.has("stats") and parsed.stats.has(stat):
			stats[stat] = int(parsed.stats[stat])
	salvage = int(parsed.get("salvage", salvage))
	relics = int(parsed.get("relics", relics))
	dive_count = int(parsed.get("dive_count", 0))
	best_depth_m = float(parsed.get("best_depth_m", 0.0))
	total_banked = int(parsed.get("total_banked", 0))
	var net = parsed.get("pending_net", {})
	pending_net = net if typeof(net) == TYPE_DICTIONARY else {}

# ---------- input & args ----------
func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--autodive":
			autoplay = true
		elif arg.begins_with("--shot="):
			shot_path = arg.trim_prefix("--shot=")
		elif arg.begins_with("--shot-hub="):
			shot_hub_path = arg.trim_prefix("--shot-hub=")
		elif arg.begins_with("--shot-delay="):
			shot_delay = float(arg.trim_prefix("--shot-delay="))
		elif arg.begins_with("--timescale="):
			timescale = float(arg.trim_prefix("--timescale="))
		elif arg == "--greedy":
			greedy = true
		elif arg == "--fresh":
			_fresh = true
			if FileAccess.file_exists(SAVE_PATH):
				DirAccess.remove_absolute(SAVE_PATH)

func _setup_input() -> void:
	_action("move_left", [KEY_A, KEY_LEFT], JOY_AXIS_LEFT_X, -1.0)
	_action("move_right", [KEY_D, KEY_RIGHT], JOY_AXIS_LEFT_X, 1.0)
	_action("move_up", [KEY_W, KEY_UP], JOY_AXIS_LEFT_Y, -1.0)
	_action("move_down", [KEY_S, KEY_DOWN], JOY_AXIS_LEFT_Y, 1.0)
	_action("dash", [KEY_SHIFT], -1, 0.0, JOY_BUTTON_RIGHT_SHOULDER)
	_action("tether", [KEY_SPACE], -1, 0.0, JOY_BUTTON_A)
	_action("drop", [KEY_G], -1, 0.0, JOY_BUTTON_DPAD_DOWN)
	_action("interact", [KEY_E], -1, 0.0, JOY_BUTTON_X)

func _action(name: String, keys: Array, axis: int = -1, axis_value: float = 0.0, button: int = -1) -> void:
	if InputMap.has_action(name):
		return
	InputMap.add_action(name, 0.2)
	for key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event(name, ev)
	if axis >= 0:
		var motion := InputEventJoypadMotion.new()
		motion.axis = axis
		motion.axis_value = axis_value
		InputMap.action_add_event(name, motion)
	if button >= 0:
		var btn := InputEventJoypadButton.new()
		btn.button_index = button
		InputMap.action_add_event(name, btn)
