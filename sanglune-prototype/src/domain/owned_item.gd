class_name OwnedItem
extends RefCounted
## Une pièce que le joueur possède : un modèle du catalogue, une rareté et un niveau.
## Son identifiant (uid) la distingue d'une autre pièce du même modèle.

var uid: int
var def: ItemDef
var rarity: int
var level: int


func _init(p_uid: int, p_def: ItemDef, p_rarity: int = Rarity.Tier.CROISSANT, p_level: int = PowerBudget.MIN_LEVEL) -> void:
    uid = p_uid
    def = p_def
    rarity = p_rarity
    level = p_level


## Caractéristique -> pour mille.
func modifiers() -> Dictionary:
    return PowerBudget.modifiers(def, rarity, level)


## Le trait de la pièce, éveillé seulement en Pleine lune.
func gear_trait() -> int:
    return def.gear_trait if rarity == Rarity.Tier.PLEINE_LUNE else GearTrait.Trait.NONE


func net_milli_points() -> int:
    return PowerBudget.net_milli_points(def, rarity, level)


func to_dict() -> Dictionary:
    return {"uid": uid, "id": String(def.id), "rarity": rarity, "level": level}


## Relit une pièce sauvegardée. Renvoie null si quoi que ce soit est invalide : modèle inconnu,
## rareté ou niveau hors bornes, identifiant absent.
static func from_dict(data: Variant) -> OwnedItem:
    if not data is Dictionary:
        return null
    var def := ItemCatalog.by_id(data.get("id"))
    var uid: Variant = whole_number(data.get("uid"))
    var rarity: Variant = whole_number(data.get("rarity"))
    var level: Variant = whole_number(data.get("level"))
    if def == null or not uid is int or uid <= 0:
        return null
    if not Rarity.is_valid(rarity) or not PowerBudget.is_valid_level(level):
        return null
    return OwnedItem.new(uid, def, rarity, level)


## Le JSON relit tous les nombres en flottants : on n'accepte qu'un nombre entier.
static func whole_number(value: Variant) -> Variant:
    if value is int:
        return value
    if value is float and is_finite(value) and value == floorf(value) and absf(value) < 1e9:
        return int(value)
    return null
