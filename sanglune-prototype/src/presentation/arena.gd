class_name Arena
extends Node2D
## Le duel animé : fait tourner le Duel à 60 frames par seconde, anime les pantins et relaie les entrées.
## La logique de combat vit dans src/domain ; ici on montre, on fait vibrer l'impact et on écoute les doigts.

signal home_requested
signal match_finished(player_won: bool) ## seulement si report_results : l'enchaînement montre alors le reliquaire
signal forfeit_requested ## en Chasse, « Abandonner » confirmé depuis la pause

const VIEW := Vector2(1280, 720)
const PX_PER_MM := 0.09
const ARENA_LEFT := 190.0
const GROUND_Y := 470.0
const END_MENU_DELAY := 45 ## frames avant d'afficher la fin de match, pour ne pas relancer en martelant Frappe
const END_BUTTON_SIZE := Vector2(360, 72)
const PAUSE_BUTTON_SIZE := Vector2(64, 48)
const RIM_DISTANCE := 3.0 ## épaisseur du liseré de lune, en pixels
const SHAKE_DECAY := 0.8

## Secousse et étincelles selon le coup reçu : plus le coup est lourd, plus l'écran tremble.
const IMPACT_STRENGTH := {
    CombatAction.Kind.FRAPPE: 4.0,
    CombatAction.Kind.PLONGEON: 7.0,
    CombatAction.Kind.ULTIME: 11.0,
}
const GUARD_BREAK_STRENGTH := 8.0
const BLOCK_STRENGTH := 2.5

## Boutons tactiles du pouce droit : ils déclenchent les mêmes actions que le clavier.
## Le pouce gauche a le joystick : marcher, sauter (haut), esquiver (bas).
const BUTTONS := [
    {"action": "frappe", "label": "Frappe", "pos": Vector2(1160, 612), "radius": 72.0},
    {"action": "parade", "label": "Parade", "pos": Vector2(1004, 652), "radius": 56.0},
    {"action": "ultime", "label": "Ultime", "pos": Vector2(1178, 452), "radius": 52.0},
]

## Aide clavier, affichée seulement sur ordinateur.
const KEYBOARD_HELP := "Q D bouger   Z saut   S esquive   J frappe   L parade   I ultime   Échap pause"
const END_KEYBOARD_HELP := "J rejouer   Échap accueil"

var player_knight: KnightClass
var enemy_knight: KnightClass
var player_gear: Loadout ## équipement du joueur ; null : armes de départ
var enemy_gear: Loadout
var player_look: Dictionary ## la silhouette du joueur (garde-robe comprise) ; vide : celle de son équipement
var enemy_title := "L'ombre" ## au-dessus de la vie de l'adversaire : son palier, ou « Gardien »
var enemy_reaction := 12 ## frames entre deux décisions de l'IA adverse
var enemy_accuracy := 0.7
var report_results := false ## true : à la fin du match, match_finished remplace le menu « Rejouer »
var player_bonus: StatBonus ## bénédictions et blessures de la Chasse ; null hors Chasse
var enemy_bonus: StatBonus
var forfeit_mode := false ## en Chasse : la pause propose « Abandonner » (deux touches) au lieu d'« Accueil »
var enemy_look := {} ## la silhouette d'un seigneur (vide : celle de son équipement)
var enemy_scale := 1.0 ## la taille d'un seigneur
var boss_id: StringName = &""
var moon_mark := {} ## la marque de la Prêtresse de Sang : {"x": millimètres, "frames": restantes}
var moon_beam := {} ## l'impact de la lune : {"x": millimètres, "frames": restantes}
var _enrage_announced := false
var _forfeit_button: Button
var _confirming_forfeit := false
var _reported := false
var duel: Duel
var touch_buttons: Array[TouchScreenButton] = []
var joystick: ThumbStick
var message := ""
var message_frames := 0
var _player: IntentSource = PlayerInput.new()
var _enemy: IntentSource
var _world: Node2D
var _fx: Node2D
var _puppets := {} ## camp (-1 joueur, 1 ombre) -> KnightPuppet
var _outcome := {-1: 0, 1: 0} ## 1 manche gagnée, -1 perdue : le pantin lève l'arme ou pose un genou
var _hud: ArenaHud
var _end_menu: VBoxContainer
var _replay_button: Button
var _pause_menu: VBoxContainer
var _resume_button: Button
var _pause_button: Button
var _paused := false
var _end_frames := 0
var _shake := 0.0


## À appeler avant d'ajouter la scène à l'arbre. Sans appel, le Veilleur affronte un chevalier au hasard.
func configure(p_player_knight: KnightClass, p_enemy_knight: KnightClass,
        p_player_gear: Loadout = null, p_enemy_gear: Loadout = null, p_player_look: Dictionary = {}) -> void:
    player_knight = p_player_knight
    enemy_knight = p_enemy_knight
    player_gear = p_player_gear
    enemy_gear = p_enemy_gear
    player_look = p_player_look
    if is_node_ready():
        _build_puppets()
        replay()


func _ready() -> void:
    InputBindings.register()
    if player_knight == null:
        player_knight = KnightClass.starter()
    if enemy_knight == null:
        var rng := RandomNumberGenerator.new()
        rng.randomize()
        enemy_knight = KnightClass.pick_random(rng)
    _build_world()
    _create_touch_buttons()
    joystick = ThumbStick.new()
    joystick.z_index = 51
    add_child(joystick)
    _hud = ArenaHud.new()
    _hud.arena = self
    _hud.z_index = 50
    add_child(_hud)
    _create_end_menu()
    _create_pause_controls()
    replay()


func _physics_process(_delta: float) -> void:
    if _paused:
        return
    if duel.state == Duel.State.MATCH_OVER:
        _update_end_menu()
    else:
        var left_intent := _player.next_intent(duel.left, duel.right)
        var right_intent := _enemy.next_intent(duel.right, duel.left)
        duel.step(left_intent, right_intent)
        _read_events()
        _watch_boss()
    _tick_moon_fx()
    if message_frames > 0:
        message_frames -= 1
    _update_puppets()
    _update_shake()
    _fx.queue_redraw()
    _hud.queue_redraw()


## L'ombre d'un palier du Chemin : son titre et la vivacité de son IA (son chevalier et son équipement passent par configure).
func set_shadow(shadow: ShadowOpponent) -> void:
    enemy_title = "Gardien" if shadow.guardian else "Palier %d" % shadow.palier
    enemy_reaction = shadow.reaction_frames
    enemy_accuracy = shadow.accuracy


## Un duel de la Chasse : son rang (ou « Grand Veneur »), la vivacité de l'ombre et les bonus des deux camps.
## À appeler avant l'ajout à l'arbre, après configure.
func set_hunt_duel(hunt: Hunt, shadow: ShadowOpponent) -> void:
    set_shadow(shadow)
    enemy_title = "Duel %d/%d" % [hunt.index + 1, Hunt.LENGTH]
    if shadow.boss != &"":
        boss_id = shadow.boss
        enemy_title = Boss.display_name(shadow.boss)
        enemy_look = shadow.gear.look() if shadow.gear != null else {}
        enemy_look.merge(Boss.look(shadow.boss), true)
        enemy_scale = Boss.scale(shadow.boss)
    player_bonus = hunt.player_bonus()
    enemy_bonus = hunt.enemy_bonus()
    report_results = true
    forfeit_mode = true


## Nouveau match, mêmes chevaliers.
func replay() -> void:
    duel = Duel.new(player_knight, enemy_knight, player_gear, enemy_gear, player_bonus, enemy_bonus)
    _enemy = AiInput.new(AiBrain.new(Time.get_ticks_msec(), enemy_reaction, enemy_accuracy))
    _reported = false
    _enrage_announced = false
    moon_mark = {}
    moon_beam = {}
    _outcome = {-1: 0, 1: 0}
    _end_frames = 0
    _end_menu.hide()
    resume_duel()
    _flash("Manche 1", 80)


func request_home() -> void:
    home_requested.emit()


func pause_duel() -> void:
    _paused = true
    joystick.set_enabled(false)
    _pause_button.hide()
    _pause_menu.show()
    _resume_button.grab_focus()
    _hud.queue_redraw()


func resume_duel() -> void:
    _paused = false
    _reset_forfeit()
    joystick.set_enabled(true)
    _pause_menu.hide()
    _pause_button.visible = duel.state != Duel.State.MATCH_OVER
    _hud.queue_redraw()


func is_paused() -> bool:
    return _paused


func is_end_menu_visible() -> bool:
    return _end_menu.visible


func puppet(side: int) -> KnightPuppet:
    return _puppets[side]


## Retour Android ou Échap : met en pause, reprend, ou ramène à l'accueil une fois le match fini.
func go_back() -> bool:
    if _end_menu.visible:
        request_home()
    elif _paused:
        resume_duel()
    elif duel.state != Duel.State.MATCH_OVER:
        pause_duel()
    return true


## Position des pieds d'un chevalier à l'écran.
static func feet_position(f: Fighter) -> Vector2:
    return Vector2(ARENA_LEFT + f.x * PX_PER_MM, GROUND_Y - f.y * PX_PER_MM)


func _build_world() -> void:
    _world = Node2D.new()
    add_child(_world)
    var stage := ArenaStage.new()
    stage.ground_y = GROUND_Y
    stage.z_index = -10
    _world.add_child(stage)
    _fx = Node2D.new()
    _fx.z_index = -2
    _fx.draw.connect(_draw_fx)
    _world.add_child(_fx)
    _build_puppets()


func _build_puppets() -> void:
    for old: KnightPuppet in _puppets.values():
        old.queue_free()
    var mine := player_look if not player_look.is_empty() else (player_gear.look() if player_gear != null else {})
    _puppets[-1] = _make_puppet(player_knight, Palette.CYAN, mine)
    _puppets[1] = _make_enemy_puppet(enemy_knight)


## L'ombre, ou le seigneur avec sa silhouette et sa taille. Le Changeforme en change à chaque manche.
func _make_enemy_puppet(knight: KnightClass) -> KnightPuppet:
    var look := enemy_look if not enemy_look.is_empty() else (enemy_gear.look() if enemy_gear != null else {})
    if knight != enemy_knight:
        look = Boss.look(boss_id)
    var made := _make_puppet(knight, Palette.FOE_RED, look)
    made.base_scale = enemy_scale
    return made


func _make_puppet(knight: KnightClass, accent: Color, look: Dictionary) -> KnightPuppet:
    var puppet := KnightPuppet.new()
    var rims: Array[Vector2] = [Vector2.ZERO]
    puppet.setup(knight.id, accent, rims, true, look)
    _world.add_child(puppet)
    return puppet


func _update_puppets() -> void:
    if duel.right.knight.id != _puppets[1].knight_id: ## le Changeforme a changé de chevalier
        _puppets[1].queue_free()
        _puppets[1] = _make_enemy_puppet(duel.right.knight)
    var moon := _world.to_global(ArenaStage.MOON_CENTER)
    for side: int in _puppets:
        var f := duel.fighter(side)
        var puppet: KnightPuppet = _puppets[side]
        puppet.follow(f, feet_position(f), _outcome[side])
        puppet.light_from(moon, RIM_DISTANCE)


func _update_end_menu() -> void:
    _end_frames += 1
    if _end_frames < END_MENU_DELAY:
        return
    if report_results:
        if not _reported:
            _reported = true
            match_finished.emit(duel.match_winner < 0)
        return
    if not _end_menu.visible:
        _end_menu.show()
        _pause_button.hide()
        joystick.set_enabled(false)
        _replay_button.grab_focus()
    if Input.is_action_just_pressed("frappe"):
        replay()


func _read_events() -> void:
    for event: Dictionary in duel.events:
        match event["type"]:
            "round_start":
                _outcome = {-1: 0, 1: 0}
                _flash("Manche %d" % event["round"], 80)
            "fight_start":
                _flash("Combattez !", 45)
            "ultimate":
                _flash(duel.fighter(event["side"]).ultimate.display_name, 50)
            "hit":
                _impact(-event["side"], event["side"], IMPACT_STRENGTH.get(event["action"], 4.0))
            "blocked":
                _spark(_puppets[event["side"]].chest_global(), Palette.SILVER, 8)
                _shake = maxf(_shake, BLOCK_STRENGTH)
                _flash("Paré !", 35)
            "guard_break":
                _impact(-event["side"], event["side"], GUARD_BREAK_STRENGTH)
                _flash("Garde brisée !", 40)
            "round_end":
                var winner: int = event["winner"]
                if winner != 0:
                    _outcome = {winner: 1, -winner: -1}
                _flash(_round_text(winner), 110)
            "match_end":
                _flash("Victoire" if event["winner"] < 0 else "Défaite", 1_000_000)
            "shield":
                _spark(_puppets[event["side"]].chest_global(), Palette.SILVER, 14)
                _shake = maxf(_shake, BLOCK_STRENGTH)
                _flash("Égide !" if event["left"] > 0 else "L'égide se brise !", 40)
            "thorns":
                _spark(_puppets[-event["side"]].chest_global(), Palette.FOE_RED, 8)
            "lifesteal":
                _spark(_puppets[event["side"]].chest_global(), Palette.FOE_RED, 6)
            "poison":
                _spark(_puppets[-event["side"]].chest_global(), Palette.VENOM, 10)
            "moon_warning":
                moon_mark = {"x": event["x"], "frames": Boss.MOON_WARNING}
            "moon_strike":
                moon_mark = {}
                moon_beam = {"x": event["x"], "frames": 16}
                _shake = maxf(_shake, 9.0 if event["hit"] else 4.0)
                if event["hit"]:
                    _puppets[-event["side"]].flash()


## Un coup porté : le pantin touché blanchit, des étincelles de la couleur de l'attaquant, l'écran tremble.
func _impact(defender_side: int, attacker_side: int, strength: float) -> void:
    var defender: KnightPuppet = _puppets[defender_side]
    var attacker: KnightPuppet = _puppets[attacker_side]
    defender.flash()
    _spark(defender.chest_global(), attacker.accent, int(10 + strength * 2))
    _shake = maxf(_shake, strength)


func _spark(at_global: Vector2, color: Color, amount: int) -> void:
    var sparks := CPUParticles2D.new()
    sparks.position = _world.to_local(at_global)
    sparks.z_index = 3
    sparks.one_shot = true
    sparks.explosiveness = 1.0
    sparks.amount = amount
    sparks.lifetime = 0.35
    sparks.spread = 180.0
    sparks.initial_velocity_min = 120.0
    sparks.initial_velocity_max = 280.0
    sparks.gravity = Vector2(0, 420)
    sparks.scale_amount_min = 2.0
    sparks.scale_amount_max = 4.0
    var fade := Gradient.new()
    fade.set_color(0, Color.WHITE.lerp(color, 0.4))
    fade.set_color(1, Color(color, 0.0))
    sparks.color_ramp = fade
    sparks.finished.connect(sparks.queue_free)
    _world.add_child(sparks)
    sparks.emitting = true


## Les seigneurs qui changent en cours de duel : la Furie s'éveille sous la moitié de sa vie.
func _watch_boss() -> void:
    if not _enrage_announced and duel.right.is_enraged():
        _enrage_announced = true
        _flash("Furie !", 50)
        _shake = maxf(_shake, 6.0)


func _tick_moon_fx() -> void:
    if not moon_mark.is_empty():
        moon_mark["frames"] -= 1
        if moon_mark["frames"] <= 0:
            moon_mark = {}
    if not moon_beam.is_empty():
        moon_beam["frames"] -= 1
        if moon_beam["frames"] <= 0:
            moon_beam = {}


func _update_shake() -> void:
    if _shake < 0.3:
        _shake = 0.0
        _world.position = Vector2.ZERO
        return
    _world.position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake
    _shake *= SHAKE_DECAY


## Sous les pantins : les ombres au sol, les traits de vitesse d'une esquive, la marque et l'impact de la lune.
func _draw_fx() -> void:
    _draw_moon_strike()
    for side: int in _puppets:
        var f := duel.fighter(side)
        var feet := feet_position(f)
        var width: float = KnightBuild.spec(f.knight.id)["hip_w"] * 1.5
        var shrink := clampf(1.0 - f.y / 3000.0, 0.4, 1.0)
        _fx.draw_set_transform(Vector2(feet.x, GROUND_Y + 3), 0.0, Vector2(1.0, 0.2))
        _fx.draw_circle(Vector2.ZERO, width * shrink, Color(Palette.SILHOUETTE, 0.45))
        _fx.draw_set_transform(Vector2.ZERO)
        if f.action == CombatAction.Kind.ULTIME and f.ultimate.ground_only and f.phase == Fighter.Phase.ACTIVE:
            _draw_shockwave(f, feet, _puppets[side].accent)
        if f.is_invulnerable():
            var accent: Color = _puppets[side].accent
            for i in 3:
                var y := feet.y - 40.0 - i * 40.0
                var x := feet.x - f.move_dir * (30.0 + i * 8.0)
                _fx.draw_line(Vector2(x, y), Vector2(x - f.move_dir * 60.0, y), Color(accent, 0.45 - i * 0.1), 3.0)


## La marque de la Prêtresse : une ellipse rouge qui se resserre au sol ; puis une colonne de lumière de lune.
func _draw_moon_strike() -> void:
    var radius := Boss.MOON_RADIUS * PX_PER_MM
    if not moon_mark.is_empty():
        var x: float = ARENA_LEFT + moon_mark["x"] * PX_PER_MM
        var urgency := 1.0 - float(moon_mark["frames"]) / Boss.MOON_WARNING
        _fx.draw_set_transform(Vector2(x, GROUND_Y + 2), 0.0, Vector2(1.0, 0.18))
        _fx.draw_circle(Vector2.ZERO, radius, Color(Palette.FOE_RED, 0.25 + 0.35 * urgency))
        _fx.draw_arc(Vector2.ZERO, radius * (1.5 - 0.5 * urgency), 0, TAU, 40, Palette.RIM, 9.0)
        _fx.draw_set_transform(Vector2.ZERO)
        _fx.draw_rect(Rect2(x - radius * 0.5, 0, radius, GROUND_Y), Color(Palette.FOE_RED, 0.18 * urgency))
    if not moon_beam.is_empty():
        var bx: float = ARENA_LEFT + moon_beam["x"] * PX_PER_MM
        var fade: float = moon_beam["frames"] / 16.0
        _fx.draw_rect(Rect2(bx - radius * 0.6, 0, radius * 1.2, GROUND_Y), Color(Palette.RIM, 0.55 * fade))
        _fx.draw_rect(Rect2(bx - radius * 0.2, 0, radius * 0.4, GROUND_Y), Color(Palette.INK, 0.6 * fade))


## L'onde du Séisme court au sol jusqu'à sa portée : on la voit venir, on saute par-dessus.
func _draw_shockwave(f: Fighter, feet: Vector2, accent: Color) -> void:
    var active: int = f.stat(CombatAction.Kind.ULTIME, "active")
    var progress := 1.0 - float(f.phase_frames) / maxf(active, 1.0)
    var reach := f.stat(CombatAction.Kind.ULTIME, "reach") * PX_PER_MM * clampf(progress * 1.6, 0.2, 1.0)
    var steps := 9
    for i in steps:
        var x := feet.x + f.facing() * reach * (i + 1) / steps
        var height := 10.0 + 22.0 * (1.0 - float(i) / steps)
        _fx.draw_line(Vector2(x, GROUND_Y), Vector2(x - f.facing() * 6.0, GROUND_Y - height), Color(accent, 0.85 - i * 0.07), 4.0)


func _round_text(winner: int) -> String:
    if winner < 0:
        return "Manche pour toi"
    if winner > 0:
        return "Manche pour l'ombre"
    return "Égalité, on rejoue la manche"


func _flash(text: String, frames: int) -> void:
    message = text
    message_frames = frames


func _create_touch_buttons() -> void:
    for spec: Dictionary in BUTTONS:
        var shape := CircleShape2D.new()
        shape.radius = spec["radius"]
        var button := TouchScreenButton.new()
        button.shape = shape
        button.position = spec["pos"]
        button.action = spec["action"]
        button.passby_press = spec.get("passby", false)
        button.set_meta("spec", spec)
        add_child(button)
        touch_buttons.append(button)


func _create_end_menu() -> void:
    _end_menu = _make_menu()
    _replay_button = UiStyle.make_button("Rejouer", true, END_BUTTON_SIZE)
    _replay_button.pressed.connect(replay)
    _end_menu.add_child(_replay_button)
    _end_menu.add_child(_make_home_button())


func _create_pause_controls() -> void:
    _pause_button = UiStyle.make_button("II", false, PAUSE_BUTTON_SIZE)
    _pause_button.position = Vector2((VIEW.x - PAUSE_BUTTON_SIZE.x) / 2, 128)
    _pause_button.z_index = 55
    _pause_button.focus_mode = Control.FOCUS_NONE ## sinon Espace (esquive) le déclencherait
    _pause_button.accessibility_name = "Pause"
    _pause_button.pressed.connect(pause_duel)
    add_child(_pause_button)
    _pause_menu = _make_menu()
    _resume_button = UiStyle.make_button("Reprendre", true, END_BUTTON_SIZE)
    _resume_button.pressed.connect(resume_duel)
    _pause_menu.add_child(_resume_button)
    if forfeit_mode:
        _forfeit_button = UiStyle.make_button("Abandonner", false, END_BUTTON_SIZE)
        _forfeit_button.pressed.connect(request_forfeit)
        _pause_menu.add_child(_forfeit_button)
    else:
        _pause_menu.add_child(_make_home_button())


## En Chasse, quitter le duel l'abandonne : la première touche demande confirmation.
func request_forfeit() -> void:
    if not _confirming_forfeit:
        _confirming_forfeit = true
        _forfeit_button.text = "Confirmer ?"
        _forfeit_button.add_theme_stylebox_override("normal", UiStyle.box(Palette.DUSK, Palette.LOSS, 3))
        return
    forfeit_requested.emit()


func is_confirming_forfeit() -> bool:
    return _confirming_forfeit


func _reset_forfeit() -> void:
    if _forfeit_button == null or not _confirming_forfeit:
        return
    _confirming_forfeit = false
    _forfeit_button.text = "Abandonner"
    _forfeit_button.add_theme_stylebox_override("normal", UiStyle.box(Palette.DUSK, Palette.QUIET))


func _make_menu() -> VBoxContainer:
    var menu := VBoxContainer.new()
    menu.add_theme_constant_override("separation", 16)
    menu.position = Vector2((VIEW.x - END_BUTTON_SIZE.x) / 2, 290)
    menu.z_index = 60
    menu.hide()
    add_child(menu)
    return menu


func _make_home_button() -> Button:
    var button := UiStyle.make_button("Accueil", false, END_BUTTON_SIZE)
    button.pressed.connect(request_home)
    return button
