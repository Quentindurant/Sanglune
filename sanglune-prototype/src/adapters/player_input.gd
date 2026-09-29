class_name PlayerInput
extends IntentSource
## Adaptateur d'entrée : clavier et boutons tactiles, lus à travers l'InputMap.

## Si plusieurs boutons partent sur la même frame, le premier de cette liste l'emporte.
const ACTION_PRIORITY := [
    ["rune", CombatAction.Kind.RUNE],
    ["estoc", CombatAction.Kind.ESTOC],
    ["frappe", CombatAction.Kind.FRAPPE],
    ["parade", CombatAction.Kind.PARADE],
]


func next_intent(me: Fighter, _foe: Fighter) -> Intent:
    var screen_dir := int(Input.is_action_pressed("move_right")) - int(Input.is_action_pressed("move_left"))
    return build(screen_dir, _pressed_action(), me.facing())


## Traduit une direction à l'écran en intention relative : avancer vers l'adversaire ou reculer.
static func build(screen_dir: int, action: int, facing: int) -> Intent:
    return Intent.of(screen_dir * facing, action)


func _pressed_action() -> int:
    for pair: Array in ACTION_PRIORITY:
        if Input.is_action_just_pressed(pair[0]):
            return pair[1]
    return CombatAction.Kind.NONE
