class_name IntentSource
extends RefCounted
## Port d'entrée du domaine : tout ce qui fournit une intention par frame.
## Joueur local, IA, et plus tard un adversaire en ligne via Nakama : même contrat.


func next_intent(_me: Fighter, _foe: Fighter) -> Intent:
    return Intent.of()
