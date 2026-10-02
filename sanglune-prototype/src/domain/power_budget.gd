class_name PowerBudget
extends RefCounted
## Le budget qui rend les compromis honnêtes : à rareté et niveau égaux, gains moins pertes valent toujours autant.
## Les gains se partagent le budget de la rareté, renforcé à chaque niveau ; la perte ne bouge jamais.
## Les points se comptent en millièmes pour rester entiers.

const MIN_LEVEL := 1
const MAX_LEVEL := 10
const LEVEL_BONUS := 30 ## chaque niveau au-dessus du premier ajoute 3 % aux gains de base
const BASE_POWER := 100 ## puissance d'un chevalier sans équipement
const POWER_PER_POINT := 5 ## un point de budget net vaut 5 de puissance affichée
const UPGRADE_COST_PER_LEVEL := 8 ## passer du niveau n au suivant coûte 8 × n éclats
const SHARD_VALUE := [6, 12, 25, 50] ## éclats d'une pièce en double ou recyclée, selon sa rareté
## Avec ces valeurs, quatre pièces Gibbeuse au niveau 10 apportent environ 18 points :
## le chevalier ainsi équipé bat le même sans rien environ 3 fois sur 4 (tools/gear_report.gd).


static func is_valid_level(level: Variant) -> bool:
    return level is int and level >= MIN_LEVEL and level <= MAX_LEVEL


## Budget des gains, en millièmes de point.
static func gain_milli_points(rarity: int, level: int) -> int:
    return Rarity.GAIN_TENTHS[rarity] * (1000 + LEVEL_BONUS * (level - MIN_LEVEL)) / 10


## Éclats pour faire passer une pièce de ce niveau au suivant.
static func upgrade_cost(level: int) -> int:
    return UPGRADE_COST_PER_LEVEL * level


## Éclats rendus par une pièce changée en éclats : sa rareté, plus la moitié de ce qu'ont coûté ses niveaux.
static func shard_value(rarity: int, level: int) -> int:
    var spent := UPGRADE_COST_PER_LEVEL * (level - 1) * level / 2
    return SHARD_VALUE[rarity] + spent / 2


static func loss_milli_points() -> int:
    return Rarity.LOSS_TENTHS * 100


## Ce que la pièce apporte à la puissance, en millièmes de point. Une arme de départ ne compte pas.
static func net_milli_points(def: ItemDef, rarity: int, level: int) -> int:
    if def.starter:
        return 0
    return gain_milli_points(rarity, level) - loss_milli_points()


## Les effets d'une pièce : caractéristique -> pour mille.
static func modifiers(def: ItemDef, rarity: int, level: int) -> Dictionary:
    var result := {}
    if def.starter or def.gains.is_empty() or def.losses.is_empty():
        return result
    var gains := def.gains.slice(0, Rarity.GAIN_COUNT[rarity])
    var per_gain := gain_milli_points(rarity, level) / gains.size()
    for stat in gains:
        result[stat] = result.get(stat, 0) + per_gain * GearStat.PER_POINT[stat] / 1000
    var per_loss := loss_milli_points() / def.losses.size()
    for stat in def.losses:
        result[stat] = result.get(stat, 0) - per_loss * GearStat.PER_POINT[stat] / 1000
    return result


## La puissance affichée : 100 sans équipement, plus ce qu'apporte chaque pièce portée.
static func power(net_milli_total: int) -> int:
    return BASE_POWER + (net_milli_total * POWER_PER_POINT + 500) / 1000
