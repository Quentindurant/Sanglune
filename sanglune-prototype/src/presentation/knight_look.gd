class_name KnightLook
extends RefCounted
## Silhouettes grises des quatre chevaliers : une carrure, un casque, une arme.
## Le test de la planche vaut déjà en gris : on doit reconnaître chaque chevalier à sa seule forme.
## Les silhouettes animées en os 2D remplaceront ces formes à la vertical slice.

const STEEL := Color("#7a6a8c") ## armes au repos, en gris violacé pour rester lisibles sur le fond

## body : largeur et hauteur du corps en pixels. helmet et weapon : formes dessinées ci-dessous.
const LOOKS := {
    &"veilleur": {"body": Vector2(56, 160), "helmet": &"dome", "weapon": &"sword_shield"},
    &"faucheuse": {"body": Vector2(46, 172), "helmet": &"spike", "weapon": &"halberd"},
    &"rodeuse": {"body": Vector2(42, 138), "helmet": &"hood", "weapon": &"daggers"},
    &"colosse": {"body": Vector2(80, 176), "helmet": &"bucket", "weapon": &"mace"},
}
const FALLBACK := &"veilleur"


static func has_look(knight_id: StringName) -> bool:
    return LOOKS.has(knight_id)


static func helmet_of(knight_id: StringName) -> StringName:
    return _look(knight_id)["helmet"]


static func weapon_of(knight_id: StringName) -> StringName:
    return _look(knight_id)["weapon"]


## Le corps posé sur le sol ; feet est le milieu des pieds.
static func body_rect(knight_id: StringName, feet: Vector2, scale: float = 1.0) -> Rect2:
    var size: Vector2 = _look(knight_id)["body"] * scale
    return Rect2(feet.x - size.x / 2, feet.y - size.y, size.x, size.y)


## L'œil brille dans le casque, du côté du regard.
static func eye_rect(body: Rect2, facing: float, scale: float = 1.0) -> Rect2:
    var size := Vector2(12, 4) * scale
    var center := Vector2(body.get_center().x + facing * 6 * scale, body.position.y - 14 * scale)
    return Rect2(center - size / 2, size)


static func draw_helmet(canvas: CanvasItem, knight_id: StringName, body: Rect2, facing: float, scale: float, color: Color) -> void:
    var top := Vector2(body.get_center().x, body.position.y)
    match helmet_of(knight_id):
        &"dome":
            canvas.draw_circle(_at(top, scale, facing, Vector2(0, -12)), 16 * scale, color)
        &"spike":
            canvas.draw_colored_polygon(_shape(top, scale, facing, [Vector2(-13, 0), Vector2(13, 0), Vector2(13, -26), Vector2(0, -50), Vector2(-13, -26)]), color)
        &"hood":
            canvas.draw_colored_polygon(_shape(top, scale, facing, [Vector2(-14, 0), Vector2(14, 0), Vector2(10, -26), Vector2(-24, -16)]), color)
        &"bucket":
            canvas.draw_rect(Rect2(top + Vector2(-20, -30) * scale, Vector2(40, 30) * scale), color)
            var pauldrons := Rect2(body.position + Vector2(-10, 2) * scale, Vector2(body.size.x + 20 * scale, 24 * scale))
            canvas.draw_rect(pauldrons, color)


## L'arme tenue au repos. Repère local : x vers l'avant, y vers le bas, origine à hauteur des mains.
static func draw_idle_weapon(canvas: CanvasItem, knight_id: StringName, body: Rect2, facing: float, scale: float, color: Color) -> void:
    var hands := Vector2(body.get_center().x, body.position.y + body.size.y * 0.5)
    var half := body.size.x / 2 / scale ## demi-largeur du corps, en unités locales
    var legs := body.size.y / 2 / scale ## des mains aux pieds, en unités locales
    match weapon_of(knight_id):
        &"sword_shield":
            canvas.draw_colored_polygon(_shape(hands, scale, facing, [Vector2(half + 2, -30), Vector2(half + 18, -26), Vector2(half + 18, 26), Vector2(half + 2, 34)]), color)
            _line(canvas, hands, scale, facing, Vector2(-half - 2, 6), Vector2(-half - 16, -104), color, 4)
            _line(canvas, hands, scale, facing, Vector2(-half - 14, -8), Vector2(-half + 8, -12), color, 4)
        &"halberd":
            var pole_top := -legs - 56 ## au-dessus du casque
            _line(canvas, hands, scale, facing, Vector2(half + 10, legs), Vector2(half + 10, pole_top - 16), color, 4)
            var blade: Array[Vector2] = [Vector2(half + 10, pole_top + 6), Vector2(half + 30, pole_top - 2), Vector2(half + 38, pole_top + 20), Vector2(half + 30, pole_top + 42), Vector2(half + 10, pole_top + 34)]
            canvas.draw_colored_polygon(_shape(hands, scale, facing, blade), color)
            canvas.draw_colored_polygon(_shape(hands, scale, facing, [Vector2(half + 10, pole_top + 14), Vector2(half - 4, pole_top + 22), Vector2(half + 10, pole_top + 26)]), color)
        &"daggers":
            _line(canvas, hands, scale, facing, Vector2(half, 0), Vector2(half + 30, 16), color, 3)
            _line(canvas, hands, scale, facing, Vector2(-half, 6), Vector2(-half - 22, 22), color, 3)
        &"mace":
            _line(canvas, hands, scale, facing, Vector2(half, 10), Vector2(half + 22, -32), color, 5)
            canvas.draw_circle(_at(hands, scale, facing, Vector2(half + 24, -38)), 12 * scale, color)


static func _look(knight_id: StringName) -> Dictionary:
    return LOOKS.get(knight_id, LOOKS[FALLBACK])


## Point local vers l'écran : x retourné selon le regard, puis mis à l'échelle.
static func _at(origin: Vector2, scale: float, facing: float, local: Vector2) -> Vector2:
    return origin + Vector2(local.x * facing, local.y) * scale


static func _shape(origin: Vector2, scale: float, facing: float, points: Array[Vector2]) -> PackedVector2Array:
    var result := PackedVector2Array()
    for point in points:
        result.append(_at(origin, scale, facing, point))
    return result


static func _line(canvas: CanvasItem, origin: Vector2, scale: float, facing: float, from: Vector2, to: Vector2, color: Color, width: float) -> void:
    canvas.draw_line(_at(origin, scale, facing, from), _at(origin, scale, facing, to), color, width * scale)
