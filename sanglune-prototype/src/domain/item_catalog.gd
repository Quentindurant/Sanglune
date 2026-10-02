class_name ItemCatalog
extends RefCounted
## Toutes les pièces d'équipement du jeu. Une arme appartient à un chevalier et porte son ultime ;
## heaumes, armures et talismans vont à tous. Chaque pièce a un trait, éveillé seulement en Pleine lune,
## et celles qui se voient ont un nom d'apparence pour la garde-robe.
## Les valeurs ne s'écrivent pas ici : elles découlent du budget de la rareté et du niveau (PowerBudget),
## pour que deux pièces de même rang se valent.

const STARTER_WEAPONS := {
    KnightClass.VEILLEUR: &"epee_et_ecu",
    KnightClass.FAUCHEUSE: &"hallebarde",
    KnightClass.RODEUSE: &"deux_dagues",
    KnightClass.COLOSSE: &"masse_d_armes",
}

const DEFINITIONS := {
    # Armes de départ : neutres, chacune porte l'ultime de son chevalier.
    &"epee_et_ecu": {
        "name": "Épée longue et écu", "slot": ItemDef.Slot.WEAPON, "knight": KnightClass.VEILLEUR,
        "look_name": "Épée longue",
        "ultimate": Ultimate.LAME_DE_LUNE, "starter": true, "look": {"weapon": &"sword"},
    },
    &"hallebarde": {
        "name": "Hallebarde", "slot": ItemDef.Slot.WEAPON, "knight": KnightClass.FAUCHEUSE,
        "look_name": "Hallebarde",
        "ultimate": Ultimate.MOISSON, "starter": true, "look": {"weapon": &"halberd"},
    },
    &"deux_dagues": {
        "name": "Deux dagues", "slot": ItemDef.Slot.WEAPON, "knight": KnightClass.RODEUSE,
        "look_name": "Dagues droites",
        "ultimate": Ultimate.DANSE_DES_LAMES, "starter": true, "look": {"weapon": &"dagger"},
    },
    &"masse_d_armes": {
        "name": "Masse d'armes", "slot": ItemDef.Slot.WEAPON, "knight": KnightClass.COLOSSE,
        "look_name": "Masse",
        "ultimate": Ultimate.SEISME, "starter": true, "look": {"weapon": &"mace"},
    },
    # Variantes d'armes : même famille, même ultime, un autre style.
    &"epee_effilee": {
        "name": "Épée effilée", "slot": ItemDef.Slot.WEAPON, "knight": KnightClass.VEILLEUR,
        "trait": GearTrait.Trait.RIPOSTE, "look_name": "Épée effilée",
        "ultimate": Ultimate.LAME_DE_LUNE, "look": {"weapon": &"sword_slim"},
        "gains": [GearStat.Stat.REACH, GearStat.Stat.ULT_POWER], "losses": [GearStat.Stat.POWER],
    },
    &"hallebarde_lourde": {
        "name": "Hallebarde lourde", "slot": ItemDef.Slot.WEAPON, "knight": KnightClass.FAUCHEUSE,
        "trait": GearTrait.Trait.ECHO, "look_name": "Fer large",
        "ultimate": Ultimate.MOISSON, "look": {"weapon": &"halberd_broad"},
        "gains": [GearStat.Stat.POWER, GearStat.Stat.ULT_POWER], "losses": [GearStat.Stat.REACH],
    },
    &"dagues_crochues": {
        "name": "Dagues crochues", "slot": ItemDef.Slot.WEAPON, "knight": KnightClass.RODEUSE,
        "trait": GearTrait.Trait.RIPOSTE, "look_name": "Dagues crochues",
        "ultimate": Ultimate.DANSE_DES_LAMES, "look": {"weapon": &"dagger_hooked"},
        "gains": [GearStat.Stat.REACH, GearStat.Stat.POWER], "losses": [GearStat.Stat.HP],
    },
    &"masse_a_pointes": {
        "name": "Masse à pointes", "slot": ItemDef.Slot.WEAPON, "knight": KnightClass.COLOSSE,
        "trait": GearTrait.Trait.CHUTE_LOURDE, "look_name": "Pointes",
        "ultimate": Ultimate.SEISME, "look": {"weapon": &"mace_spiked"},
        "gains": [GearStat.Stat.POWER, GearStat.Stat.STUN_RESIST], "losses": [GearStat.Stat.WALK],
    },
    # Heaumes : la vie et la résistance au choc.
    &"heaume_a_cimier": {
        "name": "Heaume à cimier", "slot": ItemDef.Slot.HELM, "look": {"crest": &"plume"},
        "trait": GearTrait.Trait.GARDE_LUNAIRE, "look_name": "Cimier",
        "gains": [GearStat.Stat.STUN_RESIST, GearStat.Stat.HP], "losses": [GearStat.Stat.DODGE],
    },
    &"heaume_a_cornes": {
        "name": "Heaume à cornes", "slot": ItemDef.Slot.HELM, "look": {"crest": &"horns"},
        "trait": GearTrait.Trait.CHUTE_LOURDE, "look_name": "Cornes",
        "gains": [GearStat.Stat.STUN_RESIST, GearStat.Stat.POWER], "losses": [GearStat.Stat.HP],
    },
    # Armures : la vie contre la mobilité.
    &"cotte_de_mailles": {
        "name": "Cotte de mailles", "slot": ItemDef.Slot.ARMOR, "look": {"pauldrons": true},
        "trait": GearTrait.Trait.GARDE_LUNAIRE, "look_name": "Épaulières",
        "gains": [GearStat.Stat.HP, GearStat.Stat.STUN_RESIST], "losses": [GearStat.Stat.WALK],
    },
    &"cape_de_rodeur": {
        "name": "Cape de rôdeur", "slot": ItemDef.Slot.ARMOR, "look": {"cape": &"long"},
        "trait": GearTrait.Trait.RIPOSTE, "look_name": "Cape",
        "gains": [GearStat.Stat.DODGE, GearStat.Stat.WALK], "losses": [GearStat.Stat.HP],
    },
    # Talismans : l'ultime.
    &"larme_de_lune": {
        "name": "Larme de lune", "slot": ItemDef.Slot.TALISMAN,
        "trait": GearTrait.Trait.AUBE_ROUGE,
        "gains": [GearStat.Stat.ULT_POWER, GearStat.Stat.STUN_RESIST], "losses": [GearStat.Stat.POWER],
    },
    &"croc_de_sang": {
        "name": "Croc de sang", "slot": ItemDef.Slot.TALISMAN,
        "trait": GearTrait.Trait.DERNIER_SOUFFLE,
        "gains": [GearStat.Stat.POWER, GearStat.Stat.ULT_POWER], "losses": [GearStat.Stat.HP],
    },
}

## Les pièces offertes à un nouveau joueur pour essayer les compromis : id -> rareté.
const WELCOME_GIFTS := {
    &"epee_effilee": Rarity.Tier.QUARTIER,
    &"hallebarde_lourde": Rarity.Tier.QUARTIER,
    &"dagues_crochues": Rarity.Tier.QUARTIER,
    &"masse_a_pointes": Rarity.Tier.QUARTIER,
    &"heaume_a_cimier": Rarity.Tier.CROISSANT,
    &"heaume_a_cornes": Rarity.Tier.QUARTIER,
    &"cotte_de_mailles": Rarity.Tier.QUARTIER,
    &"cape_de_rodeur": Rarity.Tier.GIBBEUSE,
    &"larme_de_lune": Rarity.Tier.CROISSANT,
    &"croc_de_sang": Rarity.Tier.QUARTIER,
}


## Le modèle demandé, ou null si l'identifiant est inconnu (une sauvegarde ne se croit jamais sur parole).
static func by_id(item_id: Variant) -> ItemDef:
    if not (item_id is String or item_id is StringName) or not DEFINITIONS.has(StringName(item_id)):
        return null
    return ItemDef.new(StringName(item_id), DEFINITIONS[StringName(item_id)])


static func all() -> Array[ItemDef]:
    var defs: Array[ItemDef] = []
    for item_id: StringName in DEFINITIONS:
        defs.append(by_id(item_id))
    return defs


static func starter_weapon(knight_id: StringName) -> ItemDef:
    return by_id(STARTER_WEAPONS.get(knight_id, &""))
