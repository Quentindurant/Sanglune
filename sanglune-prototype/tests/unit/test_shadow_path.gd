extends GutTest
## Chemin des ombres : une ombre fixe par palier, de plus en plus forte, un gardien tous les cinq paliers.


func test_a_palier_always_has_the_same_shadow() -> void:
    var a := ShadowPath.opponent(7)
    var b := ShadowPath.opponent(7)
    assert_eq(a.knight.id, b.knight.id)
    assert_eq(a.gear.power(), b.gear.power())
    assert_eq(a.gear.look(), b.gear.look())


func test_a_guardian_every_five_paliers() -> void:
    assert_false(ShadowPath.is_guardian(4))
    assert_true(ShadowPath.is_guardian(5))
    assert_true(ShadowPath.is_guardian(10))
    assert_true(ShadowPath.opponent(5).guardian)
    assert_false(ShadowPath.opponent(6).guardian)


func test_the_first_shadow_is_bare_and_slow() -> void:
    var first := ShadowPath.opponent(1)
    assert_eq(first.gear.power(), PowerBudget.BASE_POWER)
    assert_gt(first.reaction_frames, AiBrain.new().reaction_frames, "plus lente que l'IA d'avant")
    assert_lt(first.accuracy, AiBrain.new().accuracy)


func test_shadows_grow_stronger_along_the_path() -> void:
    var previous := ShadowPath.opponent(1)
    for palier in range(2, 40):
        var shadow := ShadowPath.opponent(palier)
        if shadow.guardian or previous.guardian:
            previous = shadow
            continue
        assert_gte(shadow.gear.power(), previous.gear.power(), "palier %d" % palier)
        assert_lte(shadow.reaction_frames, previous.reaction_frames, "palier %d" % palier)
        assert_gte(shadow.accuracy, previous.accuracy, "palier %d" % palier)
        previous = shadow


func test_a_guardian_is_stronger_than_its_neighbours() -> void:
    for guardian_palier in [5, 10, 15, 20]:
        var guardian := ShadowPath.opponent(guardian_palier)
        var before := ShadowPath.opponent(guardian_palier - 1)
        assert_gt(guardian.gear.power(), before.gear.power(), "palier %d" % guardian_palier)
        assert_lt(guardian.reaction_frames, before.reaction_frames)


func test_shadow_gear_fits_its_knight() -> void:
    for palier in range(1, 30):
        var shadow := ShadowPath.opponent(palier)
        for piece in shadow.gear.pieces():
            assert_true(piece.def.fits(shadow.knight.id), "palier %d : %s" % [palier, piece.def.id])
            assert_false(piece.def.starter)


func test_far_paliers_stay_bounded() -> void:
    var far := ShadowPath.opponent(5000)
    assert_eq(far.gear.pieces().size(), ShadowPath.MAX_PIECES)
    assert_gte(far.reaction_frames, 1)
    assert_lte(far.accuracy, 1.0)
    assert_eq(ShadowPath.opponent(0).palier, 1, "un palier invalide redevient le premier")
