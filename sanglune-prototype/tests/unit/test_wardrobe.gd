extends GutTest
## Garde-robe : apparences débloquées par les pièces, choix par emplacement, silhouette qui en découle.


func _owned(profile: PlayerProfile, item_id: StringName) -> OwnedItem:
    for owned in profile.items:
        if owned.def.id == item_id:
            return owned
    return null


func test_owned_pieces_unlock_their_looks() -> void:
    var profile := PlayerProfile.new()
    assert_true(profile.wardrobe.is_unlocked(&"heaume_a_cimier"))
    assert_true(profile.wardrobe.is_unlocked(&"epee_et_ecu"), "l'arme de départ aussi")
    assert_false(profile.wardrobe.is_unlocked(&"larme_de_lune"), "un talisman ne se voit pas")


func test_by_default_the_worn_piece_is_shown() -> void:
    var profile := PlayerProfile.new()
    profile.equip(KnightClass.VEILLEUR, _owned(profile, &"heaume_a_cornes").uid)
    assert_eq(profile.look(KnightClass.VEILLEUR).get("crest"), &"horns")
    assert_eq(profile.look(KnightClass.VEILLEUR).get("weapon"), &"sword")


func test_a_chosen_look_wins_over_the_worn_piece() -> void:
    var profile := PlayerProfile.new()
    profile.equip(KnightClass.VEILLEUR, _owned(profile, &"heaume_a_cornes").uid)
    watch_signals(profile)
    assert_true(profile.set_appearance(KnightClass.VEILLEUR, ItemDef.Slot.HELM, &"heaume_a_cimier"))
    assert_eq(profile.look(KnightClass.VEILLEUR).get("crest"), &"plume")
    assert_signal_emitted_with_parameters(profile, "appearance_changed", [KnightClass.VEILLEUR])
    assert_signal_emitted(profile, "changed")
    var stats := FighterStats.resolve(KnightClass.starter(), profile.loadout(KnightClass.VEILLEUR))
    assert_lt(stats.max_hp, KnightClass.starter().max_hp, "l'apparence ne change rien au combat : les cornes coûtent toujours de la vie")


func test_nothing_hides_the_slot_but_never_the_weapon() -> void:
    var profile := PlayerProfile.new()
    profile.equip(KnightClass.VEILLEUR, _owned(profile, &"cape_de_rodeur").uid)
    assert_true(profile.set_appearance(KnightClass.VEILLEUR, ItemDef.Slot.ARMOR, Wardrobe.NOTHING))
    assert_false(profile.look(KnightClass.VEILLEUR).has("cape"))
    assert_false(profile.set_appearance(KnightClass.VEILLEUR, ItemDef.Slot.WEAPON, Wardrobe.NOTHING))


func test_locked_or_foreign_looks_are_refused() -> void:
    var profile := PlayerProfile.new()
    var fresh := PlayerProfile.from_dict({"version": 2, "items": []})
    assert_false(fresh.set_appearance(KnightClass.VEILLEUR, ItemDef.Slot.HELM, &"heaume_a_cimier"), "pas encore gagnée")
    assert_false(profile.set_appearance(KnightClass.COLOSSE, ItemDef.Slot.WEAPON, &"epee_effilee"), "l'épée n'est pas au Colosse")
    assert_false(profile.set_appearance(KnightClass.VEILLEUR, ItemDef.Slot.ARMOR, &"heaume_a_cimier"), "pas le bon emplacement")
    assert_false(profile.set_appearance(KnightClass.VEILLEUR, ItemDef.Slot.HELM, &"auréole"))


func test_a_recycled_piece_keeps_its_look() -> void:
    var profile := PlayerProfile.new()
    var cape := _owned(profile, &"cape_de_rodeur")
    profile.recycle(cape.uid)
    assert_true(profile.wardrobe.is_unlocked(&"cape_de_rodeur"))
    assert_true(profile.set_appearance(KnightClass.RODEUSE, ItemDef.Slot.ARMOR, &"cape_de_rodeur"))
    assert_eq(profile.look(KnightClass.RODEUSE).get("cape"), &"long")


func test_trying_a_piece_shows_it_whatever_the_wardrobe_says() -> void:
    var profile := PlayerProfile.new()
    profile.set_appearance(KnightClass.VEILLEUR, ItemDef.Slot.HELM, Wardrobe.NOTHING)
    assert_eq(profile.look(KnightClass.VEILLEUR, _owned(profile, &"heaume_a_cornes")).get("crest"), &"horns")


func test_the_wardrobe_round_trips_and_is_cleaned_up() -> void:
    var profile := PlayerProfile.new()
    profile.recycle(_owned(profile, &"cape_de_rodeur").uid)
    profile.set_appearance(KnightClass.COLOSSE, ItemDef.Slot.HELM, &"heaume_a_cornes")
    profile.set_appearance(KnightClass.COLOSSE, ItemDef.Slot.ARMOR, &"cape_de_rodeur")
    var copy := PlayerProfile.from_dict(JSON.parse_string(JSON.stringify(profile.to_dict())))
    assert_eq(copy.wardrobe.choice(KnightClass.COLOSSE, ItemDef.Slot.HELM), &"heaume_a_cornes")
    assert_eq(copy.wardrobe.choice(KnightClass.COLOSSE, ItemDef.Slot.ARMOR), &"cape_de_rodeur", "même recyclée")
    var tampered := PlayerProfile.from_dict({"version": 2, "items": [], "wardrobe": {
        "unlocked": ["excalibur", 7], "choices": {"colosse": {"helm": "heaume_a_cimier", "weapon": "none"}, "paladin": {}},
    }})
    assert_eq(tampered.wardrobe.choice(KnightClass.COLOSSE, ItemDef.Slot.HELM), Wardrobe.FOLLOW, "apparence non débloquée")
    assert_eq(tampered.wardrobe.choice(KnightClass.COLOSSE, ItemDef.Slot.WEAPON), Wardrobe.FOLLOW)


func test_the_wardrobe_screen_offers_follow_looks_and_nothing() -> void:
    var profile := PlayerProfile.new()
    var screen := WardrobeScreen.new(profile, KnightClass.VEILLEUR)
    add_child_autofree(screen)
    var helm: Array = screen.chips(ItemDef.Slot.HELM)
    assert_eq(helm.map(func(e: Array) -> String: return e[0].text), ["Pièce portée", "Cimier", "Cornes", "Aucune"])
    assert_true(helm[0][0].button_pressed, "par défaut : la pièce portée")
    var weapon: Array = screen.chips(ItemDef.Slot.WEAPON)
    assert_eq(weapon.size(), 3, "pièce portée, épée longue, épée effilée, et jamais « aucune »")
    assert_true(screen.chips(ItemDef.Slot.TALISMAN).is_empty(), "un talisman ne se voit pas")


func test_choosing_on_the_wardrobe_screen_applies_at_once() -> void:
    var profile := PlayerProfile.new()
    var screen := WardrobeScreen.new(profile, KnightClass.VEILLEUR)
    add_child_autofree(screen)
    var cornes: Button = screen.chips(ItemDef.Slot.HELM)[2][0]
    cornes.pressed.emit()
    assert_eq(profile.wardrobe.choice(KnightClass.VEILLEUR, ItemDef.Slot.HELM), &"heaume_a_cornes")
    assert_true(cornes.button_pressed)
    assert_false(screen.chips(ItemDef.Slot.HELM)[0][0].button_pressed)
    watch_signals(screen)
    assert_true(screen.go_back())
    assert_signal_emitted(screen, "closed")


func test_locked_looks_are_greyed_out() -> void:
    var profile := PlayerProfile.from_dict({"version": 2, "items": []})
    var screen := WardrobeScreen.new(profile, KnightClass.VEILLEUR)
    add_child_autofree(screen)
    var helm: Array = screen.chips(ItemDef.Slot.HELM)
    assert_true(helm[1][0].disabled, "Cimier pas encore gagné")
    assert_false(helm[0][0].disabled)
    assert_false(helm[-1][0].disabled)
