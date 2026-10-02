class_name KnightPose
extends RefCounted
## Les poses du pantin, en angles absolus (radians) pour chaque segment, regard vers la droite :
## 0 pointe vers le bas, -PI/2 vers l'avant, -PI vers le haut, PI/2 vers l'arrière.
## lean penche le torse (positif = vers l'avant). body_dx avance les hanches (fente), en pixels.
## Une pose clé par moment d'action ; le pantin passe de l'une à l'autre au rythme des frames du domaine.

const KEYS := [
    "lean", "head", "upper_f", "fore_f", "weapon_f", "upper_b", "fore_b", "weapon_b",
    "thigh_f", "shin_f", "thigh_b", "shin_b", "body_dx",
]

const GUARD := {
    "lean": 0.08, "head": 0.0,
    "upper_f": -0.35, "fore_f": -1.35, "weapon_f": -2.3,
    "upper_b": -0.45, "fore_b": -1.5, "weapon_b": -1.5,
    "thigh_f": -0.32, "shin_f": 0.02, "thigh_b": 0.32, "shin_b": 0.2, "body_dx": 0.0,
}

const FRAPPE_WINDUP := {"lean": -0.12, "upper_f": -3.0, "fore_f": -3.85, "weapon_f": -4.3, "upper_b": -0.2, "fore_b": -0.9}
const FRAPPE_STRIKE := {
    "lean": 0.28, "upper_f": -1.6, "fore_f": -1.5, "weapon_f": -1.35, "upper_b": 0.3, "fore_b": -0.3,
    "thigh_f": -0.55, "shin_f": 0.25, "body_dx": 10.0,
}
const FRAPPE_FOLLOW := {"lean": 0.2, "upper_f": -0.8, "fore_f": -0.7, "weapon_f": -0.75, "body_dx": 6.0}

const PARADE_BLOCK := {
    "lean": -0.08, "upper_f": -1.25, "fore_f": -2.9, "weapon_f": -3.14,
    "upper_b": -1.35, "fore_b": -1.6, "weapon_b": -1.6,
    "thigh_f": -0.45, "shin_f": 0.35, "thigh_b": 0.4, "shin_b": 0.55,
}

## Les ultimes : un geste par arme.
const LAME_RAISE := {"lean": -0.2, "upper_f": -3.05, "fore_f": -3.14, "weapon_f": -3.14, "upper_b": -2.6, "fore_b": -3.0}
const LAME_SLASH := {
    "lean": 0.5, "upper_f": -1.1, "fore_f": -0.9, "weapon_f": -0.6, "upper_b": 0.4, "fore_b": 0.2,
    "thigh_f": -0.7, "shin_f": 0.3, "thigh_b": 0.5, "shin_b": 0.5, "body_dx": 22.0,
}
const MOISSON_WINDUP := {
    "lean": -0.25, "upper_f": 0.7, "fore_f": 1.1, "weapon_f": 1.6, "upper_b": 0.4, "fore_b": 0.2,
    "thigh_f": -0.4, "shin_f": 0.3, "thigh_b": 0.5, "shin_b": 0.7, "body_dx": -8.0,
}
const MOISSON_SWEEP := {
    "lean": 0.45, "upper_f": -1.8, "fore_f": -1.9, "weapon_f": -2.0, "upper_b": -0.6, "fore_b": -1.2,
    "thigh_f": -0.7, "shin_f": 0.2, "thigh_b": 0.6, "shin_b": 0.6, "body_dx": 16.0,
}
const MOISSON_FOLLOW := {"lean": 0.3, "upper_f": -2.6, "fore_f": -2.9, "weapon_f": -3.3, "body_dx": 10.0}
const DANSE_COIL := {
    "lean": 0.35, "upper_f": 0.6, "fore_f": 0.2, "weapon_f": -0.6, "upper_b": 0.6, "fore_b": 0.3, "weapon_b": -0.5,
    "thigh_f": -0.7, "shin_f": 0.5, "thigh_b": 0.4, "shin_b": 0.9,
}
const DANSE_STAB_FRONT := {
    "lean": 0.55, "upper_f": -1.57, "fore_f": -1.57, "weapon_f": -1.57, "upper_b": 0.6, "fore_b": 0.4, "weapon_b": -0.2,
    "thigh_f": -0.85, "shin_f": 0.1, "thigh_b": 0.6, "shin_b": 0.7, "body_dx": 10.0,
}
const DANSE_STAB_BACK := {
    "lean": 0.55, "upper_f": 0.5, "fore_f": 0.3, "weapon_f": -0.3, "upper_b": -1.5, "fore_b": -1.6, "weapon_b": -1.6,
    "thigh_f": -0.6, "shin_f": 0.4, "thigh_b": 0.7, "shin_b": 0.6, "body_dx": 10.0,
}
const SEISME_RAISE := {"lean": -0.25, "upper_f": -3.05, "fore_f": -3.2, "weapon_f": -3.4, "upper_b": -2.9, "fore_b": -3.1}
const SEISME_SLAM := {
    "lean": 0.65, "upper_f": -0.9, "fore_f": -0.6, "weapon_f": -0.2, "upper_b": -0.7, "fore_b": -0.5,
    "thigh_f": -0.8, "shin_f": 0.5, "thigh_b": 0.5, "shin_b": 1.0, "body_dx": 12.0,
}
## Préparation, coup, suite du geste, pour chaque ultime (la Danse des lames alterne ses deux dagues).
const ULTIMATE_BEATS := {
    &"lame_de_lune": [LAME_RAISE, LAME_SLASH, LAME_SLASH],
    &"moisson": [MOISSON_WINDUP, MOISSON_SWEEP, MOISSON_FOLLOW],
    &"danse_des_lames": [DANSE_COIL, DANSE_STAB_FRONT, DANSE_STAB_FRONT],
    &"seisme": [SEISME_RAISE, SEISME_SLAM, SEISME_SLAM],
}

const CROUCH := {"lean": 0.2, "thigh_f": -0.7, "shin_f": 0.45, "thigh_b": 0.25, "shin_b": 0.95}
const TUCK := {"thigh_f": -1.3, "shin_f": 0.5, "thigh_b": -0.5, "shin_b": 1.0}
const LEGS_DOWN := {"thigh_f": -0.55, "shin_f": 0.15, "thigh_b": 0.1, "shin_b": 0.4}

const DIVE_OVERHEAD := {"lean": -0.1, "upper_f": -3.0, "fore_f": -3.85, "weapon_f": -4.3}
const DIVE_STRIKE := {"lean": 0.35, "upper_f": -1.0, "fore_f": -0.8, "weapon_f": -0.55}

const DODGE_FORWARD := {
    "lean": 0.55, "upper_f": -0.8, "fore_f": -1.2, "weapon_f": -1.8, "upper_b": 0.2, "fore_b": -0.6,
    "thigh_f": -0.8, "shin_f": 0.5, "thigh_b": 0.5, "shin_b": 1.0,
}
const DODGE_BACK := {
    "lean": -0.35, "upper_f": -0.6, "fore_f": -1.6, "weapon_f": -2.4, "upper_b": -0.3, "fore_b": -1.2,
    "thigh_f": -0.55, "shin_f": 0.6, "thigh_b": 0.15, "shin_b": 1.1, "body_dx": -6.0,
}

const RECOIL := {
    "lean": -0.42, "head": -0.35, "upper_f": 0.5, "fore_f": 0.9, "weapon_f": 1.3,
    "upper_b": 0.7, "fore_b": 1.0, "weapon_b": 1.0,
    "thigh_f": -0.5, "shin_f": 0.1, "thigh_b": 0.15, "shin_b": 0.05, "body_dx": -8.0,
}

const KNEEL := {
    "lean": 0.55, "head": 0.45, "upper_f": 0.15, "fore_f": 0.25, "weapon_f": 0.6,
    "upper_b": 0.1, "fore_b": 0.2, "weapon_b": 0.2,
    "thigh_f": -1.45, "shin_f": 0.0, "thigh_b": 0.0, "shin_b": 1.57, "body_dx": 0.0,
}

const VICTORY := {"lean": -0.08, "upper_f": -3.0, "fore_f": -3.1, "weapon_f": -3.14, "upper_b": -0.3, "fore_b": -0.6}

const STUN_RECOIL_SHARE := 0.25 ## part de l'étourdissement passée à encaisser, le reste à se redresser


## La pose de garde, qui respire doucement. time en secondes.
static func idle(time: float) -> Dictionary:
    var breath := sin(time * 1.7)
    return merge(GUARD, {
        "lean": GUARD["lean"] + 0.025 * breath,
        "upper_f": GUARD["upper_f"] + 0.04 * sin(time * 1.7 + 0.6),
        "fore_f": GUARD["fore_f"] + 0.04 * sin(time * 1.7 + 0.6),
    })


## La garde en marche : cycle des jambes en radians, il avance avec la distance parcourue.
static func walk(cycle: float) -> Dictionary:
    var swing := sin(cycle)
    return merge(GUARD, {
        "thigh_f": -0.3 + 0.45 * swing,
        "shin_f": -0.3 + 0.45 * swing + 0.5 * maxf(0.0, sin(cycle + 1.3)),
        "thigh_b": 0.3 - 0.45 * swing,
        "shin_b": 0.3 - 0.45 * swing + 0.5 * maxf(0.0, -sin(cycle + 1.3)),
        "lean": GUARD["lean"] + 0.03 * absf(swing),
    })


## La pose cible d'un chevalier.
## progress : avancement de la phase en cours, de 0 à 1. outcome : 1 manche gagnée, -1 perdue, 0 en cours.
## base : la pose de repos du moment (garde qui respire, ou marche).
static func target(f: Fighter, progress: float, base: Dictionary, outcome: int = 0) -> Dictionary:
    var p := clampf(progress, 0.0, 1.0)
    if outcome < 0 or f.hp <= 0:
        return merge(GUARD, KNEEL)
    if outcome > 0:
        return merge(GUARD, VICTORY)
    if f.phase == Fighter.Phase.STUNNED:
        return _stunned(f, p, base)
    if f.is_airborne():
        return _airborne(f, p, base)
    match f.action:
        CombatAction.Kind.FRAPPE:
            return _three_beats(base, FRAPPE_WINDUP, FRAPPE_STRIKE, FRAPPE_FOLLOW, f.phase, p)
        CombatAction.Kind.ULTIME:
            return _ultimate(f, base, p)
        CombatAction.Kind.PARADE:
            return _parade(base, f.phase, p)
        CombatAction.Kind.ESQUIVE:
            var forward := f.move_dir == f.facing()
            return _hold(base, DODGE_FORWARD if forward else DODGE_BACK, f.phase, p)
        CombatAction.Kind.SAUT, CombatAction.Kind.PLONGEON:
            return _hold(base, CROUCH, f.phase, p)
    return base


## Mélange deux poses : t = 0 donne a, t = 1 donne b.
static func blend(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
    var result := {}
    for key: String in KEYS:
        result[key] = lerpf(a[key], b[key], t)
    return result


## Une pose clé ne liste que ce qui change : le reste vient de la base.
static func merge(base: Dictionary, overrides: Dictionary) -> Dictionary:
    var result := base.duplicate()
    for key: String in overrides:
        result[key] = overrides[key]
    return result


static func ease_out(t: float) -> float:
    return 1.0 - pow(1.0 - clampf(t, 0.0, 1.0), 3.0)


static func ease_in_out(t: float) -> float:
    return smoothstep(0.0, 1.0, clampf(t, 0.0, 1.0))


## Préparation, coup, puis suite du geste et retour en garde. Le coup se joue dans la première moitié de la phase active.
static func _three_beats(base: Dictionary, prepare: Dictionary, strike: Dictionary, follow: Dictionary, phase: int, p: float) -> Dictionary:
    var prepared := merge(base, prepare)
    var struck := merge(base, strike)
    match phase:
        Fighter.Phase.STARTUP:
            return blend(base, prepared, ease_out(p))
        Fighter.Phase.ACTIVE:
            return blend(prepared, struck, ease_out(p * 2.0))
        Fighter.Phase.RECOVERY:
            var followed := merge(base, follow)
            if p < 0.35:
                return blend(struck, followed, ease_out(p / 0.35))
            return blend(followed, base, ease_in_out((p - 0.35) / 0.65))
    return base


static func _ultimate(f: Fighter, base: Dictionary, p: float) -> Dictionary:
    var beats: Array = ULTIMATE_BEATS.get(f.ultimate.id, ULTIMATE_BEATS[&"lame_de_lune"])
    if f.ultimate.id == &"danse_des_lames" and f.phase == Fighter.Phase.ACTIVE:
        var alternate := 0.5 + 0.5 * sin(p * TAU * f.ultimate.hits * 0.5)
        var stabs := blend(merge(base, DANSE_STAB_FRONT), merge(base, DANSE_STAB_BACK), alternate)
        return blend(merge(base, DANSE_COIL), stabs, ease_out(p * 6.0))
    return _three_beats(base, beats[0], beats[1], beats[2], f.phase, p)


static func _parade(base: Dictionary, phase: int, p: float) -> Dictionary:
    var block := merge(base, PARADE_BLOCK)
    match phase:
        Fighter.Phase.STARTUP:
            return blend(base, block, ease_out(p))
        Fighter.Phase.ACTIVE:
            return block
        Fighter.Phase.RECOVERY:
            return blend(block, base, ease_in_out(p))
    return base


## Une pose tenue pendant l'action, prise vite et quittée en douceur.
static func _hold(base: Dictionary, held: Dictionary, phase: int, p: float) -> Dictionary:
    var pose := merge(base, held)
    match phase:
        Fighter.Phase.STARTUP:
            return blend(base, pose, ease_out(p))
        Fighter.Phase.RECOVERY:
            return blend(pose, base, ease_in_out(p))
    return pose


static func _stunned(_f: Fighter, p: float, base: Dictionary) -> Dictionary:
    var recoil := merge(base, RECOIL)
    if p < STUN_RECOIL_SHARE:
        return blend(base, recoil, ease_out(p / STUN_RECOIL_SHARE))
    return blend(recoil, base, ease_in_out((p - STUN_RECOIL_SHARE) / (1.0 - STUN_RECOIL_SHARE)))


## En l'air : jambes repliées en montant, tendues vers le sol en descendant ; le plongeon frappe vers le bas.
static func _airborne(f: Fighter, p: float, base: Dictionary) -> Dictionary:
    var legs := TUCK if f.vy > 0 else LEGS_DOWN
    var body := merge(GUARD, legs)
    if f.action == CombatAction.Kind.PLONGEON:
        var overhead := merge(body, DIVE_OVERHEAD)
        if f.phase == Fighter.Phase.STARTUP:
            return blend(body, overhead, ease_out(p))
        return blend(overhead, merge(body, DIVE_STRIKE), ease_out(p * 4.0))
    return blend(base, body, 0.85)
