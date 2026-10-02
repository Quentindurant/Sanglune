extends GutTest
## Profil joueur : chevalier actif, évènement de changement, relecture prudente, sauvegardes.

const TEST_PATH := "user://test_profile.json"


func after_each() -> void:
    if FileAccess.file_exists(TEST_PATH):
        DirAccess.remove_absolute(TEST_PATH)


func test_new_profile_plays_the_veilleur() -> void:
    assert_eq(PlayerProfile.new().knight().id, KnightClass.VEILLEUR)


func test_selecting_a_knight_announces_the_change() -> void:
    var profile := PlayerProfile.new()
    watch_signals(profile)
    assert_true(profile.select_knight(KnightClass.COLOSSE))
    assert_eq(profile.knight_id, KnightClass.COLOSSE)
    assert_signal_emit_count(profile, "changed", 1)


func test_selecting_the_same_knight_changes_nothing() -> void:
    var profile := PlayerProfile.new()
    watch_signals(profile)
    profile.select_knight(KnightClass.VEILLEUR)
    assert_signal_not_emitted(profile, "changed")


func test_unknown_knight_is_refused() -> void:
    var profile := PlayerProfile.new()
    assert_false(profile.select_knight(&"paladin"))
    assert_eq(profile.knight_id, KnightClass.VEILLEUR)


func test_round_trip_through_a_dictionary() -> void:
    var profile := PlayerProfile.new()
    profile.select_knight(KnightClass.RODEUSE)
    assert_eq(PlayerProfile.from_dict(profile.to_dict()).knight_id, KnightClass.RODEUSE)


func test_invalid_stored_data_falls_back_to_defaults() -> void:
    for data: Dictionary in [{}, {"knight": "paladin"}, {"knight": 42}, {"knight": null}]:
        assert_eq(PlayerProfile.from_dict(data).knight_id, KnightClass.VEILLEUR, str(data))


func test_memory_store_keeps_the_profile() -> void:
    var store := MemoryProfileStore.new()
    var profile := store.load_profile()
    profile.select_knight(KnightClass.FAUCHEUSE)
    store.save_profile(profile)
    assert_eq(store.load_profile().knight_id, KnightClass.FAUCHEUSE)


func test_local_store_survives_a_restart() -> void:
    var profile := PlayerProfile.new()
    profile.select_knight(KnightClass.COLOSSE)
    LocalProfileStore.new(TEST_PATH).save_profile(profile)
    assert_eq(LocalProfileStore.new(TEST_PATH).load_profile().knight_id, KnightClass.COLOSSE)


func test_local_store_without_file_gives_a_new_profile() -> void:
    assert_eq(LocalProfileStore.new(TEST_PATH).load_profile().knight_id, KnightClass.VEILLEUR)


func test_local_store_ignores_a_corrupted_file() -> void:
    var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
    file.store_string("{ pas du json")
    file.close()
    assert_eq(LocalProfileStore.new(TEST_PATH).load_profile().knight_id, KnightClass.VEILLEUR)


# Équipement

func _owned(profile: PlayerProfile, item_id: StringName) -> OwnedItem:
    for owned in profile.items:
        if owned.def.id == item_id:
            return owned
    return null


func test_a_new_player_holds_every_starter_weapon_and_the_welcome_gifts() -> void:
    var profile := PlayerProfile.new()
    for knight in KnightClass.all():
        var weapon := profile.equipped(knight.id, ItemDef.Slot.WEAPON)
        assert_not_null(weapon, String(knight.id))
        assert_true(weapon.def.starter)
    for item_id: StringName in ItemCatalog.WELCOME_GIFTS:
        assert_not_null(_owned(profile, item_id), String(item_id))
    assert_eq(profile.items.size(), KnightClass.all().size() + ItemCatalog.WELCOME_GIFTS.size())


func test_a_new_player_wears_nothing_but_his_weapon() -> void:
    var profile := PlayerProfile.new()
    for slot in [ItemDef.Slot.HELM, ItemDef.Slot.ARMOR, ItemDef.Slot.TALISMAN]:
        assert_null(profile.equipped(KnightClass.VEILLEUR, slot))
    assert_eq(profile.loadout(KnightClass.VEILLEUR).power(), PowerBudget.BASE_POWER)


func test_pieces_offered_for_a_slot_fit_the_knight() -> void:
    var profile := PlayerProfile.new()
    var weapons := profile.items_for(KnightClass.COLOSSE, ItemDef.Slot.WEAPON)
    assert_eq(weapons.size(), 2)
    for owned in weapons:
        assert_eq(owned.def.knight_id, KnightClass.COLOSSE)
    assert_eq(profile.items_for(KnightClass.COLOSSE, ItemDef.Slot.HELM).size(), 2)


func test_pieces_offered_come_strongest_first() -> void:
    var weapons := PlayerProfile.new().items_for(KnightClass.VEILLEUR, ItemDef.Slot.WEAPON)
    assert_false(weapons[0].def.starter)
    assert_true(weapons[-1].def.starter)


func test_equipping_announces_the_change_and_shapes_the_loadout() -> void:
    var profile := PlayerProfile.new()
    var mail := _owned(profile, &"cotte_de_mailles")
    watch_signals(profile)
    assert_true(profile.equip(KnightClass.COLOSSE, mail.uid))
    assert_eq(profile.equipped(KnightClass.COLOSSE, ItemDef.Slot.ARMOR), mail)
    assert_signal_emitted_with_parameters(profile, "equipment_changed", [KnightClass.COLOSSE])
    assert_signal_emit_count(profile, "changed", 1)
    assert_gt(profile.loadout(KnightClass.COLOSSE).power(), PowerBudget.BASE_POWER)
    assert_null(profile.equipped(KnightClass.VEILLEUR, ItemDef.Slot.ARMOR), "chaque chevalier a son équipement")


func test_equipping_the_piece_already_worn_changes_nothing() -> void:
    var profile := PlayerProfile.new()
    var mail := _owned(profile, &"cotte_de_mailles")
    profile.equip(KnightClass.VEILLEUR, mail.uid)
    watch_signals(profile)
    assert_true(profile.equip(KnightClass.VEILLEUR, mail.uid))
    assert_signal_not_emitted(profile, "changed")


func test_a_weapon_of_another_knight_or_an_unknown_piece_is_refused() -> void:
    var profile := PlayerProfile.new()
    assert_false(profile.equip(KnightClass.COLOSSE, _owned(profile, &"epee_effilee").uid))
    assert_false(profile.equip(KnightClass.VEILLEUR, 9999))
    assert_false(profile.equip(&"paladin", _owned(profile, &"cotte_de_mailles").uid))


func test_a_piece_can_be_removed_but_not_the_weapon() -> void:
    var profile := PlayerProfile.new()
    profile.equip(KnightClass.VEILLEUR, _owned(profile, &"heaume_a_cimier").uid)
    assert_true(profile.unequip(KnightClass.VEILLEUR, ItemDef.Slot.HELM))
    assert_null(profile.equipped(KnightClass.VEILLEUR, ItemDef.Slot.HELM))
    assert_false(profile.unequip(KnightClass.VEILLEUR, ItemDef.Slot.HELM))
    assert_false(profile.unequip(KnightClass.VEILLEUR, ItemDef.Slot.WEAPON))


func test_changing_weapon_and_back() -> void:
    var profile := PlayerProfile.new()
    var slim := _owned(profile, &"epee_effilee")
    profile.equip(KnightClass.VEILLEUR, slim.uid)
    assert_eq(profile.loadout(KnightClass.VEILLEUR).look()["weapon"], &"sword_slim")
    profile.equip(KnightClass.VEILLEUR, profile.items_for(KnightClass.VEILLEUR, ItemDef.Slot.WEAPON)[-1].uid)
    assert_eq(profile.loadout(KnightClass.VEILLEUR).look()["weapon"], &"sword")


func test_a_won_piece_joins_the_inventory() -> void:
    var profile := PlayerProfile.new()
    watch_signals(profile)
    var won := profile.add_item(&"croc_de_sang", Rarity.Tier.GIBBEUSE)
    assert_not_null(won)
    assert_eq(profile.item(won.uid), won)
    assert_signal_emitted(profile, "item_added")
    assert_signal_emitted(profile, "changed")
    assert_null(profile.add_item(&"excalibur", Rarity.Tier.CROISSANT))
    assert_null(profile.add_item(&"croc_de_sang", 9))
    assert_null(profile.add_item(&"croc_de_sang", Rarity.Tier.CROISSANT, 11))


func test_equipment_round_trips_through_a_dictionary() -> void:
    var profile := PlayerProfile.new()
    var cape := _owned(profile, &"cape_de_rodeur")
    var won := profile.add_item(&"heaume_a_cornes", Rarity.Tier.PLEINE_LUNE, 4)
    profile.equip(KnightClass.RODEUSE, cape.uid)
    profile.equip(KnightClass.RODEUSE, won.uid)
    var copy := PlayerProfile.from_dict(JSON.parse_string(JSON.stringify(profile.to_dict())))
    assert_eq(copy.items.size(), profile.items.size())
    assert_eq(copy.equipped(KnightClass.RODEUSE, ItemDef.Slot.ARMOR).uid, cape.uid)
    var helm := copy.equipped(KnightClass.RODEUSE, ItemDef.Slot.HELM)
    assert_eq(helm.rarity, Rarity.Tier.PLEINE_LUNE)
    assert_eq(helm.level, 4)
    var fresh := copy.add_item(&"larme_de_lune", Rarity.Tier.CROISSANT)
    assert_null(profile.item(fresh.uid), "un identifiant n'est jamais réutilisé")


func test_a_version_one_profile_keeps_its_knight_and_receives_the_gifts() -> void:
    var profile := PlayerProfile.from_dict({"version": 1, "knight": "faucheuse"})
    assert_eq(profile.knight_id, KnightClass.FAUCHEUSE)
    assert_not_null(_owned(profile, &"hallebarde_lourde"))
    assert_true(profile.equipped(KnightClass.FAUCHEUSE, ItemDef.Slot.WEAPON).def.starter)


func test_tampered_equipment_is_cleaned_up() -> void:
    var data := {
        "version": 2, "knight": "veilleur", "next_uid": 3,
        "items": [
            {"uid": 1, "id": "cotte_de_mailles", "rarity": 1, "level": 1},
            {"uid": 1, "id": "croc_de_sang", "rarity": 1, "level": 1},
            {"uid": 2, "id": "excalibur", "rarity": 1, "level": 1},
            {"uid": 3, "id": "heaume_a_cimier", "rarity": 7, "level": 1},
            {"uid": 4, "id": "heaume_a_cimier", "rarity": 0, "level": 99},
            {"uid": 5.5, "id": "larme_de_lune", "rarity": 0, "level": 1},
            {"uid": 6, "id": "epee_effilee", "rarity": 2, "level": 3},
            "pas une pièce",
        ],
        "equipped": {
            "veilleur": {"armor": 1, "helm": 1, "talisman": 42},
            "colosse": {"weapon": 6},
            "paladin": {"armor": 1},
        },
    }
    var profile := PlayerProfile.from_dict(data)
    var kept := profile.items.filter(func(o: OwnedItem) -> bool: return not o.def.starter)
    assert_eq(kept.size(), 2, "seules la cotte et l'épée sont valides")
    assert_eq(profile.equipped(KnightClass.VEILLEUR, ItemDef.Slot.ARMOR).def.id, &"cotte_de_mailles")
    assert_null(profile.equipped(KnightClass.VEILLEUR, ItemDef.Slot.HELM), "une cotte ne se porte pas en heaume")
    assert_null(profile.equipped(KnightClass.VEILLEUR, ItemDef.Slot.TALISMAN))
    assert_true(profile.equipped(KnightClass.COLOSSE, ItemDef.Slot.WEAPON).def.starter, "l'épée n'est pas au Colosse")
    for knight in KnightClass.all():
        assert_not_null(profile.equipped(knight.id, ItemDef.Slot.WEAPON), "l'arme de départ revient toujours")
    var fresh := profile.add_item(&"larme_de_lune", Rarity.Tier.CROISSANT)
    assert_eq(profile.items.filter(func(o: OwnedItem) -> bool: return o.uid == fresh.uid).size(), 1)


func test_a_huge_inventory_is_capped() -> void:
    var stored := []
    for i in PlayerProfile.MAX_ITEMS + 50:
        stored.append({"uid": i + 1, "id": "larme_de_lune", "rarity": 0, "level": 1})
    var profile := PlayerProfile.from_dict({"version": 2, "items": stored})
    assert_lte(profile.items.size(), PlayerProfile.MAX_ITEMS + KnightClass.all().size())


func test_local_store_keeps_the_equipment() -> void:
    var profile := PlayerProfile.new()
    profile.equip(KnightClass.VEILLEUR, _owned(profile, &"heaume_a_cimier").uid)
    LocalProfileStore.new(TEST_PATH).save_profile(profile)
    var reloaded := LocalProfileStore.new(TEST_PATH).load_profile()
    assert_eq(reloaded.equipped(KnightClass.VEILLEUR, ItemDef.Slot.HELM).def.id, &"heaume_a_cimier")


# Éclats, palier, amélioration

func test_a_new_player_starts_at_the_first_palier_without_shards() -> void:
    var profile := PlayerProfile.new()
    assert_eq(profile.palier, 1)
    assert_eq(profile.shards, 0)
    assert_eq(profile.pity, 0)


func test_upgrading_costs_shards_and_raises_the_level() -> void:
    var profile := PlayerProfile.new()
    var cape := _owned(profile, &"cape_de_rodeur")
    assert_false(profile.upgrade(cape.uid), "pas d'éclats, pas d'amélioration")
    profile.add_shards(PowerBudget.upgrade_cost(1) + 3)
    var before: int = cape.modifiers()[GearStat.Stat.DODGE]
    watch_signals(profile)
    assert_true(profile.upgrade(cape.uid))
    assert_eq(cape.level, 2)
    assert_eq(profile.shards, 3)
    assert_gt(cape.modifiers()[GearStat.Stat.DODGE], before)
    assert_signal_emitted(profile, "item_upgraded")
    assert_signal_emitted(profile, "changed")


func test_a_starter_weapon_or_a_maxed_piece_cannot_be_upgraded() -> void:
    var profile := PlayerProfile.new()
    profile.add_shards(10000)
    assert_false(profile.upgrade(profile.equipped(KnightClass.VEILLEUR, ItemDef.Slot.WEAPON).uid))
    var top := profile.add_item(&"croc_de_sang", Rarity.Tier.QUARTIER, PowerBudget.MAX_LEVEL)
    assert_false(profile.upgrade(top.uid))
    assert_false(profile.upgrade(424242))


func test_shards_palier_and_guarantee_round_trip_and_are_bounded() -> void:
    var profile := PlayerProfile.new()
    profile.add_shards(57)
    profile.clear_palier()
    profile.set_pity(4)
    var copy := PlayerProfile.from_dict(JSON.parse_string(JSON.stringify(profile.to_dict())))
    assert_eq(copy.shards, 57)
    assert_eq(copy.palier, 2)
    assert_eq(copy.pity, 4)
    var tampered := PlayerProfile.from_dict({"version": 2, "items": [], "shards": -5, "palier": 0, "pity": 99})
    assert_eq(tampered.shards, 0)
    assert_eq(tampered.palier, 1)
    assert_eq(tampered.pity, LootTable.PITY_LIMIT - 1)
    var garbage := PlayerProfile.from_dict({"version": 2, "items": [], "shards": "beaucoup", "palier": 2.5})
    assert_eq(garbage.shards, 0)
    assert_eq(garbage.palier, 1)



# Recyclage

func test_recycling_turns_a_piece_into_shards() -> void:
    var profile := PlayerProfile.new()
    var cape := _owned(profile, &"cape_de_rodeur")
    var count := profile.items.size()
    watch_signals(profile)
    assert_eq(profile.recycle(cape.uid), PowerBudget.SHARD_VALUE[Rarity.Tier.GIBBEUSE])
    assert_eq(profile.items.size(), count - 1)
    assert_null(profile.item(cape.uid))
    assert_eq(profile.shards, PowerBudget.SHARD_VALUE[Rarity.Tier.GIBBEUSE])
    assert_signal_emitted(profile, "item_recycled")
    assert_signal_emitted(profile, "changed")


func test_recycling_refunds_half_of_the_upgrades() -> void:
    var profile := PlayerProfile.new()
    var helm := _owned(profile, &"heaume_a_cimier")
    profile.add_shards(PowerBudget.upgrade_cost(1) + PowerBudget.upgrade_cost(2))
    profile.upgrade(helm.uid)
    profile.upgrade(helm.uid)
    assert_eq(profile.shards, 0)
    var spent := PowerBudget.upgrade_cost(1) + PowerBudget.upgrade_cost(2)
    assert_eq(profile.recycle(helm.uid), PowerBudget.SHARD_VALUE[Rarity.Tier.CROISSANT] + spent / 2)


func test_a_worn_piece_or_a_starter_weapon_cannot_be_recycled() -> void:
    var profile := PlayerProfile.new()
    var mail := _owned(profile, &"cotte_de_mailles")
    profile.equip(KnightClass.COLOSSE, mail.uid)
    assert_true(profile.is_worn(mail.uid))
    assert_eq(profile.recycle(mail.uid), 0)
    assert_not_null(profile.item(mail.uid))
    var starter := profile.equipped(KnightClass.VEILLEUR, ItemDef.Slot.WEAPON)
    assert_eq(profile.recycle(starter.uid), 0)
    assert_eq(profile.recycle(31337), 0)
