class_name FighterStats
extends RefCounted
## Les caractéristiques d'un chevalier pour un duel : celles de sa classe, ajustées par ce qu'il porte.
## Calculées une seule fois, en entiers : deux téléphones qui reçoivent le même équipement simulent le même combat.
## Sans équipement, elles valent exactement celles de la classe. Un StatBonus (bénédictions et blessures d'une Chasse)
## s'ajoute à l'équipement, dans les mêmes unités ; il ne compte pas dans la puissance affichée.

const ATTACKS: Array[int] = [CombatAction.Kind.FRAPPE, CombatAction.Kind.PLONGEON] ## ce que l'arme renforce

var knight: KnightClass
var max_hp: int
var walk_speed: int
var jump_speed: int
var dodge_speed: int
var stun_resist: int ## pour mille d'étourdissement en moins à chaque coup reçu
var ultimate_id: StringName
var power: int
var traits: Array[int] = [] ## traits des pièces Pleine lune portées (GearTrait)
var rules := {} ## règles d'un seigneur de la Chasse (Boss.Rule -> valeur)
var _frames := {} ## action -> startup, active, recovery, damage, reach


static func resolve(p_knight: KnightClass, loadout: Loadout = null, bonus: StatBonus = null) -> FighterStats:
    var stats := FighterStats.new()
    stats.knight = p_knight
    var mods: Dictionary = loadout.modifiers() if loadout != null else {}
    if bonus != null:
        for stat: int in bonus.mods:
            mods[stat] = mods.get(stat, 0) + bonus.mods[stat]
    stats.max_hp = GearStat.grow(p_knight.max_hp, mods.get(GearStat.Stat.HP, 0))
    stats.walk_speed = GearStat.grow(p_knight.walk_speed, mods.get(GearStat.Stat.WALK, 0))
    stats.jump_speed = p_knight.jump_speed
    stats.dodge_speed = GearStat.grow(p_knight.dodge_speed, mods.get(GearStat.Stat.DODGE, 0))
    stats.stun_resist = mods.get(GearStat.Stat.STUN_RESIST, 0)
    stats.ultimate_id = loadout.ultimate_id() if loadout != null else p_knight.ultimate_id
    stats.power = loadout.power() if loadout != null else PowerBudget.BASE_POWER
    if loadout != null:
        stats.traits = loadout.traits()
    if bonus != null:
        stats.rules = bonus.rules.duplicate()
        for gear_trait in bonus.traits:
            if not gear_trait in stats.traits:
                stats.traits.append(gear_trait)
    for kind: int in CombatAction.DATA:
        var frames := {}
        for key: String in ["startup", "active", "recovery", "damage", "reach"]:
            frames[key] = p_knight.stat(kind, key)
        if kind in ATTACKS:
            frames["damage"] = GearStat.grow(frames["damage"], mods.get(GearStat.Stat.POWER, 0))
            frames["reach"] = GearStat.grow(frames["reach"], mods.get(GearStat.Stat.REACH, 0))
        stats._frames[kind] = frames
    var ultimate := Ultimate.by_id(stats.ultimate_id)
    if ultimate == null:
        stats.ultimate_id = p_knight.ultimate_id
        ultimate = Ultimate.by_id(stats.ultimate_id)
    stats._frames[CombatAction.Kind.ULTIME] = {
        "startup": ultimate.stat("startup"),
        "active": ultimate.stat("active"),
        "recovery": ultimate.stat("recovery"),
        "damage": GearStat.grow(ultimate.stat("damage"), mods.get(GearStat.Stat.ULT_POWER, 0)),
        "reach": ultimate.stat("reach"),
    }
    return stats


## Une donnée de combat, par exemple stat(Kind.FRAPPE, "reach").
func stat(kind: int, key: String) -> int:
    return _frames[kind][key]


## La valeur d'une règle de seigneur, 0 si elle ne joue pas.
func rule(which: int) -> int:
    return rules.get(which, 0)


func has_trait(gear_trait: int) -> bool:
    return gear_trait in traits


## L'étourdissement réellement subi après un coup qui en inflige base_frames.
func stun_frames(base_frames: int) -> int:
    return GearStat.shorten(base_frames, stun_resist)
