extends GutTest
## Chevalier : phases d'une action, file d'attente, étourdissement, jauge de rune.


func _run(f: Fighter, frames: int) -> void:
    for i in frames:
        f.advance_phase()


func _started(kind: int) -> Fighter:
    var f := Fighter.new(-1, 3500)
    f.request(kind)
    f.try_start_buffered()
    return f


func test_new_fighter_is_idle_with_full_hp() -> void:
    var f := Fighter.new(-1, 3500)
    assert_eq(f.hp, f.max_hp())
    assert_eq(f.knight.id, KnightClass.VEILLEUR, "sans classe précisée, c'est le Veilleur")
    assert_true(f.is_free())
    assert_eq(f.facing(), 1, "le chevalier de gauche regarde vers la droite")


func test_requested_action_starts_when_free() -> void:
    var f := _started(CombatAction.Kind.FRAPPE)
    assert_eq(f.action, CombatAction.Kind.FRAPPE)
    assert_eq(f.phase, Fighter.Phase.STARTUP)


func test_frappe_goes_through_its_three_phases() -> void:
    var f := _started(CombatAction.Kind.FRAPPE)
    _run(f, CombatAction.stat(CombatAction.Kind.FRAPPE, "startup"))
    assert_eq(f.phase, Fighter.Phase.ACTIVE)
    _run(f, CombatAction.stat(CombatAction.Kind.FRAPPE, "active"))
    assert_eq(f.phase, Fighter.Phase.RECOVERY)
    _run(f, CombatAction.stat(CombatAction.Kind.FRAPPE, "recovery"))
    assert_true(f.is_free())


func test_parade_protects_only_while_active() -> void:
    var f := _started(CombatAction.Kind.PARADE)
    assert_false(f.is_guarding(), "pas encore de protection pendant la mise en garde")
    _run(f, CombatAction.stat(CombatAction.Kind.PARADE, "startup"))
    assert_true(f.is_guarding())


func test_action_requested_while_busy_waits_in_buffer() -> void:
    var f := Fighter.new(-1, 3500)
    f.stun(3)
    f.request(CombatAction.Kind.PARADE)
    assert_false(f.try_start_buffered(), "occupé : l'action attend")
    _run(f, 3)
    assert_true(f.try_start_buffered())
    assert_eq(f.action, CombatAction.Kind.PARADE)


func test_buffered_action_expires() -> void:
    var f := Fighter.new(-1, 3500)
    f.stun(20)
    f.request(CombatAction.Kind.FRAPPE)
    _run(f, Fighter.BUFFER_FRAMES)
    assert_eq(f.buffered_action, CombatAction.Kind.NONE)


func test_ultimate_needs_a_full_rune_gauge() -> void:
    var f := Fighter.new(-1, 3500)
    f.rune = Fighter.MAX_RUNE - 1
    f.request(CombatAction.Kind.ULTIME)
    assert_false(f.try_start_buffered())
    assert_eq(f.rune, Fighter.MAX_RUNE - 1, "la jauge n'est pas consommée")


func test_ultimate_empties_the_rune_gauge() -> void:
    var f := Fighter.new(-1, 3500)
    f.rune = Fighter.MAX_RUNE
    f.request(CombatAction.Kind.ULTIME)
    assert_true(f.try_start_buffered())
    assert_eq(f.rune, 0)


func test_hits_charge_the_rune_up_to_its_max() -> void:
    var f := _started(CombatAction.Kind.FRAPPE)
    f.rune = Fighter.MAX_RUNE - 1
    f.register_hit()
    f.register_hit()
    assert_eq(f.rune, Fighter.MAX_RUNE)
    assert_false(f.is_attack_active(), "un coup ne touche qu'une fois")


func test_stun_cancels_the_current_action() -> void:
    var f := _started(CombatAction.Kind.FRAPPE)
    f.stun(10)
    assert_eq(f.action, CombatAction.Kind.NONE)
    assert_eq(f.phase, Fighter.Phase.STUNNED)


func test_hp_never_goes_below_zero() -> void:
    var f := Fighter.new(-1, 3500)
    f.take_hit(f.max_hp() * 5, 5)
    assert_eq(f.hp, 0)
