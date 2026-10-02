class_name KnightBuild
extends RefCounted
## Gabarit de chaque chevalier pour son pantin : longueurs des os, carrure, casque et arme.
## Une arme, un casque, une carrure : chaque chevalier se reconnaît à sa seule silhouette.
## L'équipement ajoute des pièces (cimier, cape, épaulières) et change la forme de l'arme dans sa famille,
## mais ne touche jamais la carrure ni le casque : on reconnaît toujours le chevalier.
## Repère : x vers l'avant (le regard), y vers le bas, en pixels. Un membre au repos pend vers +y.

const FOOT_HEIGHT := 4.0

const SPECS := {
    &"veilleur": {
        "thigh": 40.0, "shin": 40.0, "torso": 62.0, "upper": 33.0, "fore": 31.0,
        "hip_w": 30.0, "chest_w": 38.0, "limb_w": 14.0,
        "helmet": &"dome", "weapon": &"sword", "off_hand": &"shield", "pauldrons": false,
    },
    &"faucheuse": {
        "thigh": 45.0, "shin": 45.0, "torso": 66.0, "upper": 36.0, "fore": 34.0,
        "hip_w": 26.0, "chest_w": 32.0, "limb_w": 12.0,
        "helmet": &"spike", "weapon": &"halberd", "off_hand": &"none", "pauldrons": false,
    },
    &"rodeuse": {
        "thigh": 36.0, "shin": 34.0, "torso": 54.0, "upper": 30.0, "fore": 28.0,
        "hip_w": 24.0, "chest_w": 30.0, "limb_w": 11.0,
        "helmet": &"hood", "weapon": &"dagger", "off_hand": &"dagger", "pauldrons": false,
    },
    &"colosse": {
        "thigh": 42.0, "shin": 40.0, "torso": 68.0, "upper": 36.0, "fore": 34.0,
        "hip_w": 40.0, "chest_w": 54.0, "limb_w": 18.0,
        "helmet": &"bucket", "weapon": &"mace", "off_hand": &"none", "pauldrons": true,
    },
}
const FALLBACK := &"veilleur"

## Les formes d'arme permises pour chaque famille : l'équipement change l'arme sans changer de famille.
const WEAPON_FAMILIES := {
    &"sword": [&"sword", &"sword_slim"],
    &"halberd": [&"halberd", &"halberd_broad"],
    &"dagger": [&"dagger", &"dagger_hooked"],
    &"mace": [&"mace", &"mace_spiked"],
}
## Les seigneurs de la Chasse ont des pièces à eux : bois de cerf, couronne, couronne d'épines, auréole, voile ;
## cape en lambeaux, manteau jusqu'aux chevilles.
const CRESTS: Array[StringName] = [&"none", &"plume", &"horns", &"antlers", &"crown", &"thorns", &"halo", &"veil"]
const CAPES: Array[StringName] = [&"none", &"long", &"tattered", &"mantle"]
## Hauteur du sommet de chaque casque au-dessus du cou, là où se pose un cimier.
const HELMET_TOP := {&"dome": -29.0, &"spike": -24.0, &"hood": -27.0, &"bucket": -30.0}

## Pointe de chaque arme dans le repère de la main : c'est elle qui trace la traînée.
const WEAPON_TIPS := {
    &"sword": Vector2(0, 102),
    &"sword_slim": Vector2(0, 118),
    &"halberd": Vector2(0, 160),
    &"halberd_broad": Vector2(0, 164),
    &"dagger": Vector2(0, 46),
    &"dagger_hooked": Vector2(8, 46),
    &"mace": Vector2(0, 76),
    &"mace_spiked": Vector2(0, 86),
}


static func has_spec(knight_id: StringName) -> bool:
    return SPECS.has(knight_id)


static func spec(knight_id: StringName) -> Dictionary:
    return SPECS.get(knight_id, SPECS[FALLBACK])


## Le gabarit du chevalier habillé de son équipement (Loadout.look). Ce qui n'est pas permis est ignoré.
static func dressed(knight_id: StringName, look: Dictionary = {}) -> Dictionary:
    var s := spec(knight_id).duplicate()
    s["crest"] = &"none"
    s["cape"] = &"none"
    var family: Array = WEAPON_FAMILIES.get(s["weapon"], [])
    var weapon: Variant = look.get("weapon")
    if _allowed(weapon, family):
        if s["off_hand"] == s["weapon"]:
            s["off_hand"] = StringName(weapon) ## deux armes en main : les deux changent
        s["weapon"] = StringName(weapon)
    if _allowed(look.get("crest"), CRESTS):
        s["crest"] = StringName(look["crest"])
    if _allowed(look.get("cape"), CAPES):
        s["cape"] = StringName(look["cape"])
    if look.get("pauldrons") is bool and look["pauldrons"]:
        s["pauldrons"] = true
    return s


static func _allowed(value: Variant, options: Array) -> bool:
    return (value is StringName or value is String) and options.has(StringName(value))


## Hauteur des hanches au-dessus des pieds, jambes tendues : sert à poser l'ombre et les étincelles.
static func standing_hip_height(knight_id: StringName) -> float:
    var s := spec(knight_id)
    return s["thigh"] + s["shin"] + FOOT_HEIGHT


static func standing_height(knight_id: StringName) -> float:
    return standing_hip_height(knight_id) + spec(knight_id)["torso"] + 30.0


## Un segment de membre, du point d'attache vers +y, légèrement effilé.
static func limb(length: float, width: float) -> PackedVector2Array:
    return PackedVector2Array([
        Vector2(-width * 0.5, -2), Vector2(width * 0.5, -2),
        Vector2(width * 0.4, length + 2), Vector2(-width * 0.4, length + 2),
    ])


## Le torse monte des hanches (0, 0) jusqu'aux épaules (0, -torso).
static func torso(s: Dictionary) -> PackedVector2Array:
    var length: float = s["torso"]
    var hip: float = s["hip_w"] * 0.5
    var chest: float = s["chest_w"] * 0.5
    return PackedVector2Array([
        Vector2(-hip, 6), Vector2(hip, 6),
        Vector2(chest, -length * 0.72), Vector2(chest * 0.7, -length - 2),
        Vector2(-chest * 0.7, -length - 2), Vector2(-chest, -length * 0.72),
    ])


static func pauldrons(s: Dictionary) -> PackedVector2Array:
    var length: float = s["torso"]
    var half: float = s["chest_w"] * 0.5 + 9.0
    return PackedVector2Array([
        Vector2(-half, -length - 4), Vector2(half, -length - 4),
        Vector2(half + 2, -length + 16), Vector2(-half - 2, -length + 16),
    ])


static func foot() -> PackedVector2Array:
    return PackedVector2Array([Vector2(-6, -3), Vector2(15, -3), Vector2(17, FOOT_HEIGHT), Vector2(-7, FOOT_HEIGHT)])


## Le casque, au-dessus du cou (0, 0).
static func helmet(kind: StringName) -> PackedVector2Array:
    match kind:
        &"spike":
            return PackedVector2Array([Vector2(-12, 2), Vector2(12, 2), Vector2(12, -24), Vector2(0, -48), Vector2(-12, -24)])
        &"hood":
            return PackedVector2Array([Vector2(-13, 2), Vector2(13, 2), Vector2(11, -25), Vector2(-2, -29), Vector2(-26, -12)])
        &"bucket":
            return PackedVector2Array([Vector2(-17, 2), Vector2(17, 2), Vector2(18, -30), Vector2(-18, -30)])
    return circle(Vector2(0, -14), 15.0)


## Le cimier, posé au sommet du casque : une ou deux pièces, dans le repère de la tête.
static func crest(kind: StringName, helmet_kind: StringName) -> Array[PackedVector2Array]:
    var top: float = HELMET_TOP.get(helmet_kind, -29.0)
    match kind:
        &"plume":
            return [PackedVector2Array([
                Vector2(3, top + 3), Vector2(-1, top - 8), Vector2(-12, top - 15), Vector2(-27, top - 13),
                Vector2(-38, top - 2), Vector2(-28, top - 5), Vector2(-16, top - 2), Vector2(-6, top + 5),
            ])]
        &"horns":
            return [
                PackedVector2Array([Vector2(6, top + 10), Vector2(11, top + 1), Vector2(17, top - 11), Vector2(24, top - 22), Vector2(18, top - 5), Vector2(14, top + 9)]),
                PackedVector2Array([Vector2(-6, top + 10), Vector2(-11, top + 1), Vector2(-17, top - 11), Vector2(-24, top - 22), Vector2(-18, top - 5), Vector2(-14, top + 9)]),
            ]
        &"antlers":
            var antlers: Array[PackedVector2Array] = []
            for side: float in [1.0, -1.0]:
                var base := Vector2(side * 6, top + 4)
                var mid := Vector2(side * 14, top - 14)
                var tip := Vector2(side * 10, top - 34)
                antlers.append(bar(base, mid, 4.0))
                antlers.append(bar(mid, tip, 3.5))
                antlers.append(bar(mid + (tip - mid) * 0.3, Vector2(side * 26, top - 26), 3.0))
                antlers.append(bar(mid + (tip - mid) * 0.7, Vector2(side * 22, top - 40), 2.5))
                antlers.append(bar(base + (mid - base) * 0.6, Vector2(side * 2, top - 20), 2.5))
            return antlers
        &"crown":
            return [PackedVector2Array([
                Vector2(-15, top + 4), Vector2(15, top + 4), Vector2(16, top - 11), Vector2(10, top - 3), Vector2(5, top - 15),
                Vector2(0, top - 4), Vector2(-5, top - 15), Vector2(-10, top - 3), Vector2(-16, top - 11),
            ])]
        &"thorns":
            var thorns: Array[PackedVector2Array] = []
            for i in 7:
                var x := -15.0 + i * 5.0
                var lean := (x / 15.0) * 7.0
                thorns.append(PackedVector2Array([Vector2(x - 3, top + 4), Vector2(x + 3, top + 4), Vector2(x + lean, top - 9 - (i % 2) * 5)]))
            thorns.append(bar(Vector2(-16, top + 3), Vector2(16, top + 3), 3.0))
            return thorns
        &"halo":
            var halo: Array[PackedVector2Array] = []
            var center := Vector2(-2, top - 14)
            for i in 12:
                var a := TAU * i / 12.0
                var b := TAU * (i + 1) / 12.0
                halo.append(bar(center + Vector2(cos(a) * 17, sin(a) * 5), center + Vector2(cos(b) * 17, sin(b) * 5), 3.0))
            return halo
        &"veil":
            return [PackedVector2Array([
                Vector2(4, top + 2), Vector2(-6, top - 3), Vector2(-20, top + 8), Vector2(-27, top + 30),
                Vector2(-22, top + 52), Vector2(-12, top + 44), Vector2(-8, top + 22), Vector2(-2, top + 10),
            ])]
    return []


## Une barre épaisse de a à b : les pièces fines (bois de cerf, auréole) se construisent ainsi.
static func bar(a: Vector2, b: Vector2, width: float) -> PackedVector2Array:
    var side := (b - a).orthogonal().normalized() * width * 0.5
    return PackedVector2Array([a + side, b + side, b - side, a - side])


## La cape tombe des épaules dans le dos, jusqu'à mi-cuisse : dans le repère du torse.
static func cape(s: Dictionary) -> PackedVector2Array:
    var length: float = s["torso"]
    var chest: float = s["chest_w"] * 0.5
    match s.get("cape", &"long"):
        &"tattered":
            return PackedVector2Array([
                Vector2(-chest * 0.5, -length + 2), Vector2(-chest - 3, -length + 8), Vector2(-chest - 12, -length * 0.4),
                Vector2(-chest - 22, 30), Vector2(-chest - 15, 22), Vector2(-chest - 12, 38), Vector2(-chest - 5, 24),
                Vector2(-chest + 1, 34), Vector2(-chest + 4, 12), Vector2(-chest * 0.3, -length * 0.3),
            ])
        &"mantle":
            var floor_y: float = s["thigh"] + s["shin"] * 0.85
            return PackedVector2Array([
                Vector2(-chest * 0.5, -length + 2), Vector2(-chest - 4, -length + 8), Vector2(-chest - 14, -length * 0.3),
                Vector2(-chest - 26, floor_y), Vector2(-chest + 2, floor_y + 4), Vector2(-chest + 4, 10),
                Vector2(-chest * 0.3, -length * 0.3),
            ])
    return PackedVector2Array([
        Vector2(-chest * 0.5, -length + 2), Vector2(-chest - 3, -length + 8), Vector2(-chest - 11, -length * 0.4),
        Vector2(-chest - 19, 24), Vector2(-chest - 5, 32), Vector2(-chest + 5, 14), Vector2(-chest * 0.3, -length * 0.3),
    ])


## La fente des yeux, dans le casque, du côté du regard.
static func eye(kind: StringName) -> PackedVector2Array:
    var top := -18.0 if kind == &"bucket" else -16.0
    return PackedVector2Array([Vector2(2, top), Vector2(13, top), Vector2(13, top + 4), Vector2(2, top + 4)])


## Les pièces d'une arme, dans le repère de la main : +y prolonge l'avant-bras.
static func weapon(kind: StringName) -> Array[PackedVector2Array]:
    match kind:
        &"sword":
            return [
                _rect(Vector2(-2.5, -4), Vector2(2.5, 10)),
                _rect(Vector2(-10, 10), Vector2(10, 14)),
                PackedVector2Array([Vector2(-3.2, 14), Vector2(3.2, 14), Vector2(2.6, 92), Vector2(0, 102), Vector2(-2.6, 92)]),
            ]
        &"sword_slim":
            return [
                _rect(Vector2(-2.5, -4), Vector2(2.5, 10)),
                _rect(Vector2(-8, 10), Vector2(8, 13)),
                PackedVector2Array([Vector2(-2.4, 13), Vector2(2.4, 13), Vector2(2.0, 104), Vector2(0, 118), Vector2(-2.0, 104)]),
            ]
        &"halberd_broad":
            return [
                _rect(Vector2(-2.5, -70), Vector2(2.5, 132)),
                PackedVector2Array([Vector2(2.5, 104), Vector2(30, 92), Vector2(42, 120), Vector2(30, 152), Vector2(2.5, 142)]),
                PackedVector2Array([Vector2(-2.5, 116), Vector2(-20, 110), Vector2(-12, 124), Vector2(-2.5, 130)]),
                PackedVector2Array([Vector2(-3, 132), Vector2(3, 132), Vector2(0, 164)]),
            ]
        &"dagger_hooked":
            return [
                _rect(Vector2(-2, -4), Vector2(2, 8)),
                _rect(Vector2(-6, 8), Vector2(6, 11)),
                PackedVector2Array([Vector2(-2.6, 11), Vector2(2.6, 11), Vector2(5, 24), Vector2(11, 38), Vector2(8, 46), Vector2(2, 34), Vector2(-1, 22)]),
            ]
        &"mace_spiked":
            return [
                _rect(Vector2(-2.8, -6), Vector2(2.8, 50)),
                circle(Vector2(0, 62), 14.0, 8),
                PackedVector2Array([Vector2(-5, 74), Vector2(5, 74), Vector2(0, 86)]),
                PackedVector2Array([Vector2(11, 56), Vector2(11, 68), Vector2(24, 62)]),
                PackedVector2Array([Vector2(-11, 56), Vector2(-11, 68), Vector2(-24, 62)]),
                PackedVector2Array([Vector2(6, 70), Vector2(12, 64), Vector2(18, 78)]),
                PackedVector2Array([Vector2(-6, 70), Vector2(-12, 64), Vector2(-18, 78)]),
            ]
        &"halberd":
            return [
                _rect(Vector2(-2.5, -70), Vector2(2.5, 132)),
                PackedVector2Array([Vector2(2.5, 110), Vector2(26, 102), Vector2(33, 124), Vector2(26, 146), Vector2(2.5, 138)]),
                PackedVector2Array([Vector2(-2.5, 118), Vector2(-15, 124), Vector2(-2.5, 130)]),
                PackedVector2Array([Vector2(-3, 130), Vector2(3, 130), Vector2(0, 160)]),
            ]
        &"dagger":
            return [
                _rect(Vector2(-2, -4), Vector2(2, 8)),
                _rect(Vector2(-6, 8), Vector2(6, 11)),
                PackedVector2Array([Vector2(-2.6, 11), Vector2(2.6, 11), Vector2(0, 46)]),
            ]
        &"mace":
            var head := circle(Vector2(0, 62), 13.0, 8)
            return [
                _rect(Vector2(-2.8, -6), Vector2(2.8, 52)),
                head,
                PackedVector2Array([Vector2(-4, 72), Vector2(4, 72), Vector2(0, 80)]),
                PackedVector2Array([Vector2(10, 58), Vector2(10, 66), Vector2(19, 62)]),
                PackedVector2Array([Vector2(-10, 58), Vector2(-10, 66), Vector2(-19, 62)]),
            ]
        &"shield":
            ## L'écu se tient en travers de l'avant-bras : vertical quand le bras pointe vers l'avant, pointe en bas.
            return [PackedVector2Array([Vector2(30, 4), Vector2(30, 20), Vector2(-10, 23), Vector2(-38, 13), Vector2(-10, 2)])]
    return []


static func weapon_tip(kind: StringName) -> Vector2:
    return WEAPON_TIPS.get(kind, Vector2(0, 40))


static func circle(center: Vector2, radius: float, points: int = 12) -> PackedVector2Array:
    var result := PackedVector2Array()
    for i in points:
        result.append(center + Vector2.from_angle(TAU * i / points) * radius)
    return result


static func diamond(center: Vector2, half: float) -> PackedVector2Array:
    return PackedVector2Array([center + Vector2(0, -half), center + Vector2(half * 0.7, 0), center + Vector2(0, half), center + Vector2(-half * 0.7, 0)])


static func _rect(from: Vector2, to: Vector2) -> PackedVector2Array:
    return PackedVector2Array([from, Vector2(to.x, from.y), to, Vector2(from.x, to.y)])
