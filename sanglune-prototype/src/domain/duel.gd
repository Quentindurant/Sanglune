class_name Duel
extends RefCounted
## Règles d'un duel en deux manches gagnantes, à pas de temps fixe (60 frames par seconde).
## Le Duel ne connaît ni l'écran ni les entrées : il reçoit deux intentions par frame.
## Le triangle naît des timings : la frappe, rapide, interrompt l'estoc ; l'estoc brise la parade ;
## la parade bloque la frappe et offre une riposte. Le Colosse fait exception : tous ses coups brisent la parade.

enum State { ROUND_INTRO, FIGHTING, ROUND_OVER, MATCH_OVER }
enum Outcome { NONE, HIT, BLOCKED, GUARD_BREAK }

const FPS := 60
const ROUND_FRAMES := 60 * FPS
const INTRO_FRAMES := 90
const ROUND_OVER_FRAMES := 120
const ROUNDS_TO_WIN := 2
const ARENA_MIN := 0
const ARENA_MAX := 10000
const LEFT_START := 3500
const RIGHT_START := 6500
const MIN_GAP := 700 ## distance minimale entre les deux centres, en millimètres
const PUSHBACK := 300 ## recul infligé par un coup, en millimètres

var left_knight: KnightClass
var right_knight: KnightClass
var left: Fighter
var right: Fighter
var state: int = State.ROUND_INTRO
var state_frames: int = 0
var round_number: int = 0
var round_time_left: int = ROUND_FRAMES
var wins := {-1: 0, 1: 0}
var match_winner: int = 0 ## -1 gauche, 1 droite, 0 match en cours
var events: Array[Dictionary] = [] ## ce qui s'est passé pendant la dernière frame


## Sans chevaliers précisés, deux Veilleurs s'affrontent.
func _init(p_left_knight: KnightClass = null, p_right_knight: KnightClass = null) -> void:
    left_knight = p_left_knight if p_left_knight != null else KnightClass.starter()
    right_knight = p_right_knight if p_right_knight != null else KnightClass.starter()
    restart()


func restart() -> void:
    wins = {-1: 0, 1: 0}
    round_number = 0
    match_winner = 0
    _start_round()


## Avance le duel d'une frame.
func step(left_intent: Intent, right_intent: Intent) -> void:
    events.clear()
    match state:
        State.ROUND_INTRO:
            state_frames -= 1
            if state_frames <= 0:
                skip_intro()
        State.FIGHTING:
            _fight_frame(left_intent, right_intent)
        State.ROUND_OVER:
            state_frames -= 1
            if state_frames <= 0:
                _start_round()


## Passe directement au combat (utilisé par les tests, et plus tard par le mode entraînement).
func skip_intro() -> void:
    _set_state(State.FIGHTING, 0)
    events.append({"type": "fight_start"})


func fighter(side: int) -> Fighter:
    return left if side < 0 else right


func seconds_left() -> int:
    return ceili(round_time_left / float(FPS))


func _start_round() -> void:
    round_number += 1
    left = Fighter.new(-1, LEFT_START, left_knight)
    right = Fighter.new(1, RIGHT_START, right_knight)
    round_time_left = ROUND_FRAMES
    _set_state(State.ROUND_INTRO, INTRO_FRAMES)
    events.append({"type": "round_start", "round": round_number})


func _fight_frame(left_intent: Intent, right_intent: Intent) -> void:
    _apply_intent(left, right, left_intent)
    _apply_intent(right, left, right_intent)
    left.try_start_buffered()
    right.try_start_buffered()
    # Les deux coups sont évalués avant d'appliquer quoi que ce soit : deux frappes simultanées s'échangent.
    var left_strike := _strike(left, right)
    var right_strike := _strike(right, left)
    _resolve(left, right, left_strike)
    _resolve(right, left, right_strike)
    left.advance_phase()
    right.advance_phase()
    round_time_left -= 1
    _check_round_end()


func _apply_intent(me: Fighter, foe: Fighter, intent: Intent) -> void:
    if intent == null:
        return
    me.request(intent.action)
    if me.is_free() and intent.move != 0:
        var target := me.x + signi(intent.move) * me.facing() * me.walk_speed()
        me.x = _legal_position(me, foe, target)


## Ce que produirait le coup de l'attaquant cette frame.
func _strike(attacker: Fighter, defender: Fighter) -> Dictionary:
    if not attacker.is_attack_active():
        return {"outcome": Outcome.NONE}
    var kind := attacker.action
    if absi(attacker.x - defender.x) > attacker.stat(kind, "reach"):
        return {"outcome": Outcome.NONE}
    var outcome := Outcome.HIT
    if kind != CombatAction.Kind.RUNE and defender.is_guarding():
        var breaks := kind == CombatAction.Kind.ESTOC or attacker.knight.breaks_guard
        outcome = Outcome.GUARD_BREAK if breaks else Outcome.BLOCKED
    return {"outcome": outcome, "action": kind, "damage": attacker.stat(kind, "damage")}


func _resolve(attacker: Fighter, defender: Fighter, strike: Dictionary) -> void:
    match strike["outcome"]:
        Outcome.HIT:
            attacker.register_hit()
            defender.take_hit(strike["damage"], Fighter.HITSTUN)
            var pushed: int = defender.x + attacker.facing() * PUSHBACK
            defender.x = _legal_position(defender, attacker, pushed)
            events.append({"type": "hit", "side": attacker.side, "action": strike["action"]})
        Outcome.BLOCKED:
            attacker.stun(Fighter.BLOCKED_STUN)
            events.append({"type": "blocked", "side": defender.side})
        Outcome.GUARD_BREAK:
            attacker.register_hit()
            defender.take_hit(strike["damage"], Fighter.GUARD_BREAK_STUN)
            events.append({"type": "guard_break", "side": attacker.side})


func _legal_position(me: Fighter, foe: Fighter, target: int) -> int:
    var clamped := clampi(target, ARENA_MIN, ARENA_MAX)
    if me.side < 0:
        return mini(clamped, foe.x - MIN_GAP)
    return maxi(clamped, foe.x + MIN_GAP)


func _check_round_end() -> void:
    var left_down := left.hp <= 0
    var right_down := right.hp <= 0
    if not left_down and not right_down and round_time_left > 0:
        return
    var winner := 0
    if left_down != right_down:
        winner = 1 if left_down else -1
    elif not left_down:
        # Temps écoulé : le plus de vie l'emporte, l'égalité rejoue la manche.
        winner = signi(right.hp - left.hp)
    _end_round(winner)


func _end_round(winner: int) -> void:
    if winner != 0:
        wins[winner] += 1
    events.append({"type": "round_end", "winner": winner})
    if winner != 0 and wins[winner] >= ROUNDS_TO_WIN:
        match_winner = winner
        _set_state(State.MATCH_OVER, 0)
        events.append({"type": "match_end", "winner": winner})
    else:
        _set_state(State.ROUND_OVER, ROUND_OVER_FRAMES)


func _set_state(new_state: int, frames: int) -> void:
    state = new_state
    state_frames = frames
