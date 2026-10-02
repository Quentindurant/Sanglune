extends GutTest
## Déplacements : saut, plongeon, passage par-dessus l'adversaire, esquive.

const NONE := CombatAction.Kind.NONE
const FRAPPE := CombatAction.Kind.FRAPPE
const PARADE := CombatAction.Kind.PARADE
const ESQUIVE := CombatAction.Kind.ESQUIVE
const SAUT := CombatAction.Kind.SAUT

var duel: Duel


func before_each() -> void:
    duel = Duel.new()
    duel.skip_intro()


func _place(left_x: int, right_x: int) -> void:
    duel.left.x = left_x
    duel.right.x = right_x


func _idle(frames: int) -> void:
    for i in frames:
        duel.step(Intent.of(), Intent.of())


## Avance jusqu'à la réception du chevalier (au plus deux secondes).
func _until_landed(f: Fighter) -> void:
    for i in 120:
        if not f.is_airborne():
            return
        _idle(1)


func _startup(kind: int) -> int:
    return duel.left.stat(kind, "startup")


func test_jump_leaves_the_ground_after_its_run_up() -> void:
    _place(3000, 7000)
    duel.step(Intent.of(0, SAUT), Intent.of())
    _idle(_startup(SAUT) - 1)
    assert_true(duel.left.is_airborne(), "l'élan est fini, le chevalier s'envole")
    _idle(20)
    assert_gt(duel.left.y, Duel.CROSS_HEIGHT, "au sommet, il passe au-dessus d'un chevalier")


func test_jump_lands_with_a_short_recovery() -> void:
    _place(3000, 7000)
    duel.step(Intent.of(0, SAUT), Intent.of())
    _idle(_startup(SAUT))
    _until_landed(duel.left)
    assert_eq(duel.left.y, 0)
    assert_eq(duel.left.phase, Fighter.Phase.RECOVERY, "réception : un court temps vulnérable")
    _idle(duel.left.stat(SAUT, "recovery"))
    assert_true(duel.left.is_free())


func test_standing_jump_goes_straight_up() -> void:
    _place(3000, 7000)
    duel.step(Intent.of(0, SAUT), Intent.of())
    _idle(_startup(SAUT))
    _until_landed(duel.left)
    assert_eq(duel.left.x, 3000)


func test_jump_toward_the_opponent_moves_forward() -> void:
    _place(2000, 8000)
    duel.step(Intent.of(1, SAUT), Intent.of())
    _idle(_startup(SAUT))
    _until_landed(duel.left)
    assert_gt(duel.left.x, 2000 + duel.left.knight.jump_speed * 30)


func test_jump_keeps_the_momentum_of_a_walk() -> void:
    _place(2000, 8000)
    for i in 5:
        duel.step(Intent.of(1), Intent.of())
    var before := duel.left.x
    duel.step(Intent.of(0, SAUT), Intent.of())
    _idle(_startup(SAUT))
    _until_landed(duel.left)
    assert_gt(duel.left.x, before + duel.left.knight.jump_speed * 30, "glisser du pouce de > vers Saut garde l'élan")


func test_seisme_passes_under_a_jumping_knight() -> void:
    duel = Duel.new(KnightClass.by_id(KnightClass.COLOSSE), KnightClass.by_id(KnightClass.VEILLEUR))
    duel.skip_intro()
    _place(4000, 5500)
    duel.left.rune = Fighter.MAX_RUNE
    duel.step(Intent.of(0, CombatAction.Kind.ULTIME), Intent.of())
    _idle(13)
    duel.step(Intent.of(), Intent.of(0, SAUT))
    _idle(40)
    assert_eq(duel.right.hp, duel.right.max_hp(), "l'onde du Séisme passe sous un chevalier en l'air")


func test_frappe_catches_a_knight_in_the_air() -> void:
    _place(4000, 5200)
    duel.step(Intent.of(0, FRAPPE), Intent.of(0, SAUT))
    _idle(15)
    assert_eq(duel.right.hp, duel.right.max_hp() - duel.left.stat(FRAPPE, "damage"))
    assert_eq(duel.right.phase, Fighter.Phase.STUNNED)
    _until_landed(duel.right)
    assert_eq(duel.right.y, 0, "touché en l'air, il retombe")


func test_cannot_walk_or_parry_in_the_air() -> void:
    _place(3000, 7000)
    duel.step(Intent.of(0, SAUT), Intent.of())
    _idle(_startup(SAUT) + 5)
    var x_in_air := duel.left.x
    duel.step(Intent.of(1, PARADE), Intent.of())
    assert_eq(duel.left.x, x_in_air, "pas de marche en l'air")
    assert_ne(duel.left.action, PARADE, "pas de parade en l'air")


func test_jumping_over_the_opponent_switches_sides() -> void:
    _place(4000, 4800)
    duel.step(Intent.of(1, SAUT), Intent.of())
    _idle(_startup(SAUT))
    _until_landed(duel.left)
    _idle(1)
    assert_gt(duel.left.x, duel.right.x, "passé de l'autre côté")
    assert_gte(duel.left.x - duel.right.x, Duel.MIN_GAP)
    assert_eq(duel.left.facing(), -1, "il se retourne vers l'adversaire")
    assert_eq(duel.right.facing(), 1, "l'adversaire aussi")


func test_advancing_still_goes_toward_the_opponent_after_crossing() -> void:
    _place(4000, 4800)
    duel.step(Intent.of(1, SAUT), Intent.of())
    _idle(_startup(SAUT))
    _until_landed(duel.left)
    _idle(duel.left.stat(SAUT, "recovery") + 1)
    var before := duel.left.x
    duel.step(Intent.of(1), Intent.of())
    assert_lt(duel.left.x, before, "avancer, c'est aller vers l'adversaire, désormais à gauche")


func test_landing_on_the_opponent_pushes_the_bodies_apart_smoothly() -> void:
    _place(5000, 5000)
    duel.left.y = 5
    duel.left.vy = -10
    _idle(1)
    assert_lte(absi(duel.left.x - 5000), Duel.SEPARATION_SPEED, "pas de téléportation")
    _idle(10)
    assert_gte(absi(duel.right.x - duel.left.x), Duel.MIN_GAP)


func test_bodies_pushed_apart_stay_inside_the_arena() -> void:
    _place(100, 100)
    duel.left.y = 5
    duel.left.vy = -10
    _idle(20)
    assert_gte(absi(duel.right.x - duel.left.x), Duel.MIN_GAP)
    for f in [duel.left, duel.right]:
        assert_between(f.x, Duel.ARENA_MIN, Duel.ARENA_MAX)


func test_plongeon_from_the_air_hits_a_grounded_opponent() -> void:
    _place(3000, 4800)
    duel.step(Intent.of(1, SAUT), Intent.of())
    _idle(_startup(SAUT) + 8)
    duel.step(Intent.of(0, FRAPPE), Intent.of())
    assert_eq(duel.left.action, CombatAction.Kind.PLONGEON, "une frappe en l'air devient un plongeon")
    _until_landed(duel.left)
    assert_eq(duel.right.hp, duel.right.max_hp() - duel.left.stat(CombatAction.Kind.PLONGEON, "damage"))


func test_plongeon_breaks_a_parade() -> void:
    _place(3000, 4800)
    duel.step(Intent.of(1, SAUT), Intent.of())
    _idle(_startup(SAUT) + 8)
    duel.step(Intent.of(0, FRAPPE), Intent.of(0, PARADE))
    _idle(7)
    assert_eq(duel.right.phase, Fighter.Phase.STUNNED, "le plongeon venu du ciel brise la garde")
    assert_eq(duel.right.hp, duel.right.max_hp() - duel.left.stat(CombatAction.Kind.PLONGEON, "damage"))
    assert_ne(duel.left.phase, Fighter.Phase.STUNNED)


func test_dodge_goes_backwards_by_default() -> void:
    _place(4000, 6000)
    duel.step(Intent.of(0, ESQUIVE), Intent.of())
    _idle(20)
    var distance: int = duel.left.stat(ESQUIVE, "active") * duel.left.knight.dodge_speed
    assert_eq(duel.left.x, 4000 - distance)


func test_dodge_forward_stops_against_the_opponent() -> void:
    _place(4000, 5200)
    duel.step(Intent.of(1, ESQUIVE), Intent.of())
    _idle(20)
    assert_eq(duel.left.x, duel.right.x - Duel.MIN_GAP)


func test_dodge_makes_a_frappe_miss() -> void:
    _place(4000, 5200)
    duel.step(Intent.of(), Intent.of(0, FRAPPE))
    _idle(6)
    duel.step(Intent.of(1, ESQUIVE), Intent.of())
    _idle(30)
    assert_eq(duel.left.hp, duel.left.max_hp(), "intouchable pendant l'élan de l'esquive")


func test_dodge_recovery_can_be_punished() -> void:
    _place(4000, 5200)
    duel.step(Intent.of(1, ESQUIVE), Intent.of())
    _idle(3)
    duel.step(Intent.of(), Intent.of(0, FRAPPE))
    _idle(15)
    assert_lt(duel.left.hp, duel.left.max_hp(), "une esquive mal placée se paie")


func test_attacks_only_hit_in_front() -> void:
    _place(4000, 3000)
    duel.step(Intent.of(), Intent.of(0, FRAPPE))
    _idle(20)
    assert_eq(duel.left.hp, duel.left.max_hp(), "la frappe part dans le dos de la cible, elle rate")
