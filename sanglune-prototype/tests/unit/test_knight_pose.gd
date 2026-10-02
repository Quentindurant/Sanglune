extends GutTest
## Poses du pantin : complètes, calées sur les phases, et lisibles (on voit le coup se préparer puis partir).

const FRAPPE := CombatAction.Kind.FRAPPE
const ULTIME := CombatAction.Kind.ULTIME


func _fighter_in(kind: int, frames: int) -> Fighter:
    var f := Fighter.new(-1, 3000)
    f.request(kind)
    f.try_start_buffered()
    for i in frames:
        f.advance_phase()
    return f


func _assert_complete(pose: Dictionary, context: String) -> void:
    for key: String in KnightPose.KEYS:
        assert_true(pose.has(key), "%s : %s" % [context, key])
        assert_false(is_nan(float(pose.get(key, 0.0))), "%s : %s" % [context, key])


func test_every_moment_gives_a_complete_pose() -> void:
    for kind: int in CombatAction.DATA:
        for frames in [0, 3, 8, 20, 40]:
            var f := _fighter_in(kind, frames)
            for progress in [-1.0, 0.0, 0.5, 1.0, 2.0]:
                _assert_complete(KnightPose.target(f, progress, KnightPose.GUARD), "%s %d %.1f" % [CombatAction.LABELS[kind], frames, progress])


func test_frappe_winds_up_behind_then_strikes_forward() -> void:
    var startup := _fighter_in(FRAPPE, 1)
    var windup := KnightPose.target(startup, 1.0, KnightPose.GUARD)
    assert_lt(windup["weapon_f"], -PI, "l'arme passe derrière la tête")
    var active := _fighter_in(FRAPPE, CombatAction.stat(FRAPPE, "startup"))
    var strike := KnightPose.target(active, 1.0, KnightPose.GUARD)
    assert_between(strike["weapon_f"], -PI, 0.0, "l'arme part vers l'avant")


func test_every_ultimate_has_its_own_complete_poses() -> void:
    var strikes := {}
    for knight in KnightClass.all():
        var f := Fighter.new(-1, 3000, knight)
        f.rune = Fighter.MAX_RUNE
        f.request(ULTIME)
        f.try_start_buffered()
        for i in f.stat(ULTIME, "startup"):
            f.advance_phase()
        var strike := KnightPose.target(f, 1.0, KnightPose.GUARD)
        _assert_complete(strike, f.ultimate.display_name)
        strikes[str(strike)] = true
    assert_eq(strikes.size(), 4, "chaque ultime a son geste")


func test_knocked_out_knight_kneels_and_winner_raises_the_weapon() -> void:
    var down := Fighter.new(-1, 3000)
    down.hp = 0
    assert_eq(KnightPose.target(down, 0.0, KnightPose.GUARD)["thigh_f"], KnightPose.KNEEL["thigh_f"])
    var winner := Fighter.new(1, 6000)
    assert_eq(KnightPose.target(winner, 0.0, KnightPose.GUARD, 1)["weapon_f"], KnightPose.VICTORY["weapon_f"])


func test_blend_goes_from_one_pose_to_the_other() -> void:
    var halfway := KnightPose.blend(KnightPose.GUARD, KnightPose.merge(KnightPose.GUARD, KnightPose.RECOIL), 0.5)
    assert_almost_eq(halfway["lean"], (KnightPose.GUARD["lean"] + KnightPose.RECOIL["lean"]) / 2.0, 0.0001)


func test_walking_moves_the_legs() -> void:
    assert_ne(KnightPose.walk(0.0)["thigh_f"], KnightPose.walk(PI / 2)["thigh_f"])
