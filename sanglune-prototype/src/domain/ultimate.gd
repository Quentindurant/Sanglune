class_name Ultimate
extends RefCounted
## Les capacités ultimes : chacune appartient à une arme. Elle part quand les trois runes sont allumées et vide la jauge.
## Toutes traversent la parade ; chacune a sa propre parade : sortir de portée, sauter, esquiver ou frapper pendant la préparation.
## L'arme équipée décide de l'ultime (voir ItemCatalog et Loadout).

const LAME_DE_LUNE := &"lame_de_lune"
const MOISSON := &"moisson"
const DANSE_DES_LAMES := &"danse_des_lames"
const SEISME := &"seisme"

## startup, active, recovery : frames. damage : par coup, sur une vie de 1000. reach : portée en millimètres.
## hits : nombre de coups, espacés de hit_interval frames. stun : étourdissement infligé, en frames.
## pushback : recul infligé, en millimètres. dash : élan vers l'avant pendant le coup, en millimètres par frame.
## invulnerable : intouchable pendant le coup. ground_only : une onde au sol, qu'on évite en sautant.
const CATALOG := {
    LAME_DE_LUNE: {
        "name": "Lame de lune", "startup": 16, "active": 6, "recovery": 22, "damage": 220, "reach": 2300,
        "hits": 1, "hit_interval": 0, "stun": 24, "pushback": 500, "dash": 0, "invulnerable": false, "ground_only": false,
    },
    MOISSON: {
        "name": "Moisson", "startup": 20, "active": 8, "recovery": 26, "damage": 180, "reach": 3000,
        "hits": 1, "hit_interval": 0, "stun": 24, "pushback": 1000, "dash": 0, "invulnerable": false, "ground_only": false,
    },
    DANSE_DES_LAMES: {
        "name": "Danse des lames", "startup": 8, "active": 18, "recovery": 18, "damage": 80, "reach": 1100,
        "hits": 3, "hit_interval": 6, "stun": 14, "pushback": 120, "dash": 85, "invulnerable": true, "ground_only": false,
    },
    SEISME: {
        "name": "Séisme", "startup": 22, "active": 6, "recovery": 26, "damage": 210, "reach": 2600,
        "hits": 1, "hit_interval": 0, "stun": 40, "pushback": 300, "dash": 0, "invulnerable": false, "ground_only": true,
    },
}

var id: StringName
var display_name: String
var hits: int
var hit_interval: int
var stun: int
var pushback: int
var dash: int
var invulnerable: bool
var ground_only: bool
var _stats := {}


func _init(p_id: StringName, data: Dictionary) -> void:
    id = p_id
    display_name = data["name"]
    hits = data["hits"]
    hit_interval = data["hit_interval"]
    stun = data["stun"]
    pushback = data["pushback"]
    dash = data["dash"]
    invulnerable = data["invulnerable"]
    ground_only = data["ground_only"]
    for key: String in ["startup", "active", "recovery", "damage", "reach"]:
        _stats[key] = data[key]


## L'ultime demandé, ou null si l'identifiant est inconnu.
static func by_id(ultimate_id: StringName) -> Ultimate:
    if not CATALOG.has(ultimate_id):
        return null
    return Ultimate.new(ultimate_id, CATALOG[ultimate_id])


static func all() -> Array[Ultimate]:
    var result: Array[Ultimate] = []
    for ultimate_id: StringName in CATALOG:
        result.append(by_id(ultimate_id))
    return result


## Une donnée de frames, comme pour les autres actions : startup, active, recovery, damage ou reach.
func stat(key: String) -> int:
    return _stats[key]
