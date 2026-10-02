class_name ArenaStage
extends Node2D
## Le décor du duel : les ruines sous la lune rouge, des braises qui montent.
## Tout reste désaturé et en valeur moyenne derrière les combattants : jamais de noir sur noir, même au soleil.

const VIEW := Vector2(1280, 720)
const MOON_CENTER := Vector2(640, 250)
const MOON_RADIUS := 150.0
const RUINS := Color("#26162f") ## plus sombre que le ciel, bien plus clair que le noir des chevaliers

var ground_y := 470.0


func _ready() -> void:
    add_child(_make_embers())


func _draw() -> void:
    _gradient(0.0, ground_y * 0.55, Palette.NIGHT, Palette.DUSK)
    _gradient(ground_y * 0.55, ground_y, Palette.DUSK, Palette.PURPLE)
    draw_circle(MOON_CENTER, MOON_RADIUS + 60, Color(Palette.MOON, 0.07))
    draw_circle(MOON_CENTER, MOON_RADIUS + 26, Color(Palette.MOON, 0.12))
    draw_circle(MOON_CENTER, MOON_RADIUS, Color(Palette.MOON, 0.85))
    _draw_ruins()
    draw_rect(Rect2(0, ground_y, VIEW.x, VIEW.y - ground_y), Palette.NEAREST_SET)
    draw_line(Vector2(0, ground_y), Vector2(VIEW.x, ground_y), Color(Palette.PURPLE, 0.9), 2.0)


## Colonnes brisées et une arche, posées sur l'horizon.
func _draw_ruins() -> void:
    var base := ground_y
    for column: Array in [[70.0, 34.0, 210.0], [250.0, 30.0, 150.0], [1060.0, 32.0, 190.0], [1215.0, 38.0, 250.0]]:
        var x: float = column[0]
        var width: float = column[1]
        var height: float = column[2]
        draw_colored_polygon(PackedVector2Array([
            Vector2(x - width / 2, base), Vector2(x + width / 2, base),
            Vector2(x + width / 2, base - height + 12), Vector2(x + width * 0.1, base - height),
            Vector2(x - width / 2, base - height + 22),
        ]), RUINS)
        draw_rect(Rect2(x - width / 2 - 6, base - 14, width + 12, 14), RUINS)
    var arch := PackedVector2Array([Vector2(788, base)])
    for i in 13:
        arch.append(Vector2(905, base - 135) + Vector2(cos(PI + PI * i / 12.0) * 117, sin(PI + PI * i / 12.0) * 70))
    arch.append_array([Vector2(1022, base), Vector2(1000, base)])
    for i in 13:
        arch.append(Vector2(905, base - 120) + Vector2(cos(TAU - PI * i / 12.0) * 95, sin(TAU - PI * i / 12.0) * 70))
    arch.append(Vector2(810, base))
    draw_colored_polygon(arch, RUINS)


func _gradient(top: float, bottom: float, from: Color, to: Color) -> void:
    var points := PackedVector2Array([Vector2(0, top), Vector2(VIEW.x, top), Vector2(VIEW.x, bottom), Vector2(0, bottom)])
    draw_polygon(points, PackedColorArray([from, from, to, to]))


func _make_embers() -> CPUParticles2D:
    var embers := CPUParticles2D.new()
    embers.position = Vector2(VIEW.x / 2, ground_y)
    embers.amount = 30
    embers.lifetime = 5.0
    embers.preprocess = 5.0
    embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
    embers.emission_rect_extents = Vector2(VIEW.x / 2, 6)
    embers.direction = Vector2(0, -1)
    embers.spread = 25.0
    embers.gravity = Vector2(5, -8)
    embers.initial_velocity_min = 15.0
    embers.initial_velocity_max = 40.0
    embers.scale_amount_min = 2.0
    embers.scale_amount_max = 3.5
    var fade := Gradient.new()
    fade.set_color(0, Palette.EMBER)
    fade.set_color(1, Color(Palette.MOON, 0.0))
    embers.color_ramp = fade
    return embers
