extends GutTest
## Écran de choix : toucher une carte, changer au clavier, confirmer.

var select: KnightSelect


func before_each() -> void:
    select = KnightSelect.new(KnightClass.VEILLEUR)
    add_child_autofree(select)


func _press(action: String) -> void:
    var event := InputEventAction.new()
    event.action = action
    event.pressed = true
    select._unhandled_input(event)


func _card(position: int) -> KnightCard:
    return select.get_children().filter(func(n: Node) -> bool: return n is KnightCard)[position]


func test_shows_one_card_per_knight_with_the_choice_pressed() -> void:
    var cards := select.get_children().filter(func(n: Node) -> bool: return n is KnightCard)
    assert_eq(cards.size(), KnightClass.all().size())
    assert_true(_card(0).button_pressed, "le Veilleur est présélectionné")
    assert_false(_card(1).button_pressed)


func test_tapping_a_card_selects_it() -> void:
    _card(2).pressed.emit()
    assert_eq(select.selected().id, KnightClass.RODEUSE)
    assert_true(_card(2).button_pressed)
    assert_false(_card(0).button_pressed, "une seule carte enfoncée à la fois")


func test_keyboard_moves_the_selection() -> void:
    _press("move_right")
    assert_eq(select.selected().id, KnightClass.FAUCHEUSE)
    _press("move_left")
    _press("move_left")
    assert_eq(select.selected().id, KnightClass.COLOSSE)


func test_frappe_confirms_the_selected_knight() -> void:
    watch_signals(select)
    _card(3).pressed.emit()
    _press("frappe")
    assert_signal_emitted(select, "confirmed")
    var knight: KnightClass = get_signal_parameters(select, "confirmed")[0]
    assert_eq(knight.id, KnightClass.COLOSSE)
