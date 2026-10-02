class_name KnightSelect
extends Control
## Écran « Chevaliers » : toucher une carte la sélectionne, « Choisir » en fait le chevalier actif,
## « Équiper » ouvre son armurerie, « Retour » ne change rien.
## Au clavier : Q/D ou flèches pour changer de chevalier, J ou Entrée pour choisir.

signal confirmed(knight: KnightClass)
signal equip_requested(knight: KnightClass)
signal cancelled

const VIEW := Vector2(1280, 720)
const CARD_TOP := 96.0
const CARD_GAP := 24.0
const CHOOSE_BUTTON_SIZE := Vector2(360, 80)
const EQUIP_BUTTON_SIZE := Vector2(260, 80)
const BUTTON_GAP := 24.0
const CHOOSE_BUTTON_TOP := 584.0
const BACK_BUTTON_SIZE := Vector2(170, 56)

var _picker: KnightPicker
var _cards: Array[KnightCard] = []
var _choose_button: Button


func _init(selected_id: StringName = KnightClass.VEILLEUR) -> void:
    _picker = KnightPicker.new(selected_id)


func _ready() -> void:
    InputBindings.register()
    set_anchors_preset(Control.PRESET_FULL_RECT)
    _build_cards()
    _build_buttons()
    _refresh()


func selected() -> KnightClass:
    return _picker.selected()


func select_index(position: int) -> void:
    _picker.select_index(position)
    _refresh()


func confirm() -> void:
    confirmed.emit(_picker.selected())


func cancel() -> void:
    cancelled.emit()


func request_equip() -> void:
    equip_requested.emit(_picker.selected())


## Le retour Android ramène à l'accueil sans changer de chevalier.
func go_back() -> bool:
    cancel()
    return true


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
    draw_rect(Rect2(Vector2.ZERO, VIEW), Palette.NIGHT)
    draw_circle(Vector2(VIEW.x / 2, 300), 300, Color(Palette.MOON, 0.12))
    draw_string(UiStyle.TITLE_FONT, Vector2(0, 70), "Chevaliers", HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 56, Palette.INK)


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


func _build_buttons() -> void:
    var left := (VIEW.x - EQUIP_BUTTON_SIZE.x - BUTTON_GAP - CHOOSE_BUTTON_SIZE.x) / 2
    var equip := UiStyle.make_button("Équiper", false, EQUIP_BUTTON_SIZE)
    equip.position = Vector2(left, CHOOSE_BUTTON_TOP)
    equip.pressed.connect(request_equip)
    add_child(equip)
    _choose_button = UiStyle.make_button("Choisir", true, CHOOSE_BUTTON_SIZE)
    _choose_button.position = Vector2(left + EQUIP_BUTTON_SIZE.x + BUTTON_GAP, CHOOSE_BUTTON_TOP)
    _choose_button.pressed.connect(confirm)
    add_child(_choose_button)
    var back := UiStyle.make_button("Retour", false, BACK_BUTTON_SIZE)
    back.position = Vector2(32, 20)
    back.pressed.connect(cancel)
    add_child(back)
    _choose_button.grab_focus.call_deferred()


func _step(direction: int) -> void:
    _picker.step(direction)
    _refresh()


## La carte sélectionnée reste enfoncée, les autres se relèvent.
func _refresh() -> void:
    for i in _cards.size():
        _cards[i].set_pressed_no_signal(i == _picker.index)
        _cards[i].set_animated(i == _picker.index)
        _cards[i].queue_redraw()
    if _choose_button != null:
        _choose_button.accessibility_description = "Choisir %s" % _picker.selected().display_name
