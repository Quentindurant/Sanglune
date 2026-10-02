class_name GearTrait
extends RefCounted
## Les traits des pièces Pleine lune : un effet qui change la façon de jouer, en plus des gains.
## Chaque modèle de pièce a son trait (ItemCatalog) ; seule sa version Pleine lune l'éveille.
## Deux pièces au même trait ne le doublent pas.

enum Trait { NONE, RIPOSTE, GARDE_LUNAIRE, CHUTE_LOURDE, AUBE_ROUGE, DERNIER_SOUFFLE, ECHO }

const NAMES := {
    Trait.RIPOSTE: "Riposte",
    Trait.GARDE_LUNAIRE: "Garde lunaire",
    Trait.CHUTE_LOURDE: "Chute lourde",
    Trait.AUBE_ROUGE: "Aube rouge",
    Trait.DERNIER_SOUFFLE: "Dernier souffle",
    Trait.ECHO: "Écho",
}

const DESCRIPTIONS := {
    Trait.RIPOSTE: "après une esquive, ta Frappe part plus vite",
    Trait.GARDE_LUNAIRE: "une parade réussie allume une rune",
    Trait.CHUTE_LOURDE: "un plongeon qui touche étourdit plus longtemps",
    Trait.AUBE_ROUGE: "chaque manche commence avec une rune",
    Trait.DERNIER_SOUFFLE: "sous un quart de ta vie, tes coups font plus mal",
    Trait.ECHO: "un ultime qui touche rend une rune",
}

const RIPOSTE_WINDOW := 40 ## frames après l'élan de l'esquive pendant lesquelles la Frappe est plus vive
const RIPOSTE_FRAMES := 3 ## frames de préparation en moins
const CHUTE_LOURDE_FRAMES := 12 ## frames d'étourdissement en plus
const DERNIER_SOUFFLE_SHARE := 4 ## le trait s'éveille sous 1/4 de la vie
const DERNIER_SOUFFLE_BONUS := 200 ## pour mille de dégâts en plus


static func is_valid(value: Variant) -> bool:
    return value is int and NAMES.has(value)


static func display_name(value: int) -> String:
    return NAMES.get(value, "")


static func describe(value: int) -> String:
    return DESCRIPTIONS.get(value, "")
