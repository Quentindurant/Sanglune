extends GutTest
## Traits des pièces Pleine lune : seulement éveillés en Pleine lune, et chacun change le combat.

const FRAPPE := CombatAction.Kind.FRAPPE


func _gear(knight_id: StringName, item_id: StringName, rarity: int = Rarity.Tier.PLEINE_LUNE) -> Loadout:
    var loadout := Loadout.new(knight_id)
    loadout.wear(OwnedItem.new(1, ItemCatalog.by_id(item_id), rarity))
    return loadout


func _duel(left_gear: Loadout = null, right_gear: Loadout = null) -> Duel:
    var knight := KnightClass.starter()
    var duel := Duel.new(knight, knight, left_gear, right_gear)
    duel.skip_intro()
    return duel


func _step(duel: Duel, frames: int, left: Intent = null, right: Intent = null) -> void:
    for i in frames:
        duel.step(left if left != null else Intent.of(), right if right != null else Intent.of())
        left = null
        right = null


func test_every_piece_has_a_trait_and_only_a_full_moon_awakens_it() -> void:
    for def in ItemCatalog.all():
        if def.starter:
            continue
        assert_true(GearTrait.is_valid(def.gear_trait), String(def.id))
        assert_eq(OwnedItem.new(1, def, Rarity.Tier.GIBBEUSE).gear_trait(), GearTrait.Trait.NONE)
        assert_eq(OwnedItem.new(1, def, Rarity.Tier.PLEINE_LUNE).gear_trait(), def.gear_trait)
        assert_ne(GearTrait.describe(def.gear_trait), "")


func test_two_pieces_with_the_same_trait_do_not_stack() -> void:
    var loadout := _gear(KnightClass.VEILLEUR, &"heaume_a_cimier")
    loadout.wear(OwnedItem.new(2, ItemCatalog.by_id(&"cotte_de_mailles"), Rarity.Tier.PLEINE_LUNE))
    assert_eq(loadout.traits(), [GearTrait.Trait.GARDE_LUNAIRE])


func test_aube_rouge_starts_every_round_with_a_rune() -> void:
    var duel := _duel(_gear(KnightClass.VEILLEUR, &"larme_de_lune"))
    assert_eq(duel.left.rune, 1)
    assert_eq(duel.right.rune, 0)
    assert_eq(_duel(_gear(KnightClass.VEILLEUR, &"larme_de_lune", Rarity.Tier.GIBBEUSE)).left.rune, 0)


func test_garde_lunaire_lights_a_rune_on_a_successful_parry() -> void:
    for gear in [_gear(KnightClass.VEILLEUR, &"heaume_a_cimier"), null]:
        var duel := _duel(null, gear)
        duel.right.face(-1)
        duel.left.x = duel.right.x - 1200
        _step(duel, 1, null, Intent.of(0, CombatAction.Kind.PARADE))
        _step(duel, 4)
        _step(duel, 30, Intent.of(0, FRAPPE))
        assert_eq(duel.left.hp, duel.left.max_hp())
        assert_eq(duel.right.hp, duel.right.max_hp(), "la frappe est parée")
        assert_eq(duel.right.rune, 1 if gear != null else 0)


func test_chute_lourde_stuns_longer_after_a_plunge() -> void:
    var stuns := []
    for gear in [null, _gear(KnightClass.COLOSSE, &"masse_a_pointes")]:
        var knight := KnightClass.by_id(KnightClass.COLOSSE)
        var duel := Duel.new(knight, KnightClass.starter(), gear, null)
        duel.skip_intro()
        duel.left.x = duel.right.x - 1000
        duel.left.y = 400
        duel.left.vy = 0
        duel.left.request(FRAPPE)
        var stunned := 0
        for i in 80:
            duel.step(Intent.of(), Intent.of())
            if duel.right.phase == Fighter.Phase.STUNNED:
                stunned = maxi(stunned, duel.right.phase_frames)
        stuns.append(stunned)
    assert_gt(stuns[0], 0, "le plongeon touche")
    assert_eq(stuns[1], stuns[0] + GearTrait.CHUTE_LOURDE_FRAMES)


func test_dernier_souffle_hits_harder_when_almost_down() -> void:
    var knight := KnightClass.starter()
    var stats := FighterStats.resolve(knight, _gear(knight.id, &"croc_de_sang"))
    var fighter := Fighter.new(-1, 0, knight, stats)
    var healthy := fighter.damage(FRAPPE)
    fighter.hp = fighter.max_hp() / 5
    assert_gt(fighter.damage(FRAPPE), healthy)
    assert_eq(healthy, stats.stat(FRAPPE, "damage"))


func test_riposte_quickens_the_strike_right_after_a_dodge() -> void:
    var knight := KnightClass.starter()
    var stats := FighterStats.resolve(knight, _gear(knight.id, &"cape_de_rodeur"))
    var fighter := Fighter.new(-1, 0, knight, stats)
    fighter.request(CombatAction.Kind.ESQUIVE)
    fighter.try_start_buffered(1)
    while fighter.phase != Fighter.Phase.IDLE:
        fighter.advance_phase()
    fighter.request(FRAPPE)
    fighter.try_start_buffered(1)
    assert_eq(fighter.phase_frames, stats.stat(FRAPPE, "startup") - GearTrait.RIPOSTE_FRAMES)
    while fighter.phase != Fighter.Phase.IDLE:
        fighter.advance_phase()
    fighter.request(FRAPPE)
    fighter.try_start_buffered(1)
    assert_eq(fighter.phase_frames, stats.stat(FRAPPE, "startup"), "seulement la frappe qui suit l'esquive")


func test_echo_gives_back_a_rune_when_the_ultimate_lands() -> void:
    var knight := KnightClass.by_id(KnightClass.FAUCHEUSE)
    var stats := FighterStats.resolve(knight, _gear(knight.id, &"hallebarde_lourde"))
    var fighter := Fighter.new(-1, 0, knight, stats)
    fighter.rune = Fighter.MAX_RUNE
    fighter.request(CombatAction.Kind.ULTIME)
    fighter.try_start_buffered(1)
    assert_eq(fighter.rune, 0)
    fighter.register_hit()
    assert_eq(fighter.rune, 1)
    fighter.register_hit()
    assert_eq(fighter.rune, 1, "une seule fois par ultime")


func test_guardians_far_up_the_path_wear_full_moons() -> void:
    var guardian := ShadowPath.opponent(ShadowPath.FULL_MOON_GUARDIAN_PALIER)
    assert_true(guardian.guardian)
    for piece in guardian.gear.pieces():
        assert_eq(piece.rarity, Rarity.Tier.PLEINE_LUNE)
    assert_false(guardian.gear.traits().is_empty())
    for piece in ShadowPath.opponent(15).gear.pieces():
        assert_lt(piece.rarity, Rarity.Tier.PLEINE_LUNE)
