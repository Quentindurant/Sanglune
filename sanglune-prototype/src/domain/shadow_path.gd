class_name ShadowPath
extends RefCounted
## Le Chemin des ombres : une suite de paliers contre l'IA. Chaque palier a toujours la même ombre
## (même chevalier, même équipement), pour qu'on puisse la retenter et l'apprendre.
## Plus on monte, plus l'ombre est vive et équipée ; tous les cinq paliers, un gardien plus fort encore.

const GUARDIAN_EVERY := 5
const MAX_PIECES := 4
const SEED_STEP := 7919 ## un grand nombre premier : deux paliers voisins ont des tirages sans rapport
## IA : lente et hésitante au premier palier, vive et précise plus haut. Elle gagne une frame de vivacité
## tous les deux paliers : elle rejoint l'ancienne IA du jeu (12 frames, 70 %) vers le palier 20 (tools/path_report.gd).
const FIRST_REACTION := 22
const FASTEST_REACTION := 8
const PALIERS_PER_FRAME := 2
const FIRST_ACCURACY := 0.4
const ACCURACY_STEP := 0.015
const BEST_ACCURACY := 0.85
const GUARDIAN_REACTION_BONUS := 2
const GUARDIAN_ACCURACY_BONUS := 0.06
const GUARDIAN_LEVEL_BONUS := 2
const FULL_MOON_GUARDIAN_PALIER := 20 ## dès ce palier, les gardiens portent des Pleines lunes, et leurs traits


static func is_guardian(palier: int) -> bool:
    return palier > 0 and palier % GUARDIAN_EVERY == 0


static func opponent(palier: int) -> ShadowOpponent:
    var p := maxi(1, palier)
    return build(p, is_guardian(p), p * SEED_STEP)


## Une ombre de la force d'un palier, tirée avec cette graine (la Chasse en tire de nouvelles à chaque partie).
## guardian : la force d'un gardien, quel que soit le palier. knight : un chevalier imposé (les seigneurs de la Chasse).
static func build(palier: int, guardian: bool, seed_value: int, knight: KnightClass = null) -> ShadowOpponent:
    var p := maxi(1, palier)
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_value
    var shadow := ShadowOpponent.new()
    shadow.palier = p
    shadow.guardian = guardian
    shadow.knight = KnightClass.pick_random(rng)
    if knight != null:
        shadow.knight = knight
    shadow.gear = _gear(shadow.knight.id, p, shadow.guardian, rng)
    var reaction := maxi(FASTEST_REACTION, FIRST_REACTION - p / PALIERS_PER_FRAME)
    var accuracy := minf(BEST_ACCURACY, FIRST_ACCURACY + ACCURACY_STEP * p)
    if shadow.guardian:
        reaction = maxi(FASTEST_REACTION - 2, reaction - GUARDIAN_REACTION_BONUS)
        accuracy = minf(0.95, accuracy + GUARDIAN_ACCURACY_BONUS)
    shadow.reaction_frames = reaction
    shadow.accuracy = accuracy
    return shadow


## Combien de pièces, de quelle rareté, de quel niveau : rien aux deux premiers paliers, puis de plus en plus.
static func gear_rank(palier: int, guardian: bool) -> Dictionary:
    var pieces := clampi((palier - 1) / 2, 0, MAX_PIECES)
    var rarity := Rarity.Tier.CROISSANT
    if palier >= 12:
        rarity = Rarity.Tier.GIBBEUSE
    elif palier >= 6:
        rarity = Rarity.Tier.QUARTIER
    var level := clampi(1 + (palier - 9) / 3, PowerBudget.MIN_LEVEL, PowerBudget.MAX_LEVEL)
    if guardian: ## une pièce, un rang et deux niveaux de plus
        pieces = mini(MAX_PIECES, pieces + 1)
        var top := Rarity.Tier.PLEINE_LUNE if palier >= FULL_MOON_GUARDIAN_PALIER else Rarity.Tier.GIBBEUSE
        rarity = mini(top, rarity + 1)
        level = mini(PowerBudget.MAX_LEVEL, level + GUARDIAN_LEVEL_BONUS)
    return {"pieces": pieces, "rarity": rarity, "level": level}


static func _gear(knight_id: StringName, palier: int, guardian: bool, rng: RandomNumberGenerator) -> Loadout:
    var gear := Loadout.new(knight_id)
    var rank := gear_rank(palier, guardian)
    var slots := ItemDef.SLOTS.duplicate()
    for i in range(slots.size() - 1, 0, -1): ## mélange déterministe
        var j := rng.randi_range(0, i)
        var swap: int = slots[i]
        slots[i] = slots[j]
        slots[j] = swap
    for i in rank["pieces"]:
        var choices := LootTable.droppable(knight_id, slots[i])
        if choices.is_empty():
            continue
        var def: ItemDef = choices[rng.randi_range(0, choices.size() - 1)]
        gear.wear(OwnedItem.new(-1 - i, def, rank["rarity"], rank["level"]))
    return gear
