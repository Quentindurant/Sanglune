class_name ItemDef
extends RefCounted
## Le modèle d'une pièce d'équipement, tel que décrit dans ItemCatalog : son nom, son emplacement,
## ce qu'elle renforce et ce qu'elle affaiblit, et son apparence. La rareté et le niveau viennent de la pièce possédée.

enum Slot { WEAPON, HELM, ARMOR, TALISMAN }

const SLOTS: Array[int] = [Slot.WEAPON, Slot.HELM, Slot.ARMOR, Slot.TALISMAN]
const SLOT_NAMES := {Slot.WEAPON: "Arme", Slot.HELM: "Heaume", Slot.ARMOR: "Armure", Slot.TALISMAN: "Talisman"}
const SLOT_KEYS := {Slot.WEAPON: "weapon", Slot.HELM: "helm", Slot.ARMOR: "armor", Slot.TALISMAN: "talisman"}

var id: StringName
var display_name: String
var slot: int
var knight_id: StringName ## vide : n'importe quel chevalier peut la porter ; une arme appartient toujours à un chevalier
var gains: Array[int] = [] ## dans l'ordre : une pièce Croissant n'a que le premier gain
var losses: Array[int] = []
var ultimate_id: StringName ## pour une arme : l'ultime qu'elle donne
var look: Dictionary ## pièces de silhouette ajoutées au pantin (voir KnightBuild.dressed)
var starter: bool ## l'arme de départ d'un chevalier : neutre, toujours possédée
var gear_trait: int ## le trait éveillé par la version Pleine lune (GearTrait)
var look_name: String ## nom court de l'apparence dans la garde-robe ; vide si la pièce ne se voit pas


func _init(p_id: StringName, data: Dictionary) -> void:
    id = p_id
    display_name = data["name"]
    slot = data["slot"]
    knight_id = data.get("knight", &"")
    gains.assign(data.get("gains", []))
    losses.assign(data.get("losses", []))
    ultimate_id = data.get("ultimate", &"")
    look = data.get("look", {})
    starter = data.get("starter", false)
    gear_trait = data.get("trait", GearTrait.Trait.NONE)
    look_name = data.get("look_name", "")


## Ce chevalier peut-il porter cette pièce ?
func fits(p_knight_id: StringName) -> bool:
    return knight_id == &"" or knight_id == p_knight_id


func is_weapon() -> bool:
    return slot == Slot.WEAPON


static func slot_from_key(key: Variant) -> int:
    for slot_id: int in SLOT_KEYS:
        if SLOT_KEYS[slot_id] == key:
            return slot_id
    return -1
