extends GutTest
## Butin : la rareté tirée, la garantie, les pièces possibles, et ce que rapporte un duel.


func _profile() -> PlayerProfile:
    return PlayerProfile.new()


func test_rarities_follow_their_weights() -> void:
    var rng := RngRandomSource.new(11)
    var counts := [0, 0, 0, 0]
    for i in 4000:
        counts[LootTable.roll_rarity(rng, 0)] += 1
    assert_almost_eq(counts[0] / 4000.0, 0.6, 0.04)
    assert_almost_eq(counts[1] / 4000.0, 0.28, 0.04)
    assert_almost_eq(counts[2] / 4000.0, 0.1, 0.03)
    assert_almost_eq(counts[3] / 4000.0, 0.02, 0.01)


func test_the_tenth_reliquary_without_gibbeuse_gives_one() -> void:
    var always_croissant := ScriptedRandomSource.new([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
    assert_eq(LootTable.roll_rarity(always_croissant, LootTable.PITY_LIMIT - 2), Rarity.Tier.CROISSANT)
    assert_eq(LootTable.roll_rarity(always_croissant, LootTable.PITY_LIMIT - 1), Rarity.Tier.GIBBEUSE)


func test_a_minimum_rarity_is_respected() -> void:
    var rng := ScriptedRandomSource.new([0])
    assert_eq(LootTable.roll_rarity(rng, 0, Rarity.Tier.GIBBEUSE), Rarity.Tier.GIBBEUSE)


func test_a_dropped_piece_fits_the_knight_and_is_never_a_starter() -> void:
    var rng := RngRandomSource.new(5)
    var slots := {}
    for i in 400:
        var def := LootTable.roll_piece(rng, KnightClass.RODEUSE)
        assert_false(def.starter)
        assert_true(def.fits(KnightClass.RODEUSE), String(def.id))
        slots[def.slot] = true
    assert_eq(slots.size(), ItemDef.SLOTS.size(), "les quatre emplacements tombent")


func test_a_victory_opens_a_reliquary_and_climbs_a_palier() -> void:
    var profile := _profile()
    var count := profile.items.size()
    watch_signals(profile)
    var reward := Reliquary.open(profile, true, false, ScriptedRandomSource.new([95, 1, 0]))
    assert_true(reward.won)
    assert_eq(reward.palier, 1)
    assert_eq(profile.palier, 2)
    assert_true(reward.has_new_piece())
    assert_eq(reward.item.rarity, Rarity.Tier.GIBBEUSE)
    assert_eq(profile.items.size(), count + 1)
    assert_eq(profile.shards, Reliquary.SHARDS_WIN)
    assert_eq(profile.pity, 0, "une Gibbeuse remet la garantie à zéro")
    assert_signal_emitted_with_parameters(profile, "palier_cleared", [1])


func test_a_defeat_gives_shards_and_keeps_the_palier() -> void:
    var profile := _profile()
    var count := profile.items.size()
    var reward := Reliquary.open(profile, false, false, ScriptedRandomSource.new())
    assert_false(reward.won)
    assert_null(reward.item)
    assert_eq(profile.palier, 1)
    assert_eq(profile.shards, Reliquary.SHARDS_LOSS)
    assert_eq(profile.items.size(), count)


func test_a_piece_already_owned_turns_into_shards() -> void:
    var profile := _profile() ## le cadeau de bienvenue contient déjà un Heaume à cimier Croissant
    var helm_slot := ItemDef.SLOTS.find(ItemDef.Slot.HELM)
    var count := profile.items.size()
    var reward := Reliquary.open(profile, true, false, ScriptedRandomSource.new([0, helm_slot, 0]))
    assert_eq(reward.item.def.id, &"heaume_a_cimier")
    assert_true(reward.duplicate)
    assert_false(reward.has_new_piece())
    assert_eq(profile.items.size(), count)
    assert_eq(profile.shards, Reliquary.SHARDS_WIN + PowerBudget.SHARD_VALUE[Rarity.Tier.CROISSANT])
    assert_eq(profile.pity, 1)


func test_a_rarer_copy_of_an_owned_piece_is_kept() -> void:
    var profile := _profile()
    var helm_slot := ItemDef.SLOTS.find(ItemDef.Slot.HELM)
    var reward := Reliquary.open(profile, true, false, ScriptedRandomSource.new([65, helm_slot, 0]))
    assert_eq(reward.item.rarity, Rarity.Tier.QUARTIER)
    assert_eq(reward.item.def.id, &"heaume_a_cimier")
    assert_true(reward.has_new_piece())


func test_a_guardian_always_gives_a_gibbeuse() -> void:
    var profile := _profile()
    var reward := Reliquary.open(profile, true, true, ScriptedRandomSource.new([0, 0, 0]))
    assert_true(reward.guardian)
    assert_gte(reward.item.rarity, Rarity.Tier.GIBBEUSE)


func test_the_guarantee_counts_reliquaries_without_gibbeuse() -> void:
    var profile := _profile()
    for i in LootTable.PITY_LIMIT - 1:
        Reliquary.open(profile, true, false, ScriptedRandomSource.new([0, 0, 0]))
    assert_eq(profile.pity, LootTable.PITY_LIMIT - 1)
    var reward := Reliquary.open(profile, true, false, ScriptedRandomSource.new([0, 0, 0]))
    assert_eq(reward.item.rarity, Rarity.Tier.GIBBEUSE)
    assert_eq(profile.pity, 0)


func test_the_fortieth_reliquary_without_full_moon_gives_one() -> void:
    var rng := ScriptedRandomSource.new([0])
    assert_eq(LootTable.roll_rarity(rng, 0, Rarity.Tier.CROISSANT, LootTable.FULL_MOON_PITY_LIMIT - 1), Rarity.Tier.PLEINE_LUNE)


func test_the_full_moon_guarantee_counts_and_resets() -> void:
    var profile := _profile()
    Reliquary.open(profile, true, false, ScriptedRandomSource.new([0, 0, 0]))
    assert_eq(profile.full_moon_pity, 1)
    Reliquary.open(profile, true, false, ScriptedRandomSource.new([99, 0, 0]))
    assert_eq(profile.full_moon_pity, 0, "une Pleine lune remet sa garantie à zéro")
    assert_eq(profile.pity, 0, "et celle de la Gibbeuse aussi")
