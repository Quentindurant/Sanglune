class_name UiStyle
extends RefCounted
## Styles d'interface partagés : grands boutons faciles à viser au pouce, contrastes de la planche,
## et un contour bien visible quand un bouton a le focus clavier.

const CORNER_RADIUS := 14
const BUTTON_FONT_SIZE := 28


static func box(bg: Color, border: Color, border_width: int = 2) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = bg
    style.border_color = border
    style.set_border_width_all(border_width)
    style.set_corner_radius_all(CORNER_RADIUS)
    style.set_content_margin_all(12)
    return style


## Bouton principal (Combattre, Rejouer) ou secondaire (Changer de chevalier).
static func make_button(text: String, primary: bool, min_size: Vector2) -> Button:
    var button := Button.new()
    button.text = text
    button.custom_minimum_size = min_size
    var bg := Palette.DULL_BLOOD if primary else Palette.DUSK
    var border := Palette.MOON if primary else Palette.QUIET
    button.add_theme_stylebox_override("normal", box(bg, border))
    button.add_theme_stylebox_override("hover", box(bg.lightened(0.12), border))
    button.add_theme_stylebox_override("pressed", box(bg.darkened(0.25), Palette.INK))
    button.add_theme_stylebox_override("focus", box(Color.TRANSPARENT, Palette.INK, 3))
    button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
    for color_name: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
        button.add_theme_color_override(color_name, Palette.INK)
    return button
