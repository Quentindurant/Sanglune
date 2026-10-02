extends GutTest
## Armurerie : quatre emplacements, la liste des pièces d'un emplacement, l'essai sur le pantin, équiper, revenir.

var profile: PlayerProfile
var armory: ArmoryScreen


func before_each() -> void:
    profile = PlayerProfile.new()
    armory = ArmoryScreen.new(profile, KnightClass.VEILLEUR)
    add_child_autofree(armory)


func _row_for(item_id: StringName) -> GearPieceButton:
    for row in armory.rows():
        if row.item != null and row.item.def.id == item_id:
            return row
    return null


func test_shows_four_slots_with_what_is_worn() -> void:
    for slot in ItemDef.SLOTS:
        assert_not_null(armory.tile(slot), ItemDef.SLOT_NAMES[slot])
    assert_true(armory.tile(ItemDef.Slot.WEAPON).item.def.starter, "l'arme de départ en main")
    assert_null(armory.tile(ItemDef.Slot.HELM).item, "aucun heaume au départ")
    assert_false(armory.is_picker_open())


func test_a_slot_lists_only_the_pieces_that_fit() -> void:
    armory.tile(ItemDef.Slot.WEAPON).pressed.emit()
    assert_true(armory.is_picker_open())
    assert_null(armory.tile(ItemDef.Slot.WEAPON), "les emplacements laissent la place à la liste")
    var ids := armory.rows().map(func(r: GearPieceButton) -> StringName: return r.item.def.id)
    assert_eq(ids.size(), 2)
    assert_true(&"epee_effilee" in ids and &"epee_et_ecu" in ids, str(ids))


func test_a_removable_slot_offers_nothing_as_a_choice() -> void:
    armory.open_slot(ItemDef.Slot.HELM)
    assert_null(armory.rows()[-1].item, "« Rien » en dernier")
    armory.open_slot(ItemDef.Slot.WEAPON)
    for row in armory.rows():
        assert_not_null(row.item, "une arme ne se retire pas")


func test_trying_a_piece_dresses_the_puppet_without_equipping_it() -> void:
    armory.open_slot(ItemDef.Slot.HELM)
    _row_for(&"heaume_a_cornes").pressed.emit()
    assert_eq(armory.previewed().def.id, &"heaume_a_cornes")
    assert_eq(armory.preview_loadout().look().get("crest"), &"horns")
    assert_null(profile.equipped(KnightClass.VEILLEUR, ItemDef.Slot.HELM), "rien n'est posé tant qu'on n'équipe pas")
    assert_true(_row_for(&"heaume_a_cornes").button_pressed)


func test_equipping_saves_the_piece_and_returns_to_the_slots() -> void:
    watch_signals(profile)
    armory.open_slot(ItemDef.Slot.ARMOR)
    _row_for(&"cape_de_rodeur").pressed.emit()
    armory.equip_preview()
    assert_eq(profile.equipped(KnightClass.VEILLEUR, ItemDef.Slot.ARMOR).def.id, &"cape_de_rodeur")
    assert_signal_emitted(profile, "changed")
    assert_false(armory.is_picker_open())
    assert_eq(armory.tile(ItemDef.Slot.ARMOR).item.def.id, &"cape_de_rodeur")


func test_choosing_nothing_removes_the_piece() -> void:
    var cimier: OwnedItem = profile.items_for(KnightClass.VEILLEUR, ItemDef.Slot.HELM).filter(
        func(o: OwnedItem) -> bool: return o.def.id == &"heaume_a_cimier")[0]
    profile.equip(KnightClass.VEILLEUR, cimier.uid)
    armory.open_slot(ItemDef.Slot.HELM)
    armory.rows()[-1].pressed.emit()
    armory.equip_preview()
    assert_null(profile.equipped(KnightClass.VEILLEUR, ItemDef.Slot.HELM))


func test_the_worn_piece_is_marked_and_tried_first() -> void:
    armory.open_slot(ItemDef.Slot.WEAPON)
    var worn := armory.rows().filter(func(r: GearPieceButton) -> bool: return r.worn)
    assert_eq(worn.size(), 1)
    assert_true(worn[0].item.def.starter)
    assert_eq(armory.previewed(), worn[0].item)


func test_back_closes_the_list_then_the_armory() -> void:
    watch_signals(armory)
    armory.open_slot(ItemDef.Slot.TALISMAN)
    assert_true(armory.go_back())
    assert_false(armory.is_picker_open())
    assert_signal_not_emitted(armory, "closed")
    assert_true(armory.go_back())
    assert_signal_emitted(armory, "closed")


func test_a_piece_button_describes_itself_for_screen_readers() -> void:
    armory.open_slot(ItemDef.Slot.HELM)
    var text := _row_for(&"heaume_a_cimier").accessibility_name
    assert_string_contains(text, "Heaume à cimier")
    assert_string_contains(text, "Croissant, niveau 1")
    assert_string_contains(text, "Esquive −20 %")


func test_percent_rounds_to_whole_numbers() -> void:
    assert_eq(GearView.percent(140), "+14 %")
    assert_eq(GearView.percent(-200), "−20 %")
    assert_eq(GearView.percent(225), "+23 %")
    assert_eq(GearView.percent(0), "+0 %")


func _upgrade_button() -> Button:
    for child in armory.get_children():
        if child is Button and child.text.begins_with("Améliorer"):
            return child
    return null


func test_a_tried_piece_can_be_upgraded_with_shards() -> void:
    profile.add_shards(50)
    armory.open_slot(ItemDef.Slot.ARMOR)
    var cape := _row_for(&"cape_de_rodeur").item
    armory.preview(cape)
    var button := _upgrade_button()
    assert_true(button.visible)
    assert_false(button.disabled)
    assert_string_contains(button.text, str(PowerBudget.upgrade_cost(1)))
    button.pressed.emit()
    assert_eq(cape.level, 2)
    assert_eq(profile.shards, 50 - PowerBudget.upgrade_cost(1))
    assert_eq(armory.previewed(), cape, "on reste sur la pièce améliorée")
    assert_string_contains(_row_for(&"cape_de_rodeur").accessibility_name, "niveau 2")


func test_upgrading_without_shards_is_greyed_out() -> void:
    armory.open_slot(ItemDef.Slot.ARMOR)
    armory.preview(_row_for(&"cape_de_rodeur").item)
    assert_true(_upgrade_button().visible)
    assert_true(_upgrade_button().disabled)


func test_a_starter_weapon_offers_no_upgrade() -> void:
    profile.add_shards(50)
    armory.open_slot(ItemDef.Slot.WEAPON)
    armory.preview(profile.equipped(KnightClass.VEILLEUR, ItemDef.Slot.WEAPON))
    assert_false(_upgrade_button().visible)



func _recycle_button() -> Button:
    for child in armory.get_children():
        if child is Button and (child.text.begins_with("Recycler") or child.text == "Confirmer ?"):
            return child
    return null


func test_recycling_asks_for_a_second_touch() -> void:
    armory.open_slot(ItemDef.Slot.ARMOR)
    armory.preview(_row_for(&"cape_de_rodeur").item)
    var button := _recycle_button()
    assert_true(button.visible)
    assert_eq(button.text, "Recycler +%d" % PowerBudget.SHARD_VALUE[Rarity.Tier.GIBBEUSE])
    button.pressed.emit()
    assert_eq(button.text, "Confirmer ?")
    assert_not_null(_row_for(&"cape_de_rodeur"), "rien n'est recyclé à la première touche")
    button.pressed.emit()
    assert_null(_row_for(&"cape_de_rodeur"))
    assert_eq(profile.shards, PowerBudget.SHARD_VALUE[Rarity.Tier.GIBBEUSE])


func test_trying_another_piece_cancels_the_confirmation() -> void:
    armory.open_slot(ItemDef.Slot.ARMOR)
    armory.preview(_row_for(&"cape_de_rodeur").item)
    _recycle_button().pressed.emit()
    armory.preview(_row_for(&"cotte_de_mailles").item)
    assert_string_starts_with(_recycle_button().text, "Recycler")


func test_a_worn_piece_offers_no_recycling() -> void:
    var mail: OwnedItem = profile.items_for(KnightClass.VEILLEUR, ItemDef.Slot.ARMOR).filter(
        func(o: OwnedItem) -> bool: return o.def.id == &"cotte_de_mailles")[0]
    profile.equip(KnightClass.VEILLEUR, mail.uid)
    armory.open_slot(ItemDef.Slot.ARMOR)
    armory.preview(mail)
    assert_false(_recycle_button().visible)
