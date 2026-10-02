class_name HomeScreen
extends Control
## Écran d'accueil de la planche : le chevalier actif devant la lune rouge, « Jouer », « Chasse » et « Chevaliers ».
## Sous son nom : le palier du Chemin des ombres qui l'attend, et sa puissance. Une Chasse en cours se lit sur son bouton.

signal play_requested
signal knights_requested
signal hunt_requested

const VIEW := Vector2(1280, 720)
const HORIZON_Y := 575.0
const MOON_CENTER := Vector2(640, 352)
const MOON_RADIUS := 196.0
const KNIGHT_SCALE := 1.45
const PLAY_SIZE := Vector2(340, 88)
const KNIGHTS_SIZE := Vector2(300, 72)
const HUNT_SIZE := Vector2(340, 72)
const HUNT_GAP := 16.0
const BUTTONS_CENTER_Y := 640.0
const SIDE_MARGIN := 48.0

var knight: KnightClass
var look: Dictionary ## l'équipement porté, sur la silhouette
var palier: int
var power: int
var hunt_step := 0 ## le duel à disputer de la Chasse en cours (1 à 7), 0 sans Chasse
var _puppet: KnightPuppet


func _init(p_knight: KnightClass = null, p_look: Dictionary = {}, p_palier: int = 1, p_power: int = PowerBudget.BASE_POWER,
        p_hunt_step: int = 0) -> void:
    knight = p_knight if p_knight != null else KnightClass.starter()
    look = p_look
    palier = p_palier
    power = p_power
    hunt_step = p_hunt_step


## « Chasse », ou « Chasse · 3/7 » quand une Chasse attend.
func hunt_label() -> String:
    return "Chasse · %d/%d" % [hunt_step, Hunt.LENGTH] if hunt_step > 0 else "Chasse"


## « Palier 3 · Puissance 112 », ou « Gardien du palier 5 · Puissance 130 ».
func path_line() -> String:
    var where := "Gardien du palier %d" % palier if ShadowPath.is_guardian(palier) else "Palier %d" % palier
    return "%s · Puissance %d" % [where, power]


func _ready() -> void:
    InputBindings.register()
    set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(_make_embers())
    _puppet = _make_puppet()
    add_child(_puppet)
    var play := UiStyle.make_button("Jouer", true, PLAY_SIZE)
    play.position = Vector2(VIEW.x - PLAY_SIZE.x - SIDE_MARGIN, BUTTONS_CENTER_Y - PLAY_SIZE.y / 2)
    play.pressed.connect(play_requested.emit)
    add_child(play)
    var hunt := UiStyle.make_button(hunt_label(), false, HUNT_SIZE)
    hunt.position = Vector2(play.position.x, play.position.y - HUNT_SIZE.y - HUNT_GAP)
    hunt.pressed.connect(hunt_requested.emit)
    add_child(hunt)
    var knights := UiStyle.make_button("Chevaliers", false, KNIGHTS_SIZE)
    knights.position = Vector2(SIDE_MARGIN, BUTTONS_CENTER_Y - KNIGHTS_SIZE.y / 2)
    knights.pressed.connect(knights_requested.emit)
    add_child(knights)
    play.grab_focus.call_deferred()


## L'accueil est le premier écran : le retour ne mène nulle part ailleurs.
func go_back() -> bool:
    return false


func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("frappe"):
        play_requested.emit()
        get_viewport().set_input_as_handled()


func _draw() -> void:
    _draw_sky()
    _draw_moon()
    draw_rect(Rect2(0, HORIZON_Y, VIEW.x, VIEW.y - HORIZON_Y), Palette.NEAREST_SET)
    draw_string(UiStyle.TITLE_FONT, Vector2(0, 108), "Sanglune", HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 104, Palette.INK)
    draw_string(UiStyle.TEXT_FONT, Vector2(0, 146), "La lune ne se couche plus.", HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 26, Palette.QUIET)
    draw_string(UiStyle.TEXT_FONT, Vector2(0, HORIZON_Y + 64), knight.display_name, HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 30, Palette.INK)
    draw_string(UiStyle.TEXT_FONT, Vector2(0, HORIZON_Y + 96), path_line(), HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 21, Palette.QUIET)


## Dégradé de la planche : violet nuit en haut, pourpre vers l'horizon.
func _draw_sky() -> void:
    var middle := HORIZON_Y * 0.5
    _vertical_gradient(0.0, middle, Palette.NIGHT, Palette.DUSK)
    _vertical_gradient(middle, HORIZON_Y, Palette.DUSK, Palette.PURPLE)


func _vertical_gradient(top: float, bottom: float, from: Color, to: Color) -> void:
    var points := PackedVector2Array([Vector2(0, top), Vector2(VIEW.x, top), Vector2(VIEW.x, bottom), Vector2(0, bottom)])
    draw_polygon(points, PackedColorArray([from, from, to, to]))


func _draw_moon() -> void:
    draw_circle(MOON_CENTER, MOON_RADIUS + 70, Color(Palette.MOON, 0.07))
    draw_circle(MOON_CENTER, MOON_RADIUS + 34, Color(Palette.MOON, 0.12))
    draw_circle(MOON_CENTER, MOON_RADIUS, Palette.MOON)


## Le chevalier en pantin qui respire, noir pur sur la lune : la lune derrière lui dessine un liseré tout autour.
func _make_puppet() -> KnightPuppet:
    var puppet := KnightPuppet.new()
    var halo: Array[Vector2] = [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2)]
    puppet.setup(knight.id, Palette.CYAN, halo, true, look)
    puppet.position = Vector2(VIEW.x / 2, HORIZON_Y)
    puppet.scale = Vector2.ONE * KNIGHT_SCALE
    puppet.z_index = 5
    puppet.auto_idle = true
    return puppet


## Braises qui montent de l'horizon, comme sur la planche.
func _make_embers() -> CPUParticles2D:
    var embers := CPUParticles2D.new()
    embers.position = Vector2(VIEW.x / 2, HORIZON_Y)
    embers.amount = 40
    embers.lifetime = 6.0
    embers.preprocess = 6.0
    embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
    embers.emission_rect_extents = Vector2(VIEW.x / 2, 8)
    embers.direction = Vector2(0, -1)
    embers.spread = 25.0
    embers.gravity = Vector2(6, -10)
    embers.initial_velocity_min = 18.0
    embers.initial_velocity_max = 48.0
    embers.scale_amount_min = 2.0
    embers.scale_amount_max = 4.0
    var fade := Gradient.new()
    fade.set_color(0, Palette.EMBER)
    fade.set_color(1, Color(Palette.MOON, 0.0))
    embers.color_ramp = fade
    return embers
