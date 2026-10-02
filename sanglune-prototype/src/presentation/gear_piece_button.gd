class_name GearPieceButton
extends Button
## Une pièce d'équipement à toucher : sa lune, son nom, ce qu'elle renforce et ce qu'elle affaiblit.
## Sert aux quatre emplacements de l'armurerie (avec le nom de l'emplacement au-dessus)
## et à la liste des pièces d'un emplacement (la pièce portée y est marquée).
## Une arme montre son ultime ; une Pleine lune, son trait (le nom seul sur une case étroite).

const NAME_SIZE := 27
const EFFECT_SIZE := 18
const LINE_GAP := 25.0
const PADDING := 20.0
const MOON_RADIUS := 13.0
const WIDE := 480.0 ## au-delà de cette largeur, le trait s'écrit avec sa description
const BOTTOM_PADDING := 24.0

var item: OwnedItem ## null : l'emplacement est vide
var heading: String ## nom de l'emplacement, ou vide dans une liste
var worn: bool


func _init(p_item: OwnedItem, p_size: Vector2, p_heading: String = "", p_worn: bool = false) -> void:
    item = p_item
    heading = p_heading
    worn = p_worn
    custom_minimum_size = p_size
    size = p_size
    add_theme_stylebox_override("normal", UiStyle.box(Palette.DUSK, Palette.PURPLE))
    add_theme_stylebox_override("hover", UiStyle.box(Palette.DUSK.lightened(0.06), Palette.QUIET))
    add_theme_stylebox_override("pressed", UiStyle.box(Palette.DUSK.lightened(0.1), Palette.CYAN, 4))
    add_theme_stylebox_override("hover_pressed", UiStyle.box(Palette.DUSK.lightened(0.14), Palette.CYAN, 4))
    add_theme_stylebox_override("focus", UiStyle.box(Color.TRANSPARENT, Palette.INK, 3))
    accessibility_name = describe()


## Ce que lit un lecteur d'écran : emplacement, nom, rareté, effets.
func describe() -> String:
    var words := []
    if heading != "":
        words.append(heading)
    if item == null:
        words.append("Rien")
        return ", ".join(words)
    if item.def.starter:
        words.append(item.def.display_name)
    else:
        words.append("%s, %s, niveau %d" % [item.def.display_name, Rarity.display_name(item.rarity), item.level])
    var parts := GearView.effects(item)
    for entry: Array in parts["gains"] + parts["losses"]:
        words.append("%s %s" % [entry[0], GearView.percent(entry[1])])
    if item.def.is_weapon() and Ultimate.by_id(item.def.ultimate_id) != null:
        words.append("ultime %s" % Ultimate.by_id(item.def.ultimate_id).display_name)
    if item.gear_trait() != GearTrait.Trait.NONE:
        words.append("%s : %s" % [GearTrait.display_name(item.gear_trait()), GearTrait.describe(item.gear_trait())])
    if worn:
        words.append("porté")
    return ", ".join(words)


func _draw() -> void:
    var font := UiStyle.TEXT_FONT
    var name_y := 40.0
    if heading != "":
        draw_string(font, Vector2(PADDING, 32), heading, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Palette.QUIET)
        name_y = 70.0
    if item == null:
        draw_string(font, Vector2(PADDING, name_y), "Rien", HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE, Palette.QUIET)
        return
    var right := size.x - PADDING
    if not item.def.starter: ## une arme de départ est neutre : pas de rareté à montrer
        var moon_center := Vector2(right - MOON_RADIUS, name_y - 9)
        GearView.draw_moon(self, moon_center, MOON_RADIUS, item.rarity)
        right = moon_center.x - MOON_RADIUS - 12
        var level := "Niv. %d" % item.level
        draw_string(font, Vector2(0, name_y - 2), level, HORIZONTAL_ALIGNMENT_RIGHT, right, 18, Palette.QUIET)
        right -= font.get_string_size(level, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 14
    if worn:
        draw_string(font, Vector2(0, name_y - 2), "Porté", HORIZONTAL_ALIGNMENT_RIGHT, right, 18, Palette.CYAN)
    draw_string(font, Vector2(PADDING, name_y), item.def.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE, Palette.INK)
    var y := name_y + 32
    for row: Array in GearView.effect_rows(item, EFFECT_SIZE, size.x - 2 * PADDING):
        GearView.draw_effect_line(self, Vector2(PADDING, y), row[0], EFFECT_SIZE, row[1])
        y += LINE_GAP
    if item.def.is_weapon():
        _draw_ultimate(Vector2(PADDING, y))
        y += LINE_GAP
    if item.gear_trait() != GearTrait.Trait.NONE:
        _draw_trait(Vector2(PADDING, y))


## La hauteur dont une pièce a besoin : nom, effets, ultime d'une arme, trait d'une Pleine lune.
static func needed_height(p_item: OwnedItem, width: float, with_heading: bool) -> float:
    var top := 70.0 if with_heading else 40.0
    if p_item == null:
        return top + BOTTOM_PADDING
    var lines := GearView.effect_rows(p_item, EFFECT_SIZE, width - 2 * PADDING).size()
    if p_item.def.is_weapon():
        lines += 1
    if p_item.gear_trait() != GearTrait.Trait.NONE:
        lines += 1
    return top + 32 + LINE_GAP * maxi(0, lines - 1) + BOTTOM_PADDING


## Le trait d'une Pleine lune : une lune pleine, son nom, et sa description quand la place le permet.
func _draw_trait(origin: Vector2) -> void:
    var gear_trait := item.gear_trait()
    GearView.draw_moon(self, origin + Vector2(6, -EFFECT_SIZE * 0.32), 6.0, Rarity.Tier.PLEINE_LUNE)
    var text := GearTrait.display_name(gear_trait)
    if size.x >= WIDE:
        text += " · " + GearTrait.describe(gear_trait)
    draw_string(UiStyle.TEXT_FONT, origin + Vector2(18, 0), text, HORIZONTAL_ALIGNMENT_LEFT, size.x - origin.x - PADDING - 18,
        EFFECT_SIZE, Palette.INK)


## L'arme décide de l'ultime : son nom, derrière un losange cyan, la couleur de ton jeu.
func _draw_ultimate(origin: Vector2) -> void:
    var ultimate := Ultimate.by_id(item.def.ultimate_id)
    if ultimate == null:
        return
    var center := origin + Vector2(6, -EFFECT_SIZE * 0.32)
    draw_colored_polygon(KnightBuild.diamond(center, 6.0), Palette.CYAN)
    draw_string(UiStyle.TEXT_FONT, origin + Vector2(18, 0), "Ultime · %s" % ultimate.display_name,
        HORIZONTAL_ALIGNMENT_LEFT, -1, EFFECT_SIZE, Palette.QUIET)
