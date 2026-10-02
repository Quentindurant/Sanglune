class_name StatBonus
extends RefCounted
## Ce qui renforce un chevalier pour un seul duel, en plus de son équipement : les bénédictions et les blessures
## d'une Chasse, et la règle d'un seigneur (Boss.Rule). Mêmes unités que l'équipement (pour mille par caractéristique,
## traits de GearTrait), pour que FighterStats les additionne sans rien savoir de la Chasse.

var mods := {} ## GearStat.Stat -> pour mille (négatif pour une blessure)
var traits: Array[int] = [] ## GearTrait.Trait, sans doublon
var rules := {} ## Boss.Rule -> valeur


func add_mod(stat: int, permille: int) -> void:
    if not GearStat.is_valid(stat) or permille == 0:
        return
    mods[stat] = mods.get(stat, 0) + permille


func add_trait(gear_trait: int) -> void:
    if GearTrait.is_valid(gear_trait) and not gear_trait in traits:
        traits.append(gear_trait)


func add_rule(which: int, value: int) -> void:
    if value != 0 and which in Boss.Rule.values():
        rules[which] = value


func is_empty() -> bool:
    return mods.is_empty() and traits.is_empty() and rules.is_empty()
