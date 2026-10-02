class_name ArenaHud
extends Node2D
## Tout ce qui se lit par-dessus le duel : vies, runes, temps, manches, boutons tactiles, messages et voile des menus.

var arena: Arena


func _draw() -> void:
    if arena == null or arena.duel == null:
        return
    var duel := arena.duel
    var my_bar := Palette.VENOM if duel.left.is_poisoned() else Palette.SILVER
    _draw_side(duel.left, Vector2(40, 30), false, "Toi · " + duel.left.knight.display_name, my_bar, Palette.CYAN)
    var foe_name := arena.enemy_title if arena.boss_id != &"" else arena.enemy_title + " · " + duel.right.knight.display_name
    _draw_side(duel.right, Vector2(820, 30), true, foe_name, Palette.FOE_RED, Palette.FOE_RED)
    for i in duel.right.shield: ## l'égide du Bastion : un écu par coup qu'elle boira encore
        _draw_shield(Vector2(1232 - i * 26, 92))
    var center := Vector2(Arena.VIEW.x / 2, 62)
    draw_circle(center, 32, Color(Palette.SILHOUETTE, 0.8))
    draw_arc(center, 32, 0, TAU, 48, Palette.MOON, 2.0)
    draw_string(UiStyle.TEXT_FONT, Vector2(center.x - 40, center.y + 10), str(duel.seconds_left()), HORIZONTAL_ALIGNMENT_CENTER, 80, 32, Palette.INK)
    for i in duel.rounds_needed[-1]:
        _draw_pip(Vector2(center.x - 22 - i * 18, 112), duel.wins[-1] > i, Palette.SILVER)
    for i in duel.rounds_needed[1]:
        _draw_pip(Vector2(center.x + 22 + i * 18, 112), duel.wins[1] > i, Palette.FOE_RED)
    _draw_touch_buttons(duel.left.rune)
    var menu_open := arena.is_end_menu_visible() or arena.is_paused()
    if menu_open:
        draw_rect(Rect2(Vector2.ZERO, Arena.VIEW), Color(Palette.NIGHT, 0.65))
    _draw_help(Arena.END_KEYBOARD_HELP if arena.is_end_menu_visible() else Arena.KEYBOARD_HELP, arena.is_paused())
    if arena.message_frames > 0:
        draw_string(UiStyle.TEXT_FONT, Vector2(0, 240), arena.message, HORIZONTAL_ALIGNMENT_CENTER, Arena.VIEW.x, 54, Palette.INK)


func _draw_side(f: Fighter, origin: Vector2, mirrored: bool, name_text: String, bar: Color, rune_color: Color) -> void:
    var width := 420.0
    var align := HORIZONTAL_ALIGNMENT_RIGHT if mirrored else HORIZONTAL_ALIGNMENT_LEFT
    draw_string(UiStyle.TEXT_FONT, origin, name_text, align, width, 24, Palette.INK)
    var frame := Rect2(origin.x, origin.y + 10, width, 18)
    draw_rect(frame, Color(Palette.SILHOUETTE, 0.7))
    var fill_w := width * f.hp / float(f.max_hp())
    var fill_x := origin.x + width - fill_w if mirrored else origin.x
    draw_rect(Rect2(fill_x, frame.position.y, fill_w, frame.size.y), bar)
    draw_rect(frame, Color(Palette.INK, 0.5), false, 1.0)
    for i in Fighter.MAX_RUNE:
        var seg_x := origin.x + width - 48 - i * 54 if mirrored else origin.x + i * 54
        draw_rect(Rect2(seg_x, origin.y + 36, 48, 8), rune_color if i < f.rune else Color(rune_color, 0.2))


func _draw_shield(pos: Vector2) -> void:
    var points := PackedVector2Array([pos + Vector2(-9, -9), pos + Vector2(9, -9), pos + Vector2(8, 3), pos + Vector2(0, 11), pos + Vector2(-8, 3)])
    draw_colored_polygon(points, Color(Palette.SILVER, 0.85))


func _draw_pip(pos: Vector2, filled: bool, color: Color) -> void:
    var points := PackedVector2Array([pos + Vector2(0, -6), pos + Vector2(6, 0), pos + Vector2(0, 6), pos + Vector2(-6, 0)])
    if filled:
        draw_colored_polygon(points, color)
    else:
        points.append(points[0])
        draw_polyline(points, Color(color, 0.6), 1.5)


func _draw_touch_buttons(player_rune: int) -> void:
    for button in arena.touch_buttons:
        var spec: Dictionary = button.get_meta("spec")
        var center: Vector2 = spec["pos"]
        var radius: float = spec["radius"]
        var pressed := button.is_pressed()
        draw_circle(center, radius, Color(Palette.SILHOUETTE, 0.75 if pressed else 0.45))
        draw_arc(center, radius, 0, TAU, 48, Color(Palette.INK, 0.9 if pressed else 0.45), 2.0)
        if spec["action"] == "ultime":
            _draw_ultimate_charge(center, radius, player_rune)
        draw_string(UiStyle.TEXT_FONT, Vector2(center.x - radius, center.y + 7), spec["label"], HORIZONTAL_ALIGNMENT_CENTER, radius * 2, 23, Palette.INK)


## L'anneau de l'Ultime se remplit rune après rune ; plein, le bouton s'allume et pulse.
func _draw_ultimate_charge(center: Vector2, radius: float, runes: int) -> void:
    if runes >= Fighter.MAX_RUNE:
        var pulse := 0.35 + 0.25 * sin(Time.get_ticks_msec() / 160.0)
        draw_circle(center, radius, Color(Palette.CYAN, pulse))
        draw_arc(center, radius + 5, 0, TAU, 48, Palette.CYAN, 4.0)
    elif runes > 0:
        draw_arc(center, radius + 5, -PI / 2, -PI / 2 + TAU * runes / float(Fighter.MAX_RUNE), 48, Palette.CYAN, 3.0)


## L'aide clavier ne s'affiche que sur ordinateur, et pas pendant la pause.
func _draw_help(text: String, paused: bool) -> void:
    if OS.has_feature("mobile") or paused:
        return
    draw_string(UiStyle.TEXT_FONT, Vector2(330, 708), text, HORIZONTAL_ALIGNMENT_CENTER, 620, 17, Color(Palette.QUIET, 0.75))
