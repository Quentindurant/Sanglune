class_name GearView
extends RefCounted
## Dessins partagés de l'équipement : la lune de rareté et les effets d'une pièce (gains en argent, perte en rouge sourd).
## Pas de texte de rareté : la lune suffit, plus elle est pleine, plus la pièce est rare.

## Position de la frontière d'ombre pour chaque rareté : 1 lune noire, 0 demi-lune, -1 pleine lune.
const MOON_TERMINATOR := [0.55, 0.0, -0.55, -1.0]
const ARC_POINTS := 16
const TRIANGLE := 6.0


## La lune de rareté, centrée en center.
static func draw_moon(canvas: CanvasItem, center: Vector2, radius: float, rarity: int) -> void:
    canvas.draw_circle(center, radius, Color(Palette.MOON, 0.18))
    var k: float = MOON_TERMINATOR[clampi(rarity, 0, MOON_TERMINATOR.size() - 1)]
    var lit := PackedVector2Array()
    for i in ARC_POINTS + 1:
        var angle := -PI / 2 + PI * i / ARC_POINTS
        lit.append(center + Vector2(cos(angle) * radius, sin(angle) * radius))
    for i in range(ARC_POINTS - 1, 0, -1):
        var angle := -PI / 2 + PI * i / ARC_POINTS
        lit.append(center + Vector2(cos(angle) * radius * k, sin(angle) * radius))
    canvas.draw_colored_polygon(lit, Palette.MOON)
    canvas.draw_arc(center, radius, 0, TAU, 32, Color(Palette.MOON, 0.8), 1.5)


## Un éclat de lune : la monnaie qui améliore les pièces.
static func draw_shard(canvas: CanvasItem, center: Vector2, size: float) -> void:
    var points := PackedVector2Array([
        center + Vector2(0, -size), center + Vector2(size * 0.55, -size * 0.1),
        center + Vector2(size * 0.15, size), center + Vector2(-size * 0.5, size * 0.2),
    ])
    canvas.draw_colored_polygon(points, Palette.MOON)
    canvas.draw_line(points[0], points[2], Color(Palette.INK, 0.45), 1.0)


## Les gains d'une pièce, puis ses pertes : [[libellé, pour mille], ...].
static func effects(item: OwnedItem) -> Dictionary:
    var gains := []
    var losses := []
    if item == null:
        return {"gains": gains, "losses": losses}
    var mods := item.modifiers()
    for stat: int in item.def.gains + item.def.losses: ## dans l'ordre du modèle : le gain principal d'abord
        if mods.get(stat, 0) == 0:
            continue
        var entry := [GearStat.LABEL[stat], mods[stat]]
        if mods[stat] > 0:
            gains.append(entry)
        else:
            losses.append(entry)
    return {"gains": gains, "losses": losses}


## « +14 % » ou « −8 % », arrondi au pour cent.
static func percent(permille: int) -> String:
    var value := (absi(permille) + 5) / 10
    return "%s%d %%" % ["+" if permille >= 0 else "−", value]


## Une ligne d'effets : un triangle (vers le haut pour un gain, vers le bas pour une perte), le libellé et la valeur.
## Renvoie la largeur dessinée.
static func draw_effect_line(canvas: CanvasItem, origin: Vector2, entries: Array, font_size: int, gain: bool) -> float:
    var font := UiStyle.TEXT_FONT
    var color := Palette.GAIN if gain else Palette.LOSS
    var x := origin.x
    for entry: Array in entries:
        _draw_triangle(canvas, Vector2(x + TRIANGLE, origin.y - font_size * 0.32), gain, color)
        x += TRIANGLE * 2 + 6
        var text := "%s %s" % [entry[0], percent(entry[1])]
        canvas.draw_string(font, Vector2(x, origin.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
        x += font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 18
    return x - origin.x


## La largeur qu'occuperait une ligne d'effets, pour savoir s'il faut la couper.
static func effect_line_width(entries: Array, font_size: int) -> float:
    var width := 0.0
    for entry: Array in entries:
        var text := "%s %s" % [entry[0], percent(entry[1])]
        width += TRIANGLE * 2 + 6 + UiStyle.TEXT_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 18
    return width - 18 if width > 0 else 0.0


## Les lignes à dessiner : les gains ensemble s'ils tiennent, sinon un par ligne ; puis les pertes.
## Chaque ligne : [entrées, est_un_gain].
static func effect_rows(item: OwnedItem, font_size: int, max_width: float) -> Array:
    var parts := effects(item)
    var rows := []
    if not parts["gains"].is_empty():
        if effect_line_width(parts["gains"], font_size) <= max_width:
            rows.append([parts["gains"], true])
        else:
            for entry: Array in parts["gains"]:
                rows.append([[entry], true])
    if not parts["losses"].is_empty():
        rows.append([parts["losses"], false])
    return rows


static func _draw_triangle(canvas: CanvasItem, center: Vector2, up: bool, color: Color) -> void:
    var tip := -TRIANGLE if up else TRIANGLE
    canvas.draw_colored_polygon(PackedVector2Array([
        center + Vector2(-TRIANGLE, -tip * 0.7), center + Vector2(TRIANGLE, -tip * 0.7), center + Vector2(0, tip),
    ]), color)
