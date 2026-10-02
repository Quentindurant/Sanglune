class_name KnightClass
extends RefCounted
## Les quatre chevaliers de la v1. Une classe ajuste les données de base de CombatAction :
## allonge, vitesse de mise en garde et de reprise, puissance, vie et vitesse de marche.
## Tout l'équilibrage des chevaliers se règle dans ROSTER.

const VEILLEUR := &"veilleur"
const FAUCHEUSE := &"faucheuse"
const RODEUSE := &"rodeuse"
const COLOSSE := &"colosse"

const BASE_HP := 1000 ## une vie fine : même un petit bonus d'équipement compte
const BASE_WALK_SPEED := 42 ## millimètres par frame, soit environ 2,5 m/s
const DAMAGE_STEP := 10 ## les dégâts d'une classe tombent sur des dizaines : l'équilibrage des chevaliers est réglé ainsi
const RATING_STEP := 7.0 ## écart de note par unité de multiplicateur, pour l'écran de choix
const JUMP_SPEED_RATIO := 1.3 ## un saut avec élan va un peu plus vite que la marche
const DODGE_SPEED_RATIO := 2.5 ## une esquive file deux fois et demie plus vite que la marche

## reach : multiplie la portée. startup, recovery : multiplient les frames (plus petit = plus rapide).
## power : multiplie les dégâts. walk : multiplie la vitesse de marche. hp : points de vie.
## breaks_guard : toutes ses attaques brisent la parade. ultimate : l'ultime de son arme de départ.
const ROSTER := [
    {
        "id": VEILLEUR, "name": "Le Veilleur", "weapon": "Épée longue et écu",
        "strength": "Équilibré, idéal pour apprendre", "weakness": "Ne domine nulle part",
        "reach": 1.0, "startup": 1.0, "recovery": 1.0, "power": 1.0, "walk": 1.0,
        "hp": BASE_HP, "breaks_guard": false, "ultimate": Ultimate.LAME_DE_LUNE,
    },
    {
        "id": FAUCHEUSE, "name": "La Faucheuse", "weapon": "Hallebarde",
        "strength": "Allonge maximale", "weakness": "Lente à la reprise",
        "reach": 1.3, "startup": 1.1, "recovery": 1.4, "power": 1.1, "walk": 0.9,
        "hp": BASE_HP, "breaks_guard": false, "ultimate": Ultimate.MOISSON,
    },
    {
        "id": RODEUSE, "name": "La Rôdeuse", "weapon": "Deux dagues",
        "strength": "Vitesse maximale", "weakness": "Doit coller sa cible",
        "reach": 0.78, "startup": 0.75, "recovery": 0.72, "power": 0.8, "walk": 1.25,
        "hp": BASE_HP, "breaks_guard": false, "ultimate": Ultimate.DANSE_DES_LAMES,
    },
    {
        "id": COLOSSE, "name": "Le Colosse", "weapon": "Masse d'armes et plaques",
        "strength": "Chaque coup brise la garde", "weakness": "Le plus lent",
        "reach": 0.95, "startup": 1.3, "recovery": 1.15, "power": 1.35, "walk": 0.8,
        "hp": 1200, "breaks_guard": true, "ultimate": Ultimate.SEISME,
    },
]

var id: StringName
var display_name: String
var weapon: String
var strength: String
var weakness: String
var reach_scale: float
var startup_scale: float
var recovery_scale: float
var power: float
var walk_speed: int
var jump_speed: int ## vitesse horizontale d'un saut avec élan, en millimètres par frame
var dodge_speed: int ## vitesse pendant l'esquive, en millimètres par frame
var max_hp: int
var breaks_guard: bool
var ultimate_id: StringName ## l'ultime de l'arme de départ
var _stats := {} ## données de frames calculées une fois : entiers, donc déterministes pour le réseau


func _init(data: Dictionary) -> void:
    id = data["id"]
    display_name = data["name"]
    weapon = data["weapon"]
    strength = data["strength"]
    weakness = data["weakness"]
    reach_scale = data["reach"]
    startup_scale = data["startup"]
    recovery_scale = data["recovery"]
    power = data["power"]
    walk_speed = roundi(BASE_WALK_SPEED * float(data["walk"]))
    jump_speed = roundi(walk_speed * JUMP_SPEED_RATIO)
    dodge_speed = roundi(walk_speed * DODGE_SPEED_RATIO)
    max_hp = data["hp"]
    breaks_guard = data["breaks_guard"]
    ultimate_id = data["ultimate"]
    _build_stats()


## Les quatre chevaliers, dans l'ordre de l'écran de choix.
static func all() -> Array[KnightClass]:
    var knights: Array[KnightClass] = []
    for data: Dictionary in ROSTER:
        knights.append(KnightClass.new(data))
    return knights


## Le chevalier demandé, ou null si l'identifiant est inconnu (entrée à ne jamais croire sur parole).
static func by_id(knight_id: StringName) -> KnightClass:
    for data: Dictionary in ROSTER:
        if data["id"] == knight_id:
            return KnightClass.new(data)
    return null


## Le chevalier proposé par défaut : le Veilleur, idéal pour apprendre.
static func starter() -> KnightClass:
    return by_id(VEILLEUR)


## Un chevalier au hasard, miroir compris. Même graine, même tirage.
static func pick_random(rng: RandomNumberGenerator) -> KnightClass:
    return KnightClass.new(ROSTER[rng.randi_range(0, ROSTER.size() - 1)])


## Une donnée de CombatAction ajustée pour ce chevalier, par exemple stat(Kind.FRAPPE, "reach").
func stat(kind: int, key: String) -> int:
    return _stats[kind][key]


## Notes de 1 à 5 affichées sur l'écran de choix. Le Veilleur vaut 3 partout.
func ratings() -> Dictionary:
    return {
        "Allonge": _rating(reach_scale),
        "Vitesse": _rating(1.0 / startup_scale), ## la vitesse à laquelle un coup part
        "Puissance": _rating(power),
    }


func _build_stats() -> void:
    for kind: int in CombatAction.DATA:
        var stats: Dictionary = CombatAction.DATA[kind].duplicate()
        stats["startup"] = maxi(1, roundi(stats["startup"] * startup_scale))
        stats["recovery"] = maxi(1, roundi(stats["recovery"] * recovery_scale))
        stats["damage"] = roundi(stats["damage"] * power / DAMAGE_STEP) * DAMAGE_STEP
        stats["reach"] = roundi(stats["reach"] * reach_scale)
        _stats[kind] = stats


static func _rating(scale: float) -> int:
    return clampi(roundi(3.0 + (scale - 1.0) * RATING_STEP), 1, 5)
