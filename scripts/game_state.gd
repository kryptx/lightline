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

const BANDS := {
	1: {"name": "THE SHALLOWS", "suit": 1},
	2: {"name": "THE MIDDENS", "suit": 2},
	3: {"name": "THE CATHEDRAL", "suit": 3},
}
## Suit tiers gate the depth bands. Buying a tier needs the previous Keeper's
## pressure core plus relics.
const SUIT_TIERS := {
	2: {"relics": 4, "core": 1, "label": "Suit II — Middens-rated"},
	3: {"relics": 8, "core": 2, "label": "Suit III — Cathedral-rated"},
}
const ABILITY_ORDER := ["sonar", "flare", "anchor"]
const ABILITIES := {
	"sonar": {
		"title": "Sonar Pulse", "key_hint": "pulse",
		"costs": [3, 4, 6],  # relics per rank
		"ranks": [
			"Ping reveals pickups and threats ~350px through the dark.",
			"Longer ping (~550px) that reads through rock.",
			"The ping staggers predators for a moment.",
		],
	},
	"flare": {
		"title": "Flare", "key_hint": "throw",
		"costs": [2, 4, 6],
		"ranks": [
			"Throw a burning light. Predators are lured to it.",
			"Burns twice as long and drifts upward.",
			"White flare: predators flee it instead.",
		],
	},
	"anchor": {
		"title": "Anchor", "key_hint": "place / deposit",
		"costs": [3, 5, 7],
		"ranks": [
			"Place an anchor; cargo deposited there survives your death.",
			"Depositing cargo also steadies the line (+15% light).",
			"Deposited cargo is banked instantly up the line.",
		],
	},
}
const SPECIES_ORDER := ["fish_teal", "fish_rose", "urchin", "lanternjaw", "eel", "choir"]
const SPECIES := {
	"fish_teal": {"title": "Glimmerfin", "passive": "You read their slipstream: +8% swim speed."},
	"fish_rose": {"title": "Rosefin", "passive": "You notice what they nose at: pickups glint brighter and farther."},
	"urchin": {"title": "Pinlight Urchin", "passive": "You know where the spines aren't: urchin stings cost half the light."},
	"lanternjaw": {"title": "Lanternjaw", "passive": "Its lure no longer fools you — false lights burn red in your eye."},
	"eel": {"title": "Midden Eel", "passive": "You count its coil: eels telegraph longer before striking."},
	"choir": {"title": "The Choir", "passive": "You hear the hymn's shape: their song rings visibly farther, and panics you half as much."},
}

var stats := {"lungs": 0, "beam": 0, "grip": 0, "fins": 0, "nerve": 0}
var salvage := 25
var relics := 0
var dive_count := 0
var best_depth_m := 0.0
var total_banked := 0
# --- alpha progression (knowledge survives death; all saved) ---
var suit_tier := 1
var cores := []            # pressure cores held, e.g. [1, 2]
var keepers_defeated := [] # keeper ids
var abilities := {"sonar": 0, "flare": 0, "anchor": 0}  # owned ranks 0..3
var equipped := ["", ""]   # ability ids in slots Q / R
var bestiary := []         # scanned species ids
var logs_found := []       # log ids 1..15
var anchor_stash := {}     # {"x","y","salvage","relics"} surviving cargo
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
var spawn_depth_m := 0.0
var test_keeper := 0
var _fresh := false

var _post_load_overrides: Array[Callable] = []

func _ready() -> void:
	_setup_input()
	_parse_args()
	load_game()
	# debug overrides must win over whatever the save file says
	for override in _post_load_overrides:
		override.call()

# ---------- derived stats ----------
func max_light() -> float:
	return 70.0 + 9.0 * stats.lungs

func beam_radius() -> float:
	return 150.0 + 20.0 * stats.beam

func carry_capacity() -> int:
	return 8 + 3 * stats.grip

func swim_speed() -> float:
	var speed: float = 200.0 + 13.0 * stats.fins
	if has_scan("fish_teal"):
		speed *= 1.08
	return speed

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

# ---------- knowledge, gear, suits ----------
func has_scan(species: String) -> bool:
	return species in bestiary

func record_scan(species: String) -> bool:
	if species in bestiary:
		return false
	bestiary.append(species)
	save_game()
	return true

func record_log(id: int) -> void:
	if not logs_found.has(id):
		logs_found.append(id)
		logs_found.sort()
		save_game()

## The next log Marlowe left in a given band (logs are found in order per band).
func next_log_for_band(band: int) -> int:
	var pool: Array = Logs.BAND_LOGS.get(band, [])
	for id in pool:
		if not logs_found.has(id):
			return id
	return -1

func keeper_defeated(id: int) -> bool:
	return keepers_defeated.has(id)

func record_keeper(id: int) -> void:
	if not keepers_defeated.has(id):
		keepers_defeated.append(id)
		if not cores.has(id):
			cores.append(id)
		relics += 2
		save_game()

func can_buy_suit(tier: int) -> bool:
	if tier != suit_tier + 1 or not SUIT_TIERS.has(tier):
		return false
	var req: Dictionary = SUIT_TIERS[tier]
	return relics >= req.relics and cores.has(req.core)

func buy_suit(tier: int) -> bool:
	if not can_buy_suit(tier):
		return false
	relics -= SUIT_TIERS[tier].relics
	suit_tier = tier
	save_game()
	return true

func ability_rank(id: String) -> int:
	return int(abilities.get(id, 0))

func ability_cost(id: String) -> int:
	var rank := ability_rank(id)
	if rank >= 3:
		return -1
	return ABILITIES[id].costs[rank]

func can_buy_ability(id: String) -> bool:
	var cost := ability_cost(id)
	return cost > 0 and relics >= cost

func buy_ability(id: String) -> bool:
	if not can_buy_ability(id):
		return false
	relics -= ability_cost(id)
	abilities[id] += 1
	# owning your first ability auto-equips it
	if abilities[id] == 1:
		if equipped[0] == "":
			equipped[0] = id
		elif equipped[1] == "":
			equipped[1] = id
	save_game()
	return true

func equip_ability(id: String, slot: int) -> void:
	if ability_rank(id) <= 0:
		return
	var other := 1 - slot
	if equipped[other] == id:
		equipped[other] = ""
	equipped[slot] = id
	save_game()

## The "next time" hint: nearest unpurchased upgrade.
func next_goal_hint() -> String:
	if can_buy_suit(suit_tier + 1):
		return "The pressure core hums in the workshop. %s is ready to be fitted." % SUIT_TIERS[suit_tier + 1].label
	if SUIT_TIERS.has(suit_tier + 1) and cores.has(SUIT_TIERS[suit_tier + 1].core):
		return "You hold the core for %s — %d more relics to fit it." % [
			SUIT_TIERS[suit_tier + 1].label, SUIT_TIERS[suit_tier + 1].relics - relics]
	if suit_tier < 3 and not keeper_defeated(suit_tier):
		return "Something big guards the floor of %s. Its core would rate your suit deeper." % BANDS[suit_tier].name.capitalize()
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
		"suit_tier": suit_tier,
		"cores": cores,
		"keepers_defeated": keepers_defeated,
		"abilities": abilities,
		"equipped": equipped,
		"bestiary": bestiary,
		"logs_found": logs_found,
		"anchor_stash": anchor_stash,
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
	suit_tier = int(parsed.get("suit_tier", 1))
	cores = _int_array(parsed.get("cores", []))
	keepers_defeated = _int_array(parsed.get("keepers_defeated", []))
	var ab = parsed.get("abilities", {})
	if typeof(ab) == TYPE_DICTIONARY:
		for id in ABILITY_ORDER:
			abilities[id] = int(ab.get(id, 0))
	var eq = parsed.get("equipped", ["", ""])
	if typeof(eq) == TYPE_ARRAY and eq.size() == 2:
		equipped = [str(eq[0]), str(eq[1])]
	bestiary = []
	for s in parsed.get("bestiary", []):
		bestiary.append(str(s))
	logs_found = _int_array(parsed.get("logs_found", []))
	var stash = parsed.get("anchor_stash", {})
	anchor_stash = stash if typeof(stash) == TYPE_DICTIONARY else {}

func _int_array(raw) -> Array:
	var out := []
	if typeof(raw) == TYPE_ARRAY:
		for v in raw:
			out.append(int(v))
	return out

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
		elif arg.begins_with("--suit="):  # debug
			var tier := clampi(int(arg.trim_prefix("--suit=")), 1, 3)
			_post_load_overrides.append(func() -> void: suit_tier = tier)
		elif arg.begins_with("--relics="):  # debug
			var amount := int(arg.trim_prefix("--relics="))
			_post_load_overrides.append(func() -> void: relics = amount)
		elif arg.begins_with("--spawn-depth="):  # debug: start the dive this deep (m)
			spawn_depth_m = float(arg.trim_prefix("--spawn-depth="))
		elif arg == "--scan-all":  # debug
			_post_load_overrides.append(func() -> void: bestiary = SPECIES_ORDER.duplicate())
		elif arg.begins_with("--test-keeper="):  # debug: autopilot fights keeper N
			test_keeper = int(arg.trim_prefix("--test-keeper="))
		elif arg.begins_with("--stat="):  # debug: --stat=lungs:10
			var kv := arg.trim_prefix("--stat=").split(":")
			_post_load_overrides.append(func() -> void: stats[kv[0]] = int(kv[1]))
		elif arg.begins_with("--ability="):  # debug: --ability=sonar:3
			var parts := arg.trim_prefix("--ability=").split(":")
			_post_load_overrides.append(func() -> void:
				abilities[parts[0]] = int(parts[1])
				if equipped[0] == "":
					equipped[0] = parts[0]
				elif equipped[1] == "" and not parts[0] in equipped:
					equipped[1] = parts[0])
		elif arg == "--fresh":
			_fresh = true
			if FileAccess.file_exists(SAVE_PATH):
				DirAccess.remove_absolute(SAVE_PATH)

func _setup_input() -> void:
	_action("move_left", [KEY_A, KEY_LEFT], JOY_AXIS_LEFT_X, -1.0)
	_action("move_right", [KEY_D, KEY_RIGHT], JOY_AXIS_LEFT_X, 1.0)
	_action("move_up", [KEY_W, KEY_UP], JOY_AXIS_LEFT_Y, -1.0)
	_action("move_down", [KEY_S, KEY_DOWN], JOY_AXIS_LEFT_Y, 1.0)
	_action("dash", [KEY_SHIFT], JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_action("tether", [KEY_SPACE], -1, 0.0, JOY_BUTTON_A)
	_action("drop", [KEY_G], -1, 0.0, JOY_BUTTON_DPAD_DOWN)
	_action("interact", [KEY_E], -1, 0.0, JOY_BUTTON_X)
	_action("ability_1", [KEY_Q], -1, 0.0, JOY_BUTTON_LEFT_SHOULDER)
	_action("ability_2", [KEY_R], -1, 0.0, JOY_BUTTON_RIGHT_SHOULDER)
	_action("douse", [KEY_F], -1, 0.0, JOY_BUTTON_Y)

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
