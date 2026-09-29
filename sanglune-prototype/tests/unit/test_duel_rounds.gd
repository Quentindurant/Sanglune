extends GutTest
## Déroulé du match : intro, manches, temps limite, égalité, deux manches gagnantes.


func _idle(duel: Duel, frames: int) -> void:
    for i in frames:
        duel.step(Intent.of(), Intent.of())


## Le chevalier de gauche finit l'adversaire d'une frappe.
func _left_knocks_out_right(duel: Duel) -> void:
    duel.skip_intro()
    duel.right.hp = 1
    duel.left.x = 4000
    duel.right.x = 5200
    duel.step(Intent.of(0, CombatAction.Kind.FRAPPE), Intent.of())
    _idle(duel, 9)


func _has_event(duel: Duel, type: String) -> bool:
    return duel.events.any(func(e: Dictionary) -> bool: return e["type"] == type)


func test_round_opens_with_an_intro() -> void:
    var duel := Duel.new()
    assert_eq(duel.state, Duel.State.ROUND_INTRO)
    _idle(duel, Duel.INTRO_FRAMES)
    assert_eq(duel.state, Duel.State.FIGHTING)


func test_intents_are_ignored_during_the_intro() -> void:
    var duel := Duel.new()
    duel.step(Intent.of(1, CombatAction.Kind.FRAPPE), Intent.of(1))
    assert_eq(duel.left.x, Duel.LEFT_START)
    assert_true(duel.left.is_free())


func test_timer_counts_down_in_seconds() -> void:
    var duel := Duel.new()
    duel.skip_intro()
    _idle(duel, Duel.FPS)
    assert_eq(duel.seconds_left(), 59)


func test_knockout_gives_the_round_to_the_striker() -> void:
    var duel := Duel.new()
    _left_knocks_out_right(duel)
    assert_eq(duel.wins[-1], 1)
    assert_eq(duel.state, Duel.State.ROUND_OVER)


func test_time_out_gives_the_round_to_the_healthier_knight() -> void:
    var duel := Duel.new()
    duel.skip_intro()
    duel.left.hp = 50
    duel.round_time_left = 1
    _idle(duel, 1)
    assert_eq(duel.wins[1], 1)


func test_draw_replays_the_round() -> void:
    var duel := Duel.new()
    duel.skip_intro()
    duel.round_time_left = 1
    _idle(duel, 1)
    assert_eq(duel.wins[-1] + duel.wins[1], 0)
    _idle(duel, Duel.ROUND_OVER_FRAMES)
    assert_eq(duel.round_number, 2)
    assert_eq(duel.state, Duel.State.ROUND_INTRO)
    assert_eq(duel.left.hp, duel.left.max_hp(), "chaque manche repart à pleine vie")


func test_two_round_wins_end_the_match() -> void:
    var duel := Duel.new()
    duel.wins[-1] = 1
    _left_knocks_out_right(duel)
    assert_eq(duel.match_winner, -1)
    assert_eq(duel.state, Duel.State.MATCH_OVER)
    assert_true(_has_event(duel, "match_end"))


func test_restart_resets_the_score() -> void:
    var duel := Duel.new()
    duel.wins[-1] = 1
    duel.restart()
    assert_eq(duel.wins[-1], 0)
    assert_eq(duel.round_number, 1)
    assert_eq(duel.match_winner, 0)
