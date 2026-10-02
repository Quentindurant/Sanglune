class_name Loadout
extends RefCounted
## Ce que porte un chevalier, emplacement par emplacement. Sans arme posée, il tient son arme de départ.

var knight_id: StringName
var _pieces := {} ## emplacement -> OwnedItem


func _init(p_knight_id: StringName) -> void:
    knight_id = p_knight_id


## Pose une pièce à son emplacement. Refusée si ce chevalier ne peut pas la porter.
func wear(item: OwnedItem) -> bool:
    if item == null or not item.def.fits(knight_id):
        return false
    _pieces[item.def.slot] = item
    return true


func piece(slot: int) -> OwnedItem:
    return _pieces.get(slot)


func pieces() -> Array[OwnedItem]:
    var result: Array[OwnedItem] = []
    for slot in ItemDef.SLOTS:
        if _pieces.has(slot):
            result.append(_pieces[slot])
    return result


## La somme des effets de toutes les pièces portées : caractéristique -> pour mille.
func modifiers() -> Dictionary:
    var total := {}
    for item in pieces():
        var mods := item.modifiers()
        for stat: int in mods:
            total[stat] = total.get(stat, 0) + mods[stat]
    return total


## Les traits éveillés par les pièces Pleine lune portées, sans doublon.
func traits() -> Array[int]:
    var result: Array[int] = []
    for item in pieces():
        var gear_trait := item.gear_trait()
        if gear_trait != GearTrait.Trait.NONE and not gear_trait in result:
            result.append(gear_trait)
    return result


## L'ultime vient de l'arme.
func ultimate_id() -> StringName:
    var weapon := piece(ItemDef.Slot.WEAPON)
    if weapon != null and weapon.def.ultimate_id != &"":
        return weapon.def.ultimate_id
    var starter := ItemCatalog.starter_weapon(knight_id)
    return starter.ultimate_id if starter != null else &""


## Les pièces de silhouette de tout ce qui est porté (voir KnightBuild.dressed).
func look() -> Dictionary:
    var result := {}
    for item in pieces():
        result.merge(item.def.look, true)
    return result


func power() -> int:
    var total := 0
    for item in pieces():
        total += item.net_milli_points()
    return PowerBudget.power(total)
