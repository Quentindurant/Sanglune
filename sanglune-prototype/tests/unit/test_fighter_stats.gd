extends GutTest
## Caractéristiques résolues : la classe, ajustée par l'équipement, appliquée au duel.


func _gear(knight_id: StringName, item_id: StringName, rarity: int = Rarity.Tier.QUARTIER, level: int = 1) -> Loadout:
    var loadout := Loadout.new(knight_id)
    loadout.wear(OwnedItem.new(1, ItemCatalog.by_id(item_id), rarity, level))
    return loadout


func test_without_gear_every_knight_keeps_exactly_its_class_stats() -> void:
    for knight in KnightClass.all():
        var stats := FighterStats.resolve(knight, Loadout.new(knight.id))
        assert_eq(stats.max_hp, knight.max_hp)
        assert_eq(stats.walk_speed, knight.walk_speed)
        assert_eq(stats.jump_speed, knight.jump_speed)
        assert_eq(stats.dodge_speed, knight.dodge_speed)
        assert_eq(stats.ultimate_id, knight.ultimate_id)
        for kind: int in CombatAction.DATA:
            for key: String in ["startup", "active", "recovery", "damage", "reach"]:
                assert_eq(stats.stat(kind, key), knight.stat(kind, key), "%s %d %s" % [knight.id, kind, key])
        var ultimate := Ultimate.by_id(knight.ultimate_id)
        assert_eq(stats.stat(CombatAction.Kind.ULTIME, "damage"), ultimate.stat("damage"))
        assert_eq(stats.stun_frames(Fighter.HITSTUN), Fighter.HITSTUN)


func test_a_starter_weapon_changes_nothing() -> void:
    var knight := KnightClass.by_id(KnightClass.FAUCHEUSE)
    var loadout := Loadout.new(knight.id)
    loadout.wear(OwnedItem.new(1, ItemCatalog.starter_weapon(knight.id)))
    var stats := FighterStats.resolve(knight, loadout)
    assert_eq(stats.stat(CombatAction.Kind.FRAPPE, "reach"), knight.stat(CombatAction.Kind.FRAPPE, "reach"))
    assert_eq(stats.power, PowerBudget.BASE_POWER)


func test_chainmail_adds_life_and_slows_the_walk() -> void:
    var knight := KnightClass.starter()
    var stats := FighterStats.resolve(knight, _gear(knight.id, &"cotte_de_mailles"))
    assert_gt(stats.max_hp, knight.max_hp)
    assert_lt(stats.walk_speed, knight.walk_speed)
    assert_lt(stats.stun_frames(Fighter.HITSTUN), Fighter.HITSTUN)


func test_a_slim_sword_reaches_further_and_feeds_the_ultimate_but_hurts_less() -> void:
    var knight := KnightClass.starter()
    var stats := FighterStats.resolve(knight, _gear(knight.id, &"epee_effilee"))
    var frappe := CombatAction.Kind.FRAPPE
    assert_gt(stats.stat(frappe, "reach"), knight.stat(frappe, "reach"))
    assert_lt(stats.stat(frappe, "damage"), knight.stat(frappe, "damage"))
    assert_gt(stats.stat(CombatAction.Kind.ULTIME, "damage"), Ultimate.by_id(knight.ultimate_id).stat("damage"))
    assert_eq(stats.stat(frappe, "startup"), knight.stat(frappe, "startup"), "la vitesse des coups ne bouge pas")
    assert_eq(stats.stat(CombatAction.Kind.PARADE, "active"), knight.stat(CombatAction.Kind.PARADE, "active"))


func test_a_talisman_strengthens_the_ultimate() -> void:
    var knight := KnightClass.starter()
    var stats := FighterStats.resolve(knight, _gear(knight.id, &"larme_de_lune"))
    var ultimate := Ultimate.by_id(knight.ultimate_id)
    assert_gt(stats.stat(CombatAction.Kind.ULTIME, "damage"), ultimate.stat("damage"))
    assert_lt(stats.stat(CombatAction.Kind.FRAPPE, "damage"), knight.stat(CombatAction.Kind.FRAPPE, "damage"))


func test_the_equipped_weapon_decides_the_ultimate() -> void:
    var odd_weapon := ItemDef.new(&"test_marteau", {
        "name": "Marteau d'essai", "slot": ItemDef.Slot.WEAPON, "knight": KnightClass.VEILLEUR,
        "ultimate": Ultimate.SEISME, "starter": true,
    })
    var loadout := Loadout.new(KnightClass.VEILLEUR)
    loadout.wear(OwnedItem.new(7, odd_weapon))
    var fighter := Fighter.new(-1, 0, KnightClass.starter(), FighterStats.resolve(KnightClass.starter(), loadout))
    assert_eq(fighter.ultimate.id, Ultimate.SEISME)
    assert_eq(fighter.stat(CombatAction.Kind.ULTIME, "reach"), Ultimate.by_id(Ultimate.SEISME).stat("reach"))


func test_a_loadout_refuses_a_weapon_of_another_knight() -> void:
    var loadout := Loadout.new(KnightClass.COLOSSE)
    assert_false(loadout.wear(OwnedItem.new(1, ItemCatalog.by_id(&"epee_effilee"))))
    assert_null(loadout.piece(ItemDef.Slot.WEAPON))
    assert_eq(loadout.ultimate_id(), Ultimate.SEISME)


func test_the_duel_applies_each_side_gear() -> void:
    var knight := KnightClass.starter()
    var duel := Duel.new(knight, knight, _gear(knight.id, &"cotte_de_mailles"), null)
    assert_gt(duel.left.max_hp(), duel.right.max_hp())
    assert_eq(duel.left.hp, duel.left.max_hp())


func test_resistance_shortens_the_stun_received() -> void:
    var knight := KnightClass.starter()
    var tough := Fighter.new(1, 0, knight, FighterStats.resolve(knight, _gear(knight.id, &"heaume_a_cornes")))
    var bare := Fighter.new(1, 0, knight)
    tough.take_hit(5, Fighter.HITSTUN)
    bare.take_hit(5, Fighter.HITSTUN)
    assert_lt(tough.phase_frames, bare.phase_frames)


func test_a_cape_lengthens_the_dodge() -> void:
    var knight := KnightClass.starter()
    var stats := FighterStats.resolve(knight, _gear(knight.id, &"cape_de_rodeur"))
    assert_gt(stats.dodge_speed, knight.dodge_speed)
    assert_lt(stats.max_hp, knight.max_hp)


func test_the_look_gathers_every_worn_piece() -> void:
    var loadout := _gear(KnightClass.VEILLEUR, &"heaume_a_cimier")
    loadout.wear(OwnedItem.new(2, ItemCatalog.by_id(&"cape_de_rodeur")))
    loadout.wear(OwnedItem.new(3, ItemCatalog.by_id(&"epee_effilee")))
    var look := loadout.look()
    assert_eq(look.get("crest"), &"plume")
    assert_eq(look.get("cape"), &"long")
    assert_eq(look.get("weapon"), &"sword_slim")
