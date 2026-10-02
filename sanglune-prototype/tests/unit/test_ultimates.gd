extends GutTest
## Ultimes : un par arme, la jauge de runes les déclenche, chacun a son caractère et sa parade.

const ULTIME := CombatAction.Kind.ULTIME
const FRAPPE := CombatAction.Kind.FRAPPE


func _duel(left_id: StringName, right_id: StringName, gap: int) -> Duel:
    var duel := Duel.new(KnightClass.by_id(left_id), KnightClass.by_id(right_id))
    duel.skip_intro()
    duel.left.x = 4000
    duel.right.x = 4000 + gap
    duel.left.rune = Fighter.MAX_RUNE
    return duel


func _run(duel: Duel, frames: int) -> void:
    duel.step(Intent.of(0, ULTIME), Intent.of())
    for i in frames - 1:
        duel.step(Intent.of(), Intent.of())


func test_each_knight_carries_the_ultimate_of_its_weapon() -> void:
    var ids := {}
    for knight in KnightClass.all():
        var f := Fighter.new(-1, 3000, knight)
        assert_not_null(f.ultimate, knight.display_name)
        ids[f.ultimate.id] = true
    assert_eq(ids.size(), 4, "quatre armes, quatre ultimes")


func test_unknown_ultimate_is_rejected() -> void:
    assert_null(Ultimate.by_id(&"meteore"))
    assert_eq(Ultimate.all().size(), Ultimate.CATALOG.size())


func test_starting_an_ultimate_is_announced() -> void:
    var duel := _duel(KnightClass.VEILLEUR, KnightClass.VEILLEUR, 1500)
    duel.step(Intent.of(0, ULTIME), Intent.of())
    var announced := duel.events.filter(func(e: Dictionary) -> bool: return e["type"] == "ultimate")
    assert_eq(announced.size(), 1)
    assert_eq(announced[0]["ultimate"], Ultimate.LAME_DE_LUNE)


func test_moisson_reaches_far_and_throws_back() -> void:
    var duel := _duel(KnightClass.FAUCHEUSE, KnightClass.VEILLEUR, 2900)
    _run(duel, 30)
    assert_eq(duel.right.hp, duel.right.max_hp() - duel.left.stat(ULTIME, "damage"))
    assert_gte(duel.right.x, 4000 + 2900 + 900, "la Moisson repousse loin")


func test_danse_des_lames_dashes_in_and_strikes_three_times() -> void:
    var duel := _duel(KnightClass.RODEUSE, KnightClass.VEILLEUR, 1500)
    _run(duel, 40)
    assert_eq(duel.right.hp, duel.right.max_hp() - 3 * duel.left.stat(ULTIME, "damage"))
    assert_gt(duel.left.x, 4000, "la Rôdeuse s'élance")


func test_danse_des_lames_cannot_be_touched_while_it_dances() -> void:
    var duel := _duel(KnightClass.RODEUSE, KnightClass.VEILLEUR, 1500)
    duel.step(Intent.of(0, ULTIME), Intent.of())
    for i in duel.left.stat(ULTIME, "startup"):
        duel.step(Intent.of(), Intent.of())
    assert_true(duel.left.is_invulnerable())


func test_seisme_stuns_for_long() -> void:
    var duel := _duel(KnightClass.COLOSSE, KnightClass.VEILLEUR, 2000)
    _run(duel, duel.left.stat(ULTIME, "startup") + 1)
    assert_eq(duel.right.phase, Fighter.Phase.STUNNED)
    assert_gt(duel.right.phase_frames, Fighter.HITSTUN, "plus long qu'un coup ordinaire")


func test_ultimate_hits_do_not_light_runes() -> void:
    var duel := _duel(KnightClass.VEILLEUR, KnightClass.VEILLEUR, 1500)
    _run(duel, 30)
    assert_eq(duel.left.rune, 0)
