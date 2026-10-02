class_name WardrobeScreen
extends Control
## Garde-robe d'un chevalier : pour l'arme, le heaume et l'armure, montrer la pièce portée, une apparence débloquée,
## ou rien. Un choix s'applique tout de suite au pantin ; les apparences encore verrouillées restent grisées.

signal closed

const VIEW := Vector2(1280, 720)
const FEET_Y := 640.0
const PUPPET_X := 320.0
const PUPPET_SCALE := 1.6
const PANEL_X := 620.0
const PANEL_WIDTH := 620.0
const FIRST_ROW_Y := 168.0
const ROW_STEP := 150.0
const CHIP_HEIGHT := 64.0
const CHIP_GAP := 10.0
const SLOTS: Array[int] = [ItemDef.Slot.WEAPON, ItemDef.Slot.HELM, ItemDef.Slot.ARMOR] ## le talisman ne se voit pas
const FOLLOW_LABEL := "Pièce portée"
const NOTHING_LABEL := "Aucune"

var profile: PlayerProfile
var knight: KnightClass
var _chips := {} ## emplacement -> [[Button, valeur], ...]
var _puppet: KnightPuppet


func _init(p_profile: PlayerProfile, knight_id: StringName) -> void:
    profile = p_profile
    knight = KnightClass.by_id(knight_id)
    if knight == null:
        knight = KnightClass.starter()


func _ready() -> void:
    InputBindings.register()
    set_anchors_preset(Control.PRESET_FULL_RECT)
    var back := UiStyle.make_button("Retour", false, Vector2(170, 56))
    back.position = Vector2(32, 20)
    back.pressed.connect(go_back)
    add_child(back)
    for i in SLOTS.size():
        _build_row(SLOTS[i], FIRST_ROW_Y + i * ROW_STEP)
    _refresh()


## Choisit l'apparence d'un emplacement : Wardrobe.FOLLOW, Wardrobe.NOTHING ou un modèle débloqué.
func choose(slot: int, value: StringName) -> void:
    profile.set_appearance(knight.id, slot, value)
    _refresh()


## Les touches d'un emplacement : [[bouton, valeur], ...], pour les tests.
func chips(slot: int) -> Array:
    return _chips.get(slot, [])


func go_back() -> bool:
    closed.emit()
    return true


func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, VIEW), Palette.NIGHT)
    draw_circle(Vector2(PUPPET_X, 380), 250, Color(Palette.MOON, 0.1))
    draw_line(Vector2(PUPPET_X - 150, FEET_Y), Vector2(PUPPET_X + 150, FEET_Y), Color(Palette.QUIET, 0.35), 2.0)
    draw_string(UiStyle.TITLE_FONT, Vector2(0, 70), "Garde-robe", HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 52, Palette.INK)
    draw_string(UiStyle.TEXT_FONT, Vector2(0, 104), knight.display_name, HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 24, Palette.QUIET)
    for i in SLOTS.size():
        draw_string(UiStyle.TEXT_FONT, Vector2(PANEL_X, FIRST_ROW_Y + i * ROW_STEP - 12),
            ItemDef.SLOT_NAMES[SLOTS[i]], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Palette.QUIET)


func _build_row(slot: int, top: float) -> void:
    var options := [[FOLLOW_LABEL, Wardrobe.FOLLOW]]
    for def in profile.wardrobe.looks_for(knight.id, slot):
        options.append([def.look_name, def.id])
    if slot != ItemDef.Slot.WEAPON:
        options.append([NOTHING_LABEL, Wardrobe.NOTHING])
    var width := (PANEL_WIDTH - CHIP_GAP * (options.size() - 1)) / options.size()
    var row := []
    for i in options.size():
        var chip := Button.new()
        chip.text = options[i][0]
        chip.toggle_mode = true
        chip.custom_minimum_size = Vector2(width, CHIP_HEIGHT)
        chip.size = chip.custom_minimum_size
        chip.position = Vector2(PANEL_X + i * (width + CHIP_GAP), top)
        chip.clip_text = true
        chip.add_theme_font_size_override("font_size", 21)
        chip.add_theme_stylebox_override("normal", UiStyle.box(Palette.DUSK, Palette.PURPLE))
        chip.add_theme_stylebox_override("hover", UiStyle.box(Palette.DUSK.lightened(0.06), Palette.QUIET))
        chip.add_theme_stylebox_override("pressed", UiStyle.box(Palette.DUSK.lightened(0.1), Palette.CYAN, 4))
        chip.add_theme_stylebox_override("hover_pressed", UiStyle.box(Palette.DUSK.lightened(0.14), Palette.CYAN, 4))
        chip.add_theme_stylebox_override("disabled", UiStyle.box(Color(Palette.DUSK, 0.4), Color(Palette.PURPLE, 0.4)))
        chip.add_theme_stylebox_override("focus", UiStyle.box(Color.TRANSPARENT, Palette.INK, 3))
        for color_name: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
            chip.add_theme_color_override(color_name, Palette.INK)
        chip.add_theme_color_override("font_disabled_color", Color(Palette.QUIET, 0.4))
        chip.pressed.connect(choose.bind(slot, options[i][1]))
        add_child(chip)
        row.append([chip, options[i][1]])
    _chips[slot] = row


## Les touches suivent le choix et les apparences débloquées ; le pantin porte la garde-robe.
func _refresh() -> void:
    for slot: int in _chips:
        var chosen := profile.wardrobe.choice(knight.id, slot)
        for entry: Array in _chips[slot]:
            var chip: Button = entry[0]
            var value: StringName = entry[1]
            var locked := value != Wardrobe.FOLLOW and value != Wardrobe.NOTHING and not profile.wardrobe.is_unlocked(value)
            chip.disabled = locked
            chip.set_pressed_no_signal(value == chosen)
            chip.accessibility_description = "verrouillée : gagne la pièce pour la débloquer" if locked else ""
    _rebuild_puppet()


func _rebuild_puppet() -> void:
    if _puppet != null:
        _puppet.queue_free()
    _puppet = KnightPuppet.new()
    var halo: Array[Vector2] = [Vector2(-2, -2)]
    _puppet.setup(knight.id, Palette.CYAN, halo, true, profile.look(knight.id))
    _puppet.position = Vector2(PUPPET_X, FEET_Y)
    _puppet.scale = Vector2.ONE * PUPPET_SCALE
    _puppet.z_index = 5
    _puppet.auto_idle = true
    add_child(_puppet)
