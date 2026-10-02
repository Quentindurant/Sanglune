class_name HuntView
extends RefCounted
## Dessins partagés de la Chasse : la rune d'une bénédiction, la larme de lune, le soin, la blessure, le Grand Veneur.
## Ce qui ne dure que la Chasse est en cyan (la couleur du joueur) ; ce qui se garde, en lumière de lune.

const TEMPORARY := Palette.CYAN
const KEPT := Palette.SILVER


## La rune d'une bénédiction : un losange ; une flèche pour une caractéristique, une étoile pour un trait.
static func draw_rune(canvas: CanvasItem, center: Vector2, radius: float, is_trait: bool, color: Color = TEMPORARY) -> void:
    var diamond := PackedVector2Array([
        center + Vector2(0, -radius), center + Vector2(radius * 0.8, 0),
        center + Vector2(0, radius), center + Vector2(-radius * 0.8, 0),
    ])
    canvas.draw_colored_polygon(diamond, Color(color, 0.16))
    diamond.append(diamond[0])
    canvas.draw_polyline(diamond, color, maxf(1.5, radius * 0.08))
    var r := radius * 0.42
    if is_trait:
        var star := PackedVector2Array()
        for i in 8:
            var angle := -PI / 2 + PI * i / 4.0
            star.append(center + Vector2(cos(angle), sin(angle)) * (r if i % 2 == 0 else r * 0.4))
        canvas.draw_colored_polygon(star, color)
    else:
        canvas.draw_colored_polygon(PackedVector2Array([
            center + Vector2(0, -r), center + Vector2(r * 0.8, r * 0.1), center + Vector2(-r * 0.8, r * 0.1),
        ]), color)
        canvas.draw_rect(Rect2(center + Vector2(-r * 0.25, r * 0.1), Vector2(r * 0.5, r * 0.8)), color)


## La larme de lune : une goutte qui rejoue un duel perdu.
static func draw_tear(canvas: CanvasItem, center: Vector2, size: float, color: Color = TEMPORARY) -> void:
    var drop := PackedVector2Array([center + Vector2(0, -size)])
    for i in 13:
        var angle := -PI * 0.15 + PI * 1.3 * i / 12.0
        drop.append(center + Vector2(cos(angle) * size * 0.62, size * 0.32 + sin(angle) * size * 0.62))
    canvas.draw_colored_polygon(drop, Color(color, 0.25))
    drop.append(drop[0])
    canvas.draw_polyline(drop, color, maxf(1.5, size * 0.08))


## Le soin : une croix pleine dans un cercle.
static func draw_heal(canvas: CanvasItem, center: Vector2, size: float, color: Color = TEMPORARY) -> void:
    canvas.draw_circle(center, size, Color(color, 0.16))
    canvas.draw_arc(center, size, 0, TAU, 40, color, maxf(1.5, size * 0.08))
    var arm := size * 0.55
    var thick := size * 0.24
    canvas.draw_rect(Rect2(center + Vector2(-thick / 2, -arm), Vector2(thick, arm * 2)), color)
    canvas.draw_rect(Rect2(center + Vector2(-arm, -thick / 2), Vector2(arm * 2, thick)), color)


## Une blessure : une entaille en rouge sourd.
static func draw_wound(canvas: CanvasItem, center: Vector2, size: float) -> void:
    canvas.draw_line(center + Vector2(-size, size * 0.6), center + Vector2(size, -size * 0.6), Palette.LOSS, maxf(2.0, size * 0.3))


## Les cornes du Grand Veneur, au-dessus d'un cercle.
static func draw_horns(canvas: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
    for side in [-1.0, 1.0]:
        canvas.draw_colored_polygon(PackedVector2Array([
            center + Vector2(side * radius * 0.35, -radius * 0.8),
            center + Vector2(side * radius * 0.75, -radius * 0.55),
            center + Vector2(side * radius * 1.0, -radius * 1.55),
        ]), color)


## Un cadenas : une nuit encore fermée.
static func draw_lock(canvas: CanvasItem, center: Vector2, size: float, color: Color) -> void:
    canvas.draw_arc(center + Vector2(0, -size * 0.35), size * 0.5, PI, TAU, 16, color, maxf(2.0, size * 0.16))
    canvas.draw_rect(Rect2(center + Vector2(-size * 0.75, -size * 0.35), Vector2(size * 1.5, size * 1.15)), color)


## La force d'une nuit : un, deux ou trois losanges rouges.
static func draw_danger(canvas: CanvasItem, center: Vector2, level: int) -> void:
    var count := level + 1
    for i in count:
        var c := center + Vector2((i - (count - 1) / 2.0) * 22.0, 0)
        canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -7), c + Vector2(6, 0), c + Vector2(0, 7), c + Vector2(-6, 0)]), Palette.FOE_RED)


## La lune d'une nuit, en phases : plus la nuit est dure, plus la lune est pleine.
static func night_phase(level: int) -> int:
    return [Rarity.Tier.CROISSANT, Rarity.Tier.GIBBEUSE, Rarity.Tier.PLEINE_LUNE][level]


## La meilleure rareté que peut donner le Grand Veneur de cette nuit.
static func best_rarity(level: int) -> int:
    var weights: Array = HuntDifficulty.value(level, "final_rarity")
    var best := Rarity.Tier.CROISSANT
    for tier in weights.size():
        if weights[tier] > 0:
            best = tier
    return best


## Le nom d'une bénédiction et ce qu'elle fait : [nom, effets [[libellé, pour mille]...], description d'un trait].
static func blessing_lines(id: StringName) -> Array:
    var entries := []
    var effect := Blessing.mods(id)
    for stat: int in effect:
        entries.append([GearStat.LABEL[stat], effect[stat]])
    var description := GearTrait.describe(Blessing.gear_trait(id)) if Blessing.is_trait(id) else ""
    return [Blessing.display_name(id), entries, description]


## Une ligne centrée dans une largeur.
static func centered(canvas: CanvasItem, y: float, x: float, width: float, text: String, font_size: int, color: Color) -> void:
    canvas.draw_string(UiStyle.TEXT_FONT, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, color)
