class_name Intent
extends RefCounted
## Ce qu'un combattant veut faire pendant une frame, qu'il soit joueur, IA ou, plus tard, réseau.

var move: int = 0 ## 1 avance vers l'adversaire, -1 recule, 0 reste en place
var action: int = CombatAction.Kind.NONE


static func of(p_move: int = 0, p_action: int = CombatAction.Kind.NONE) -> Intent:
    var intent := Intent.new()
    intent.move = p_move
    intent.action = p_action
    return intent
