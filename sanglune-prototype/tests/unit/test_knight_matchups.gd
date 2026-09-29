extends GutTest
## Les chevaliers en duel : vie, marche, allonge, vitesse et garde brisée du Colosse.

const NONE := CombatAction.Kind.NONE
const FRAPPE := CombatAction.Kind.FRAPPE
const PARADE := CombatAction.Kind.PARADE


func _duel(left_id: StringName, right_id: StringName, gap: int) -> Duel:
    var duel := Duel.new(KnightClass.by_id(left_id), KnightClass.by_id(right_id))
    duel.skip_intro()
    duel.left.x = 4000
    duel.right.x = 4000 + gap
    return duel


## Avance de n frames ; les actions ne sont demandées qu'à la première.
func _step(duel: Duel, left_action: int, right_action: int, frames: int) -> void:
    duel.step(Intent.of(0, left_action), Intent.of(0, right_action))
    for i in frames - 1:
        duel.step(Intent.of(), Intent.of())


func _reach(knight_id: StringName) -> int:
    return KnightClass.by_id(knight_id).stat(FRAPPE, "reach")


func test_each_knight_starts_with_its_own_hp() -> void:
    var duel := _duel(KnightClass.COLOSSE, KnightClass.RODEUSE, 3000)
    assert_eq(duel.left.hp, KnightClass.by_id(KnightClass.COLOSSE).max_hp)
    assert_gt(duel.left.hp, duel.right.hp, "le Colosse encaisse plus que la Rôdeuse")


func test_knights_keep_their_class_from_round_to_round() -> void:
    var duel := _duel(KnightClass.FAUCHEUSE, KnightClass.COLOSSE, 3000)
    duel.round_time_left = 1
    duel.right.hp -= 1
    _step(duel, NONE, NONE, 1 + Duel.ROUND_OVER_FRAMES)
    assert_eq(duel.round_number, 2)
    assert_eq(duel.left.knight.id, KnightClass.FAUCHEUSE)
    assert_eq(duel.right.knight.id, KnightClass.COLOSSE)


func test_rodeuse_walks_faster_than_the_colosse() -> void:
    var duel := _duel(KnightClass.RODEUSE, KnightClass.COLOSSE, 3000)
    for i in 30:
        duel.step(Intent.of(-1), Intent.of(-1))
    var rodeuse_moved := 4000 - duel.left.x
    var colosse_moved := duel.right.x - 7000
    assert_gt(rodeuse_moved, colosse_moved)


func test_faucheuse_hits_from_where_the_veilleur_would_miss() -> void:
    var gap := (_reach(KnightClass.VEILLEUR) + _reach(KnightClass.FAUCHEUSE)) / 2
    var veilleur := _duel(KnightClass.VEILLEUR, KnightClass.VEILLEUR, gap)
    _step(veilleur, FRAPPE, NONE, 20)
    assert_eq(veilleur.right.hp, veilleur.right.max_hp(), "hors de portée du Veilleur")
    var faucheuse := _duel(KnightClass.FAUCHEUSE, KnightClass.VEILLEUR, gap)
    _step(faucheuse, FRAPPE, NONE, 20)
    assert_lt(faucheuse.right.hp, faucheuse.right.max_hp(), "l'allonge de la Faucheuse porte")


func test_rodeuse_must_stick_to_her_target() -> void:
    var gap := (_reach(KnightClass.RODEUSE) + _reach(KnightClass.VEILLEUR)) / 2
    var rodeuse := _duel(KnightClass.RODEUSE, KnightClass.VEILLEUR, gap)
    _step(rodeuse, FRAPPE, NONE, 20)
    assert_eq(rodeuse.right.hp, rodeuse.right.max_hp(), "trop loin pour ses dagues")
    var veilleur := _duel(KnightClass.VEILLEUR, KnightClass.VEILLEUR, gap)
    _step(veilleur, FRAPPE, NONE, 20)
    assert_lt(veilleur.right.hp, veilleur.right.max_hp())


func test_colosse_frappe_breaks_a_parade() -> void:
    var duel := _duel(KnightClass.COLOSSE, KnightClass.VEILLEUR, 1200)
    _step(duel, FRAPPE, NONE, 3)
    _step(duel, NONE, PARADE, 12)
    assert_eq(duel.right.hp, duel.right.max_hp() - duel.left.stat(FRAPPE, "damage"))
    assert_eq(duel.right.phase, Fighter.Phase.STUNNED, "la garde est brisée")
    assert_ne(duel.left.phase, Fighter.Phase.STUNNED, "le Colosse n'est pas exposé")


func test_rodeuse_beats_a_colosse_frappe_thrown_at_the_same_time() -> void:
    var duel := _duel(KnightClass.RODEUSE, KnightClass.COLOSSE, 1000)
    _step(duel, FRAPPE, FRAPPE, 30)
    assert_lt(duel.right.hp, duel.right.max_hp(), "la Rôdeuse touche la première")
    assert_eq(duel.left.hp, duel.left.max_hp(), "le Colosse est interrompu")


func test_damage_follows_the_knight_power() -> void:
    var duel := _duel(KnightClass.COLOSSE, KnightClass.VEILLEUR, 1200)
    _step(duel, FRAPPE, NONE, 20)
    assert_eq(duel.right.hp, duel.right.max_hp() - duel.left.stat(FRAPPE, "damage"))
    assert_gt(duel.left.stat(FRAPPE, "damage"), CombatAction.stat(FRAPPE, "damage"))
