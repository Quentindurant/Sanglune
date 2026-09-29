class_name Arena
extends Node2D
## Scène du prototype gris : fait tourner le Duel à 60 frames par seconde et le dessine en formes simples.
## La logique de combat vit dans src/domain ; ici on affiche et on relaie les entrées.

signal change_knight_requested

const VIEW := Vector2(1280, 720)
const PX_PER_MM := 0.09
const ARENA_LEFT := 190.0
const GROUND_Y := 470.0
const END_MENU_DELAY := 45 ## frames avant d'afficher la fin de match, pour ne pas relancer en martelant Frappe
const END_BUTTON_SIZE := Vector2(360, 72)

const STUNNED := Color("#3a2a44")
const TELEGRAPH := Color("#ffd166") ## couleur de prototype : un coup se prépare

## Hauteur de l'arme au-dessus du sol, en pixels, selon l'attaque.
const WEAPON_HEIGHT := {
    CombatAction.Kind.FRAPPE: 125.0,
    CombatAction.Kind.ESTOC: 90.0,
    CombatAction.Kind.RUNE: 105.0,
}

## Boutons tactiles : ils déclenchent les mêmes actions que le clavier.
const BUTTONS := [
    {"action": "move_left", "label": "<", "pos": Vector2(120, 640), "radius": 54.0},
    {"action": "move_right", "label": ">", "pos": Vector2(250, 640), "radius": 54.0},
    {"action": "parade", "label": "Parade", "pos": Vector2(1180, 530), "radius": 48.0},
    {"action": "rune", "label": "Rune", "pos": Vector2(1055, 540), "radius": 42.0},
    {"action": "estoc", "label": "Estoc", "pos": Vector2(1040, 660), "radius": 48.0},
    {"action": "frappe", "label": "Frappe", "pos": Vector2(1170, 650), "radius": 58.0},
]

const KEYBOARD_HELP := "Clavier : Q/D ou flèches, J Frappe, K Estoc, L Parade, I Rune"
const END_KEYBOARD_HELP := "Clavier : J pour rejouer, Échap pour changer de chevalier"

var player_knight: KnightClass
var enemy_knight: KnightClass
var duel: Duel
var _player: IntentSource = PlayerInput.new()
var _enemy: IntentSource
var _buttons: Array[TouchScreenButton] = []
var _end_menu: VBoxContainer
var _replay_button: Button
var _end_frames := 0
var _message := ""
var _message_frames := 0
var _font: Font


## À appeler avant d'ajouter la scène à l'arbre. Sans appel, le Veilleur affronte un chevalier au hasard.
func configure(p_player_knight: KnightClass, p_enemy_knight: KnightClass) -> void:
    player_knight = p_player_knight
    enemy_knight = p_enemy_knight


func _ready() -> void:
    InputBindings.register()
    _font = ThemeDB.fallback_font
    if player_knight == null:
        player_knight = KnightClass.starter()
    if enemy_knight == null:
        var rng := RandomNumberGenerator.new()
        rng.randomize()
        enemy_knight = KnightClass.pick_random(rng)
    _create_touch_buttons()
    _create_end_menu()
    replay()


func _physics_process(_delta: float) -> void:
    if duel.state == Duel.State.MATCH_OVER:
        _update_end_menu()
    else:
        var left_intent := _player.next_intent(duel.left, duel.right)
        var right_intent := _enemy.next_intent(duel.right, duel.left)
        duel.step(left_intent, right_intent)
        _read_events()
    if _message_frames > 0:
        _message_frames -= 1
    queue_redraw()


## Nouveau match, mêmes chevaliers.
func replay() -> void:
    duel = Duel.new(player_knight, enemy_knight)
    _enemy = AiInput.new(AiBrain.new(Time.get_ticks_msec()))
    _end_frames = 0
    _end_menu.hide()
    _flash("Manche 1", 80)


func request_knight_change() -> void:
    change_knight_requested.emit()


func is_end_menu_visible() -> bool:
    return _end_menu.visible


func _update_end_menu() -> void:
    _end_frames += 1
    if _end_frames < END_MENU_DELAY:
        return
    if not _end_menu.visible:
        _end_menu.show()
        _replay_button.grab_focus()
    if Input.is_action_just_pressed("frappe"):
        replay()
    elif Input.is_action_just_pressed("ui_cancel"):
        request_knight_change()


func _create_touch_buttons() -> void:
    for spec: Dictionary in BUTTONS:
        var shape := CircleShape2D.new()
        shape.radius = spec["radius"]
        var button := TouchScreenButton.new()
        button.shape = shape
        button.position = spec["pos"]
        button.action = spec["action"]
        button.set_meta("spec", spec)
        add_child(button)
        _buttons.append(button)


func _create_end_menu() -> void:
    _end_menu = VBoxContainer.new()
    _end_menu.add_theme_constant_override("separation", 16)
    _end_menu.position = Vector2((VIEW.x - END_BUTTON_SIZE.x) / 2, 290)
    _replay_button = UiStyle.make_button("Rejouer", true, END_BUTTON_SIZE)
    _replay_button.pressed.connect(replay)
    _end_menu.add_child(_replay_button)
    var change_button := UiStyle.make_button("Changer de chevalier", false, END_BUTTON_SIZE)
    change_button.pressed.connect(request_knight_change)
    _end_menu.add_child(change_button)
    _end_menu.hide()
    add_child(_end_menu)


func _read_events() -> void:
    for event: Dictionary in duel.events:
        match event["type"]:
            "round_start":
                _flash("Manche %d" % event["round"], 80)
            "fight_start":
                _flash("Combattez !", 45)
            "blocked":
                _flash("Paré !", 35)
            "guard_break":
                _flash("Garde brisée !", 40)
            "round_end":
                _flash(_round_text(event["winner"]), 110)
            "match_end":
                _flash("Victoire" if event["winner"] < 0 else "Défaite", 1_000_000)


func _round_text(winner: int) -> String:
    if winner < 0:
        return "Manche pour toi"
    if winner > 0:
        return "Manche pour l'ombre"
    return "Égalité, on rejoue la manche"


func _flash(text: String, frames: int) -> void:
    _message = text
    _message_frames = frames


func _to_px(x_mm: int) -> float:
    return ARENA_LEFT + x_mm * PX_PER_MM


func _draw() -> void:
    _draw_stage()
    _draw_fighter(duel.left, Palette.CYAN)
    _draw_fighter(duel.right, Palette.FOE_RED)
    _draw_hud()
    _draw_buttons()
    if _end_menu.visible:
        draw_rect(Rect2(Vector2.ZERO, VIEW), Color(Palette.NIGHT, 0.65)) ## voile derrière le menu de fin
        _draw_help(END_KEYBOARD_HELP)
    if _message_frames > 0:
        draw_string(_font, Vector2(0, 240), _message, HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 44, Palette.INK)


## Fond en valeur moyenne derrière les combattants : jamais de noir sur noir, même au soleil.
func _draw_stage() -> void:
    draw_rect(Rect2(Vector2.ZERO, VIEW), Palette.DUSK)
    draw_circle(Vector2(VIEW.x / 2, 250), 170, Color(Palette.MOON, 0.35))
    draw_rect(Rect2(0, GROUND_Y, VIEW.x, VIEW.y - GROUND_Y), Palette.NEAREST_SET)
    draw_line(Vector2(_to_px(Duel.ARENA_MIN), GROUND_Y), Vector2(_to_px(Duel.ARENA_MAX), GROUND_Y), Color(Palette.QUIET, 0.5), 2.0)


func _draw_fighter(f: Fighter, accent: Color) -> void:
    var cx := _to_px(f.x)
    var dir := float(f.facing())
    var body := KnightLook.body_rect(f.knight.id, Vector2(cx, GROUND_Y))
    var stunned := f.phase == Fighter.Phase.STUNNED
    var fill := STUNNED if stunned else Palette.SILHOUETTE
    if f.action == CombatAction.Kind.NONE:
        KnightLook.draw_idle_weapon(self, f.knight.id, body, dir, 1.0, KnightLook.STEEL)
    KnightLook.draw_helmet(self, f.knight.id, body, dir, 1.0, fill)
    draw_rect(body, fill)
    var outline := TELEGRAPH if f.phase == Fighter.Phase.STARTUP else accent
    draw_rect(body, outline, false, 3.0)
    draw_rect(KnightLook.eye_rect(body, dir), accent)
    _draw_weapon(f, cx, body, accent)
    var label: String = "Étourdi" if stunned else CombatAction.LABELS[f.action]
    draw_string(_font, Vector2(cx - 80, GROUND_Y + 30), label, HORIZONTAL_ALIGNMENT_CENTER, 160, 18, Palette.QUIET)


func _draw_weapon(f: Fighter, cx: float, body: Rect2, accent: Color) -> void:
    if f.action == CombatAction.Kind.NONE:
        return
    var dir := float(f.facing())
    if f.action == CombatAction.Kind.PARADE:
        if f.phase == Fighter.Phase.ACTIVE:
            var shield_x := cx + dir * (body.size.x / 2 + 8) - 5
            draw_rect(Rect2(shield_x, GROUND_Y - 150, 10, 110), accent)
        return
    var reach_px := f.stat(f.action, "reach") * PX_PER_MM
    var height: float = WEAPON_HEIGHT[f.action]
    var start := Vector2(cx + dir * body.size.x / 2, GROUND_Y - height)
    var end := Vector2(cx + dir * reach_px, GROUND_Y - height)
    match f.phase:
        Fighter.Phase.STARTUP:
            draw_line(start, end, Color(TELEGRAPH, 0.35), 2.0)
        Fighter.Phase.ACTIVE:
            draw_line(start, end, accent, 10.0 if f.action == CombatAction.Kind.RUNE else 6.0)
        Fighter.Phase.RECOVERY:
            draw_line(start, end, Color(accent, 0.25), 4.0)


func _draw_hud() -> void:
    _draw_side_hud(duel.left, Vector2(40, 30), false, "Toi · " + player_knight.display_name, Palette.SILVER, Palette.CYAN)
    _draw_side_hud(duel.right, Vector2(820, 30), true, "L'ombre · " + enemy_knight.display_name, Palette.FOE_RED, Palette.FOE_RED)
    var center := Vector2(VIEW.x / 2, 62)
    draw_circle(center, 32, Color(Palette.SILHOUETTE, 0.8))
    draw_arc(center, 32, 0, TAU, 48, Palette.MOON, 2.0)
    draw_string(_font, Vector2(center.x - 40, center.y + 10), str(duel.seconds_left()), HORIZONTAL_ALIGNMENT_CENTER, 80, 28, Palette.INK)
    for i in Duel.ROUNDS_TO_WIN:
        _draw_pip(Vector2(center.x - 22 - i * 18, 112), duel.wins[-1] > i, Palette.SILVER)
        _draw_pip(Vector2(center.x + 22 + i * 18, 112), duel.wins[1] > i, Palette.FOE_RED)
    if not _end_menu.visible:
        _draw_help(KEYBOARD_HELP)


func _draw_help(text: String) -> void:
    draw_string(_font, Vector2(330, 708), text, HORIZONTAL_ALIGNMENT_CENTER, 620, 15, Color(Palette.QUIET, 0.7))


func _draw_side_hud(f: Fighter, origin: Vector2, mirrored: bool, name_text: String, bar: Color, rune_color: Color) -> void:
    var width := 420.0
    var align := HORIZONTAL_ALIGNMENT_RIGHT if mirrored else HORIZONTAL_ALIGNMENT_LEFT
    draw_string(_font, origin, name_text, align, width, 20, Palette.INK)
    var frame := Rect2(origin.x, origin.y + 10, width, 18)
    draw_rect(frame, Color(Palette.SILHOUETTE, 0.7))
    var fill_w := width * f.hp / float(f.max_hp())
    var fill_x := origin.x + width - fill_w if mirrored else origin.x
    draw_rect(Rect2(fill_x, frame.position.y, fill_w, frame.size.y), bar)
    draw_rect(frame, Color(Palette.INK, 0.5), false, 1.0)
    for i in Fighter.MAX_RUNE:
        var seg_x := origin.x + width - 48 - i * 54 if mirrored else origin.x + i * 54
        var color := rune_color if i < f.rune else Color(rune_color, 0.2)
        draw_rect(Rect2(seg_x, origin.y + 36, 48, 8), color)


func _draw_pip(pos: Vector2, filled: bool, color: Color) -> void:
    var points := PackedVector2Array([pos + Vector2(0, -6), pos + Vector2(6, 0), pos + Vector2(0, 6), pos + Vector2(-6, 0)])
    if filled:
        draw_colored_polygon(points, color)
    else:
        points.append(points[0])
        draw_polyline(points, Color(color, 0.6), 1.5)


func _draw_buttons() -> void:
    for button in _buttons:
        var spec: Dictionary = button.get_meta("spec")
        var center: Vector2 = spec["pos"]
        var radius: float = spec["radius"]
        var pressed := button.is_pressed()
        draw_circle(center, radius, Color(Palette.SILHOUETTE, 0.75 if pressed else 0.45))
        draw_arc(center, radius, 0, TAU, 48, Color(Palette.INK, 0.9 if pressed else 0.45), 2.0)
        if spec["action"] == "rune":
            var charge := duel.left.rune / float(Fighter.MAX_RUNE)
            if charge > 0.0:
                draw_arc(center, radius + 5, -PI / 2, -PI / 2 + TAU * charge, 48, Palette.CYAN, 3.0)
        draw_string(_font, Vector2(center.x - radius, center.y + 7), spec["label"], HORIZONTAL_ALIGNMENT_CENTER, radius * 2, 20, Palette.INK)
