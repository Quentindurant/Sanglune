class_name KnightCard
extends Button
## Carte d'un chevalier sur l'écran de choix : silhouette, arme, notes, atout et point faible.
## Toute la carte se touche ; la carte choisie s'entoure de cyan, la couleur de ton chevalier.

const CARD_SIZE := Vector2(268, 460)
const FEET_Y := 206.0
const SILHOUETTE_SCALE := 0.7
const PIP_SIZE := Vector2(16, 10)
const PIP_GAP := 5.0
const SIDE_MARGIN := 20.0

var knight: KnightClass
var _puppet: KnightPuppet


func _init(p_knight: KnightClass) -> void:
    knight = p_knight
    toggle_mode = true
    focus_mode = Control.FOCUS_NONE ## le clavier passe par Q/D ; le focus reste sur « Combattre »
    custom_minimum_size = CARD_SIZE
    size = CARD_SIZE
    accessibility_name = "%s, %s. Atout : %s. Point faible : %s." % [knight.display_name, knight.weapon, knight.strength, knight.weakness]
    add_theme_stylebox_override("normal", UiStyle.box(Palette.DUSK, Palette.PURPLE))
    add_theme_stylebox_override("hover", UiStyle.box(Palette.DUSK.lightened(0.06), Palette.QUIET))
    add_theme_stylebox_override("pressed", UiStyle.box(Palette.DUSK.lightened(0.1), Palette.CYAN, 4))
    add_theme_stylebox_override("hover_pressed", UiStyle.box(Palette.DUSK.lightened(0.14), Palette.CYAN, 4))
    _puppet = KnightPuppet.new()
    var rim: Array[Vector2] = [Vector2(-3, -3)]
    _puppet.setup(knight.id, Palette.CYAN, rim)
    _puppet.position = Vector2(CARD_SIZE.x / 2, FEET_Y)
    _puppet.scale = Vector2.ONE * SILHOUETTE_SCALE
    _puppet.z_index = 5
    add_child(_puppet)


## La carte choisie fait respirer son chevalier ; les autres restent en garde.
func set_animated(animated: bool) -> void:
    _puppet.auto_idle = animated
    if not animated:
        _puppet.show_pose(KnightPose.GUARD)


func _draw() -> void:
    var font := UiStyle.TEXT_FONT
    var width := size.x
    _draw_silhouette(Vector2(width / 2, FEET_Y))
    draw_string(font, Vector2(0, 246), knight.display_name, HORIZONTAL_ALIGNMENT_CENTER, width, 28, Palette.INK)
    var ultimate := Ultimate.by_id(knight.ultimate_id)
    draw_string(font, Vector2(0, 270), "%s · %s" % [knight.weapon, ultimate.display_name], HORIZONTAL_ALIGNMENT_CENTER, width, 18, Palette.QUIET)
    var row_y := 304.0
    var ratings := knight.ratings()
    for label: String in ratings:
        draw_string(font, Vector2(SIDE_MARGIN, row_y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Palette.INK)
        _draw_pips(Vector2(width - SIDE_MARGIN, row_y - 11), ratings[label])
        row_y += 25.0
    _draw_trait(Vector2(SIDE_MARGIN, 386), knight.strength, Palette.CYAN, Palette.INK)
    _draw_trait(Vector2(SIDE_MARGIN, 434), knight.weakness, Palette.FOE_RED, Palette.QUIET)


func _draw_silhouette(feet: Vector2) -> void:
    draw_line(feet + Vector2(-90, 0), feet + Vector2(90, 0), Color(Palette.QUIET, 0.35), 2.0)


## Cinq cases alignées à droite de right_top, pleines jusqu'à la note.
func _draw_pips(right_top: Vector2, value: int) -> void:
    for i in 5:
        var x := right_top.x - (5 - i) * (PIP_SIZE.x + PIP_GAP) + PIP_GAP
        var pip := Rect2(Vector2(x, right_top.y), PIP_SIZE)
        if i < value:
            draw_rect(pip, Palette.SILVER)
        else:
            draw_rect(pip, Color(Palette.SILVER, 0.35), false, 1.0)


## Un losange de couleur, puis le texte sur deux lignes au plus.
func _draw_trait(origin: Vector2, text: String, marker: Color, ink: Color) -> void:
    var center := origin + Vector2(5, -5)
    var diamond := PackedVector2Array([center + Vector2(0, -5), center + Vector2(5, 0), center + Vector2(0, 5), center + Vector2(-5, 0)])
    draw_colored_polygon(diamond, marker)
    var text_width := size.x - origin.x - SIDE_MARGIN - 16
    draw_multiline_string(UiStyle.TEXT_FONT, origin + Vector2(16, 0), text, HORIZONTAL_ALIGNMENT_LEFT, text_width, 18, 2, ink)
