class_name PlayerProfile
extends RefCounted
## Ce que le jeu retient du joueur, sur son téléphone uniquement : son chevalier actif, ses pièces d'équipement,
## ce que porte chaque chevalier, ses éclats, son palier sur le Chemin des ombres, sa garde-robe, la Chasse en cours
## et ses records de Chasse. Aucune donnée personnelle.
## Les valeurs relues sont toujours revalidées : le fichier peut avoir été modifié.

signal changed ## émis à chaque modification, pour que la sauvegarde suive sans qu'on y pense
signal equipment_changed(knight_id: StringName) ## un chevalier a changé de pièce
signal item_added(item: OwnedItem) ## une pièce rejoint l'inventaire
signal item_upgraded(item: OwnedItem) ## une pièce gagne un niveau
signal item_recycled(item: OwnedItem) ## une pièce changée en éclats
signal appearance_changed(knight_id: StringName) ## un chevalier a changé d'apparence
signal palier_cleared(palier: int) ## une ombre vaincue : on monte d'un palier
signal hunt_closed(difficulty: int, duels_won: int) ## une Chasse se termine

const VERSION := 2
const MAX_ITEMS := 500 ## au-delà, une pièce relue ou gagnée en trop est ignorée
const MAX_SHARDS := 999999
const MAX_PALIER := 9999

var knight_id: StringName = KnightClass.VEILLEUR
var items: Array[OwnedItem] = []
var shards := 0 ## les éclats, pour améliorer les pièces
var palier := 1 ## le palier du Chemin des ombres à disputer
var pity := 0 ## reliquaires ouverts depuis la dernière Gibbeuse (voir LootTable)
var full_moon_pity := 0 ## reliquaires ouverts depuis la dernière Pleine lune
var wardrobe := Wardrobe.new()
var hunt: Hunt ## la Chasse en cours, ou null
var hunt_records := {} ## HuntDifficulty.Level -> meilleur nombre de duels gagnés en une Chasse
var bestiary: Array[StringName] = [] ## les seigneurs de la Chasse déjà vaincus (Boss)
var recent_bosses: Array[StringName] = [] ## les seigneurs des dernières Chasses, le plus récent à la fin
var _next_uid := 1
var _equipped := {} ## chevalier -> {emplacement: uid}


## Un nouveau joueur : l'arme de départ de chaque chevalier, et quelques pièces offertes pour essayer les compromis.
func _init() -> void:
    _ensure_starter_weapons()
    for item_id: StringName in ItemCatalog.WELCOME_GIFTS:
        _add(ItemCatalog.by_id(item_id), ItemCatalog.WELCOME_GIFTS[item_id], PowerBudget.MIN_LEVEL)


func knight() -> KnightClass:
    return KnightClass.by_id(knight_id)


## Change de chevalier actif. Un identifiant inconnu est refusé.
func select_knight(new_id: StringName) -> bool:
    if KnightClass.by_id(new_id) == null:
        return false
    if new_id != knight_id:
        knight_id = new_id
        changed.emit()
    return true


func item(uid: int) -> OwnedItem:
    for owned in items:
        if owned.uid == uid:
            return owned
    return null


## Les pièces que ce chevalier peut porter à cet emplacement, les plus puissantes d'abord.
func items_for(p_knight_id: StringName, slot: int) -> Array[OwnedItem]:
    var result: Array[OwnedItem] = []
    for owned in items:
        if owned.def.slot == slot and owned.def.fits(p_knight_id):
            result.append(owned)
    result.sort_custom(_stronger_first)
    return result


## La pièce portée à cet emplacement, ou null. Un chevalier tient toujours une arme : la sienne de départ par défaut.
func equipped(p_knight_id: StringName, slot: int) -> OwnedItem:
    var worn: OwnedItem = item(_equipped.get(p_knight_id, {}).get(slot, 0))
    if worn == null and slot == ItemDef.Slot.WEAPON:
        return _starter_weapon_of(p_knight_id)
    return worn


## Pose une pièce possédée sur un chevalier. Refusé si la pièce n'existe pas ou ne lui va pas.
func equip(p_knight_id: StringName, uid: int) -> bool:
    var owned := item(uid)
    if KnightClass.by_id(p_knight_id) == null or owned == null or not owned.def.fits(p_knight_id):
        return false
    if equipped(p_knight_id, owned.def.slot) == owned:
        return true
    _set_equipped(p_knight_id, owned.def.slot, uid)
    _announce_equipment(p_knight_id)
    return true


## Retire la pièce d'un emplacement. L'arme ne se retire pas : on en change.
func unequip(p_knight_id: StringName, slot: int) -> bool:
    if slot == ItemDef.Slot.WEAPON or not _equipped.get(p_knight_id, {}).has(slot):
        return false
    _equipped[p_knight_id].erase(slot)
    _announce_equipment(p_knight_id)
    return true


## La silhouette du chevalier : à chaque emplacement, l'apparence choisie dans la garde-robe, sinon la pièce portée.
## trying : une pièce qu'on essaie ; son emplacement la montre, quoi qu'ait choisi la garde-robe.
func look(p_knight_id: StringName, trying: OwnedItem = null) -> Dictionary:
    var result := {}
    for slot in ItemDef.SLOTS:
        var source: ItemDef = null
        var chosen := wardrobe.choice(p_knight_id, slot)
        if trying != null and trying.def.slot == slot:
            source = trying.def
        elif chosen == Wardrobe.NOTHING:
            continue
        elif chosen != Wardrobe.FOLLOW:
            source = ItemCatalog.by_id(chosen)
        else:
            var worn := equipped(p_knight_id, slot)
            source = worn.def if worn != null else null
        if source != null:
            result.merge(source.look, true)
    return result


## Choisit l'apparence d'un emplacement (Wardrobe.FOLLOW, Wardrobe.NOTHING ou un modèle débloqué).
func set_appearance(p_knight_id: StringName, slot: int, value: StringName) -> bool:
    if not wardrobe.choose(p_knight_id, slot, value):
        return false
    appearance_changed.emit(p_knight_id)
    changed.emit()
    return true


## Tout ce que porte ce chevalier, prêt pour le duel.
func loadout(p_knight_id: StringName) -> Loadout:
    var result := Loadout.new(p_knight_id)
    for slot in ItemDef.SLOTS:
        var worn := equipped(p_knight_id, slot)
        if worn != null:
            result.wear(worn)
    return result


## Ajoute une pièce gagnée. Renvoie la pièce, ou null si le modèle est inconnu, le rang invalide ou l'inventaire plein.
func add_item(item_id: StringName, rarity: int, level: int = PowerBudget.MIN_LEVEL) -> OwnedItem:
    var def := ItemCatalog.by_id(item_id)
    if def == null or not Rarity.is_valid(rarity) or not PowerBudget.is_valid_level(level) or items.size() >= MAX_ITEMS:
        return null
    var owned := _add(def, rarity, level)
    item_added.emit(owned)
    changed.emit()
    return owned


## Une pièce de ce modèle, au moins aussi rare, est-elle déjà là ?
func owns_at_least(item_id: StringName, rarity: int) -> bool:
    for owned in items:
        if owned.def.id == item_id and owned.rarity >= rarity:
            return true
    return false


func add_shards(amount: int) -> void:
    if amount <= 0:
        return
    shards = mini(MAX_SHARDS, shards + amount)
    changed.emit()


## Une ombre vaincue : le palier suivant attend.
func clear_palier() -> void:
    var cleared := palier
    palier = mini(MAX_PALIER, palier + 1)
    palier_cleared.emit(cleared)
    changed.emit()


## Une nuit de Chasse est ouverte d'office, ou une fois finie celle qu'elle demande.
func hunt_unlocked(difficulty: int) -> bool:
    if not HuntDifficulty.is_valid(difficulty):
        return false
    var needed := HuntDifficulty.requirement(difficulty)
    return needed < 0 or hunt_record(needed) >= Hunt.LENGTH


func hunt_record(difficulty: int) -> int:
    return hunt_records.get(difficulty, 0)


## Part en Chasse avec le chevalier actif. Refusé si une Chasse est déjà en cours ou si la nuit est fermée.
func start_hunt(difficulty: int, seed_value: int) -> Hunt:
    if hunt != null or not hunt_unlocked(difficulty):
        return null
    var started := Hunt.new(difficulty, seed_value, knight_id)
    started.pick_bosses(recent_bosses, bestiary)
    for id in started.bosses:
        recent_bosses.erase(id)
        recent_bosses.append(id)
    while recent_bosses.size() > Boss.RECENT_MEMORY:
        recent_bosses.pop_front()
    _set_hunt(started)
    changed.emit()
    return hunt


## Un seigneur vaincu entre au bestiaire. Renvoie true la première fois.
func defeat_boss(id: StringName) -> bool:
    if not Boss.is_valid(id) or id in bestiary:
        return false
    bestiary.append(id)
    changed.emit()
    return true


## Une Chasse se termine (Hunt.conclude) : on retient le record et on l'oublie.
func close_hunt(difficulty: int, duels_won: int) -> void:
    if HuntDifficulty.is_valid(difficulty):
        hunt_records[difficulty] = maxi(hunt_record(difficulty), clampi(duels_won, 0, Hunt.LENGTH))
    _set_hunt(null)
    hunt_closed.emit(difficulty, duels_won)
    changed.emit()


func set_pity(value: int) -> void:
    pity = clampi(value, 0, LootTable.PITY_LIMIT - 1)


func set_full_moon_pity(value: int) -> void:
    full_moon_pity = clampi(value, 0, LootTable.FULL_MOON_PITY_LIMIT - 1)


## Une pièce peut monter de niveau si elle n'est pas une arme de départ et pas déjà au plus haut.
func can_upgrade(uid: int) -> bool:
    var owned := item(uid)
    return owned != null and not owned.def.starter and owned.level < PowerBudget.MAX_LEVEL \
        and shards >= PowerBudget.upgrade_cost(owned.level)


## Fait monter une pièce d'un niveau, contre des éclats. Refusé s'il en manque.
func upgrade(uid: int) -> bool:
    if not can_upgrade(uid):
        return false
    var owned := item(uid)
    shards -= PowerBudget.upgrade_cost(owned.level)
    owned.level += 1
    item_upgraded.emit(owned)
    changed.emit()
    return true


## La pièce est-elle portée par l'un des chevaliers ?
func is_worn(uid: int) -> bool:
    for worn_by: StringName in _equipped:
        if uid in _equipped[worn_by].values():
            return true
    return false


## Une pièce se recycle si elle n'est ni une arme de départ, ni portée.
func can_recycle(uid: int) -> bool:
    var owned := item(uid)
    return owned != null and not owned.def.starter and not is_worn(uid)


## Change une pièce en éclats. Renvoie les éclats gagnés, 0 si c'est refusé.
func recycle(uid: int) -> int:
    if not can_recycle(uid):
        return 0
    var owned := item(uid)
    var gained := PowerBudget.shard_value(owned.rarity, owned.level)
    items.erase(owned)
    shards = mini(MAX_SHARDS, shards + gained)
    item_recycled.emit(owned)
    changed.emit()
    return gained


func to_dict() -> Dictionary:
    var stored_items := []
    for owned in items:
        stored_items.append(owned.to_dict())
    var stored_equipped := {}
    for worn_by: StringName in _equipped:
        var slots := {}
        for slot: int in _equipped[worn_by]:
            slots[ItemDef.SLOT_KEYS[slot]] = _equipped[worn_by][slot]
        if not slots.is_empty():
            stored_equipped[String(worn_by)] = slots
    return {
        "version": VERSION, "knight": String(knight_id), "next_uid": _next_uid,
        "items": stored_items, "equipped": stored_equipped,
        "shards": shards, "palier": palier, "pity": pity, "full_moon_pity": full_moon_pity,
        "wardrobe": wardrobe.to_dict(), "hunt": hunt.to_dict() if hunt != null else null,
        "hunt_records": _stored_hunt_records(),
        "bestiary": bestiary.map(func(id: StringName) -> String: return String(id)),
        "recent_bosses": recent_bosses.map(func(id: StringName) -> String: return String(id)),
    }


## Reconstruit un profil depuis des données relues. Tout ce qui est absent ou invalide est écarté.
## Un profil de la version 1 (le chevalier seul) devient un nouveau joueur qui garde son chevalier.
static func from_dict(data: Dictionary) -> PlayerProfile:
    var profile := PlayerProfile.new()
    var stored: Variant = data.get("knight")
    if (stored is String or stored is StringName) and KnightClass.by_id(StringName(stored)) != null:
        profile.knight_id = StringName(stored)
    var version: Variant = OwnedItem.whole_number(data.get("version"))
    if version is int and version >= 2 and data.get("items") is Array:
        profile._restore_items(data["items"], data.get("next_uid"))
        profile._restore_equipped(data.get("equipped"))
        profile.wardrobe.restore(data.get("wardrobe"))
    profile.shards = _bounded(data.get("shards"), 0, MAX_SHARDS, 0)
    profile.palier = _bounded(data.get("palier"), 1, MAX_PALIER, 1)
    profile.pity = _bounded(data.get("pity"), 0, LootTable.PITY_LIMIT - 1, 0)
    profile.full_moon_pity = _bounded(data.get("full_moon_pity"), 0, LootTable.FULL_MOON_PITY_LIMIT - 1, 0)
    profile._restore_hunt_records(data.get("hunt_records"))
    profile.bestiary = _boss_list(data.get("bestiary"), Boss.ids().size())
    profile.recent_bosses = _boss_list(data.get("recent_bosses"), Boss.RECENT_MEMORY)
    profile._set_hunt(Hunt.from_dict(data.get("hunt")))
    return profile


## Un entier relu, ramené dans ses bornes ; la valeur par défaut s'il n'en est pas un.
static func _bounded(value: Variant, low: int, high: int, fallback: int) -> int:
    var whole: Variant = OwnedItem.whole_number(value)
    return clampi(whole, low, high) if whole is int else fallback


## Une liste de seigneurs relue : seulement des seigneurs connus, sans doublon, au plus limit.
static func _boss_list(stored: Variant, limit: int) -> Array[StringName]:
    var result: Array[StringName] = []
    if not stored is Array:
        return result
    for entry: Variant in stored:
        if result.size() >= limit:
            break
        if Boss.is_valid(entry) and not StringName(entry) in result:
            result.append(StringName(entry))
    return result


func _stored_hunt_records() -> Dictionary:
    var stored := {}
    for level: int in hunt_records:
        stored[HuntDifficulty.key(level)] = hunt_records[level]
    return stored


func _restore_hunt_records(stored: Variant) -> void:
    if not stored is Dictionary:
        return
    for stored_key: Variant in stored:
        var level := HuntDifficulty.from_key(stored_key)
        var best: Variant = OwnedItem.whole_number(stored[stored_key])
        if level >= 0 and best is int:
            hunt_records[level] = clampi(best, 0, Hunt.LENGTH)


## La Chasse suivie : chacune de ses étapes est sauvegardée aussitôt.
func _set_hunt(value: Hunt) -> void:
    if hunt != null and hunt.changed.is_connected(changed.emit):
        hunt.changed.disconnect(changed.emit)
    hunt = value
    if hunt != null:
        hunt.changed.connect(changed.emit)


func _restore_items(stored_items: Array, stored_next_uid: Variant) -> void:
    items.clear()
    _equipped.clear()
    wardrobe = Wardrobe.new()
    var highest := 0
    for entry: Variant in stored_items:
        if items.size() >= MAX_ITEMS:
            break
        var owned := OwnedItem.from_dict(entry)
        if owned == null or item(owned.uid) != null:
            continue
        items.append(owned)
        wardrobe.unlock(owned.def)
        highest = maxi(highest, owned.uid)
    var next: Variant = OwnedItem.whole_number(stored_next_uid)
    _next_uid = maxi(highest + 1, next if next is int else 1)
    _ensure_starter_weapons()


func _restore_equipped(stored: Variant) -> void:
    if not stored is Dictionary:
        return
    for knight_key: Variant in stored:
        var knight_class := KnightClass.by_id(StringName(knight_key)) if knight_key is String else null
        if knight_class == null or not stored[knight_key] is Dictionary:
            continue
        for slot_key: Variant in stored[knight_key]:
            var slot := ItemDef.slot_from_key(slot_key)
            var uid: Variant = OwnedItem.whole_number(stored[knight_key][slot_key])
            var owned := item(uid) if uid is int else null
            if slot >= 0 and owned != null and owned.def.slot == slot and owned.def.fits(knight_class.id):
                _set_equipped(knight_class.id, slot, owned.uid)


func _ensure_starter_weapons() -> void:
    for knight_class in KnightClass.all():
        if _starter_weapon_of(knight_class.id) == null:
            _add(ItemCatalog.starter_weapon(knight_class.id), Rarity.Tier.CROISSANT, PowerBudget.MIN_LEVEL)


func _starter_weapon_of(p_knight_id: StringName) -> OwnedItem:
    var starter: StringName = ItemCatalog.STARTER_WEAPONS.get(p_knight_id, &"")
    for owned in items:
        if owned.def.id == starter:
            return owned
    return null


func _add(def: ItemDef, rarity: int, level: int) -> OwnedItem:
    var owned := OwnedItem.new(_next_uid, def, rarity, level)
    _next_uid += 1
    items.append(owned)
    wardrobe.unlock(def)
    return owned


func _set_equipped(p_knight_id: StringName, slot: int, uid: int) -> void:
    if not _equipped.has(p_knight_id):
        _equipped[p_knight_id] = {}
    _equipped[p_knight_id][slot] = uid


func _announce_equipment(p_knight_id: StringName) -> void:
    equipment_changed.emit(p_knight_id)
    changed.emit()


static func _stronger_first(a: OwnedItem, b: OwnedItem) -> bool:
    if a.net_milli_points() != b.net_milli_points():
        return a.net_milli_points() > b.net_milli_points()
    if a.def.display_name != b.def.display_name:
        return a.def.display_name < b.def.display_name
    return a.uid < b.uid
