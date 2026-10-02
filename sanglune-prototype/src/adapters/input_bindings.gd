class_name InputBindings
extends RefCounted
## Actions d'entrée et leurs touches clavier, pour jouer aussi sur PC.
## Touches physiques : sur un clavier AZERTY, KEY_A correspond à Q et KEY_W à Z (ZQSD).

const BINDINGS := {
    "move_left": [KEY_A, KEY_LEFT],
    "move_right": [KEY_D, KEY_RIGHT],
    "saut": [KEY_W, KEY_UP],
    "esquive": [KEY_S, KEY_DOWN, KEY_SPACE],
    "frappe": [KEY_J],
    "parade": [KEY_L],
    "ultime": [KEY_I],
}


static func register() -> void:
    for action: String in BINDINGS:
        if InputMap.has_action(action):
            continue
        InputMap.add_action(action)
        for key: int in BINDINGS[action]:
            var event := InputEventKey.new()
            event.physical_keycode = key
            InputMap.action_add_event(action, event)
