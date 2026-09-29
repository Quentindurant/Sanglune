class_name AiInput
extends IntentSource
## Adaptateur d'entrée : branche une AiBrain sur le port IntentSource.

var _brain: AiBrain


func _init(brain: AiBrain) -> void:
    _brain = brain


func next_intent(me: Fighter, foe: Fighter) -> Intent:
    return _brain.decide(me, foe)
