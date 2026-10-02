extends GutTest
## Accueil : le chevalier actif devant la lune, « Jouer » et « Chevaliers ».

var home: HomeScreen


func before_each() -> void:
    home = HomeScreen.new(KnightClass.by_id(KnightClass.FAUCHEUSE))
    add_child_autofree(home)


func _button(text: String) -> Button:
    for child in home.get_children():
        if child is Button and child.text == text:
            return child
    return null


func test_shows_the_active_knight() -> void:
    assert_eq(home.knight.id, KnightClass.FAUCHEUSE)


func test_play_button_asks_for_a_duel() -> void:
    watch_signals(home)
    _button("Jouer").pressed.emit()
    assert_signal_emitted(home, "play_requested")


func test_knights_button_opens_the_knights() -> void:
    watch_signals(home)
    _button("Chevaliers").pressed.emit()
    assert_signal_emitted(home, "knights_requested")


func test_frappe_key_also_plays() -> void:
    watch_signals(home)
    var event := InputEventAction.new()
    event.action = "frappe"
    event.pressed = true
    home._unhandled_input(event)
    assert_signal_emitted(home, "play_requested")


func test_back_is_not_handled_on_the_home_screen() -> void:
    assert_false(home.go_back(), "à l'accueil, le retour Android quitte le jeu")


func test_shows_the_palier_and_the_power() -> void:
    assert_eq(autofree(HomeScreen.new(KnightClass.starter(), {}, 3, 112)).path_line(), "Palier 3 · Puissance 112")
    assert_eq(autofree(HomeScreen.new(KnightClass.starter(), {}, 5, 130)).path_line(), "Gardien du palier 5 · Puissance 130")
