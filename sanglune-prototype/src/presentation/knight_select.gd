class_name KnightSelect
extends Control
## Écran de choix du chevalier. Toucher une carte la sélectionne, « Combattre » lance le duel.
## Clavier : Q/D ou flèches pour changer de chevalier, J ou Entrée pour combattre.

signal confirmed(knight: KnightClass)

const VIEW := Vector2(1280, 720)
const CARD_TOP := 96.0
const CARD_GAP := 24.0
const FIGHT_BUTTON_SIZE := Vector2(360, 80)
const FIGHT_BUTTON_TOP := 584.0
const HINT := "L'ombre tire son chevalier au hasard.   Clavier : Q/D pour choisir, J pour combattre."

var _picker: KnightPicker
var _cards: Array[KnightCard] = []
var _fight_button: Button


func _init(selected_id: StringName = KnightClass.VEILLEUR) -> void:
    _picker = KnightPicker.new(selected_id)


func _ready() -> void:
    InputBindings.register()
    set_anchors_preset(Control.PRESET_FULL_RECT)
    _build_cards()
    _build_fight_button()
    _refresh()


func selected() -> KnightClass:
    return _picker.selected()


func select_index(position: int) -> void:
    _picker.select_index(position)
    _refresh()


func confirm() -> void:
    confirmed.emit(_picker.selected())


func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("move_left"):
        _step(-1)
    elif event.is_action_pressed("move_right"):
        _step(1)
    elif event.is_action_pressed("frappe"):
        confirm()
    else:
        return
    get_viewport().set_input_as_handled()


func _draw() -> void:
    var font := ThemeDB.fallback_font
    draw_rect(Rect2(Vector2.ZERO, VIEW), Palette.NIGHT)
    draw_circle(Vector2(VIEW.x / 2, 300), 300, Color(Palette.MOON, 0.12))
    draw_string(font, Vector2(0, 62), "Choisis ton chevalier", HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 40, Palette.INK)
    draw_string(font, Vector2(0, 702), HINT, HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 15, Palette.QUIET)


func _build_cards() -> void:
    var knights := _picker.knights
    var row_width := knights.size() * KnightCard.CARD_SIZE.x + (knights.size() - 1) * CARD_GAP
    var left := (VIEW.x - row_width) / 2
    for i in knights.size():
        var card := KnightCard.new(knights[i])
        card.position = Vector2(left + i * (KnightCard.CARD_SIZE.x + CARD_GAP), CARD_TOP)
        card.pressed.connect(select_index.bind(i))
        add_child(card)
        _cards.append(card)


func _build_fight_button() -> void:
    _fight_button = UiStyle.make_button("Combattre", true, FIGHT_BUTTON_SIZE)
    _fight_button.position = Vector2((VIEW.x - FIGHT_BUTTON_SIZE.x) / 2, FIGHT_BUTTON_TOP)
    _fight_button.pressed.connect(confirm)
    add_child(_fight_button)
    _fight_button.grab_focus.call_deferred()


func _step(direction: int) -> void:
    _picker.step(direction)
    _refresh()


## La carte sélectionnée reste enfoncée, les autres se relèvent.
func _refresh() -> void:
    for i in _cards.size():
        _cards[i].set_pressed_no_signal(i == _picker.index)
        _cards[i].queue_redraw()
    if _fight_button != null:
        _fight_button.accessibility_description = "Combattre avec %s" % _picker.selected().display_name
