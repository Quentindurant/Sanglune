class_name Duel
extends RefCounted
## Règles d'un duel en deux manches gagnantes, à pas de temps fixe (60 frames par seconde).
## Le Duel ne connaît ni l'écran ni les entrées : il reçoit deux intentions par frame.
## Le triangle naît des timings : la parade bloque la frappe et offre une riposte ; le plongeon, venu du ciel,
## brise la parade ; la frappe, rapide, cueille un chevalier en l'air. La parade ne protège que de face :
## sauter par-dessus un chevalier qui pare, c'est le prendre à revers. Le Colosse brise la garde de tous ses coups.
## L'esquive rend intouchable un court instant avant une reprise vulnérable.
## L'Ultime de chaque arme traverse la parade ; on l'évite en sortant de portée, en sautant ou en esquivant.
## left et right désignent les camps de départ : après un saut par-dessus, left peut se trouver à droite.

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
const CROSS_HEIGHT := 900 ## au-dessus de cette hauteur, un chevalier en l'air passe par-dessus l'autre
const SEPARATION_SPEED := 70 ## quand deux corps se chevauchent, chacun s'écarte de ça par frame
const PUSHBACK := 300 ## recul infligé par un coup, en millimètres

var left_knight: KnightClass
var right_knight: KnightClass
var left_stats: FighterStats ## caractéristiques avec l'équipement, résolues une fois pour tout le match
var right_stats: FighterStats
var left: Fighter
var right: Fighter
var state: int = State.ROUND_INTRO
var state_frames: int = 0
var round_number: int = 0
var round_time_left: int = ROUND_FRAMES
var wins := {-1: 0, 1: 0}
var rounds_needed := {-1: ROUNDS_TO_WIN, 1: ROUNDS_TO_WIN} ## manches à gagner, par camp (le Roi aux trois couronnes en exige trois)
var round_frames := ROUND_FRAMES ## durée d'une manche (le Sablier la raccourcit)
var timeout_winner := 0 ## au temps, ce camp l'emporte d'office (le Sablier) ; 0 : le plus de vie
var match_winner: int = 0 ## -1 gauche, 1 droite, 0 match en cours
var events: Array[Dictionary] = [] ## ce qui s'est passé pendant la dernière frame
var _bonuses := {} ## camp -> StatBonus, pour le Changeforme qui change de chevalier à chaque manche
var _base_knights := {}
var _moon_clock := {-1: 0, 1: 0}


## Sans chevaliers précisés, deux Veilleurs s'affrontent. Sans équipement, chacun tient son arme de départ.
## Les bonus (bénédictions et blessures d'une Chasse) s'ajoutent à l'équipement.
func _init(p_left_knight: KnightClass = null, p_right_knight: KnightClass = null,
        left_gear: Loadout = null, right_gear: Loadout = null,
        left_bonus: StatBonus = null, right_bonus: StatBonus = null) -> void:
    left_knight = p_left_knight if p_left_knight != null else KnightClass.starter()
    right_knight = p_right_knight if p_right_knight != null else KnightClass.starter()
    left_stats = FighterStats.resolve(left_knight, left_gear, left_bonus)
    right_stats = FighterStats.resolve(right_knight, right_gear, right_bonus)
    _bonuses = {-1: left_bonus, 1: right_bonus}
    _base_knights = {-1: left_knight, 1: right_knight}
    _setup_boss_rules()
    restart()


## Les règles de seigneur qui touchent au match entier : manches à gagner, durée des manches.
func _setup_boss_rules() -> void:
    for side in [-1, 1]:
        var stats := left_stats if side < 0 else right_stats
        var to_beat := stats.rule(Boss.Rule.ROUNDS_TO_BEAT)
        if to_beat > 0:
            rounds_needed[-side] = to_beat
        var seconds := stats.rule(Boss.Rule.SANDGLASS)
        if seconds > 0:
            round_frames = seconds * FPS
            timeout_winner = side


## Le Changeforme : le chevalier de cette manche, sans équipement (ses forces viennent de sa règle).
func _shape_for_round(side: int) -> void:
    var stats := left_stats if side < 0 else right_stats
    if stats.rule(Boss.Rule.SHAPESHIFT) <= 0:
        return
    var shapes := Boss.shapes(_base_knights[side].id)
    var knight := KnightClass.by_id(shapes[(round_number - 1) % shapes.size()])
    var shaped := FighterStats.resolve(knight, null, _bonuses[side])
    if side < 0:
        left_knight = knight
        left_stats = shaped
    else:
        right_knight = knight
        right_stats = shaped


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


## Sens dans lequel se trouve l'adversaire : 1 vers la droite de l'arène, -1 vers la gauche.
static func toward(me: Fighter, foe: Fighter) -> int:
    var direction := signi(foe.x - me.x)
    return direction if direction != 0 else me.facing()


func seconds_left() -> int:
    return ceili(round_time_left / float(FPS))


func _start_round() -> void:
    round_number += 1
    _shape_for_round(-1)
    _shape_for_round(1)
    left = Fighter.new(-1, LEFT_START, left_knight, left_stats)
    right = Fighter.new(1, RIGHT_START, right_knight, right_stats)
    round_time_left = round_frames
    _moon_clock = {-1: 0, 1: 0}
    _set_state(State.ROUND_INTRO, INTRO_FRAMES)
    events.append({"type": "round_start", "round": round_number})


func _fight_frame(left_intent: Intent, right_intent: Intent) -> void:
    _apply_intent(left, right, left_intent)
    _apply_intent(right, left, right_intent)
    _start_action(left, right)
    _start_action(right, left)
    _move(left, right)
    _move(right, left)
    _separate()
    # Les deux coups sont évalués avant d'appliquer quoi que ce soit : deux frappes simultanées s'échangent.
    var left_strike := _strike(left, right)
    var right_strike := _strike(right, left)
    _resolve(left, right, left_strike)
    _resolve(right, left, right_strike)
    left.advance_phase()
    right.advance_phase()
    _moon_frame(left, right)
    _moon_frame(right, left)
    _turn_to_face(left, right)
    _turn_to_face(right, left)
    round_time_left -= 1
    _check_round_end()


## Avancer, c'est toujours aller vers l'adversaire, même après être passé de l'autre côté.
func _apply_intent(me: Fighter, foe: Fighter, intent: Intent) -> void:
    if intent == null:
        return
    me.request(intent.action, intent.move)
    if me.is_free() and intent.move != 0:
        var direction := signi(intent.move) * toward(me, foe)
        me.x = _legal_position(me, foe, me.x + direction * me.walk_speed())
        me.note_walk(direction)


## Une action démarre : un ultime s'annonce, pour que l'écran le montre.
func _start_action(me: Fighter, foe: Fighter) -> void:
    if me.try_start_buffered(toward(me, foe)) and me.action == CombatAction.Kind.ULTIME:
        events.append({"type": "ultimate", "side": me.side, "ultimate": me.ultimate.id})


## Élan de l'esquive ou de l'ultime, puis vol et chute du saut.
func _move(me: Fighter, foe: Fighter) -> void:
    if me.action == CombatAction.Kind.ESQUIVE and me.is_invulnerable():
        me.x = _legal_position(me, foe, me.x + me.move_dir * me.stats.dodge_speed)
    elif me.is_dashing():
        me.x = _legal_position(me, foe, me.x + me.facing() * me.ultimate.dash)
    if me.is_airborne():
        me.x = _legal_position(me, foe, me.x + me.air_vx)
        me.fall()


func _turn_to_face(me: Fighter, foe: Fighter) -> void:
    if me.can_turn():
        me.face(toward(me, foe))


## Ce que produirait le coup de l'attaquant cette frame.
func _strike(attacker: Fighter, defender: Fighter) -> Dictionary:
    if not attacker.is_attack_active():
        return {"outcome": Outcome.NONE}
    var kind := attacker.action
    var out_of_reach := absi(attacker.x - defender.x) > attacker.stat(kind, "reach")
    var misses := out_of_reach or not _in_front(attacker, defender) or _passes_under(attacker, defender)
    if misses or defender.is_invulnerable():
        return {"outcome": Outcome.NONE}
    var outcome := Outcome.HIT
    if kind != CombatAction.Kind.ULTIME and _guards_against(defender, attacker):
        var breaks := kind == CombatAction.Kind.PLONGEON or attacker.knight.breaks_guard
        outcome = Outcome.GUARD_BREAK if breaks else Outcome.BLOCKED
    return {"outcome": outcome, "action": kind, "damage": attacker.damage(kind)}


## Une onde au sol (le Séisme) passe sous un chevalier en l'air.
func _passes_under(attacker: Fighter, defender: Fighter) -> bool:
    return attacker.action == CombatAction.Kind.ULTIME and attacker.ultimate.ground_only and defender.is_airborne()


## La parade ne protège que de face : un coup venu de dos passe.
func _guards_against(defender: Fighter, attacker: Fighter) -> bool:
    return defender.is_guarding() and _in_front(defender, attacker)


func _resolve(attacker: Fighter, defender: Fighter, strike: Dictionary) -> void:
    if strike["outcome"] != Outcome.NONE and strike["outcome"] != Outcome.BLOCKED and defender.shield > 0:
        defender.shield -= 1 ## l'égide du Bastion boit les dégâts, pas le choc ; le coup compte pour les runes
        attacker.register_hit()
        defender.stun(Fighter.HITSTUN)
        events.append({"type": "shield", "side": defender.side, "left": defender.shield})
        return
    if strike["outcome"] == Outcome.HIT or strike["outcome"] == Outcome.GUARD_BREAK:
        _boss_on_hit(attacker, defender, strike["damage"])
    match strike["outcome"]:
        Outcome.HIT:
            var ultimate := attacker.action == CombatAction.Kind.ULTIME
            var stun := attacker.ultimate.stun if ultimate else Fighter.HITSTUN
            attacker.register_hit()
            defender.take_hit(strike["damage"], stun + attacker.bonus_stun(strike["action"]))
            var pushed: int = defender.x + attacker.facing() * (attacker.ultimate.pushback if ultimate else PUSHBACK)
            defender.x = _legal_position(defender, attacker, pushed)
            events.append({"type": "hit", "side": attacker.side, "action": strike["action"]})
        Outcome.BLOCKED:
            attacker.stun(Fighter.BLOCKED_STUN)
            defender.register_parry()
            events.append({"type": "blocked", "side": defender.side})
        Outcome.GUARD_BREAK:
            attacker.register_hit()
            defender.take_hit(strike["damage"], Fighter.GUARD_BREAK_STUN + attacker.bonus_stun(strike["action"]))
            events.append({"type": "guard_break", "side": attacker.side})


## Ce que font les règles de seigneur quand un coup porte : ronces, sang volé, venin.
func _boss_on_hit(attacker: Fighter, defender: Fighter, damage: int) -> void:
    var thorns := defender.stats.rule(Boss.Rule.THORNS)
    if thorns > 0:
        attacker.hp = maxi(0, attacker.hp - maxi(1, damage * thorns / 1000))
        events.append({"type": "thorns", "side": defender.side})
    var steal := attacker.stats.rule(Boss.Rule.LIFESTEAL)
    if steal > 0:
        attacker.heal(damage * steal / 1000)
        events.append({"type": "lifesteal", "side": attacker.side})
    var venom := attacker.stats.rule(Boss.Rule.POISON)
    if venom > 0:
        defender.apply_poison(Boss.POISON_FRAMES, maxi(1, defender.max_hp() * venom / 10000))
        events.append({"type": "poison", "side": attacker.side})


## La Prêtresse de Sang : la lune marque le sol sous l'adversaire, puis frappe la marque.
## On l'évite en sautant, en esquivant ou en quittant la marque.
func _moon_frame(caster: Fighter, target: Fighter) -> void:
    var every := caster.stats.rule(Boss.Rule.MOON_STRIKE)
    if every <= 0 or caster.hp <= 0:
        return
    _moon_clock[caster.side] += 1
    if _moon_clock[caster.side] == every:
        _moon_clock[caster.side] = 0
        target.danger_x = target.x
        target.danger_left = Boss.MOON_WARNING
        events.append({"type": "moon_warning", "side": caster.side, "x": target.x})
    elif target.danger_left == 1:
        var hit := not target.is_airborne() and not target.is_invulnerable() \
            and absi(target.x - target.danger_x) <= Boss.MOON_RADIUS
        if hit:
            target.take_hit(Boss.MOON_DAMAGE, Fighter.HITSTUN)
        events.append({"type": "moon_strike", "side": caster.side, "x": target.danger_x, "hit": hit})


## Un coup ne touche que devant soi.
func _in_front(attacker: Fighter, defender: Fighter) -> bool:
    var direction := signi(defender.x - attacker.x)
    return direction == 0 or direction == attacker.facing()


## Les corps se bloquent, sauf si l'un des deux passe assez haut au-dessus de l'autre.
func _bodies_collide(a: Fighter, b: Fighter) -> bool:
    return a.y < CROSS_HEIGHT and b.y < CROSS_HEIGHT


func _is_left_of(me: Fighter, foe: Fighter) -> bool:
    return me.x < foe.x or (me.x == foe.x and me.facing() > 0)


## Où le chevalier peut aller : dans l'arène, et sans s'enfoncer dans l'autre quand les corps se touchent.
## Si les corps se chevauchent déjà (après une réception), il ne peut que s'éloigner.
func _legal_position(me: Fighter, foe: Fighter, target: int) -> int:
    var clamped := clampi(target, ARENA_MIN, ARENA_MAX)
    if not _bodies_collide(me, foe):
        return clamped
    if _is_left_of(me, foe):
        return mini(clamped, maxi(foe.x - MIN_GAP, me.x))
    return maxi(clamped, mini(foe.x + MIN_GAP, me.x))


## Deux corps qui se chevauchent s'écartent en douceur, sans sortir de l'arène.
func _separate() -> void:
    if not _bodies_collide(left, right) or absi(right.x - left.x) >= MIN_GAP:
        return
    var first := left if _is_left_of(left, right) else right
    var second := right if first == left else left
    var overlap := MIN_GAP - (second.x - first.x)
    var push := mini(SEPARATION_SPEED, ceili(overlap / 2.0))
    first.x -= push
    second.x += push
    if first.x < ARENA_MIN:
        second.x += ARENA_MIN - first.x
        first.x = ARENA_MIN
    if second.x > ARENA_MAX:
        first.x -= second.x - ARENA_MAX
        second.x = ARENA_MAX


func _check_round_end() -> void:
    var left_down := left.hp <= 0
    var right_down := right.hp <= 0
    if not left_down and not right_down and round_time_left > 0:
        return
    var winner := 0
    if left_down != right_down:
        winner = 1 if left_down else -1
    elif not left_down:
        # Temps écoulé : le plus de vie l'emporte, l'égalité rejoue la manche ; le Sablier, lui, gagne d'office.
        winner = timeout_winner if timeout_winner != 0 else signi(right.hp - left.hp)
    _end_round(winner)


func _end_round(winner: int) -> void:
    if winner != 0:
        wins[winner] += 1
    events.append({"type": "round_end", "winner": winner})
    if winner != 0 and wins[winner] >= rounds_needed[winner]:
        match_winner = winner
        _set_state(State.MATCH_OVER, 0)
        events.append({"type": "match_end", "winner": winner})
    else:
        _set_state(State.ROUND_OVER, ROUND_OVER_FRAMES)


func _set_state(new_state: int, frames: int) -> void:
    state = new_state
    state_frames = frames
