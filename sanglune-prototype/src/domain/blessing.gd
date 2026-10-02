class_name Blessing
extends RefCounted
## Les bénédictions de la Chasse : des renforts qui ne durent que la Chasse en cours.
## Les unes renforcent une caractéristique et se cumulent jusqu'à MAX_STACK fois ; les autres prêtent un trait
## des pièces Pleine lune (GearTrait), une seule fois.
## Bien plus fortes qu'une pièce d'équipement : c'est le plaisir de la Chasse, et les ombres montent en face.

const MAX_STACK := 3
const STAT_WEIGHT := 3 ## une bénédiction de caractéristique sort trois fois plus souvent qu'un trait
const TRAIT_WEIGHT := 1

const CATALOG := {
    &"sang_vif": {"name": "Sang vif", "mods": {GearStat.Stat.HP: 100}},
    &"lame_affutee": {"name": "Lame affûtée", "mods": {GearStat.Stat.POWER: 80}},
    &"bras_long": {"name": "Bras long", "mods": {GearStat.Stat.REACH: 70}},
    &"pas_de_loup": {"name": "Pas de loup", "mods": {GearStat.Stat.WALK: 100, GearStat.Stat.DODGE: 100}},
    &"peau_de_pierre": {"name": "Peau de pierre", "mods": {GearStat.Stat.STUN_RESIST: 200}},
    &"coeur_de_lune": {"name": "Cœur de lune", "mods": {GearStat.Stat.ULT_POWER: 200}},
    &"riposte": {"trait": GearTrait.Trait.RIPOSTE},
    &"garde_lunaire": {"trait": GearTrait.Trait.GARDE_LUNAIRE},
    &"chute_lourde": {"trait": GearTrait.Trait.CHUTE_LOURDE},
    &"aube_rouge": {"trait": GearTrait.Trait.AUBE_ROUGE},
    &"dernier_souffle": {"trait": GearTrait.Trait.DERNIER_SOUFFLE},
    &"echo": {"trait": GearTrait.Trait.ECHO},
}


static func is_valid(id: Variant) -> bool:
    return (id is StringName or id is String) and CATALOG.has(StringName(id))


static func ids() -> Array[StringName]:
    var result: Array[StringName] = []
    for id: StringName in CATALOG:
        result.append(id)
    return result


static func is_trait(id: StringName) -> bool:
    return CATALOG.get(id, {}).has("trait")


static func gear_trait(id: StringName) -> int:
    return CATALOG.get(id, {}).get("trait", GearTrait.Trait.NONE)


static func display_name(id: StringName) -> String:
    if is_trait(id):
        return GearTrait.display_name(gear_trait(id))
    return CATALOG.get(id, {}).get("name", "")


## Caractéristique -> pour mille, pour une seule fois cette bénédiction.
static func mods(id: StringName) -> Dictionary:
    return CATALOG.get(id, {}).get("mods", {})


## Combien de fois on peut la prendre en une Chasse.
static func max_stack(id: StringName) -> int:
    return 1 if is_trait(id) else MAX_STACK


static func weight(id: StringName) -> int:
    return TRAIT_WEIGHT if is_trait(id) else STAT_WEIGHT


## Ce que donne une liste de bénédictions (une même bénédiction peut y figurer plusieurs fois).
static func bonus_of(taken: Array[StringName], into: StatBonus = null) -> StatBonus:
    var bonus := into if into != null else StatBonus.new()
    for id in taken:
        if is_trait(id):
            bonus.add_trait(gear_trait(id))
            continue
        var effect := mods(id)
        for stat: int in effect:
            bonus.add_mod(stat, effect[stat])
    return bonus
