extends GutTest

var gs: Node


func before_each() -> void:
	gs = GameState


func test_take_damage() -> void:
	gs.run_hp = 100
	gs.run_max_hp = 100
	gs.take_damage(30)
	assert_eq(gs.run_hp, 70, "HP should decrease by damage amount")


func test_take_damage_below_zero() -> void:
	gs.run_hp = 10
	gs.take_damage(50)
	assert_true(gs.run_hp <= 0, "HP should go to 0 or below after fatal damage")


func test_heal() -> void:
	gs.run_hp = 50
	gs.run_max_hp = 100
	gs.heal(30)
	assert_eq(gs.run_hp, 80, "HP should increase by heal amount")


func test_heal_no_exceed_max() -> void:
	gs.run_hp = 90
	gs.run_max_hp = 100
	gs.heal(50)
	assert_eq(gs.run_hp, 100, "HP should not exceed max_hp")


func test_add_gold() -> void:
	gs.run_gold = 10
	gs.add_gold(25)
	assert_eq(gs.run_gold, 35, "Gold should increase by amount")


func test_is_player_dead_when_alive() -> void:
	gs.run_hp = 50
	assert_false(gs.is_player_dead(), "Player with HP > 0 should not be dead")


func test_is_player_dead_when_dead() -> void:
	gs.run_hp = 0
	assert_true(gs.is_player_dead(), "Player with HP 0 should be dead")


func test_start_new_run() -> void:
	gs.selected_world_id = "test_world"
	gs.run_hp = 30
	gs.run_gold = 999
	gs.run_kills = 5
	gs.start_new_run("test_world")
	assert_eq(gs.run_hp, gs.run_max_hp, "HP should be reset to max")
	assert_eq(gs.run_gold, 0, "Gold should be reset to 0")
	assert_eq(gs.run_kills, 0, "Kills should be reset to 0")
	assert_eq(gs.run_nodes_visited, 0, "Nodes visited should be reset")
	assert_eq(gs.run_turn_count, 0, "Turn count should be reset")


func test_memory_flag() -> void:
	gs.set_memory_flag("test_flag", true)
	assert_true(gs.has_memory_flag("test_flag"), "Flag should be set")
	gs.set_memory_flag("test_flag", false)
	assert_false(gs.has_memory_flag("test_flag"), "Flag should be unset")


func test_memory_flag_default() -> void:
	assert_false(gs.has_memory_flag("nonexistent_flag_xyz"), "Unknown flag should return false")


func test_trait_tags_add() -> void:
	gs.trait_tags = {}
	gs.add_trait_tag("courage", 3)
	assert_eq(gs.get_trait_tag_value("courage"), 3, "Trait tag should accumulate")
	gs.add_trait_tag("courage", 2)
	assert_eq(gs.get_trait_tag_value("courage"), 5, "Trait tag should accumulate additively")


func test_trait_tags_dominant() -> void:
	gs.trait_tags = {}
	gs.add_trait_tag("courage", 10)
	gs.add_trait_tag("wisdom", 5)
	gs.add_trait_tag("fear", 1)
	var dominant: Array = gs.get_dominant_traits(2)
	assert_eq(dominant.size(), 2, "Should return top 2 traits")
	assert_eq(dominant[0], "courage", "First dominant trait should be courage")


func test_has_significant_trait() -> void:
	gs.trait_tags = {}
	gs.add_trait_tag("courage", 5)
	assert_true(gs.has_significant_trait("courage", 3), "Courage >= 3 should be significant")
	assert_false(gs.has_significant_trait("courage", 10), "Courage < 10 should not be significant")
