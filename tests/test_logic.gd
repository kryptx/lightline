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

	print("-- hint --")
	check(game.next_goal_hint().length() > 10, "hint is a sentence")

	if failures == 0:
		print("ALL PASS")
	else:
		print("%d FAILURES" % failures)
	quit(1 if failures > 0 else 0)
