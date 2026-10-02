class_name Wardrobe
extends RefCounted
## La garde-robe : les apparences débloquées (une par modèle de pièce qui se voit, gardée même si la pièce
## est recyclée) et, pour chaque chevalier, l'apparence choisie à chaque emplacement.
## Par défaut, un chevalier montre les pièces qu'il porte ; on peut garder un look préféré par-dessus une pièce plus forte.

const FOLLOW := &"" ## montrer la pièce portée
const NOTHING := &"none" ## ne rien montrer (impossible pour l'arme)

var _unlocked := {} ## identifiant de modèle -> true
var _choices := {} ## chevalier -> {emplacement: FOLLOW, NOTHING ou identifiant de modèle}


## Une pièce gagnée débloque son apparence, si elle en a une.
func unlock(def: ItemDef) -> void:
    if def != null and def.look_name != "":
        _unlocked[def.id] = true


func is_unlocked(def_id: StringName) -> bool:
    return _unlocked.has(def_id)


## Les apparences possibles pour ce chevalier à cet emplacement, débloquées ou non, dans l'ordre du catalogue.
func looks_for(knight_id: StringName, slot: int) -> Array[ItemDef]:
    var result: Array[ItemDef] = []
    for def in ItemCatalog.all():
        if def.slot == slot and def.look_name != "" and def.fits(knight_id):
            result.append(def)
    return result


func choice(knight_id: StringName, slot: int) -> StringName:
    return _choices.get(knight_id, {}).get(slot, FOLLOW)


## Choisit l'apparence d'un emplacement. Refusé pour une apparence verrouillée, d'un autre emplacement ou d'un autre
## chevalier, ou pour « rien » sur l'arme. Renvoie true si le choix a changé.
func choose(knight_id: StringName, slot: int, value: StringName) -> bool:
    if KnightClass.by_id(knight_id) == null or not slot in ItemDef.SLOTS or not _allowed(knight_id, slot, value):
        return false
    if choice(knight_id, slot) == value:
        return false
    if not _choices.has(knight_id):
        _choices[knight_id] = {}
    if value == FOLLOW:
        _choices[knight_id].erase(slot)
    else:
        _choices[knight_id][slot] = value
    return true


func to_dict() -> Dictionary:
    var unlocked := []
    for def_id: StringName in _unlocked:
        unlocked.append(String(def_id))
    var choices := {}
    for knight_id: StringName in _choices:
        var slots := {}
        for slot: int in _choices[knight_id]:
            slots[ItemDef.SLOT_KEYS[slot]] = String(_choices[knight_id][slot])
        if not slots.is_empty():
            choices[String(knight_id)] = slots
    return {"unlocked": unlocked, "choices": choices}


## Relit une garde-robe sauvegardée ; tout ce qui est inconnu ou interdit est écarté.
func restore(data: Variant) -> void:
    if not data is Dictionary:
        return
    var unlocked: Variant = data.get("unlocked")
    if unlocked is Array:
        for def_id: Variant in unlocked:
            unlock(ItemCatalog.by_id(def_id))
    var choices: Variant = data.get("choices")
    if not choices is Dictionary:
        return
    for knight_key: Variant in choices:
        if not knight_key is String or not choices[knight_key] is Dictionary:
            continue
        for slot_key: Variant in choices[knight_key]:
            var value: Variant = choices[knight_key][slot_key]
            if value is String:
                choose(StringName(knight_key), ItemDef.slot_from_key(slot_key), StringName(value))


func _allowed(knight_id: StringName, slot: int, value: StringName) -> bool:
    if value == FOLLOW:
        return true
    if value == NOTHING:
        return slot != ItemDef.Slot.WEAPON
    var def := ItemCatalog.by_id(value)
    return def != null and def.slot == slot and def.fits(knight_id) and def.look_name != "" and is_unlocked(def.id)
