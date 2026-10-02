class_name Boss
extends RefCounted
## Les seigneurs de la Chasse : des boss uniques, chacun avec son nom, sa silhouette et sa règle de combat.
## Chaque Chasse en tire deux, différents de ceux des dernières Chasses : un au milieu, un au bout.
## Leur règle passe par StatBonus (rules), pour que Fighter et Duel l'appliquent sans connaître la Chasse.
## Une règle vaut un entier : 0 ou absente, la règle ne joue pas.

enum Rule {
    RUNE_REGEN, ## une rune s'allume seule toutes les N frames
    THORNS, ## pour mille des dégâts reçus renvoyés à l'attaquant
    SUPER_ARMOR, ## pendant qu'il prépare un coup, un coup reçu ne l'interrompt pas, mais lui fait pour mille de plus
    LIFESTEAL, ## pour mille des dégâts infligés rendus en vie
    SHIELD, ## coups absorbés par manche
    ROUNDS_TO_BEAT, ## manches que l'adversaire doit gagner
    SHAPESHIFT, ## change de chevalier à chaque manche
    MIRROR, ## prend le chevalier et l'équipement de son adversaire
    MOON_STRIKE, ## toutes les N frames, la lune frappe le sol sous l'adversaire
    SANDGLASS, ## manches de N secondes ; au temps, il l'emporte
    REGEN, ## pour mille de sa vie par seconde, après deux secondes sans être touché
    ENRAGE, ## sous la moitié de sa vie : pour mille de dégâts en plus, et une IA plus vive
    POISON, ## ses coups empoisonnent : pour mille de la vie adverse par seconde, pendant POISON_FRAMES
    START_RUNES, ## runes allumées au début de chaque manche
    INTANGIBLE, ## intangible une seconde sur cinq
}

const FIRST_KILL_SHARDS := 30 ## éclats du premier triomphe sur un seigneur, pour le bestiaire
const RECENT_MEMORY := 4 ## les seigneurs des dernières Chasses ne reviennent pas tout de suite
const UNSEEN_WEIGHT := 3 ## un seigneur jamais vaincu sort trois fois plus souvent

## Réglages des règles qui ne dépendent pas du seigneur.
const REGEN_DELAY := 120 ## frames sans être touché avant que la vie revienne
const POISON_FRAMES := 240
const MOON_WARNING := 60 ## frames entre l'annonce et l'impact
const MOON_RADIUS := 650 ## millimètres autour de la marque
const MOON_DAMAGE := 110
const INTANGIBLE_CYCLE := 300
const INTANGIBLE_FRAMES := 45

const CATALOG := {
    &"grand_veneur": {
        "name": "Le Grand Veneur", "epithet": "Maître de la Chasse", "knight": KnightClass.FAUCHEUSE,
        "look": {"crest": &"antlers", "cape": &"long"}, "scale": 1.1,
        "mods": {GearStat.Stat.WALK: 150}, "traits": [GearTrait.Trait.RIPOSTE], "rules": {Rule.RUNE_REGEN: 300},
        "hint": "Son ultime se charge tout seul : garde ton esquive.",
    },
    &"dame_aux_ronces": {
        "name": "La Dame aux Ronces", "epithet": "Celle qu'on ne touche pas", "knight": KnightClass.RODEUSE,
        "look": {"crest": &"thorns", "cape": &"tattered"}, "scale": 1.0,
        "mods": {}, "traits": [], "rules": {Rule.THORNS: 150},
        "hint": "Chaque coup porté te griffe : frappe peu, frappe juste.",
    },
    &"colosse_de_fer": {
        "name": "Le Colosse de Fer", "epithet": "Rempart qui marche", "knight": KnightClass.COLOSSE,
        "look": {"crest": &"crown", "pauldrons": true}, "scale": 1.3,
        "mods": {GearStat.Stat.POWER: -250, GearStat.Stat.WALK: -250}, "traits": [],
        "rules": {Rule.SUPER_ARMOR: 500},
        "hint": "Il ne bronche pas quand il prépare un coup : esquive et punis, ou frappe-le fort.",
    },
    &"sangsue": {
        "name": "La Sangsue", "epithet": "Soif sans fond", "knight": KnightClass.RODEUSE,
        "look": {"crest": &"veil", "cape": &"long"}, "scale": 1.0,
        "mods": {}, "traits": [], "rules": {Rule.LIFESTEAL: 250},
        "hint": "Ses coups la soignent : ne lui laisse aucune ouverture.",
    },
    &"bastion": {
        "name": "Le Bastion", "epithet": "Égide vivante", "knight": KnightClass.VEILLEUR,
        "look": {"crest": &"plume", "pauldrons": true}, "scale": 1.15,
        "mods": {}, "traits": [], "rules": {Rule.SHIELD: 2},
        "hint": "Son égide boit tes deux premiers coups, à chaque manche.",
    },
    &"roi_aux_trois_couronnes": {
        "name": "Le Roi aux trois couronnes", "epithet": "Trois fois sacré", "knight": KnightClass.VEILLEUR,
        "look": {"crest": &"crown", "cape": &"mantle"}, "scale": 1.1,
        "mods": {GearStat.Stat.HP: -150}, "traits": [], "rules": {Rule.ROUNDS_TO_BEAT: 3},
        "hint": "Il faut le vaincre trois fois.",
    },
    &"changeforme": {
        "name": "Le Changeforme", "epithet": "Mille visages", "knight": KnightClass.VEILLEUR,
        "look": {"cape": &"tattered"}, "scale": 1.0,
        "mods": {GearStat.Stat.POWER: 100}, "traits": [], "rules": {Rule.SHAPESHIFT: 1},
        "hint": "Il change de chevalier à chaque manche.",
    },
    &"reflet": {
        "name": "Le Reflet", "epithet": "Ton ombre, ton égal", "knight": KnightClass.VEILLEUR,
        "look": {}, "scale": 1.0,
        "mods": {}, "traits": [], "rules": {Rule.MIRROR: 1},
        "hint": "Il porte ton chevalier et ton équipement.",
    },
    &"pretresse_de_sang": {
        "name": "La Prêtresse de Sang", "epithet": "Voix de la lune", "knight": KnightClass.FAUCHEUSE,
        "look": {"crest": &"halo", "cape": &"mantle"}, "scale": 1.05,
        "mods": {}, "traits": [], "rules": {Rule.MOON_STRIKE: 360},
        "hint": "Quand le sol rougit sous toi, saute, esquive ou fuis.",
    },
    &"sablier": {
        "name": "Le Sablier", "epithet": "Le temps est à lui", "knight": KnightClass.VEILLEUR,
        "look": {"crest": &"halo", "pauldrons": true}, "scale": 1.0,
        "mods": {GearStat.Stat.HP: -100}, "traits": [], "rules": {Rule.SANDGLASS: 25},
        "hint": "Vingt-cinq secondes par manche, et le temps joue pour lui.",
    },
    &"increvable": {
        "name": "L'Increvable", "epithet": "Celui qui se relève", "knight": KnightClass.COLOSSE,
        "look": {"crest": &"horns", "cape": &"tattered"}, "scale": 1.15,
        "mods": {}, "traits": [], "rules": {Rule.REGEN: 30},
        "hint": "Il se referme si tu le laisses souffler.",
    },
    &"furie": {
        "name": "La Furie", "epithet": "Colère à vif", "knight": KnightClass.RODEUSE,
        "look": {"crest": &"horns", "cape": &"tattered"}, "scale": 1.0,
        "mods": {GearStat.Stat.HP: -150}, "traits": [], "rules": {Rule.ENRAGE: 200},
        "hint": "Blessée à moitié, elle frappe plus fort et plus vite.",
    },
    &"vipere": {
        "name": "La Vipère", "epithet": "Morsure lente", "knight": KnightClass.FAUCHEUSE,
        "look": {"crest": &"thorns"}, "scale": 1.0,
        "mods": {}, "traits": [], "rules": {Rule.POISON: 25},
        "hint": "Son venin te ronge après chaque morsure.",
    },
    &"aube_noire": {
        "name": "L'Aube Noire", "epithet": "Lune toujours pleine", "knight": KnightClass.VEILLEUR,
        "look": {"crest": &"antlers", "pauldrons": true}, "scale": 1.2,
        "mods": {GearStat.Stat.HP: -150}, "traits": [], "rules": {Rule.START_RUNES: 3},
        "hint": "Son ultime est prêt dès le premier instant.",
    },
    &"spectre": {
        "name": "Le Spectre", "epithet": "Ni chair ni ombre", "knight": KnightClass.RODEUSE,
        "look": {"crest": &"veil", "cape": &"mantle"}, "scale": 1.05,
        "mods": {GearStat.Stat.HP: -100}, "traits": [], "rules": {Rule.INTANGIBLE: 1},
        "hint": "Il se dissipe par instants : frappe quand il est net.",
    },
}


static func ids() -> Array[StringName]:
    var result: Array[StringName] = []
    for id: StringName in CATALOG:
        result.append(id)
    return result


static func is_valid(id: Variant) -> bool:
    return (id is StringName or id is String) and CATALOG.has(StringName(id))


static func data(id: StringName) -> Dictionary:
    return CATALOG.get(id, {})


static func display_name(id: StringName) -> String:
    return data(id).get("name", "")


static func epithet(id: StringName) -> String:
    return data(id).get("epithet", "")


static func hint(id: StringName) -> String:
    return data(id).get("hint", "")


static func knight_id(id: StringName) -> StringName:
    return data(id).get("knight", KnightClass.VEILLEUR)


static func look(id: StringName) -> Dictionary:
    return data(id).get("look", {})


static func scale(id: StringName) -> float:
    return data(id).get("scale", 1.0)


static func rule(id: StringName, which: int) -> int:
    return data(id).get("rules", {}).get(which, 0)


## Ce que le seigneur ajoute à son chevalier : caractéristiques, traits et règle.
static func bonus_of(id: StringName, into: StatBonus = null) -> StatBonus:
    var bonus := into if into != null else StatBonus.new()
    var entry := data(id)
    for stat: int in entry.get("mods", {}):
        bonus.add_mod(stat, entry["mods"][stat])
    for gear_trait: int in entry.get("traits", []):
        bonus.add_trait(gear_trait)
    for which: int in entry.get("rules", {}):
        bonus.add_rule(which, entry["rules"][which])
    return bonus


## Les chevaliers du Changeforme, manche après manche : le sien d'abord, puis les autres dans l'ordre du jeu.
static func shapes(first: StringName) -> Array[StringName]:
    var order: Array[StringName] = [first]
    for knight in KnightClass.all():
        if knight.id != first:
            order.append(knight.id)
    return order


## Tire count seigneurs différents. recent : ceux des dernières Chasses, écartés tant qu'il en reste assez ;
## defeated : ceux du bestiaire, qui sortent moins souvent que les inconnus.
static func pick(rng: RandomSource, count: int, recent: Array[StringName] = [], defeated: Array[StringName] = []) -> Array[StringName]:
    var chosen: Array[StringName] = []
    for n in count:
        var pool: Array[StringName] = []
        for id in ids():
            if not id in chosen and not id in recent:
                pool.append(id)
        if pool.is_empty():
            for id in ids():
                if not id in chosen:
                    pool.append(id)
        var total := 0
        for id in pool:
            total += 1 if id in defeated else UNSEEN_WEIGHT
        var roll := rng.below(total)
        for id in pool:
            roll -= 1 if id in defeated else UNSEEN_WEIGHT
            if roll < 0:
                chosen.append(id)
                break
    return chosen
