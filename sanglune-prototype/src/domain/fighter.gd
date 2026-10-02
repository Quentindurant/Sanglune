class_name Fighter
extends RefCounted
## État d'un chevalier pendant une manche : position, hauteur, vie, jauge de rune et action en cours.
## Ses données de combat (frames, portée, dégâts, vie, vitesses) viennent de FighterStats : sa classe,
## ajustée par son équipement. Son Ultime vient de son arme.
## Le chevalier gère ses phases et sa chute ; le Duel le déplace et arbitre les coups.
## Pur domaine : aucune dépendance aux nœuds Godot, donc testable sans scène.

enum Phase { IDLE, STARTUP, ACTIVE, RECOVERY, STUNNED }

const MAX_RUNE := 3
const HITSTUN := 18 ## frames d'étourdissement après un coup reçu
const BLOCKED_STUN := 24 ## frames de riposte offertes quand une frappe est parée
const GUARD_BREAK_STUN := 30 ## frames d'étourdissement quand la parade est brisée (plongeon, ou tout coup du Colosse)
const BUFFER_FRAMES := 6 ## une action demandée pendant une autre attend ce nombre de frames
const JUMP_VELOCITY := 156 ## vitesse verticale à l'envol, en millimètres par frame
const GRAVITY := 8 ## un saut dure ainsi une quarantaine de frames et monte à 1,5 m
const MOMENTUM_FRAMES := 8 ## un saut sans direction garde l'élan d'une marche de moins de 8 frames

var side: int ## camp : -1 pour le chevalier parti de gauche (le joueur), 1 pour l'autre ; ne change jamais
var x: int ## position du centre, en millimètres
var y: int = 0 ## hauteur des pieds au-dessus du sol, en millimètres
var vy: int = 0 ## vitesse verticale, en millimètres par frame
var air_vx: int = 0 ## vitesse horizontale en l'air, fixée à l'envol
var knight: KnightClass
var stats: FighterStats
var ultimate: Ultimate
var hp: int
var rune: int = 0
var action: int = CombatAction.Kind.NONE
var phase: int = Phase.IDLE
var phase_frames: int = 0 ## frames restantes dans la phase courante
var has_hit: bool = false ## un coup ne touche qu'une seule fois
var buffered_action: int = CombatAction.Kind.NONE
var buffered_move: int = 0 ## direction demandée avec l'action : 1 vers l'adversaire, -1 en arrière
var buffer_left: int = 0
var move_dir: int = 0 ## sens de l'esquive ou du saut en cours dans l'arène : -1 vers la gauche, 1 vers la droite
var _facing: int
var _air_attack_used := false
var _hits_left := 0 ## coups restants de l'action en cours (plusieurs pour certains ultimes)
var _rehit_in := 0 ## frames avant que l'ultime puisse toucher à nouveau
var _riposte_left := 0 ## trait Riposte : frames pendant lesquelles la prochaine Frappe sera plus vive
var _echo_used := false ## trait Écho : la rune n'est rendue qu'une fois par ultime
var _last_walk_dir := 0
var _last_walk_age := MOMENTUM_FRAMES + 1
# Règles de seigneur (Boss.Rule), et ce qu'elles font à l'adversaire.
var shield := 0 ## coups que l'égide absorbe encore cette manche
var poison_left := 0 ## frames de venin restantes
var danger_x := 0 ## où la lune va frapper (Prêtresse de Sang)
var danger_left := 0 ## frames avant l'impact, 0 sans menace
var _poison_tick := 0 ## vie retirée toutes les 6 frames par le venin
var _since_hit := 0
var _rune_clock := 0
var _clock := 0 ## frames de combat depuis le début de la manche


## p_stats : caractéristiques déjà résolues avec l'équipement ; sans elles, celles de la classe seule.
func _init(p_side: int, p_x: int, p_knight: KnightClass = null, p_stats: FighterStats = null) -> void:
    side = p_side
    x = p_x
    _facing = -p_side
    knight = p_knight if p_knight != null else KnightClass.starter()
    stats = p_stats if p_stats != null and p_stats.knight.id == knight.id else FighterStats.resolve(knight)
    ultimate = Ultimate.by_id(stats.ultimate_id)
    hp = stats.max_hp
    if stats.has_trait(GearTrait.Trait.AUBE_ROUGE):
        rune = 1
    rune = maxi(rune, clampi(stats.rule(Boss.Rule.START_RUNES), 0, MAX_RUNE))
    shield = maxi(0, stats.rule(Boss.Rule.SHIELD))


func max_hp() -> int:
    return stats.max_hp


func walk_speed() -> int:
    return stats.walk_speed


## Une donnée de combat propre à ce chevalier et à son équipement, par exemple stat(Kind.FRAPPE, "reach").
func stat(kind: int, key: String) -> int:
    return stats.stat(kind, key)


## Les dégâts d'un coup, trait Dernier souffle compris : sous un quart de sa vie, on frappe plus fort.
## Règle de la Furie : sous la moitié de sa vie, des dégâts en plus.
func damage(kind: int) -> int:
    var base := stat(kind, "damage")
    if is_enraged():
        base = GearStat.grow(base, stats.rule(Boss.Rule.ENRAGE))
    if stats.has_trait(GearTrait.Trait.DERNIER_SOUFFLE) and hp * GearTrait.DERNIER_SOUFFLE_SHARE <= max_hp():
        return GearStat.grow(base, GearTrait.DERNIER_SOUFFLE_BONUS)
    return base


## Règle de la Furie : la colère s'éveille sous la moitié de la vie.
func is_enraged() -> bool:
    return stats.rule(Boss.Rule.ENRAGE) > 0 and hp * 2 <= max_hp()


## Règle du Spectre : intangible une seconde sur cinq.
func is_intangible() -> bool:
    if stats.rule(Boss.Rule.INTANGIBLE) <= 0:
        return false
    return _clock % Boss.INTANGIBLE_CYCLE >= Boss.INTANGIBLE_CYCLE - Boss.INTANGIBLE_FRAMES


## Le venin de la Vipère : la vie s'écoule toutes les 6 frames pendant frames frames.
func apply_poison(frames: int, tick: int) -> void:
    poison_left = maxi(poison_left, frames)
    _poison_tick = maxi(_poison_tick, tick)


func is_poisoned() -> bool:
    return poison_left > 0


## Soigne, sans dépasser la vie de départ.
func heal(amount: int) -> void:
    if hp > 0:
        hp = mini(max_hp(), hp + maxi(0, amount))


## L'étourdissement en plus qu'inflige ce coup : un plongeon avec le trait Chute lourde.
func bonus_stun(kind: int) -> int:
    if kind == CombatAction.Kind.PLONGEON and stats.has_trait(GearTrait.Trait.CHUTE_LOURDE):
        return GearTrait.CHUTE_LOURDE_FRAMES
    return 0


## Ma parade vient de bloquer un coup : avec le trait Garde lunaire, une rune s'allume.
func register_parry() -> void:
    if stats.has_trait(GearTrait.Trait.GARDE_LUNAIRE):
        rune = mini(MAX_RUNE, rune + 1)


## Direction du regard : 1 vers la droite de l'arène, -1 vers la gauche.
func facing() -> int:
    return _facing


func face(direction: int) -> void:
    if direction != 0:
        _facing = signi(direction)


## Un chevalier se retourne seulement au sol, quand il ne frappe, ne pare ni n'esquive.
func can_turn() -> bool:
    return not is_airborne() and (phase == Phase.IDLE or action == CombatAction.Kind.SAUT)


## Libre de marcher ou de lancer une action au sol.
func is_free() -> bool:
    return phase == Phase.IDLE and not is_airborne()


func is_airborne() -> bool:
    return y > 0 or vy > 0


func is_guarding() -> bool:
    return action == CombatAction.Kind.PARADE and phase == Phase.ACTIVE


## Pendant l'élan de l'esquive, ou d'un ultime qui le permet, aucun coup ne peut toucher. Un Spectre dissipé non plus.
func is_invulnerable() -> bool:
    if is_intangible():
        return true
    if phase != Phase.ACTIVE:
        return false
    return action == CombatAction.Kind.ESQUIVE or (action == CombatAction.Kind.ULTIME and ultimate.invulnerable)


## Un ultime à élan emporte le chevalier vers l'avant pendant qu'il frappe.
func is_dashing() -> bool:
    return action == CombatAction.Kind.ULTIME and phase == Phase.ACTIVE and ultimate.dash > 0


func is_attack_active() -> bool:
    return CombatAction.is_attack(action) and phase == Phase.ACTIVE and not has_hit


## Mémorise une action et sa direction : elle partira dès que possible.
func request(kind: int, move: int = 0) -> void:
    if kind == CombatAction.Kind.NONE:
        return
    buffered_action = kind
    buffered_move = signi(move)
    buffer_left = BUFFER_FRAMES


## Le Duel signale une marche, dans le repère de l'arène : un saut qui suit de près en garde l'élan.
func note_walk(direction: int) -> void:
    _last_walk_dir = signi(direction)
    _last_walk_age = 0


## Lance l'action en attente si c'est possible. toward : sens de l'adversaire dans l'arène.
## Renvoie true si une action démarre.
func try_start_buffered(toward: int = 0) -> bool:
    if buffered_action == CombatAction.Kind.NONE:
        return false
    if is_airborne():
        return _try_start_in_air()
    if not is_free():
        return false
    var kind := buffered_action
    var move := buffered_move
    _clear_buffer()
    if kind == CombatAction.Kind.PLONGEON:
        return false
    if kind == CombatAction.Kind.ULTIME:
        if rune < MAX_RUNE:
            return false
        rune = 0
        _echo_used = false
    action = kind
    has_hit = false
    _hits_left = ultimate.hits if kind == CombatAction.Kind.ULTIME else 1
    _rehit_in = 0
    move_dir = _start_direction(kind, move, toward if toward != 0 else facing())
    _enter(Phase.STARTUP, _startup(kind))
    return true


## Trait Riposte : juste après une esquive, la Frappe part quelques frames plus tôt.
func _startup(kind: int) -> int:
    var frames := stat(kind, "startup")
    if kind == CombatAction.Kind.FRAPPE and _riposte_left > 0:
        _riposte_left = 0
        return maxi(1, frames - GearTrait.RIPOSTE_FRAMES)
    return frames


## Fait avancer l'action d'une frame. Le Duel l'appelle une fois par frame.
func advance_phase() -> void:
    _tick_buffer()
    _tick_rehit()
    _riposte_left = maxi(0, _riposte_left - 1)
    _last_walk_age = mini(_last_walk_age + 1, MOMENTUM_FRAMES + 1)
    _tick_boss_rules()
    if phase == Phase.IDLE:
        return
    phase_frames -= 1
    if phase_frames > 0:
        return
    match phase:
        Phase.STARTUP:
            if action == CombatAction.Kind.SAUT:
                _take_off()
            else:
                _enter(Phase.ACTIVE, stat(action, "active"))
        Phase.ACTIVE:
            if action == CombatAction.Kind.ESQUIVE and stats.has_trait(GearTrait.Trait.RIPOSTE):
                _riposte_left = GearTrait.RIPOSTE_WINDOW
            _enter(Phase.RECOVERY, stat(action, "recovery"))
        _:
            _to_idle()


## Fait tomber le chevalier d'une frame s'il est en l'air. Renvoie true à la réception.
func fall() -> bool:
    if not is_airborne():
        return false
    y += vy
    vy -= GRAVITY
    if y > 0:
        return false
    _land()
    return true


## Le coup actif a touché : il ne touchera plus (ou plus tard, pour un ultime à plusieurs coups).
## Un coup ordinaire allume une rune ; l'ultime, lui, vient de les consumer.
func register_hit() -> void:
    has_hit = true
    if action == CombatAction.Kind.ULTIME:
        _hits_left -= 1
        if _hits_left > 0:
            _rehit_in = ultimate.hit_interval
        if stats.has_trait(GearTrait.Trait.ECHO) and not _echo_used: ## trait Écho : un ultime qui touche rend une rune
            _echo_used = true
            rune = mini(MAX_RUNE, rune + 1)
        return
    rune = mini(MAX_RUNE, rune + 1)


## Un coup reçu : la résistance au choc de l'équipement raccourcit l'étourdissement.
## Règle du Colosse de Fer : pendant qu'il prépare un coup, il encaisse sans être interrompu.
func take_hit(damage: int, stun_frames: int) -> void:
    _since_hit = 0
    if has_super_armor():
        hp = maxi(0, hp - GearStat.grow(damage, stats.rule(Boss.Rule.SUPER_ARMOR)))
        return
    hp = maxi(0, hp - damage)
    stun(stats.stun_frames(stun_frames))


func has_super_armor() -> bool:
    var attacking := action != CombatAction.Kind.NONE and CombatAction.is_attack(action)
    return stats.rule(Boss.Rule.SUPER_ARMOR) > 0 and attacking and phase == Phase.STARTUP


## Une frame de combat pour les règles de seigneur : runes qui s'allument seules, vie qui revient, venin.
func _tick_boss_rules() -> void:
    _clock += 1
    _since_hit += 1
    var rune_every := stats.rule(Boss.Rule.RUNE_REGEN)
    if rune_every > 0:
        _rune_clock += 1
        if _rune_clock >= rune_every:
            _rune_clock = 0
            rune = mini(MAX_RUNE, rune + 1)
    var regen := stats.rule(Boss.Rule.REGEN)
    if regen > 0 and _since_hit >= Boss.REGEN_DELAY and _clock % 6 == 0:
        heal(maxi(1, max_hp() * regen / 10000))
    if poison_left > 0:
        poison_left -= 1
        if poison_left % 6 == 0:
            hp = maxi(0, hp - _poison_tick)
        if poison_left == 0:
            _poison_tick = 0
    if danger_left > 0:
        danger_left -= 1


## Annule l'action en cours et bloque le chevalier pendant quelques frames. En l'air, il retombe droit.
func stun(frames: int) -> void:
    action = CombatAction.Kind.NONE
    has_hit = false
    move_dir = 0
    air_vx = 0
    _clear_buffer()
    _enter(Phase.STUNNED, frames)


## En l'air, seule une frappe part, et devient un plongeon ; une fois par saut.
func _try_start_in_air() -> bool:
    if phase != Phase.IDLE or _air_attack_used or not CombatAction.is_air_attack_trigger(buffered_action):
        return false
    _clear_buffer()
    _air_attack_used = true
    action = CombatAction.Kind.PLONGEON
    has_hit = false
    _enter(Phase.STARTUP, stat(action, "startup"))
    return true


## L'esquive part en arrière si aucune direction n'est tenue ; le saut garde l'élan de la marche.
func _start_direction(kind: int, move: int, toward: int) -> int:
    match kind:
        CombatAction.Kind.ESQUIVE:
            return move * toward if move != 0 else -toward
        CombatAction.Kind.SAUT:
            if move != 0:
                return move * toward
            return _last_walk_dir if _last_walk_age <= MOMENTUM_FRAMES else 0
    return 0


func _take_off() -> void:
    vy = JUMP_VELOCITY
    air_vx = move_dir * stats.jump_speed
    _air_attack_used = false
    _to_idle()


## À la réception, un temps de reprise : plus long après un plongeon.
func _land() -> void:
    y = 0
    vy = 0
    air_vx = 0
    if phase == Phase.STUNNED:
        return
    action = CombatAction.Kind.PLONGEON if action == CombatAction.Kind.PLONGEON else CombatAction.Kind.SAUT
    has_hit = true
    _enter(Phase.RECOVERY, stat(action, "recovery"))


func _enter(new_phase: int, frames: int) -> void:
    phase = new_phase
    phase_frames = frames


func _to_idle() -> void:
    action = CombatAction.Kind.NONE
    phase = Phase.IDLE
    phase_frames = 0
    has_hit = false


func _tick_rehit() -> void:
    if _rehit_in <= 0:
        return
    _rehit_in -= 1
    if _rehit_in == 0 and phase == Phase.ACTIVE:
        has_hit = false


func _tick_buffer() -> void:
    if buffer_left <= 0:
        return
    buffer_left -= 1
    if buffer_left == 0:
        _clear_buffer()


func _clear_buffer() -> void:
    buffered_action = CombatAction.Kind.NONE
    buffered_move = 0
    buffer_left = 0
