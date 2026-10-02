extends GutTest
## Catalogue et budget de l'équipement : chaque pièce est un compromis, et deux pièces de même rang se valent.


func _points(mods: Dictionary) -> float:
    var total := 0.0
    for stat: int in mods:
        total += float(mods[stat]) / GearStat.PER_POINT[stat]
    return total


func test_item_ids_are_unique_and_every_definition_loads() -> void:
    var ids := {}
    for def in ItemCatalog.all():
        assert_false(ids.has(def.id), "doublon : %s" % def.id)
        ids[def.id] = true
        assert_true(def.slot in ItemDef.SLOTS, String(def.id))
    assert_eq(ids.size(), ItemCatalog.DEFINITIONS.size())


func test_every_piece_but_a_starter_weapon_is_a_compromise() -> void:
    for def in ItemCatalog.all():
        if def.starter:
            continue
        assert_eq(def.gains.size(), 2, "%s : deux gains possibles" % def.id)
        assert_gt(def.losses.size(), 0, "%s : au moins une perte" % def.id)
        for stat in def.gains:
            assert_true(GearStat.is_valid(stat), String(def.id))
            assert_false(stat in def.losses, "%s gagne et perd %s" % [def.id, stat])


func test_starter_weapons_are_neutral() -> void:
    for knight in KnightClass.all():
        var def := ItemCatalog.starter_weapon(knight.id)
        assert_not_null(def, String(knight.id))
        assert_true(def.starter)
        assert_true(PowerBudget.modifiers(def, Rarity.Tier.CROISSANT, 1).is_empty())
        assert_eq(PowerBudget.net_milli_points(def, Rarity.Tier.CROISSANT, 1), 0)


func test_each_starter_weapon_carries_its_knight_ultimate() -> void:
    for knight in KnightClass.all():
        assert_eq(ItemCatalog.starter_weapon(knight.id).ultimate_id, knight.ultimate_id, String(knight.id))


func test_weapons_belong_to_one_knight_and_other_pieces_to_all() -> void:
    for def in ItemCatalog.all():
        if def.is_weapon():
            assert_not_null(KnightClass.by_id(def.knight_id), "%s sans chevalier" % def.id)
            assert_not_null(Ultimate.by_id(def.ultimate_id), "%s sans ultime" % def.id)
        else:
            assert_eq(def.knight_id, &"", "%s devrait aller à tous" % def.id)
            assert_true(def.fits(KnightClass.COLOSSE) and def.fits(KnightClass.RODEUSE))


func test_a_weapon_only_fits_its_knight() -> void:
    var sword := ItemCatalog.by_id(&"epee_effilee")
    assert_true(sword.fits(KnightClass.VEILLEUR))
    assert_false(sword.fits(KnightClass.COLOSSE))


func test_pieces_of_the_same_rank_have_the_same_budget() -> void:
    for rarity in range(Rarity.Tier.CROISSANT, Rarity.Tier.PLEINE_LUNE + 1):
        for level in [1, 5, 10]:
            var expected := PowerBudget.net_milli_points(ItemCatalog.by_id(&"cape_de_rodeur"), rarity, level) / 1000.0
            for def in ItemCatalog.all():
                if def.starter:
                    continue
                var points := _points(PowerBudget.modifiers(def, rarity, level))
                assert_almost_eq(points, expected, 0.3, "%s, rareté %d, niveau %d" % [def.id, rarity, level])


func test_a_croissant_has_one_gain_and_rarer_pieces_two() -> void:
    var helm := ItemCatalog.by_id(&"heaume_a_cimier")
    var croissant := PowerBudget.modifiers(helm, Rarity.Tier.CROISSANT, 1)
    var quartier := PowerBudget.modifiers(helm, Rarity.Tier.QUARTIER, 1)
    assert_eq(croissant.keys().filter(func(s: int) -> bool: return croissant[s] > 0).size(), 1)
    assert_eq(quartier.keys().filter(func(s: int) -> bool: return quartier[s] > 0).size(), 2)


func test_rarer_and_higher_levels_mean_stronger_gains_but_the_same_loss() -> void:
    var cape := ItemCatalog.by_id(&"cape_de_rodeur")
    var low := PowerBudget.modifiers(cape, Rarity.Tier.QUARTIER, 1)
    var rare := PowerBudget.modifiers(cape, Rarity.Tier.GIBBEUSE, 1)
    var high := PowerBudget.modifiers(cape, Rarity.Tier.QUARTIER, 10)
    assert_gt(rare[GearStat.Stat.WALK], low[GearStat.Stat.WALK])
    assert_gt(high[GearStat.Stat.WALK], rare[GearStat.Stat.WALK])
    assert_eq(low[GearStat.Stat.HP], high[GearStat.Stat.HP])
    assert_lt(low[GearStat.Stat.HP], 0)


func test_power_starts_at_one_hundred_and_grows_with_pieces() -> void:
    assert_eq(PowerBudget.power(0), PowerBudget.BASE_POWER)
    var loadout := Loadout.new(KnightClass.VEILLEUR)
    assert_eq(loadout.power(), PowerBudget.BASE_POWER)
    var mail := OwnedItem.new(1, ItemCatalog.by_id(&"cotte_de_mailles"), Rarity.Tier.QUARTIER)
    loadout.wear(mail)
    assert_eq(loadout.power(), PowerBudget.power(mail.net_milli_points()))
    assert_gt(loadout.power(), PowerBudget.BASE_POWER)


func test_every_piece_gains_more_than_it_loses() -> void:
    for rarity in range(Rarity.Tier.CROISSANT, Rarity.Tier.PLEINE_LUNE + 1):
        assert_gt(PowerBudget.gain_milli_points(rarity, PowerBudget.MIN_LEVEL), PowerBudget.loss_milli_points())


func test_a_full_kit_at_the_top_stays_within_the_agreed_ceiling() -> void:
    var net := 4 * PowerBudget.net_milli_points(ItemCatalog.by_id(&"cape_de_rodeur"), Rarity.Tier.GIBBEUSE, PowerBudget.MAX_LEVEL)
    assert_between(net / 1000.0, 15.0, 21.0, "environ 18 points : 3 victoires sur 4 en IA contre IA")


func test_welcome_gifts_exist() -> void:
    for item_id: StringName in ItemCatalog.WELCOME_GIFTS:
        assert_not_null(ItemCatalog.by_id(item_id), String(item_id))
        assert_true(Rarity.is_valid(ItemCatalog.WELCOME_GIFTS[item_id]))


func test_unknown_or_malformed_ids_give_nothing() -> void:
    for bad: Variant in [&"excalibur", "", null, 42, {}]:
        assert_null(ItemCatalog.by_id(bad), str(bad))


func test_gear_maths_stay_whole_and_bounded() -> void:
    assert_eq(GearStat.grow(100, 0), 100)
    assert_eq(GearStat.grow(100, 140), 114)
    assert_eq(GearStat.grow(100, -5000), 20)
    assert_eq(GearStat.shorten(9, 0), 9)
    assert_eq(GearStat.shorten(10, 200), 8)
    assert_eq(GearStat.shorten(10, -200), 12)
    assert_eq(GearStat.shorten(3, 5000), 1)
