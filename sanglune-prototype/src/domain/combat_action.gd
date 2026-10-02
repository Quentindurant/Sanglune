class_name CombatAction
extends RefCounted
## Les actions d'un chevalier et leurs données de frames de base (60 frames = 1 seconde).
## Chaque chevalier ajuste ces données dans KnightClass ; l'Ultime, lui, vient de son arme (Ultimate).

enum Kind { NONE, FRAPPE, PARADE, ULTIME, ESQUIVE, SAUT, PLONGEON }

## startup : frames avant que l'action prenne effet (coup dangereux, parade active, bond, envol).
## active : frames pendant lesquelles le coup touche, la parade protège ou l'esquive rend intouchable.
## recovery : frames de récupération, vulnérables. Pour le saut, c'est la réception au sol.
## damage : vie retirée, sur une vie de 1000. reach : portée de centre à centre, en millimètres.
const DATA := {
    Kind.FRAPPE: {"startup": 9, "active": 6, "recovery": 15, "damage": 80, "reach": 1600},
    Kind.PARADE: {"startup": 3, "active": 21, "recovery": 18, "damage": 0, "reach": 0},
    Kind.ESQUIVE: {"startup": 2, "active": 10, "recovery": 14, "damage": 0, "reach": 0},
    Kind.SAUT: {"startup": 4, "active": 0, "recovery": 5, "damage": 0, "reach": 0},
    Kind.PLONGEON: {"startup": 6, "active": 40, "recovery": 14, "damage": 100, "reach": 1300},
}

const LABELS := {
    Kind.NONE: "",
    Kind.FRAPPE: "Frappe",
    Kind.PARADE: "Parade",
    Kind.ULTIME: "Ultime",
    Kind.ESQUIVE: "Esquive",
    Kind.SAUT: "Saut",
    Kind.PLONGEON: "Plongeon",
}


static func is_attack(kind: int) -> bool:
    return kind in [Kind.FRAPPE, Kind.ULTIME, Kind.PLONGEON]


## En l'air, la frappe devient un plongeon ; les autres actions attendent la réception.
static func is_air_attack_trigger(kind: int) -> bool:
    return kind == Kind.FRAPPE


## Une valeur de la table DATA, par exemple stat(Kind.FRAPPE, "reach").
static func stat(kind: int, key: String) -> int:
    return DATA[kind][key]
