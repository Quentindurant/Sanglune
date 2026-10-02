extends GutTest
## Triangle de combat : la parade bloque la frappe, le plongeon brise la parade, la frappe cueille en l'air.
## La parade ne protège que de face, et l'ultime la traverse.

const NONE := CombatAction.Kind.NONE
const FRAPPE := CombatAction.Kind.FRAPPE
const PARADE := CombatAction.Kind.PARADE
const ULTIME := CombatAction.Kind.ULTIME

var duel: Duel


func before_each() -> void:
    duel = Duel.new()
    duel.skip_intro()


## Avance de n frames ; les actions ne sont demandées qu'à la première.
func _step(left_action: int, right_action: int, frames: int) -> void:
    duel.step(Intent.of(0, left_action), Intent.of(0, right_action))
    for i in frames - 1:
        duel.step(Intent.of(), Intent.of())


func _place(gap: int) -> void:
    duel.left.x = 4000
    duel.right.x = 4000 + gap


func _last_events_have(type: String) -> bool:
    return duel.events.any(func(e: Dictionary) -> bool: return e["type"] == type)


func test_frappe_hits_an_idle_opponent_in_range() -> void:
    _place(1200)
    _step(FRAPPE, NONE, 10)
    assert_eq(duel.right.hp, duel.right.max_hp() - CombatAction.stat(FRAPPE, "damage"))
    assert_eq(duel.right.phase, Fighter.Phase.STUNNED)
    assert_eq(duel.left.rune, 1, "toucher charge la rune")


func test_frappe_misses_out_of_range() -> void:
    _place(2500)
    _step(FRAPPE, NONE, 40)
    assert_eq(duel.right.hp, duel.right.max_hp())


func test_hit_pushes_the_defender_back() -> void:
    _place(1200)
    _step(FRAPPE, NONE, 10)
    assert_eq(duel.right.x, 4000 + 1200 + Duel.PUSHBACK)


func test_parade_blocks_frappe_and_opens_a_riposte() -> void:
    _place(1200)
    _step(FRAPPE, NONE, 3)
    _step(NONE, PARADE, 7)
    assert_eq(duel.right.hp, duel.right.max_hp())
    assert_eq(duel.left.phase, Fighter.Phase.STUNNED, "l'attaquant paré est exposé")
    assert_true(_last_events_have("blocked"))


func test_parade_only_protects_the_front() -> void:
    _place(1200)
    duel.right.face(1)
    _step(FRAPPE, PARADE, 12)
    assert_eq(duel.right.hp, duel.right.max_hp() - CombatAction.stat(FRAPPE, "damage"), "une parade tournée de l'autre côté ne protège pas")


func test_frappe_interrupts_an_ultimate_in_preparation() -> void:
    _place(1200)
    duel.right.rune = Fighter.MAX_RUNE
    _step(NONE, ULTIME, 3)
    _step(FRAPPE, NONE, 10)
    assert_eq(duel.right.phase, Fighter.Phase.STUNNED)
    _step(NONE, NONE, 40)
    assert_eq(duel.left.hp, duel.left.max_hp(), "l'ultime interrompu ne part jamais")
    assert_eq(duel.right.rune, 0, "les runes sont perdues")


func test_simultaneous_frappes_trade() -> void:
    _place(1200)
    _step(FRAPPE, FRAPPE, 10)
    assert_eq(duel.left.hp, duel.left.max_hp() - CombatAction.stat(FRAPPE, "damage"))
    assert_eq(duel.right.hp, duel.right.max_hp() - CombatAction.stat(FRAPPE, "damage"))


func test_ultimate_goes_through_parade() -> void:
    _place(1500)
    duel.left.rune = Fighter.MAX_RUNE
    _step(NONE, PARADE, 1)
    _step(ULTIME, NONE, 19)
    assert_eq(duel.right.hp, duel.right.max_hp() - duel.left.stat(ULTIME, "damage"))
    assert_eq(duel.left.rune, 0)


func test_fighters_cannot_cross() -> void:
    _place(800)
    for i in 30:
        duel.step(Intent.of(1), Intent.of(1))
    assert_gte(duel.right.x - duel.left.x, Duel.MIN_GAP)


func test_fighters_stay_inside_the_arena() -> void:
    for i in 200:
        duel.step(Intent.of(-1), Intent.of(-1))
    assert_eq(duel.left.x, Duel.ARENA_MIN)
    assert_eq(duel.right.x, Duel.ARENA_MAX)


func test_no_walking_during_an_attack() -> void:
    _place(3000)
    _step(FRAPPE, NONE, 1)
    var before := duel.left.x
    for i in 10:
        duel.step(Intent.of(1), Intent.of())
    assert_eq(duel.left.x, before)
