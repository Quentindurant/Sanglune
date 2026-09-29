extends GutTest
## Les quatre chevaliers : chacun garde son identité (allonge, vitesse, puissance, garde brisée).
## Les tests comparent les chevaliers entre eux, pour que l'équilibrage reste libre dans ROSTER.

const FRAPPE := CombatAction.Kind.FRAPPE


func _knight(knight_id: StringName) -> KnightClass:
    return KnightClass.by_id(knight_id)


func _others(knight_id: StringName) -> Array[KnightClass]:
    return KnightClass.all().filter(func(k: KnightClass) -> bool: return k.id != knight_id)


func test_roster_holds_the_four_knights_of_the_v1() -> void:
    var ids := KnightClass.all().map(func(k: KnightClass) -> StringName: return k.id)
    assert_eq(ids, [KnightClass.VEILLEUR, KnightClass.FAUCHEUSE, KnightClass.RODEUSE, KnightClass.COLOSSE])


func test_unknown_id_is_rejected() -> void:
    assert_null(KnightClass.by_id(&"paladin"))
    assert_not_null(KnightClass.by_id("colosse"), "un identifiant en texte simple fonctionne aussi")


func test_starter_is_the_veilleur() -> void:
    assert_eq(KnightClass.starter().id, KnightClass.VEILLEUR)


func test_veilleur_uses_the_base_data() -> void:
    var veilleur := _knight(KnightClass.VEILLEUR)
    for kind: int in CombatAction.DATA:
        for key: String in CombatAction.DATA[kind]:
            assert_eq(veilleur.stat(kind, key), CombatAction.stat(kind, key), "%s %s" % [kind, key])
    assert_eq(veilleur.max_hp, KnightClass.BASE_HP)
    assert_eq(veilleur.walk_speed, KnightClass.BASE_WALK_SPEED)


func test_veilleur_is_never_the_best_nor_the_worst() -> void:
    var veilleur := _knight(KnightClass.VEILLEUR)
    for key: String in ["startup", "recovery", "damage", "reach"]:
        var values := KnightClass.all().map(func(k: KnightClass) -> int: return k.stat(FRAPPE, key))
        var mine := veilleur.stat(FRAPPE, key)
        assert_true(mine > values.min() and mine < values.max(), key)


func test_faucheuse_has_the_longest_reach_and_the_slowest_recovery() -> void:
    var faucheuse := _knight(KnightClass.FAUCHEUSE)
    for other in _others(KnightClass.FAUCHEUSE):
        assert_gt(faucheuse.stat(FRAPPE, "reach"), other.stat(FRAPPE, "reach"), other.display_name)
        assert_gt(faucheuse.stat(FRAPPE, "recovery"), other.stat(FRAPPE, "recovery"), other.display_name)


func test_rodeuse_is_the_fastest_but_the_shortest() -> void:
    var rodeuse := _knight(KnightClass.RODEUSE)
    for other in _others(KnightClass.RODEUSE):
        assert_lt(rodeuse.stat(FRAPPE, "startup"), other.stat(FRAPPE, "startup"), other.display_name)
        assert_lt(rodeuse.stat(FRAPPE, "reach"), other.stat(FRAPPE, "reach"), other.display_name)
        assert_gt(rodeuse.walk_speed, other.walk_speed, other.display_name)


func test_colosse_is_the_slowest_and_hits_the_hardest() -> void:
    var colosse := _knight(KnightClass.COLOSSE)
    for other in _others(KnightClass.COLOSSE):
        assert_gt(colosse.stat(FRAPPE, "startup"), other.stat(FRAPPE, "startup"), other.display_name)
        assert_gt(colosse.stat(FRAPPE, "damage"), other.stat(FRAPPE, "damage"), other.display_name)
        assert_lt(colosse.walk_speed, other.walk_speed, other.display_name)


func test_only_the_colosse_breaks_the_guard_with_every_hit() -> void:
    for knight in KnightClass.all():
        assert_eq(knight.breaks_guard, knight.id == KnightClass.COLOSSE, knight.display_name)


func test_frame_data_never_drops_below_one_frame() -> void:
    for knight in KnightClass.all():
        for kind: int in CombatAction.DATA:
            assert_gte(knight.stat(kind, "startup"), 1, knight.display_name)
            assert_gte(knight.stat(kind, "recovery"), 1, knight.display_name)


func test_ratings_go_from_one_to_five() -> void:
    assert_eq(_knight(KnightClass.VEILLEUR).ratings().values(), [3, 3, 3])
    for knight in KnightClass.all():
        for value: int in knight.ratings().values():
            assert_between(value, 1, 5, knight.display_name)


func test_ratings_tell_each_knight_apart() -> void:
    assert_eq(_best_at("Allonge"), KnightClass.FAUCHEUSE)
    assert_eq(_best_at("Vitesse"), KnightClass.RODEUSE)
    assert_eq(_best_at("Puissance"), KnightClass.COLOSSE)
    var colosse_speed: int = _knight(KnightClass.COLOSSE).ratings()["Vitesse"]
    for other in _others(KnightClass.COLOSSE):
        assert_lt(colosse_speed, other.ratings()["Vitesse"], "le Colosse est le plus lent")


## Le chevalier qui a la meilleure note, seul en tête.
func _best_at(label: String) -> StringName:
    var knights := KnightClass.all()
    knights.sort_custom(func(a: KnightClass, b: KnightClass) -> bool: return a.ratings()[label] > b.ratings()[label])
    assert_gt(knights[0].ratings()[label], knights[1].ratings()[label], "%s : un seul chevalier en tête" % label)
    return knights[0].id


func test_random_pick_is_reproducible_with_a_seed() -> void:
    var a := RandomNumberGenerator.new()
    var b := RandomNumberGenerator.new()
    a.seed = 99
    b.seed = 99
    for i in 20:
        var pick := KnightClass.pick_random(a)
        assert_eq(pick.id, KnightClass.pick_random(b).id)
        assert_not_null(KnightClass.by_id(pick.id))
