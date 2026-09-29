extends GutTest
## IA : bonnes réponses du triangle, adaptation au chevalier, temps de réaction, déterminisme.

const FRAPPE := CombatAction.Kind.FRAPPE
const ESTOC := CombatAction.Kind.ESTOC
const PARADE := CombatAction.Kind.PARADE


## IA parfaite et instantanée, placée à droite face à un adversaire à gap millimètres.
func _setup(gap: int) -> Array:
    var brain := AiBrain.new(1, 0, 1.0)
    var me := Fighter.new(1, 4000 + gap)
    var foe := Fighter.new(-1, 4000)
    return [brain, me, foe]


func _foe_starts(foe: Fighter, kind: int) -> void:
    foe.request(kind)
    foe.try_start_buffered()


func test_interrupts_an_estoc_with_a_frappe() -> void:
    var s := _setup(1200)
    _foe_starts(s[2], ESTOC)
    assert_eq(s[0].decide(s[1], s[2]).action, FRAPPE)


func test_parries_a_frappe() -> void:
    var s := _setup(1200)
    _foe_starts(s[2], FRAPPE)
    assert_eq(s[0].decide(s[1], s[2]).action, PARADE)


func test_breaks_a_parade_with_an_estoc() -> void:
    var s := _setup(1200)
    _foe_starts(s[2], PARADE)
    assert_eq(s[0].decide(s[1], s[2]).action, ESTOC)


func test_punishes_a_stunned_opponent() -> void:
    var s := _setup(1200)
    s[2].stun(20)
    assert_eq(s[0].decide(s[1], s[2]).action, FRAPPE)


func test_uses_the_rune_when_the_gauge_is_full() -> void:
    var s := _setup(1200)
    s[1].rune = Fighter.MAX_RUNE
    assert_eq(s[0].decide(s[1], s[2]).action, CombatAction.Kind.RUNE)


func test_does_not_try_to_parry_the_colosse() -> void:
    var s := _setup(1200)
    s[2] = Fighter.new(-1, 4000, KnightClass.by_id(KnightClass.COLOSSE))
    _foe_starts(s[2], FRAPPE)
    assert_eq(s[0].decide(s[1], s[2]).action, FRAPPE, "sa frappe brise la parade : il faut le prendre de vitesse")


func test_engage_distance_follows_the_knight_reach() -> void:
    var rodeuse := Fighter.new(1, 5360, KnightClass.by_id(KnightClass.RODEUSE))
    var faucheuse := Fighter.new(1, 5360, KnightClass.by_id(KnightClass.FAUCHEUSE))
    assert_lt(AiBrain.engage_range(rodeuse), AiBrain.engage_range(faucheuse))
    var foe := Fighter.new(-1, 4000)
    assert_eq(AiBrain.new(1, 0, 1.0).decide(rodeuse, foe).move, 1, "trop loin pour ses dagues : la Rôdeuse avance")


func test_walks_forward_when_far() -> void:
    var s := _setup(4000)
    var intent: Intent = s[0].decide(s[1], s[2])
    assert_eq(intent.move, 1)
    assert_eq(intent.action, CombatAction.Kind.NONE)


func test_waits_its_reaction_time_between_decisions() -> void:
    var brain := AiBrain.new(1, 5, 1.0)
    var me := Fighter.new(1, 5200)
    var foe := Fighter.new(-1, 4000)
    _foe_starts(foe, ESTOC)
    assert_eq(brain.decide(me, foe).action, FRAPPE)
    for i in 5:
        assert_eq(brain.decide(me, foe).action, CombatAction.Kind.NONE, "encore en train de réagir")


func test_same_seed_gives_the_same_choices() -> void:
    var a := AiBrain.new(42, 0, 0.7)
    var b := AiBrain.new(42, 0, 0.7)
    var me := Fighter.new(1, 5200)
    var foe := Fighter.new(-1, 4000)
    for i in 50:
        var ia := a.decide(me, foe)
        var ib := b.decide(me, foe)
        assert_eq([ia.move, ia.action], [ib.move, ib.action])
