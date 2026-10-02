class_name PlayerInput
extends IntentSource
## Adaptateur d'entrée : clavier et boutons tactiles, lus à travers l'InputMap.

## Si plusieurs boutons partent sur la même frame, le premier de cette liste l'emporte.
const ACTION_PRIORITY := [
    ["esquive", CombatAction.Kind.ESQUIVE],
    ["saut", CombatAction.Kind.SAUT],
    ["ultime", CombatAction.Kind.ULTIME],
    ["frappe", CombatAction.Kind.FRAPPE],
    ["parade", CombatAction.Kind.PARADE],
]


func next_intent(me: Fighter, foe: Fighter) -> Intent:
    var screen_dir := int(Input.is_action_pressed("move_right")) - int(Input.is_action_pressed("move_left"))
    return build(screen_dir, _pressed_action(), Duel.toward(me, foe))


## Traduit une direction à l'écran en intention relative : avancer vers l'adversaire ou reculer.
## toward : sens de l'adversaire à l'écran, 1 à droite, -1 à gauche.
static func build(screen_dir: int, action: int, toward: int) -> Intent:
    return Intent.of(screen_dir * toward, action)


func _pressed_action() -> int:
    for pair: Array in ACTION_PRIORITY:
        if Input.is_action_just_pressed(pair[0]):
            return pair[1]
    return CombatAction.Kind.NONE
