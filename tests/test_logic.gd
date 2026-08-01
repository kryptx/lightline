extends SceneTree
## Headless checks of the economy/progression logic.
## Run: godot --headless --path . -s tests/test_logic.gd -- --fresh

var failures := 0

func check(cond: bool, label: String) -> void:
	if cond:
		print("  ok  ", label)
	else:
		failures += 1
		push_error("FAIL  " + label)

func _init() -> void:
	# Game autoload isn't up when -s runs; instance it manually.
	var game = load("res://scripts/game_state.gd").new()
	game._fresh = true
	game.name = "Game"
	root.add_child(game)

	print("-- derived stats --")
	check(game.max_light() == 70.0, "base max light 70s")
	game.stats.lungs = 10
	check(game.max_light() == 160.0, "lungs 10 -> 160s")
	game.stats.lungs = 0
	check(game.carry_capacity() == 8, "base capacity 8")
	check(game.stat_cost("lungs") == 18, "rank-0 cost 18")

	print("-- buying --")
	game.salvage = 40
	check(game.buy_stat("lungs"), "can buy at 40 salvage")
	check(game.salvage == 22, "cost deducted")
	check(game.stats.lungs == 1, "rank applied")
	check(game.stat_cost("lungs") == 32, "rank-1 cost curve")
	game.salvage = 0
	check(not game.buy_stat("beam"), "cannot buy broke")

	print("-- respec --")
	game.salvage = 50
	check(game.spent_on_stats() == 18, "spent tracker")
	check(game.respec(), "respec succeeds")
	check(game.stats.lungs == 0, "ranks cleared")
	check(game.salvage == 50 + 18 - 10, "refund minus fee")

	print("-- banking --")
	var before = game.salvage
	game.bank_dive(30, 2, 120.0, 300.0, false)
	check(game.salvage == before + 30, "salvage banked")
	check(game.relics == 2, "relics banked")
	check(game.best_depth_m == 120.0, "best depth")
	check(not game.last_result.died, "ledger says survived")

	print("-- death --")
	game.record_death(Vector2(500, 900), 40, 1, 200.0, 250.0, "test reason")
	check(game.salvage == before + 30 + 4, "stipend = 10% of 40")
	check(game.pending_net.salvage == 40, "net holds salvage")
	check(game.pending_net.relics == 1, "net holds relics")
	check(game.last_result.died, "ledger says died")
	var net = game.take_pending_net()
	check(net.x == 500.0, "net position")
	check(game.pending_net.is_empty(), "net taken exactly once")

	print("-- death with empty hands --")
	game.record_death(Vector2(1, 1), 0, 0, 50.0, 60.0, "r")
	check(game.pending_net.is_empty(), "no net when nothing carried")
	check(game.last_result.salvage == 3, "minimum stipend 3")

	print("-- keepers & suits --")
	check(not game.can_buy_suit(2), "suit II blocked without core")
	game.record_keeper(1)
	check(game.cores.has(1), "core 1 held after keeper 1")
	check(game.keeper_defeated(1), "keeper 1 marked dead")
	var relics_before = game.relics
	game.record_keeper(1)
	check(game.relics == relics_before, "keeper kill only counts once")
	game.relics = 4
	check(game.can_buy_suit(2), "suit II purchasable with core + 4 relics")
	check(not game.can_buy_suit(3), "cannot skip to suit III")
	check(game.buy_suit(2), "suit II fitted")
	check(game.suit_tier == 2 and game.relics == 0, "relics spent on suit")

	print("-- abilities --")
	game.relics = 3
	check(game.ability_cost("sonar") == 3, "sonar rank 1 costs 3")
	check(game.buy_ability("sonar"), "sonar learned")
	check(game.equipped[0] == "sonar", "first ability auto-equips to Q")
	check(not game.can_buy_ability("sonar"), "cannot afford rank 2")
	game.relics = 10
	check(game.buy_ability("flare"), "flare learned")
	check(game.equipped[1] == "flare", "second ability auto-equips to R")
	game.equip_ability("flare", 0)
	check(game.equipped[0] == "flare" and game.equipped[1] == "", "re-equip moves slot")

	print("-- bestiary --")
	check(game.record_scan("lanternjaw"), "first scan recorded")
	check(not game.record_scan("lanternjaw"), "second scan is a no-op")
	check(game.has_scan("lanternjaw"), "scan queryable")
	var base_speed = 200.0 + 13.0 * game.stats.fins
	game.record_scan("fish_teal")
	check(absf(game.swim_speed() - base_speed * 1.08) < 0.01, "glimmerfin passive applies")

	print("-- logs --")
	check(game.next_log_for_band(1) == 1, "band 1 starts at log 1")
	game.record_log(1)
	game.record_log(1)
	check(game.logs_found == [1], "log dedup")
	check(game.next_log_for_band(1) == 2, "band 1 advances to log 2")
	check(game.next_log_for_band(3) == 12, "band 3 starts at log 12")
	for id in [12, 13, 14, 15]:
		game.record_log(id)
	check(game.next_log_for_band(3) == -1, "band 3 exhausts")

	print("-- suits IV and V --")
	game.suit_tier = 3
	game.record_keeper(3)
	game.record_keeper(4)
	game.relics = 30
	check(game.can_buy_suit(4), "suit IV purchasable with core 3")
	check(game.buy_suit(4), "suit IV fitted")
	check(game.can_buy_suit(5), "suit V purchasable with core 4")
	check(game.buy_suit(5), "suit V fitted")
	check(not game.SUIT_TIERS.has(6), "no suit VI")

	print("-- assists --")
	check(game.drain_scale() == 1.0, "drain assist off by default")
	game.settings.drain_assist = 2
	check(game.drain_scale() == 0.5, "drain assist -50%")
	game.settings.drain_assist = 0
	check(game.fauna_speed_scale() == 1.0, "fauna full speed by default")
	game.settings.gentle_fauna = true
	check(game.fauna_speed_scale() == 0.7, "gentle fauna 30% slower")
	game.settings.gentle_fauna = false
	game.settings.panic_off = true
	check(game.panic_gain_scale() == 0.0, "panic off zeroes panic gain")
	game.settings.panic_off = false

	print("-- endings --")
	check(game.endings_seen.is_empty(), "no endings at start")
	game.record_ending("cut")
	game.record_ending("cut")
	check(game.endings_seen == ["cut"], "ending dedup")
	check(game.last_ending == "cut", "epilogue tracks last ending")
	game.record_ending("relight")
	check(game.endings_seen.size() == 2, "second ending recorded")

	print("-- beta logs --")
	check(game.next_log_for_band(4) == 16, "band 4 starts at log 16")
	check(game.next_log_for_band(5) == 21, "band 5 starts at log 21")
	for id in range(16, 25):
		check(Logs.ENTRIES.has(id), "log %d exists" % id)

	print("-- hint --")
	game.endings_seen = []
	check("floor of the Throat" in game.next_goal_hint(), "suit V hint points at the finale")
	game.endings_seen = ["cut"]
	check("choose differently" in game.next_goal_hint(), "post-ending hint invites replay")
	game.relics = 0
	game.suit_tier = 1
	game.keepers_defeated = []
	game.cores = []
	game.endings_seen = []
	check("guards the floor" in game.next_goal_hint(), "hint points at the keeper")
	game.cores = [1]
	check("core" in game.next_goal_hint(), "hint points at held core")

	if failures == 0:
		print("ALL PASS")
	else:
		print("%d FAILURES" % failures)
	quit(1 if failures > 0 else 0)
