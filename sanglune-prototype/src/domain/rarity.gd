class_name Rarity
extends RefCounted
## La rareté d'une pièce, en phases de lune. Plus la lune est pleine, plus la pièce a de gains et plus ils sont forts.
## Toute pièce garde une perte, même la plus rare : c'est un compromis, jamais un simple bonus.

enum Tier { CROISSANT, QUARTIER, GIBBEUSE, PLEINE_LUNE }

const NAMES := ["Croissant", "Quartier", "Gibbeuse", "Pleine lune"]
const GAIN_COUNT := [1, 2, 2, 2] ## nombre de caractéristiques renforcées
const GAIN_TENTHS := [65, 70, 75, 75] ## budget des gains au niveau 1, en dixièmes de point ; la Pleine lune ajoutera un trait
const LOSS_TENTHS := 50 ## la perte, identique à toute rareté et à tout niveau


static func is_valid(tier: Variant) -> bool:
    return tier is int and tier >= Tier.CROISSANT and tier <= Tier.PLEINE_LUNE


static func display_name(tier: int) -> String:
    return NAMES[tier]
