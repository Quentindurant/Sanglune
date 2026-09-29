extends GutTest
## Enchaînement des écrans : choix du chevalier, duel, fin de match, retour au choix.


func _flow() -> GameFlow:
    var flow := GameFlow.new()
    add_child_autofree(flow)
    return flow


func _fight_with(flow: GameFlow, position: int) -> Arena:
    var select: KnightSelect = flow.current_screen
    select.select_index(position)
    select.confirm()
    return flow.current_screen


func test_starts_on_the_knight_select() -> void:
    assert_is(_flow().current_screen, KnightSelect)


func test_confirming_opens_a_duel_with_the_chosen_knight() -> void:
    var flow := _flow()
    var arena := _fight_with(flow, 3)
    assert_is(arena, Arena)
    assert_eq(arena.duel.left.knight.id, KnightClass.COLOSSE)
    assert_not_null(KnightClass.by_id(arena.duel.right.knight.id), "l'ombre a un vrai chevalier")


func test_changing_knight_reopens_the_select_on_the_last_pick() -> void:
    var flow := _flow()
    var arena := _fight_with(flow, 1)
    arena.request_knight_change()
    assert_is(flow.current_screen, KnightSelect)
    assert_eq(flow.current_screen.selected().id, KnightClass.FAUCHEUSE)


func test_end_menu_waits_before_showing_up() -> void:
    var arena := _fight_with(_flow(), 0)
    arena.duel.state = Duel.State.MATCH_OVER
    await wait_physics_frames(Arena.END_MENU_DELAY - 5)
    assert_false(arena.is_end_menu_visible(), "on ne relance pas un match en martelant Frappe")
    await wait_physics_frames(10)
    assert_true(arena.is_end_menu_visible())


func test_replay_keeps_both_knights() -> void:
    var arena := _fight_with(_flow(), 2)
    var enemy_id := arena.duel.right.knight.id
    arena.duel.state = Duel.State.MATCH_OVER
    arena.replay()
    assert_eq(arena.duel.state, Duel.State.ROUND_INTRO)
    assert_eq(arena.duel.left.knight.id, KnightClass.RODEUSE)
    assert_eq(arena.duel.right.knight.id, enemy_id)
    assert_false(arena.is_end_menu_visible())
