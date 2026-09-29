class_name Fighter
extends RefCounted
## État d'un chevalier pendant une manche : position, vie, jauge de rune et action en cours.
## Ses données de combat (frames, portée, dégâts, vie, marche) viennent de sa classe, KnightClass.
## Pur domaine : aucune dépendance aux nœuds Godot, donc testable sans scène.

enum Phase { IDLE, STARTUP, ACTIVE, RECOVERY, STUNNED }

const MAX_RUNE := 3
const HITSTUN := 18 ## frames d'étourdissement après un coup reçu
const BLOCKED_STUN := 24 ## frames de riposte offertes quand une frappe est parée
const GUARD_BREAK_STUN := 30 ## frames d'étourdissement quand la parade est brisée (estoc, ou tout coup du Colosse)
const BUFFER_FRAMES := 6 ## une action demandée pendant une autre attend ce nombre de frames

var side: int ## -1 à gauche de l'arène, 1 à droite
var x: int ## position du centre, en millimètres
var knight: KnightClass
var hp: int
var rune: int = 0
var action: int = CombatAction.Kind.NONE
var phase: int = Phase.IDLE
var phase_frames: int = 0 ## frames restantes dans la phase courante
var has_hit: bool = false ## un coup ne touche qu'une seule fois
var buffered_action: int = CombatAction.Kind.NONE
var buffer_left: int = 0


func _init(p_side: int, p_x: int, p_knight: KnightClass = null) -> void:
    side = p_side
    x = p_x
    knight = p_knight if p_knight != null else KnightClass.starter()
    hp = knight.max_hp


func max_hp() -> int:
    return knight.max_hp


func walk_speed() -> int:
    return knight.walk_speed


## Une donnée de combat propre à ce chevalier, par exemple stat(Kind.FRAPPE, "reach").
func stat(kind: int, key: String) -> int:
    return knight.stat(kind, key)


## Direction du regard : le chevalier de gauche regarde vers la droite.
func facing() -> int:
    return -side


func is_free() -> bool:
    return phase == Phase.IDLE


func is_guarding() -> bool:
    return action == CombatAction.Kind.PARADE and phase == Phase.ACTIVE


func is_attack_active() -> bool:
    return CombatAction.is_attack(action) and phase == Phase.ACTIVE and not has_hit


## Mémorise une action : elle partira dès que le chevalier sera libre.
func request(kind: int) -> void:
    if kind == CombatAction.Kind.NONE:
        return
    buffered_action = kind
    buffer_left = BUFFER_FRAMES


## Lance l'action en attente si c'est possible. Renvoie true si une action démarre.
func try_start_buffered() -> bool:
    if not is_free() or buffered_action == CombatAction.Kind.NONE:
        return false
    var kind := buffered_action
    _clear_buffer()
    if kind == CombatAction.Kind.RUNE:
        if rune < MAX_RUNE:
            return false
        rune = 0
    action = kind
    has_hit = false
    _enter(Phase.STARTUP, stat(kind, "startup"))
    return true


## Fait avancer l'action d'une frame. Le Duel l'appelle une fois par frame.
func advance_phase() -> void:
    _tick_buffer()
    if phase == Phase.IDLE:
        return
    phase_frames -= 1
    if phase_frames > 0:
        return
    match phase:
        Phase.STARTUP:
            _enter(Phase.ACTIVE, stat(action, "active"))
        Phase.ACTIVE:
            _enter(Phase.RECOVERY, stat(action, "recovery"))
        _:
            _to_idle()


## Le coup actif a touché : il ne touchera plus, et la jauge de rune se charge.
func register_hit() -> void:
    has_hit = true
    if action != CombatAction.Kind.RUNE:
        rune = mini(MAX_RUNE, rune + 1)


func take_hit(damage: int, stun_frames: int) -> void:
    hp = maxi(0, hp - damage)
    stun(stun_frames)


## Annule l'action en cours et bloque le chevalier pendant quelques frames.
func stun(frames: int) -> void:
    action = CombatAction.Kind.NONE
    has_hit = false
    _clear_buffer()
    _enter(Phase.STUNNED, frames)


func _enter(new_phase: int, frames: int) -> void:
    phase = new_phase
    phase_frames = frames


func _to_idle() -> void:
    action = CombatAction.Kind.NONE
    phase = Phase.IDLE
    phase_frames = 0
    has_hit = false


func _tick_buffer() -> void:
    if buffer_left <= 0:
        return
    buffer_left -= 1
    if buffer_left == 0:
        buffered_action = CombatAction.Kind.NONE


func _clear_buffer() -> void:
    buffered_action = CombatAction.Kind.NONE
    buffer_left = 0
