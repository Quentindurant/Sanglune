class_name GearStat
extends RefCounted
## Les caractéristiques qu'une pièce d'équipement renforce ou affaiblit.
## Une valeur s'exprime en pour mille : +100 veut dire +10 %. Tout reste entier, donc identique sur deux téléphones.

## Que des grandeurs continues : la vitesse des coups se compte en frames entières (une frame de moins sur
## une frappe vaut déjà +11 %), bien trop grossier pour le budget d'une pièce. Elle reviendra avec un minutage plus fin.
enum Stat { HP, POWER, REACH, WALK, DODGE, STUN_RESIST, ULT_POWER }

## Pour mille obtenus par point de budget. Un point vaut à peu près 1 % de vie sur l'issue d'un duel,
## mesuré par tools/gear_weights_report.gd (IA contre IA). La marche, l'esquive et la force de l'ultime,
## que l'IA exploite mal, sont réglées à l'estime : elles se jugeront en jeu.
const PER_POINT := {
    Stat.HP: 10, Stat.POWER: 16, Stat.REACH: 7, Stat.WALK: 20, Stat.DODGE: 40,
    Stat.STUN_RESIST: 30, Stat.ULT_POWER: 40,
}

## Noms courts affichés dans l'armurerie.
const LABEL := {
    Stat.HP: "Vie", Stat.POWER: "Dégâts", Stat.REACH: "Allonge", Stat.WALK: "Marche", Stat.DODGE: "Esquive",
    Stat.STUN_RESIST: "Résistance", Stat.ULT_POWER: "Force de l'ultime",
}

const MIN_PERMILLE := -800 ## une perte ne peut jamais retirer plus de 80 %
const MAX_PERMILLE := 3000


static func all() -> Array[int]:
    var stats: Array[int] = []
    for value: int in Stat.values():
        stats.append(value)
    return stats


static func is_valid(stat: Variant) -> bool:
    return stat is int and PER_POINT.has(stat)


## Une quantité qui grandit avec une valeur positive : vie, dégâts, distances, vitesses.
static func grow(base: int, permille: int) -> int:
    var factor := 1000 + clampi(permille, MIN_PERMILLE, MAX_PERMILLE)
    return maxi(1, (base * factor + 500) / 1000)


## Une durée qui raccourcit avec une valeur positive : plus rapide veut dire moins de frames.
static func shorten(frames: int, permille: int) -> int:
    var factor := 1000 - clampi(permille, MIN_PERMILLE, 800)
    return maxi(1, (frames * factor + 500) / 1000)
