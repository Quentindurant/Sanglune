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


func _draw() -> void:
    var font := ThemeDB.fallback_font
    var width := size.x
    _draw_silhouette(Vector2(width / 2, FEET_Y))
    draw_string(font, Vector2(0, 246), knight.display_name, HORIZONTAL_ALIGNMENT_CENTER, width, 24, Palette.INK)
    draw_string(font, Vector2(0, 270), knight.weapon, HORIZONTAL_ALIGNMENT_CENTER, width, 15, Palette.QUIET)
    var row_y := 304.0
    var ratings := knight.ratings()
    for label: String in ratings:
        draw_string(font, Vector2(SIDE_MARGIN, row_y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.INK)
        _draw_pips(Vector2(width - SIDE_MARGIN, row_y - 11), ratings[label])
        row_y += 25.0
    _draw_trait(Vector2(SIDE_MARGIN, 386), knight.strength, Palette.CYAN, Palette.INK)
    _draw_trait(Vector2(SIDE_MARGIN, 434), knight.weakness, Palette.FOE_RED, Palette.QUIET)


func _draw_silhouette(feet: Vector2) -> void:
    var body := KnightLook.body_rect(knight.id, feet, SILHOUETTE_SCALE)
    draw_line(feet + Vector2(-90, 0), feet + Vector2(90, 0), Color(Palette.QUIET, 0.35), 2.0)
    KnightLook.draw_idle_weapon(self, knight.id, body, 1.0, SILHOUETTE_SCALE, KnightLook.STEEL)
    KnightLook.draw_helmet(self, knight.id, body, 1.0, SILHOUETTE_SCALE, Palette.SILHOUETTE)
    draw_rect(body, Palette.SILHOUETTE)
    draw_rect(KnightLook.eye_rect(body, 1.0, SILHOUETTE_SCALE), Palette.CYAN)


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
    draw_multiline_string(ThemeDB.fallback_font, origin + Vector2(16, 0), text, HORIZONTAL_ALIGNMENT_LEFT, text_width, 15, 2, ink)
