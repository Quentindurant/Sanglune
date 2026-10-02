extends GutTest
## Les écrans de la Chasse : le bouton de l'accueil, le choix des nuits, le chemin, l'offre, la fin, et l'enchaînement.

var store: MemoryProfileStore


func before_each() -> void:
    store = MemoryProfileStore.new()


func _button(parent: Node, text: String) -> Button:
    for child in parent.get_children():
        if child is Button and child.text == text:
            return child
    return null


func _flow() -> GameFlow:
    var flow := GameFlow.new()
    flow.store = store
    flow.random = RngRandomSource.new(3)
    add_child_autofree(flow)
    return flow


## Une Chasse arrêtée sur une offre qui contient ce genre de récompense ; [chasse, indice].
func _hunt_offering(profile: PlayerProfile, kind: int) -> Array:
    for seed_value in range(1, 200):
        var hunt := Hunt.new(HuntDifficulty.Level.NUIT, seed_value, profile.knight_id)
        hunt.record_duel(true)
        for i in hunt.offer().size():
            if hunt.offer()[i].kind == kind:
                return [hunt, i]
    return [null, -1]


# --- Accueil ---

func test_the_home_screen_opens_the_hunt_and_shows_its_progress() -> void:
    var home: HomeScreen = autofree(HomeScreen.new(KnightClass.starter()))
    add_child(home)
    watch_signals(home)
    _button(home, "Chasse").pressed.emit()
    assert_signal_emitted(home, "hunt_requested")
    var busy: HomeScreen = autofree(HomeScreen.new(KnightClass.starter(), {}, 1, 100, 3))
    assert_eq(busy.hunt_label(), "Chasse · 3/7")


# --- Choix de la nuit ---

func test_three_nights_the_blood_moon_locked_at_first() -> void:
    var screen := HuntScreen.new(PlayerProfile.new())
    add_child_autofree(screen)
    assert_eq(screen.cards.size(), 3)
    assert_eq(screen.selected_level, HuntDifficulty.Level.PENOMBRE, "on commence par la Pénombre")
    assert_false(screen.cards[HuntDifficulty.Level.LUNE_DE_SANG].unlocked)
    watch_signals(screen)
    screen.select_level(HuntDifficulty.Level.LUNE_DE_SANG)
    assert_true(_button(screen, "Partir").disabled)
    screen.start()
    assert_signal_not_emitted(screen, "start_requested")


func test_choosing_a_night_and_leaving() -> void:
    var screen := HuntScreen.new(PlayerProfile.new())
    add_child_autofree(screen)
    watch_signals(screen)
    screen.cards[HuntDifficulty.Level.NUIT].pressed.emit()
    assert_true(screen.cards[HuntDifficulty.Level.NUIT].selected)
    assert_false(screen.cards[HuntDifficulty.Level.PENOMBRE].selected)
    _button(screen, "Partir").pressed.emit()
    assert_signal_emitted_with_parameters(screen, "start_requested", [HuntDifficulty.Level.NUIT])


func test_the_suggested_night_is_the_hardest_open_one_not_yet_finished() -> void:
    var profile := PlayerProfile.new()
    profile.hunt_records[HuntDifficulty.Level.PENOMBRE] = Hunt.LENGTH
    var screen := HuntScreen.new(profile)
    add_child_autofree(screen)
    assert_eq(screen.selected_level, HuntDifficulty.Level.NUIT)


# --- Le chemin ---

func test_the_path_offers_to_fight_and_asks_twice_before_giving_up() -> void:
    var profile := PlayerProfile.new()
    profile.start_hunt(HuntDifficulty.Level.PENOMBRE, 9)
    var screen := HuntScreen.new(profile)
    add_child_autofree(screen)
    watch_signals(screen)
    _button(screen, "Combattre").pressed.emit()
    assert_signal_emitted(screen, "fight_requested")
    _button(screen, "Abandonner").pressed.emit()
    assert_signal_not_emitted(screen, "forfeit_requested", "la première touche demande confirmation")
    assert_true(screen.is_confirming_forfeit())
    _button(screen, "Confirmer ?").pressed.emit()
    assert_signal_emitted(screen, "forfeit_requested")


# --- L'offre ---

func test_take_waits_for_a_choice_then_keeps_a_blessing() -> void:
    var profile := PlayerProfile.new()
    var hunt := Hunt.new(HuntDifficulty.Level.NUIT, 21)
    hunt.record_duel(true)
    var screen := HuntOfferScreen.new(profile, hunt)
    add_child_autofree(screen)
    assert_eq(screen.cards.size(), 3)
    assert_true(_button(screen, "Prendre").disabled, "rien n'est pris sans choisir")
    watch_signals(screen)
    var id := screen.cards[0].reward.blessing_id
    screen.cards[0].pressed.emit()
    assert_true(screen.cards[0].selected)
    _button(screen, "Prendre").pressed.emit()
    assert_eq(hunt.blessing_count(id), 1)
    assert_signal_emitted(screen, "continue_requested", "une bénédiction : on repart aussitôt")


func test_a_new_piece_can_be_equipped_before_going_on() -> void:
    var profile := PlayerProfile.new()
    var found := _hunt_offering(profile, HuntReward.Kind.PIECE)
    var hunt: Hunt = found[0]
    while profile.owns_at_least(hunt.offer()[found[1]].def.id, Rarity.Tier.CROISSANT):
        profile.items.erase(profile.items.filter(func(o: OwnedItem) -> bool: return o.def.id == hunt.offer()[found[1]].def.id)[0])
    var screen := HuntOfferScreen.new(profile, hunt)
    add_child_autofree(screen)
    watch_signals(screen)
    screen.select(found[1])
    screen.take()
    assert_signal_not_emitted(screen, "continue_requested")
    assert_not_null(_button(screen, "Équiper"))
    _button(screen, "Équiper").pressed.emit()
    assert_true(screen.is_equipped())
    _button(screen, "Continuer").pressed.emit()
    assert_signal_emitted(screen, "continue_requested")


func test_reward_cards_say_what_lasts() -> void:
    var blessing := HuntRewardCard.new(HuntReward.blessing(&"sang_vif"), Vector2(360, 410), 1)
    var shards := HuntRewardCard.new(HuntReward.shard_pile(20), Vector2(360, 410))
    autofree(blessing)
    autofree(shards)
    assert_string_starts_with(blessing.describe(), "Pour la Chasse, Sang vif, Vie +10 %")
    assert_eq(shards.describe(), "À garder, Éclats, +20 éclats")


# --- La fin ---

func test_the_end_after_the_last_lord_offers_to_equip_the_prize() -> void:
    var profile := PlayerProfile.new()
    var hunt := profile.start_hunt(HuntDifficulty.Level.PENOMBRE, 13)
    for i in Hunt.LENGTH - 1:
        hunt.record_duel(true)
        hunt.choose(0, profile)
    hunt.record_duel(true)
    var end := hunt.conclude(profile)
    var screen := HuntEndScreen.new(profile, end, profile.knight_id)
    add_child_autofree(screen)
    watch_signals(screen)
    if end.reward.has_new_piece():
        _button(screen, "Équiper").pressed.emit()
        assert_true(screen.is_equipped())
    _button(screen, "Nouvelle Chasse").pressed.emit()
    assert_signal_emitted(screen, "again_requested")
    _button(screen, "Accueil").pressed.emit()
    assert_signal_emitted(screen, "home_requested")


func test_the_end_after_a_defeat_has_nothing_to_equip() -> void:
    var profile := PlayerProfile.new()
    var hunt := profile.start_hunt(HuntDifficulty.Level.PENOMBRE, 13)
    hunt.record_duel(false)
    var screen := HuntEndScreen.new(profile, hunt.conclude(profile), profile.knight_id)
    add_child_autofree(screen)
    assert_null(_button(screen, "Équiper"))


# --- L'enchaînement ---

func test_a_hunt_from_the_home_screen_to_the_first_duel() -> void:
    store.saved = {"knight": "colosse"}
    var flow := _flow()
    (flow.current_screen as HomeScreen).hunt_requested.emit()
    assert_is(flow.current_screen, HuntScreen)
    (flow.current_screen as HuntScreen).start_requested.emit(HuntDifficulty.Level.PENOMBRE)
    var arena: Arena = flow.current_screen
    assert_is(arena, Arena)
    assert_eq(arena.duel.left.knight.id, KnightClass.COLOSSE)
    assert_eq(arena.duel.right.knight.id, flow.profile.hunt.opponent().knight.id)
    assert_eq(arena.enemy_title, "Duel 1/7")
    assert_true(flow.profile.hunt.in_duel)
    assert_true(store.saved["hunt"]["in_duel"], "le duel commencé est sauvegardé")


func test_a_won_duel_leads_to_the_offer_then_back_to_the_path() -> void:
    var flow := _flow()
    flow.profile.start_hunt(HuntDifficulty.Level.PENOMBRE, 5)
    flow.start_hunt_duel()
    (flow.current_screen as Arena).match_finished.emit(true)
    var offer: HuntOfferScreen = flow.current_screen
    assert_is(offer, HuntOfferScreen)
    offer.select(0)
    offer.take()
    if flow.current_screen is HuntOfferScreen: ## une pièce neuve attend « Continuer »
        (flow.current_screen as HuntOfferScreen).take()
    assert_is(flow.current_screen, HuntScreen)
    assert_eq(flow.profile.hunt.index, 1)


func test_an_offer_left_waiting_comes_back() -> void:
    var flow := _flow()
    flow.profile.start_hunt(HuntDifficulty.Level.PENOMBRE, 5)
    flow.start_hunt_duel()
    (flow.current_screen as Arena).match_finished.emit(true)
    (flow.current_screen as HuntOfferScreen).go_back()
    assert_is(flow.current_screen, HomeScreen)
    (flow.current_screen as HomeScreen).hunt_requested.emit()
    assert_is(flow.current_screen, HuntOfferScreen, "le choix attend toujours")


func test_a_lost_duel_ends_the_hunt() -> void:
    var flow := _flow()
    flow.profile.start_hunt(HuntDifficulty.Level.PENOMBRE, 5)
    flow.start_hunt_duel()
    (flow.current_screen as Arena).match_finished.emit(false)
    assert_is(flow.current_screen, HuntEndScreen)
    assert_null(flow.profile.hunt)
    assert_null(store.saved["hunt"])


func test_giving_up_in_a_duel_needs_confirmation() -> void:
    var flow := _flow()
    flow.profile.start_hunt(HuntDifficulty.Level.PENOMBRE, 5)
    flow.start_hunt_duel()
    var arena: Arena = flow.current_screen
    arena.pause_duel()
    assert_null(_button(arena._pause_menu, "Accueil"), "en Chasse, la pause propose d'abandonner")
    assert_not_null(_button(arena._pause_menu, "Abandonner"))
    arena.request_forfeit()
    assert_true(arena.is_confirming_forfeit())
    assert_is(flow.current_screen, Arena)
    arena.resume_duel()
    assert_false(arena.is_confirming_forfeit(), "reprendre annule la demande")
    arena.pause_duel()
    arena.request_forfeit()
    arena.request_forfeit()
    assert_is(flow.current_screen, HuntEndScreen)
    assert_null(flow.profile.hunt)


func test_quitting_the_game_mid_duel_counts_as_a_defeat() -> void:
    var profile := PlayerProfile.new()
    var hunt := profile.start_hunt(HuntDifficulty.Level.NUIT, 8)
    hunt.begin_duel()
    store.saved = profile.to_dict()
    var flow := _flow()
    assert_null(flow.profile.hunt, "le duel interrompu est perdu, la Chasse s'achève")
    assert_eq(flow.profile.hunt_record(HuntDifficulty.Level.NUIT), 0)


func test_a_tear_saves_an_interrupted_duel() -> void:
    var profile := PlayerProfile.new()
    var hunt := profile.start_hunt(HuntDifficulty.Level.NUIT, 8)
    hunt.has_tear = true
    hunt.begin_duel()
    store.saved = profile.to_dict()
    var flow := _flow()
    assert_not_null(flow.profile.hunt)
    assert_false(flow.profile.hunt.has_tear)
    assert_false(flow.profile.hunt.in_duel)



# --- Les seigneurs et le bestiaire ---

func test_the_bestiary_names_only_the_lords_already_beaten() -> void:
    var profile := PlayerProfile.new()
    profile.defeat_boss(&"bastion")
    var screen := BestiaryScreen.new(profile)
    add_child_autofree(screen)
    assert_eq(screen.cards.size(), Boss.ids().size(), "tous les seigneurs ont leur case")
    for card in screen.cards:
        assert_eq(card.known, card.boss == &"bastion")
        assert_eq(card.accessibility_name, "Le Bastion" if card.known else "Seigneur inconnu")
    screen.cards[0].pressed.emit()
    assert_eq(screen.selected, screen.cards[0].boss)
    watch_signals(screen)
    _button(screen, "Retour").pressed.emit()
    assert_signal_emitted(screen, "closed")


func test_the_bestiary_opens_from_the_hunt_and_comes_back() -> void:
    var flow := _flow()
    flow.show_hunt()
    var hunt_screen: HuntScreen = flow.current_screen
    _button(hunt_screen, "Bestiaire · 0/%d" % Boss.ids().size()).pressed.emit()
    assert_is(flow.current_screen, BestiaryScreen)
    flow.go_back(false)
    assert_is(flow.current_screen, HuntScreen)


func test_facing_a_lord_shows_his_name_and_silhouette() -> void:
    var profile := PlayerProfile.new()
    var hunt := profile.start_hunt(HuntDifficulty.Level.PENOMBRE, 3)
    hunt.index = Hunt.BOSS_DUELS[0]
    var screen := HuntScreen.new(profile)
    add_child_autofree(screen)
    assert_eq(screen._boss_puppets.size(), 2, "les deux seigneurs attendent sur le chemin")
    assert_eq(screen._boss_puppets[Hunt.BOSS_DUELS[0]].knight_id, Boss.knight_id(hunt.boss_id()) if Boss.rule(hunt.boss_id(), Boss.Rule.MIRROR) == 0 else hunt.knight_id)


func test_a_lord_duel_shows_his_name_and_size() -> void:
    var flow := _flow()
    var hunt := flow.profile.start_hunt(HuntDifficulty.Level.PENOMBRE, 5)
    hunt.bosses.assign([&"colosse_de_fer", &"bastion"])
    hunt.index = Hunt.BOSS_DUELS[0]
    flow.start_hunt_duel()
    var arena: Arena = flow.current_screen
    assert_eq(arena.enemy_title, "Le Colosse de Fer")
    assert_eq(arena.puppet(1).base_scale, Boss.scale(&"colosse_de_fer"))
    arena.match_finished.emit(true)
    assert_true(&"colosse_de_fer" in flow.profile.bestiary, "vaincu en jeu, il entre au bestiaire")
    assert_is(flow.current_screen, HuntOfferScreen)
    assert_eq((flow.current_screen as HuntOfferScreen).cards[2].reward.kind, HuntReward.Kind.PIECE)


func test_the_shapeshifter_puppet_follows_its_shape() -> void:
    var flow := _flow()
    var hunt := flow.profile.start_hunt(HuntDifficulty.Level.PENOMBRE, 5)
    hunt.bosses.assign([&"changeforme", &"bastion"])
    hunt.index = Hunt.BOSS_DUELS[0]
    flow.start_hunt_duel()
    var arena: Arena = flow.current_screen
    arena.duel.skip_intro()
    arena.duel.left.hp = 0
    for i in Duel.ROUND_OVER_FRAMES + 3:
        arena.duel.step(null, null)
    arena._update_puppets()
    assert_eq(arena.puppet(1).knight_id, arena.duel.right.knight.id)
    assert_ne(arena.puppet(1).knight_id, Boss.knight_id(&"changeforme"))
