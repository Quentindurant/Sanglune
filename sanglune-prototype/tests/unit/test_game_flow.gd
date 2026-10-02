extends GutTest
## Enchaînement des écrans : accueil, chevaliers, duel, pause, fin de match, retour.

var store: MemoryProfileStore


func before_each() -> void:
    store = MemoryProfileStore.new()


func after_each() -> void:
    Input.action_release("frappe")


func _flow() -> GameFlow:
    var flow := GameFlow.new()
    flow.store = store
    flow.random = RngRandomSource.new(3)
    add_child_autofree(flow)
    return flow


func _duel(flow: GameFlow) -> Arena:
    (flow.current_screen as HomeScreen).play_requested.emit()
    return flow.current_screen


func test_starts_on_the_home_screen_with_the_saved_knight() -> void:
    store.saved = {"knight": "colosse"}
    var flow := _flow()
    assert_is(flow.current_screen, HomeScreen)
    assert_eq((flow.current_screen as HomeScreen).knight.id, KnightClass.COLOSSE)


func test_play_opens_a_duel_with_the_active_knight() -> void:
    store.saved = {"knight": "rodeuse"}
    var arena := _duel(_flow())
    assert_is(arena, Arena)
    assert_eq(arena.duel.left.knight.id, KnightClass.RODEUSE)
    assert_eq(arena.duel.right.knight.id, ShadowPath.opponent(1).knight.id, "l'ombre du premier palier")


func test_choosing_a_knight_saves_it_and_returns_home() -> void:
    var flow := _flow()
    (flow.current_screen as HomeScreen).knights_requested.emit()
    var select: KnightSelect = flow.current_screen
    select.select_index(1)
    select.confirm()
    assert_is(flow.current_screen, HomeScreen)
    assert_eq((flow.current_screen as HomeScreen).knight.id, KnightClass.FAUCHEUSE)
    assert_eq(store.saved.get("knight"), "faucheuse", "le choix est sauvegardé")


func test_back_from_the_knights_keeps_the_knight() -> void:
    var flow := _flow()
    (flow.current_screen as HomeScreen).knights_requested.emit()
    (flow.current_screen as KnightSelect).select_index(3)
    flow.go_back(true)
    assert_is(flow.current_screen, HomeScreen)
    assert_eq(flow.profile.knight_id, KnightClass.VEILLEUR)
    assert_eq(store.save_count, 0, "rien à sauvegarder")


func test_back_during_a_duel_pauses_it() -> void:
    var flow := _flow()
    var arena := _duel(flow)
    flow.go_back(true)
    assert_true(arena.is_paused())
    var frozen := arena.duel.state_frames
    await wait_physics_frames(5)
    assert_eq(arena.duel.state_frames, frozen, "le duel est figé")
    flow.go_back(true)
    assert_false(arena.is_paused(), "un second retour reprend")


func test_home_from_the_pause_menu() -> void:
    var flow := _flow()
    var arena := _duel(flow)
    arena.pause_duel()
    arena.request_home()
    assert_is(flow.current_screen, HomeScreen)


func _finish(arena: Arena, player_won: bool) -> void:
    arena.duel.match_winner = -1 if player_won else 1
    arena.duel.state = Duel.State.MATCH_OVER


func test_the_match_end_waits_then_opens_the_reliquary() -> void:
    var flow := _flow()
    var arena := _duel(flow)
    _finish(arena, true)
    await wait_physics_frames(Arena.END_MENU_DELAY - 5)
    assert_is(flow.current_screen, Arena, "on ne quitte pas le duel en martelant Frappe")
    await wait_physics_frames(10)
    assert_is(flow.current_screen, ReliquaryScreen)
    assert_true((flow.current_screen as ReliquaryScreen).reward.won)


func test_a_victory_leads_to_the_next_palier() -> void:
    var flow := _flow()
    _finish(_duel(flow), true)
    await wait_physics_frames(Arena.END_MENU_DELAY + 2)
    assert_eq(flow.profile.palier, 2)
    assert_eq(store.saved["palier"], 2, "le palier est sauvegardé")
    (flow.current_screen as ReliquaryScreen).next_requested.emit()
    var arena: Arena = flow.current_screen
    assert_eq(arena.enemy_knight.id, ShadowPath.opponent(2).knight.id)
    assert_eq(arena.enemy_title, "Palier 2")


func test_a_defeat_keeps_the_palier_and_offers_a_retry() -> void:
    var flow := _flow()
    _finish(_duel(flow), false)
    await wait_physics_frames(Arena.END_MENU_DELAY + 2)
    var screen: ReliquaryScreen = flow.current_screen
    assert_false(screen.reward.won)
    assert_eq(flow.profile.palier, 1)
    assert_eq(flow.profile.shards, Reliquary.SHARDS_LOSS)
    screen.next_requested.emit()
    assert_eq((flow.current_screen as Arena).enemy_knight.id, ShadowPath.opponent(1).knight.id)


func test_back_from_the_reliquary_returns_home() -> void:
    var flow := _flow()
    _finish(_duel(flow), true)
    await wait_physics_frames(Arena.END_MENU_DELAY + 2)
    flow.go_back(true)
    assert_is(flow.current_screen, HomeScreen)
    assert_eq((flow.current_screen as HomeScreen).palier, 2)


func test_replay_keeps_both_knights() -> void:
    store.saved = {"knight": "rodeuse"}
    var arena := _duel(_flow())
    var enemy_id := arena.duel.right.knight.id
    arena.duel.state = Duel.State.MATCH_OVER
    arena.replay()
    assert_eq(arena.duel.state, Duel.State.ROUND_INTRO)
    assert_eq(arena.duel.left.knight.id, KnightClass.RODEUSE)
    assert_eq(arena.duel.right.knight.id, enemy_id)
    assert_false(arena.is_end_menu_visible())


func test_the_armory_opens_from_the_knights_and_leads_back_to_the_same_card() -> void:
    var flow := _flow()
    flow.show_knights()
    var select: KnightSelect = flow.current_screen
    select.select_index(3)
    select.request_equip()
    assert_is(flow.current_screen, ArmoryScreen)
    assert_eq((flow.current_screen as ArmoryScreen).knight.id, KnightClass.COLOSSE)
    flow.go_back(true)
    assert_is(flow.current_screen, KnightSelect)
    assert_eq((flow.current_screen as KnightSelect).selected().id, KnightClass.COLOSSE)


func test_equipment_is_saved_and_worn_in_the_duel() -> void:
    var flow := _flow()
    var mail: OwnedItem = flow.profile.items_for(KnightClass.VEILLEUR, ItemDef.Slot.ARMOR).filter(
        func(o: OwnedItem) -> bool: return o.def.id == &"cotte_de_mailles")[0]
    flow.show_armory(KnightClass.VEILLEUR)
    var armory: ArmoryScreen = flow.current_screen
    armory.open_slot(ItemDef.Slot.ARMOR)
    armory.preview(mail)
    armory.equip_preview()
    assert_eq(store.saved["equipped"]["veilleur"]["armor"], mail.uid, "l'équipement est sauvegardé")
    flow.show_home()
    assert_eq((flow.current_screen as HomeScreen).look.get("pauldrons"), true, "l'accueil montre la cotte")
    var arena := _duel(flow)
    assert_gt(arena.duel.left.max_hp(), KnightClass.starter().max_hp)


func test_the_wardrobe_opens_from_the_armory_and_is_worn_in_the_duel() -> void:
    var flow := _flow()
    flow.show_armory(KnightClass.VEILLEUR)
    (flow.current_screen as ArmoryScreen).wardrobe_requested.emit()
    var wardrobe: WardrobeScreen = flow.current_screen
    assert_is(wardrobe, WardrobeScreen)
    wardrobe.choose(ItemDef.Slot.HELM, &"heaume_a_cornes")
    flow.go_back(true)
    assert_is(flow.current_screen, ArmoryScreen)
    flow.show_home()
    assert_eq((flow.current_screen as HomeScreen).look.get("crest"), &"horns")
    var arena := _duel(flow)
    assert_eq(arena.player_look.get("crest"), &"horns")
    assert_eq(arena.duel.left.max_hp(), KnightClass.starter().max_hp, "l'apparence seule ne change pas le combat")
