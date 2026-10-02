class_name BestiaryScreen
extends Control
## Le bestiaire des seigneurs de la Chasse. Un seigneur vaincu montre sa silhouette, son nom, et en le touchant
## son surnom et sa règle ; un seigneur encore inconnu n'est qu'une ombre sans nom. De quoi donner envie d'y retourner.

signal closed

const VIEW := Vector2(1280, 720)
const COLUMNS := 5
const CARD_SIZE := Vector2(224, 128)
const CARD_GAP := Vector2(16, 12)
const GRID_TOP := 120.0
const BUTTON_TOP := 620.0
const BUTTON_HEIGHT := 76.0

var profile: PlayerProfile
var cards: Array[BestiaryCard] = []
var selected: StringName = &""


func _init(p_profile: PlayerProfile) -> void:
    profile = p_profile


func _ready() -> void:
    InputBindings.register()
    set_anchors_preset(Control.PRESET_FULL_RECT)
    var ids := Boss.ids()
    var width := CARD_SIZE.x * COLUMNS + CARD_GAP.x * (COLUMNS - 1)
    for i in ids.size():
        var card := BestiaryCard.new(ids[i], CARD_SIZE, ids[i] in profile.bestiary)
        card.position = Vector2((VIEW.x - width) / 2 + (i % COLUMNS) * (CARD_SIZE.x + CARD_GAP.x),
            GRID_TOP + (i / COLUMNS) * (CARD_SIZE.y + CARD_GAP.y))
        card.pressed.connect(select.bind(ids[i]))
        add_child(card)
        cards.append(card)
    var back := UiStyle.make_button("Retour", false, Vector2(200, BUTTON_HEIGHT))
    back.position = Vector2(40, BUTTON_TOP)
    back.pressed.connect(closed.emit)
    add_child(back)


func _process(_delta: float) -> void:
    queue_redraw()


## Choisit un seigneur : vaincu, on lit son surnom et sa règle ; inconnu, on sait seulement qu'il rôde.
func select(id: StringName) -> void:
    selected = id
    for card in cards:
        card.selected = card.boss == id


func go_back() -> bool:
    closed.emit()
    return true


func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, VIEW), Palette.NIGHT)
    draw_string(UiStyle.TITLE_FONT, Vector2(0, 70), "Bestiaire", HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 56, Palette.INK)
    HuntView.centered(self, 104, 0, VIEW.x, "%d / %d seigneurs vaincus" % [profile.bestiary.size(), Boss.ids().size()], 22, Palette.QUIET)
    if selected == &"":
        return
    if selected in profile.bestiary:
        HuntView.centered(self, 560, 0, VIEW.x, "%s · %s" % [Boss.display_name(selected), Boss.epithet(selected)], 26, Palette.INK)
        HuntView.centered(self, 594, 0, VIEW.x, Boss.hint(selected), 22, Palette.QUIET)
    else:
        HuntView.centered(self, 576, 0, VIEW.x, "Il rôde encore dans la Chasse", 24, Palette.QUIET)
