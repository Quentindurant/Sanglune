extends GutTest
## Silhouettes grises : chaque chevalier a la sienne, et deux chevaliers ne partagent ni casque ni arme.


func test_every_knight_of_the_roster_has_a_look() -> void:
    for knight in KnightClass.all():
        assert_true(KnightLook.has_look(knight.id), knight.display_name)


func test_helmets_and_weapons_tell_the_knights_apart() -> void:
    var helmets := {}
    var weapons := {}
    for knight in KnightClass.all():
        helmets[KnightLook.helmet_of(knight.id)] = true
        weapons[KnightLook.weapon_of(knight.id)] = true
    assert_eq(helmets.size(), KnightClass.all().size(), "un casque par chevalier")
    assert_eq(weapons.size(), KnightClass.all().size(), "une arme par chevalier")


func test_body_stands_on_its_feet() -> void:
    var body := KnightLook.body_rect(KnightClass.COLOSSE, Vector2(400, 470), 0.5)
    assert_eq(body.end.y, 470.0)
    assert_eq(body.get_center().x, 400.0)


func test_colosse_is_the_widest_and_rodeuse_the_smallest() -> void:
    var feet := Vector2.ZERO
    var colosse := KnightLook.body_rect(KnightClass.COLOSSE, feet)
    var rodeuse := KnightLook.body_rect(KnightClass.RODEUSE, feet)
    for knight in KnightClass.all():
        var body := KnightLook.body_rect(knight.id, feet)
        assert_gte(colosse.size.x, body.size.x, knight.display_name)
        assert_lte(rodeuse.size.y, body.size.y, knight.display_name)
