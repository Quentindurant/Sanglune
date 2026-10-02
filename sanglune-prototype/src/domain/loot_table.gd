class_name LootTable
extends RefCounted
## Ce que contient un reliquaire : d'abord la rareté, puis l'emplacement, puis la pièce.
## Deux garanties évitent les longues séries de malchance : une Gibbeuse au plus tard au PITY_LIMIT-ième reliquaire,
## une Pleine lune au plus tard au FULL_MOON_PITY_LIMIT-ième.

const RARITY_WEIGHTS := [60, 28, 10, 2] ## sur 100
const PITY_LIMIT := 10
const FULL_MOON_PITY_LIMIT := 40


## La rareté du prochain reliquaire. pity : reliquaires ouverts depuis la dernière Gibbeuse (ou mieux) ;
## full_moon_pity : depuis la dernière Pleine lune. minimum : rareté plancher (un gardien donne au moins une Gibbeuse).
static func roll_rarity(rng: RandomSource, pity: int, minimum: int = Rarity.Tier.CROISSANT, full_moon_pity: int = 0) -> int:
    if full_moon_pity >= FULL_MOON_PITY_LIMIT - 1:
        return Rarity.Tier.PLEINE_LUNE
    if pity >= PITY_LIMIT - 1:
        minimum = maxi(Rarity.Tier.GIBBEUSE, minimum)
    var total := 0
    for weight: int in RARITY_WEIGHTS:
        total += weight
    var roll := rng.below(total)
    var rarity := Rarity.Tier.CROISSANT
    for tier in RARITY_WEIGHTS.size():
        if roll < RARITY_WEIGHTS[tier]:
            rarity = tier
            break
        roll -= RARITY_WEIGHTS[tier]
    return maxi(rarity, minimum)


## Une pièce pour ce chevalier : chaque emplacement a autant de chances, puis chaque pièce de l'emplacement.
## Jamais d'arme de départ, jamais l'arme d'un autre chevalier.
static func roll_piece(rng: RandomSource, knight_id: StringName) -> ItemDef:
    var slot: int = ItemDef.SLOTS[rng.below(ItemDef.SLOTS.size())]
    var choices := droppable(knight_id, slot)
    if choices.is_empty():
        choices = droppable(knight_id, ItemDef.Slot.HELM)
    return choices[rng.below(choices.size())]


static func droppable(knight_id: StringName, slot: int) -> Array[ItemDef]:
    var result: Array[ItemDef] = []
    for def in ItemCatalog.all():
        if not def.starter and def.slot == slot and def.fits(knight_id):
            result.append(def)
    return result
