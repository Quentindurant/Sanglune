class_name CombatAction
extends RefCounted
## Les actions d'un chevalier et leurs données de frames de base (60 frames = 1 seconde).
## Chaque chevalier ajuste ces données dans KnightClass (allonge, vitesse, puissance).

enum Kind { NONE, FRAPPE, ESTOC, PARADE, RUNE }

## startup : frames avant que le coup devienne dangereux (la parade, elle, devient active).
## active : frames pendant lesquelles le coup touche, ou la parade protège.
## recovery : frames de récupération, vulnérables.
## damage : points de vie retirés. reach : portée de centre à centre, en millimètres.
const DATA := {
    Kind.FRAPPE: {"startup": 9, "active": 6, "recovery": 15, "damage": 8, "reach": 1600},
    Kind.ESTOC: {"startup": 27, "active": 6, "recovery": 27, "damage": 14, "reach": 2000},
    Kind.PARADE: {"startup": 3, "active": 21, "recovery": 18, "damage": 0, "reach": 0},
    Kind.RUNE: {"startup": 18, "active": 6, "recovery": 24, "damage": 20, "reach": 2200},
}

const LABELS := {
    Kind.NONE: "",
    Kind.FRAPPE: "Frappe",
    Kind.ESTOC: "Estoc",
    Kind.PARADE: "Parade",
    Kind.RUNE: "Rune",
}


static func is_attack(kind: int) -> bool:
    return kind == Kind.FRAPPE or kind == Kind.ESTOC or kind == Kind.RUNE


## Une valeur de la table DATA, par exemple stat(Kind.ESTOC, "reach").
static func stat(kind: int, key: String) -> int:
    return DATA[kind][key]
