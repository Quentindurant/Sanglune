extends GutTest
## Écran du reliquaire : la pièce gagnée essayée sur le pantin, Équiper, Combat suivant, Accueil ; la défaite.


func _screen(profile: PlayerProfile, reward: DuelReward) -> ReliquaryScreen:
    var screen := ReliquaryScreen.new(profile, reward, 120)
    add_child_autofree(screen)
    screen.finish_opening()
    return screen


func _button(screen: ReliquaryScreen, text: String) -> Button:
    for child in screen.get_children():
        if child is Button and child.text == text:
            return child
    return null


func _victory(profile: PlayerProfile) -> DuelReward:
    return Reliquary.open(profile, true, false, ScriptedRandomSource.new([95, ItemDef.SLOTS.find(ItemDef.Slot.ARMOR), 0]))


func test_a_victory_shows_the_new_piece_and_offers_to_equip_it() -> void:
    var profile := PlayerProfile.new()
    var reward := _victory(profile)
    var screen := _screen(profile, reward)
    assert_true(reward.has_new_piece())
    assert_not_null(_button(screen, "Équiper"))
    assert_not_null(_button(screen, "Combat suivant"))
    assert_false(screen.is_equipped(), "rien n'est posé sans le demander")


func test_equip_wears_the_piece_and_says_so() -> void:
    var profile := PlayerProfile.new()
    var reward := _victory(profile)
    var screen := _screen(profile, reward)
    _button(screen, "Équiper").pressed.emit()
    assert_true(screen.is_equipped())
    assert_eq(profile.equipped(profile.knight_id, reward.item.def.slot), reward.item)
    var done := _button(screen, "Équipé")
    assert_not_null(done)
    assert_true(done.disabled)


func test_next_and_home_are_announced() -> void:
    var profile := PlayerProfile.new()
    var screen := _screen(profile, _victory(profile))
    watch_signals(screen)
    _button(screen, "Combat suivant").pressed.emit()
    assert_signal_emitted(screen, "next_requested")
    _button(screen, "Accueil").pressed.emit()
    assert_signal_emitted(screen, "home_requested")
    assert_true(screen.go_back())


func test_a_duplicate_cannot_be_equipped() -> void:
    var profile := PlayerProfile.new()
    var reward := Reliquary.open(profile, true, false, ScriptedRandomSource.new([0, ItemDef.SLOTS.find(ItemDef.Slot.HELM), 0]))
    var screen := _screen(profile, reward)
    assert_true(reward.duplicate)
    assert_null(_button(screen, "Équiper"))


func test_a_defeat_offers_a_retry_without_a_piece() -> void:
    var profile := PlayerProfile.new()
    var screen := _screen(profile, Reliquary.open(profile, false, false, ScriptedRandomSource.new()))
    assert_not_null(_button(screen, "Réessayer"))
    assert_null(_button(screen, "Équiper"))
    assert_null(_button(screen, "Combat suivant"))


func test_frappe_goes_to_the_next_duel() -> void:
    var profile := PlayerProfile.new()
    var screen := _screen(profile, _victory(profile))
    watch_signals(screen)
    var event := InputEventAction.new()
    event.action = "frappe"
    event.pressed = true
    screen._unhandled_input(event)
    assert_signal_emitted(screen, "next_requested")
