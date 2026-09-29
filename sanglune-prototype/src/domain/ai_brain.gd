class_name AiBrain
extends RefCounted
## IA de duel volontairement battable : elle regarde l'adversaire, attend son temps de réaction,
## puis choisit la bonne réponse avec une certaine précision. Même graine, mêmes choix.

const ENGAGE_MARGIN := 100 ## l'IA avance jusqu'à se trouver un peu en deçà de la portée de sa frappe
const TOO_CLOSE_RATIO := 0.6 ## en deçà de cette part de sa distance d'engagement, l'IA recule parfois

var reaction_frames: int ## frames entre deux décisions
var accuracy: float ## probabilité de jouer la bonne réponse quand il y en a une (0 à 1)
var _rng := RandomNumberGenerator.new()
var _cooldown := 0
var _move := 0


func _init(p_seed: int = 7, p_reaction_frames: int = 12, p_accuracy: float = 0.7) -> void:
    _rng.seed = p_seed
    reaction_frames = p_reaction_frames
    accuracy = p_accuracy


func decide(me: Fighter, foe: Fighter) -> Intent:
    if _cooldown > 0:
        _cooldown -= 1
        return Intent.of(_move)
    _cooldown = reaction_frames
    var distance := absi(me.x - foe.x)
    var counter := counter_to(me, foe, distance)
    if counter != CombatAction.Kind.NONE and _rng.randf() < accuracy:
        _move = 0
        return Intent.of(0, counter)
    return _neutral(me, distance)


## La bonne réponse à ce que fait l'adversaire, ou NONE s'il n'y en a pas.
## Contre le Colosse, parer ne sert à rien : l'IA le prend de vitesse avec une frappe.
func counter_to(me: Fighter, foe: Fighter, distance: int) -> int:
    var frappe_reach := me.stat(CombatAction.Kind.FRAPPE, "reach")
    if me.rune >= Fighter.MAX_RUNE and distance <= me.stat(CombatAction.Kind.RUNE, "reach"):
        return CombatAction.Kind.RUNE
    if foe.phase == Fighter.Phase.STUNNED and distance <= frappe_reach:
        return CombatAction.Kind.FRAPPE
    if foe.phase == Fighter.Phase.STARTUP:
        var frappe_coming := foe.action == CombatAction.Kind.FRAPPE
        var interruptible := foe.action == CombatAction.Kind.ESTOC or (frappe_coming and foe.knight.breaks_guard)
        if interruptible and distance <= frappe_reach:
            return CombatAction.Kind.FRAPPE
        if frappe_coming and not foe.knight.breaks_guard:
            return CombatAction.Kind.PARADE
    var guarding_soon := foe.action == CombatAction.Kind.PARADE and foe.phase != Fighter.Phase.RECOVERY
    if guarding_soon and distance <= me.stat(CombatAction.Kind.ESTOC, "reach"):
        return CombatAction.Kind.ESTOC
    return CombatAction.Kind.NONE


## Distance à laquelle l'IA cesse d'avancer : elle dépend de l'allonge de son chevalier.
static func engage_range(me: Fighter) -> int:
    return me.stat(CombatAction.Kind.FRAPPE, "reach") - ENGAGE_MARGIN


func _neutral(me: Fighter, distance: int) -> Intent:
    var engage := engage_range(me)
    if distance > engage:
        _move = 1
        return Intent.of(1)
    if distance < engage * TOO_CLOSE_RATIO and _rng.randf() < 0.5:
        _move = -1
        return Intent.of(-1)
    _move = 0
    var roll := _rng.randf()
    if roll < 0.45:
        return Intent.of(0, CombatAction.Kind.FRAPPE)
    if roll < 0.65:
        return Intent.of(0, CombatAction.Kind.ESTOC)
    if roll < 0.8:
        return Intent.of(0, CombatAction.Kind.PARADE)
    return Intent.of()
