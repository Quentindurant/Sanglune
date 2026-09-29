extends GutTest
## Écran de choix, côté modèle : sélection par position, par identifiant, et défilement en boucle.


func test_opens_on_the_requested_knight() -> void:
    assert_eq(KnightPicker.new(KnightClass.RODEUSE).selected().id, KnightClass.RODEUSE)


func test_opens_on_the_veilleur_by_default() -> void:
    assert_eq(KnightPicker.new().selected().id, KnightClass.VEILLEUR)


func test_unknown_id_keeps_the_current_choice() -> void:
    var picker := KnightPicker.new(KnightClass.COLOSSE)
    picker.select_id(&"paladin")
    assert_eq(picker.selected().id, KnightClass.COLOSSE)


func test_out_of_range_position_is_ignored() -> void:
    var picker := KnightPicker.new()
    picker.select_index(2)
    picker.select_index(99)
    picker.select_index(-1)
    assert_eq(picker.index, 2)


func test_step_wraps_around_both_ways() -> void:
    var picker := KnightPicker.new()
    picker.step(-1)
    assert_eq(picker.selected().id, KnightClass.COLOSSE, "avant le premier, on revient au dernier")
    picker.step(1)
    assert_eq(picker.selected().id, KnightClass.VEILLEUR)
