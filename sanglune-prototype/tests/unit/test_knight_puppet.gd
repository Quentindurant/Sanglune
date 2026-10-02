extends GutTest
## Pantin squelettal : os et pièces pour chaque chevalier, pieds au sol, arme qui suit le coup, liseré et traînée.

const FRAPPE := CombatAction.Kind.FRAPPE


func _puppet(knight_id: StringName, rims: Array[Vector2] = []) -> KnightPuppet:
    var puppet := KnightPuppet.new()
    puppet.setup(knight_id, Palette.CYAN, rims)
    add_child_autofree(puppet)
    return puppet


func _lowest_point(node: Node) -> float:
    var lowest := -INF
    for child in node.get_children():
        if child is Polygon2D:
            for point in (child as Polygon2D).polygon:
                lowest = maxf(lowest, (child as Polygon2D).to_global(point).y)
        lowest = maxf(lowest, _lowest_point(child))
    return lowest


func test_every_knight_has_a_build() -> void:
    for knight in KnightClass.all():
        assert_true(KnightBuild.has_spec(knight.id), knight.display_name)
        var puppet := _puppet(knight.id)
        assert_not_null(puppet.find_child("hand_f", true, false), knight.display_name)


func test_helmets_and_weapons_tell_the_knights_apart() -> void:
    var helmets := {}
    var weapons := {}
    for knight in KnightClass.all():
        helmets[KnightBuild.spec(knight.id)["helmet"]] = true
        weapons[KnightBuild.spec(knight.id)["weapon"]] = true
    assert_eq(helmets.size(), 4, "un casque par chevalier")
    assert_eq(weapons.size(), 4, "une arme par chevalier")


func test_feet_stay_on_the_ground_in_guard() -> void:
    var puppet := _puppet(KnightClass.COLOSSE)
    puppet.position = Vector2(400, 500)
    puppet.show_pose(KnightPose.GUARD)
    assert_almost_eq(_lowest_point(puppet), 500.0, 3.0)


func test_weapon_tip_comes_forward_on_a_frappe() -> void:
    var duel := Duel.new()
    duel.skip_intro()
    var puppet := _puppet(KnightClass.VEILLEUR)
    puppet.follow(duel.left, Vector2(400, 470))
    var guard_tip := puppet.tip_global().x
    duel.step(Intent.of(0, FRAPPE), Intent.of())
    for i in CombatAction.stat(FRAPPE, "startup") + 2:
        puppet.follow(duel.left, Vector2(400, 470))
        duel.step(Intent.of(), Intent.of())
    puppet.follow(duel.left, Vector2(400, 470))
    assert_gt(puppet.tip_global().x, guard_tip, "l'arme s'avance vers l'adversaire")
    assert_gt(puppet.trail_size(), 0, "le coup laisse une traînée")


func test_trail_fades_once_the_strike_is_over() -> void:
    var duel := Duel.new()
    duel.skip_intro()
    var puppet := _puppet(KnightClass.VEILLEUR)
    duel.step(Intent.of(0, FRAPPE), Intent.of())
    for i in 60:
        puppet.follow(duel.left, Vector2(400, 470))
        duel.step(Intent.of(), Intent.of())
    assert_eq(puppet.trail_size(), 0)


func test_facing_left_mirrors_the_puppet() -> void:
    var duel := Duel.new()
    duel.skip_intro()
    var puppet := _puppet(KnightClass.VEILLEUR)
    puppet.follow(duel.right, Vector2(800, 470))
    assert_lt(puppet.tip_global().x, 800.0, "l'ombre regarde vers la gauche")


func test_rim_copies_sit_behind_the_body() -> void:
    var rims: Array[Vector2] = [Vector2(2, -2)]
    var puppet := _puppet(KnightClass.RODEUSE, rims)
    var skeletons := puppet.get_children().filter(func(n: Node) -> bool: return n is Skeleton2D)
    assert_eq(skeletons.size(), 2, "un liseré et le corps")
    assert_lt(skeletons[0].z_index, skeletons[1].z_index)


func test_flash_whitens_then_returns_to_black() -> void:
    var duel := Duel.new()
    var puppet := _puppet(KnightClass.VEILLEUR)
    puppet.flash()
    for i in KnightPuppet.FLASH_FRAMES:
        puppet.follow(duel.left, Vector2(400, 470))
    var torso := puppet.find_child("torso", true, false)
    assert_eq((torso.get_child(0) as Polygon2D).color, Palette.SILHOUETTE)


# Équipement sur la silhouette

func _count_polygons(node: Node) -> int:
    var total := 0
    for child in node.get_children():
        if child is Polygon2D:
            total += 1
        total += _count_polygons(child)
    return total


func test_the_gear_look_adds_crest_cape_and_pauldrons() -> void:
    var bare := _puppet(KnightClass.VEILLEUR)
    var dressed := KnightPuppet.new()
    dressed.setup(KnightClass.VEILLEUR, Palette.CYAN, [], true, {"crest": &"horns", "cape": &"long", "pauldrons": true})
    add_child_autofree(dressed)
    assert_eq(_count_polygons(dressed), _count_polygons(bare) + 4, "deux cornes, une cape, des épaulières")


func test_a_weapon_shape_stays_in_its_family() -> void:
    assert_eq(KnightBuild.dressed(KnightClass.VEILLEUR, {"weapon": &"sword_slim"})["weapon"], &"sword_slim")
    assert_eq(KnightBuild.dressed(KnightClass.VEILLEUR, {"weapon": &"halberd_broad"})["weapon"], &"sword", "pas de hallebarde pour le Veilleur")
    assert_eq(KnightBuild.dressed(KnightClass.VEILLEUR, {"weapon": &"sword_slim"})["off_hand"], &"shield", "l'écu reste")


func test_both_daggers_change_together() -> void:
    var s := KnightBuild.dressed(KnightClass.RODEUSE, {"weapon": &"dagger_hooked"})
    assert_eq(s["weapon"], &"dagger_hooked")
    assert_eq(s["off_hand"], &"dagger_hooked")


func test_gear_never_changes_the_build_or_the_helmet() -> void:
    var look := {"crest": &"plume", "cape": &"long", "pauldrons": true, "helmet": &"bucket", "chest_w": 99.0}
    for knight in KnightClass.all():
        var base := KnightBuild.spec(knight.id)
        var dressed := KnightBuild.dressed(knight.id, look)
        assert_eq(dressed["helmet"], base["helmet"], String(knight.id))
        assert_eq(dressed["chest_w"], base["chest_w"], String(knight.id))
        assert_eq(dressed["torso"], base["torso"], String(knight.id))


func test_every_catalog_look_is_known_to_the_build() -> void:
    for def in ItemCatalog.all():
        var knight_id := def.knight_id if def.knight_id != &"" else KnightClass.VEILLEUR
        var dressed := KnightBuild.dressed(knight_id, def.look)
        for key: String in def.look:
            assert_eq(dressed[key], def.look[key], "%s : %s" % [def.id, key])
        if def.look.has("weapon"):
            assert_true(KnightBuild.WEAPON_TIPS.has(def.look["weapon"]), String(def.id))
            assert_false(KnightBuild.weapon(def.look["weapon"]).is_empty(), String(def.id))


func test_unknown_look_values_are_ignored() -> void:
    var s := KnightBuild.dressed(KnightClass.COLOSSE, {"crest": &"ailes_de_dragon", "cape": 3, "pauldrons": "oui"})
    assert_eq(s["crest"], &"none")
    assert_eq(s["cape"], &"none")
    assert_true(s["pauldrons"], "le Colosse garde ses épaulières")
