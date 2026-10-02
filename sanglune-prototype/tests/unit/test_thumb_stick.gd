extends GutTest
## Joystick du pouce gauche : marcher, sauter vers le haut, esquiver vers le bas, tout relâcher en levant le pouce.

const ACTIONS := ["move_left", "move_right", "saut", "esquive"]

var stick: ThumbStick


func before_each() -> void:
    InputBindings.register()
    stick = ThumbStick.new()
    add_child_autofree(stick)


func after_each() -> void:
    for action: String in ACTIONS:
        Input.action_release(action)


func _touch(at: Vector2, pressed: bool = true) -> void:
    var event := InputEventScreenTouch.new()
    event.index = 0
    event.position = at
    event.pressed = pressed
    stick._input(event)


func _drag(offset: Vector2) -> void:
    var event := InputEventScreenDrag.new()
    event.index = 0
    event.position = stick.center + offset
    stick._input(event)


func _pressed() -> Array:
    return ACTIONS.filter(func(action: String) -> bool: return Input.is_action_pressed(action))


func test_thumb_lands_where_it_touches() -> void:
    _touch(Vector2(220, 560))
    assert_true(stick.is_held())
    assert_eq(stick.center, Vector2(220, 560))


func test_pushing_right_walks_right() -> void:
    _touch(Vector2(220, 560))
    _drag(Vector2(60, 0))
    assert_eq(_pressed(), ["move_right"])


func test_a_light_touch_does_nothing() -> void:
    _touch(Vector2(220, 560))
    _drag(Vector2(15, 10))
    assert_eq(_pressed(), [])


func test_walking_slightly_upward_does_not_jump() -> void:
    _touch(Vector2(220, 560))
    _drag(Vector2(60, -35))
    assert_eq(_pressed(), ["move_right"], "un pouce de biais marche, il ne saute pas")


func test_pushing_up_jumps_and_up_right_jumps_forward() -> void:
    _touch(Vector2(220, 560))
    _drag(Vector2(40, -70))
    assert_true(Input.is_action_pressed("saut"))
    assert_true(Input.is_action_pressed("move_right"))


func test_pushing_down_dodges() -> void:
    _touch(Vector2(220, 560))
    _drag(Vector2(0, 75))
    assert_eq(_pressed(), ["esquive"])


func test_lifting_the_thumb_releases_everything() -> void:
    _touch(Vector2(220, 560))
    _drag(Vector2(-70, 0))
    _touch(Vector2(150, 560), false)
    assert_eq(_pressed(), [])
    assert_false(stick.is_held())
    assert_eq(stick.center, ThumbStick.REST_CENTER)


func test_touches_outside_its_corner_are_ignored() -> void:
    _touch(Vector2(900, 600))
    assert_false(stick.is_held(), "le pouce droit garde ses boutons")


func test_disabled_during_menus() -> void:
    _touch(Vector2(220, 560))
    _drag(Vector2(70, 0))
    stick.set_enabled(false)
    assert_eq(_pressed(), [])
    _touch(Vector2(220, 560))
    assert_false(stick.is_held())
