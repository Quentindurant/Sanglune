class_name HuntDifficulty
extends RefCounted
## Les trois nuits de la Chasse. Chacune fixe la force des ombres (en paliers du Chemin des ombres), la pente
## d'un duel au suivant, le seigneur du bout de la Chasse et la valeur du butin.
## Pénombre et Nuit sont ouvertes dès le départ ; Lune de sang s'ouvre en finissant une Chasse de Nuit.

enum Level { PENOMBRE, NUIT, LUNE_DE_SANG }

const DATA := {
    Level.PENOMBRE: {
        "key": "penombre", "name": "Pénombre",
        "first_palier": 1, "palier_step": 1, "final_palier": 10, "requires": -1,
        "shadow_blessings": 0, "boss_blessings": 0,
        "offer_rarity": [70, 30, 0, 0], "final_rarity": [0, 80, 20, 0],
        "offer_shards": 12, "final_shards": 20, "shards_per_duel": 2,
    },
    Level.NUIT: {
        "key": "nuit", "name": "Nuit",
        "first_palier": 6, "palier_step": 2, "final_palier": 20, "requires": -1,
        "shadow_blessings": 0, "boss_blessings": 1,
        "offer_rarity": [0, 65, 33, 2], "final_rarity": [0, 0, 90, 10],
        "offer_shards": 20, "final_shards": 40, "shards_per_duel": 3,
    },
    Level.LUNE_DE_SANG: {
        "key": "lune_de_sang", "name": "Lune de sang",
        "first_palier": 12, "palier_step": 2, "final_palier": 30, "requires": Level.NUIT,
        "shadow_blessings": 1, "boss_blessings": 2,
        "offer_rarity": [0, 0, 85, 15], "final_rarity": [0, 0, 60, 40],
        "offer_shards": 35, "final_shards": 80, "shards_per_duel": 4,
    },
}


static func all() -> Array[int]:
    var result: Array[int] = []
    for level: int in Level.values():
        result.append(level)
    return result


static func is_valid(level: Variant) -> bool:
    return level is int and DATA.has(level)


static func display_name(level: int) -> String:
    return DATA[level]["name"]


static func key(level: int) -> String:
    return DATA[level]["key"]


## Relit une difficulté sauvegardée par sa clé ; -1 si elle est inconnue.
static func from_key(value: Variant) -> int:
    if not value is String:
        return -1
    for level: int in DATA:
        if DATA[level]["key"] == value:
            return level
    return -1


## La difficulté qu'il faut avoir finie pour ouvrir celle-ci, ou -1.
static func requirement(level: int) -> int:
    return DATA[level]["requires"]


static func value(level: int, field: String) -> Variant:
    return DATA[level][field]


## Le palier du Chemin dont l'ombre a la force du duel d'indice index (0 pour le premier).
static func palier_of(level: int, index: int) -> int:
    if index >= Hunt.LENGTH - 1:
        return DATA[level]["final_palier"]
    return DATA[level]["first_palier"] + DATA[level]["palier_step"] * index


## Tire une rareté selon une table de poids sur 100 (une case par phase de lune).
static func roll_rarity(weights: Array, rng: RandomSource) -> int:
    var total := 0
    for weight: int in weights:
        total += weight
    var roll := rng.below(total)
    for tier in weights.size():
        if roll < weights[tier]:
            return tier
        roll -= weights[tier]
    return Rarity.Tier.CROISSANT
