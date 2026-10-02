class_name AiBrain
extends RefCounted
## IA de duel volontairement battable : elle regarde l'adversaire, attend son temps de réaction,
## puis choisit la bonne réponse avec une certaine précision. Même graine, mêmes choix.

const ENGAGE_MARGIN := 100 ## l'IA avance jusqu'à se trouver un peu en deçà de la portée de sa frappe
const TOO_CLOSE_RATIO := 0.6 ## en deçà de cette part de sa distance d'engagement, l'IA recule parfois
const JUMP_IN_RANGE := 1800 ## d'assez près, l'IA saute sur un adversaire qui pare
## Direction à tenir avec chaque réponse : on esquive en arrière, on saute vers l'adversaire.
const MOVE_WITH := {CombatAction.Kind.ESQUIVE: -1, CombatAction.Kind.SAUT: 1}

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
    _cooldown = reaction_frames * 2 / 3 if me.is_enraged() else reaction_frames ## la Furie s'emballe
    var distance := absi(me.x - foe.x)
    var counter := counter_to(me, foe, distance)
    if counter != CombatAction.Kind.NONE and _rng.randf() < accuracy:
        _move = 0
        return Intent.of(MOVE_WITH.get(counter, 0), counter)
    return _neutral(me, distance)


## La lune de la Prêtresse va frapper sous moi : un saut, assez tôt pour être en l'air à l'impact.
func _moon_lands_on(me: Fighter) -> bool:
    return me.danger_left >= 6 and me.danger_left <= 36 and not me.is_airborne() \
        and absi(me.x - me.danger_x) <= Boss.MOON_RADIUS


## La bonne réponse à ce que fait l'adversaire, ou NONE s'il n'y en a pas.
## Une parade se prend par le haut (saut puis plongeon) ; un chevalier en l'air se cueille d'une frappe ;
## un ultime qui se prépare s'esquive ; contre le Colosse, parer ne sert à rien : on le prend de vitesse.
func counter_to(me: Fighter, foe: Fighter, distance: int) -> int:
    if _moon_lands_on(me):
        return CombatAction.Kind.SAUT
    if me.is_airborne():
        var plunge_in_reach := distance <= me.stat(CombatAction.Kind.PLONGEON, "reach")
        return CombatAction.Kind.FRAPPE if plunge_in_reach else CombatAction.Kind.NONE
    var frappe_reach := me.stat(CombatAction.Kind.FRAPPE, "reach")
    if _ultimate_lands(me, foe, distance):
        return CombatAction.Kind.ULTIME
    if foe.phase == Fighter.Phase.STUNNED and distance <= frappe_reach:
        return CombatAction.Kind.FRAPPE
    if foe.is_airborne() and distance <= frappe_reach:
        return CombatAction.Kind.FRAPPE
    if foe.phase == Fighter.Phase.STARTUP and foe.action == CombatAction.Kind.ULTIME:
        return CombatAction.Kind.ESQUIVE
    if foe.has_super_armor() and distance <= foe.stat(foe.action, "reach") + ENGAGE_MARGIN:
        return CombatAction.Kind.ESQUIVE ## le Colosse de Fer ne s'interrompt pas : on esquive, puis on punit
    if foe.phase == Fighter.Phase.STARTUP and foe.action == CombatAction.Kind.FRAPPE:
        if foe.knight.breaks_guard:
            return CombatAction.Kind.FRAPPE if distance <= frappe_reach else CombatAction.Kind.NONE
        return CombatAction.Kind.PARADE
    var guarding_soon := foe.action == CombatAction.Kind.PARADE and foe.phase != Fighter.Phase.RECOVERY
    if guarding_soon and distance <= JUMP_IN_RANGE:
        return CombatAction.Kind.SAUT
    return CombatAction.Kind.NONE


## L'ultime est prêt et toucherait : à portée, et pas une onde au sol contre un chevalier en l'air.
func _ultimate_lands(me: Fighter, foe: Fighter, distance: int) -> bool:
    if me.rune < Fighter.MAX_RUNE or distance > me.stat(CombatAction.Kind.ULTIME, "reach"):
        return false
    return not (me.ultimate.ground_only and foe.is_airborne())


## Distance à laquelle l'IA cesse d'avancer : elle dépend de l'allonge de son chevalier.
static func engage_range(me: Fighter) -> int:
    return me.stat(CombatAction.Kind.FRAPPE, "reach") - ENGAGE_MARGIN


func _neutral(me: Fighter, distance: int) -> Intent:
    var engage := engage_range(me)
    if distance > engage:
        _move = 1
        return Intent.of(1)
    if distance < engage * TOO_CLOSE_RATIO:
        var escape := _rng.randf()
        if escape < 0.4:
            _move = -1
            return Intent.of(-1)
        if escape < 0.5:
            _move = 0
            return Intent.of(-1, CombatAction.Kind.ESQUIVE)
    _move = 0
    var roll := _rng.randf()
    if roll < 0.45:
        return Intent.of(0, CombatAction.Kind.FRAPPE)
    if roll < 0.62:
        return Intent.of(0, CombatAction.Kind.PARADE)
    if roll < 0.74:
        return Intent.of(1, CombatAction.Kind.SAUT)
    return Intent.of()
