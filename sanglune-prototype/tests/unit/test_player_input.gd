extends GutTest
## Entrées du joueur : direction relative au regard, actions clavier enregistrées.


func test_right_on_screen_means_advance_for_the_left_knight() -> void:
    assert_eq(PlayerInput.build(1, CombatAction.Kind.NONE, 1).move, 1)


func test_right_on_screen_means_retreat_for_the_right_knight() -> void:
    assert_eq(PlayerInput.build(1, CombatAction.Kind.NONE, -1).move, -1)


func test_action_is_passed_through() -> void:
    assert_eq(PlayerInput.build(0, CombatAction.Kind.PARADE, 1).action, CombatAction.Kind.PARADE)


func test_every_action_gets_registered() -> void:
    InputBindings.register()
    for action: String in InputBindings.BINDINGS:
        assert_true(InputMap.has_action(action), action)


func test_registering_twice_does_not_duplicate_keys() -> void:
    InputBindings.register()
    InputBindings.register()
    assert_eq(InputMap.action_get_events("frappe").size(), InputBindings.BINDINGS["frappe"].size())
