class_name ArmoryScreen
extends Control
## Armurerie d'un chevalier : son pantin au centre, ses quatre emplacements autour.
## Toucher un emplacement ouvre ses pièces ; toucher une pièce l'essaie sur le pantin ; « Équiper » la pose,
## « Améliorer » lui fait gagner un niveau contre des éclats, « Recycler » la change en éclats (deux touches pour confirmer).
## Le retour ferme la liste, puis l'armurerie.

signal closed
signal wardrobe_requested

const VIEW := Vector2(1280, 720)
const FEET_Y := 640.0
const PUPPET_SCALE := 1.6
const SLOTS_PUPPET_X := 640.0
const PICKER_PUPPET_X := 320.0
const TILE_SIZE := Vector2(340, 214) ## de quoi loger une arme Pleine lune : gains, perte, ultime et trait
const TILE_POSITIONS := {
    ItemDef.Slot.WEAPON: Vector2(40, 126), ItemDef.Slot.HELM: Vector2(40, 352),
    ItemDef.Slot.ARMOR: Vector2(900, 126), ItemDef.Slot.TALISMAN: Vector2(900, 352),
}
const LIST_RECT := Rect2(620, 124, 620, 476)
const ROW_WIDTH := 596.0
const BUTTONS_TOP := 616.0
const RECYCLE_BUTTON_SIZE := Vector2(172, 80)
const UPGRADE_BUTTON_SIZE := Vector2(250, 80)
const EQUIP_BUTTON_SIZE := Vector2(174, 80)
const BUTTON_GAP := 12.0
const BACK_BUTTON_SIZE := Vector2(170, 56)

var profile: PlayerProfile
var knight: KnightClass
var _tiles := {} ## emplacement -> GearPieceButton
var _picker_slot := -1
var _preview: OwnedItem ## la pièce essayée ; null pour « Rien »
var _rows: Array[GearPieceButton] = []
var _list: VBoxContainer
var _scroll: ScrollContainer
var _equip_button: Button
var _upgrade_button: Button
var _recycle_button: Button
var _wardrobe_button: Button
var _recycle_armed := false ## première touche sur « Recycler » : la seconde confirme
var _puppet: KnightPuppet


func _init(p_profile: PlayerProfile, knight_id: StringName) -> void:
    profile = p_profile
    knight = KnightClass.by_id(knight_id)
    if knight == null:
        knight = KnightClass.starter()


func _ready() -> void:
    InputBindings.register()
    set_anchors_preset(Control.PRESET_FULL_RECT)
    _build_list()
    var back := UiStyle.make_button("Retour", false, BACK_BUTTON_SIZE)
    back.position = Vector2(32, 20)
    back.pressed.connect(go_back)
    add_child(back)
    var x := LIST_RECT.position.x
    _recycle_button = _small_button("Recycler", false, RECYCLE_BUTTON_SIZE, x, recycle_preview)
    x += RECYCLE_BUTTON_SIZE.x + BUTTON_GAP
    _upgrade_button = _small_button("Améliorer", false, UPGRADE_BUTTON_SIZE, x, upgrade_preview)
    x += UPGRADE_BUTTON_SIZE.x + BUTTON_GAP
    _equip_button = _small_button("Équiper", true, EQUIP_BUTTON_SIZE, x, equip_preview)
    _wardrobe_button = UiStyle.make_button("Garde-robe", false, Vector2(TILE_SIZE.x, 72))
    _wardrobe_button.position = Vector2(TILE_POSITIONS[ItemDef.Slot.WEAPON].x, BUTTONS_TOP)
    _wardrobe_button.pressed.connect(wardrobe_requested.emit)
    add_child(_wardrobe_button)
    _refresh()


func is_picker_open() -> bool:
    return _picker_slot >= 0


## Ouvre la liste des pièces d'un emplacement ; la pièce portée est essayée d'emblée.
func open_slot(slot: int) -> void:
    _picker_slot = slot
    _recycle_armed = false
    _preview = profile.equipped(knight.id, slot)
    _refresh()


## Essaie une pièce sur le pantin, sans rien changer à l'équipement. null : essayer l'emplacement vide.
func preview(item: OwnedItem) -> void:
    _preview = item
    _recycle_armed = false
    _refresh_picker_state()


func previewed() -> OwnedItem:
    return _preview


## Pose la pièce essayée, puis revient aux quatre emplacements.
func equip_preview() -> void:
    if not is_picker_open():
        return
    if _preview == null:
        profile.unequip(knight.id, _picker_slot)
    else:
        profile.equip(knight.id, _preview.uid)
    close_picker()


## Fait gagner un niveau à la pièce essayée, contre des éclats. La liste et la puissance suivent.
func upgrade_preview() -> void:
    _recycle_armed = false
    if _preview == null or not profile.upgrade(_preview.uid):
        return
    _rebuild_rows()
    _refresh_picker_state()


## Recycle la pièce essayée : la première touche demande confirmation, la seconde la change en éclats.
func recycle_preview() -> void:
    if _preview == null or not profile.can_recycle(_preview.uid):
        return
    if not _recycle_armed:
        _recycle_armed = true
        _refresh_recycle_button()
        return
    profile.recycle(_preview.uid)
    _preview = profile.equipped(knight.id, _picker_slot)
    _rebuild_rows()
    _refresh_picker_state()


func close_picker() -> void:
    _picker_slot = -1
    _preview = null
    _refresh()


## Le retour Android ferme d'abord la liste, puis l'armurerie.
func go_back() -> bool:
    if is_picker_open():
        close_picker()
    else:
        closed.emit()
    return true


## Ce que porterait le chevalier avec la pièce essayée.
func preview_loadout() -> Loadout:
    if not is_picker_open():
        return profile.loadout(knight.id)
    var result := Loadout.new(knight.id)
    for slot in ItemDef.SLOTS:
        var worn := profile.equipped(knight.id, slot)
        if slot != _picker_slot and worn != null:
            result.wear(worn)
    if _preview != null:
        result.wear(_preview)
    return result


## La silhouette pendant un essai : la garde-robe, sauf à l'emplacement essayé. « Rien » essayé n'y montre rien.
func _preview_look(trying: OwnedItem) -> Dictionary:
    if is_picker_open() and trying == null:
        var look := profile.look(knight.id)
        var worn := profile.equipped(knight.id, _picker_slot)
        if worn != null:
            for key: String in worn.def.look:
                look.erase(key)
        return look
    return profile.look(knight.id, trying)


func tile(slot: int) -> GearPieceButton:
    return _tiles.get(slot)


func rows() -> Array[GearPieceButton]:
    return _rows


func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, VIEW), Palette.NIGHT)
    var puppet_x := PICKER_PUPPET_X if is_picker_open() else SLOTS_PUPPET_X
    draw_circle(Vector2(puppet_x, 380), 250, Color(Palette.MOON, 0.1))
    draw_line(Vector2(puppet_x - 150, FEET_Y), Vector2(puppet_x + 150, FEET_Y), Color(Palette.QUIET, 0.35), 2.0)
    draw_string(UiStyle.TITLE_FONT, Vector2(0, 70), knight.display_name, HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 52, Palette.INK)
    _draw_power()
    if is_picker_open():
        draw_string(UiStyle.TEXT_FONT, Vector2(LIST_RECT.position.x, LIST_RECT.position.y - 14),
            ItemDef.SLOT_NAMES[_picker_slot], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Palette.QUIET)


## La puissance du chevalier ; pendant un essai, la puissance qu'il aurait, plus haute ou plus basse.
func _draw_power() -> void:
    var font := UiStyle.TEXT_FONT
    var current := profile.loadout(knight.id).power()
    var right := VIEW.x - 32
    var tried := preview_loadout().power()
    if tried != current:
        var color := Palette.GAIN if tried > current else Palette.LOSS
        draw_string(font, Vector2(0, 62), str(tried), HORIZONTAL_ALIGNMENT_RIGHT, right, 34, color)
        right -= font.get_string_size(str(tried), HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x + 12
        var mid := Vector2(right - 6, 50)
        draw_colored_polygon(PackedVector2Array([mid + Vector2(-6, -7), mid + Vector2(6, 0), mid + Vector2(-6, 7)]), color)
        right -= 22
    draw_string(font, Vector2(0, 62), str(current), HORIZONTAL_ALIGNMENT_RIGHT, right, 34, Palette.INK)
    draw_string(font, Vector2(0, 86), "Puissance", HORIZONTAL_ALIGNMENT_RIGHT, VIEW.x - 32, 20, Palette.QUIET)
    var shards := "%d éclats" % profile.shards
    draw_string(font, Vector2(0, 112), shards, HORIZONTAL_ALIGNMENT_RIGHT, VIEW.x - 32, 20, Palette.QUIET)
    var shard_x := VIEW.x - 32 - font.get_string_size(shards, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x - 12
    GearView.draw_shard(self, Vector2(shard_x, 105), 7.0)


func _build_list() -> void:
    _scroll = ScrollContainer.new()
    _scroll.position = LIST_RECT.position
    _scroll.size = LIST_RECT.size
    _scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    _scroll.follow_focus = true ## au clavier, la liste suit la pièce visée
    add_child(_scroll)
    _list = VBoxContainer.new()
    _list.add_theme_constant_override("separation", 12)
    _scroll.add_child(_list)


func _refresh() -> void:
    if _wardrobe_button != null:
        _wardrobe_button.visible = not is_picker_open()
    _rebuild_tiles()
    _rebuild_rows()
    _refresh_picker_state()


func _rebuild_tiles() -> void:
    for old: GearPieceButton in _tiles.values():
        old.queue_free()
    _tiles.clear()
    if is_picker_open():
        return
    for slot: int in TILE_POSITIONS:
        var piece := GearPieceButton.new(profile.equipped(knight.id, slot), TILE_SIZE, ItemDef.SLOT_NAMES[slot])
        piece.position = TILE_POSITIONS[slot]
        piece.pressed.connect(open_slot.bind(slot))
        add_child(piece)
        _tiles[slot] = piece
    _focus_for_keyboard(_tiles[ItemDef.Slot.WEAPON])


func _rebuild_rows() -> void:
    for old in _rows:
        old.queue_free()
    _rows.clear()
    _scroll.visible = is_picker_open()
    if not is_picker_open():
        return
    var worn := profile.equipped(knight.id, _picker_slot)
    var choices: Array = []
    choices.append_array(profile.items_for(knight.id, _picker_slot))
    if _picker_slot != ItemDef.Slot.WEAPON:
        choices.append(null) ## « Rien » : retirer la pièce
    for choice: OwnedItem in choices:
        var row_size := Vector2(ROW_WIDTH, GearPieceButton.needed_height(choice, ROW_WIDTH, false))
        var row := GearPieceButton.new(choice, row_size, "", choice == worn)
        row.toggle_mode = true
        row.mouse_filter = Control.MOUSE_FILTER_PASS ## au doigt, glisser sur une pièce fait défiler la liste
        row.pressed.connect(preview.bind(choice))
        _list.add_child(row)
        _rows.append(row)
    if not _rows.is_empty():
        _focus_for_keyboard(_rows[0])


## Au clavier, le focus permet de naviguer aux flèches. Au doigt, un contour de focus ferait croire à une sélection.
func _focus_for_keyboard(control: Control) -> void:
    if not OS.has_feature("mobile"):
        control.grab_focus.call_deferred()


## Ce qui suit l'essai : la ligne enfoncée, le pantin habillé, le bouton « Équiper » s'il y a quelque chose à changer.
func _refresh_picker_state() -> void:
    for row in _rows:
        row.set_pressed_no_signal(row.item == _preview)
    var changes := is_picker_open() and _preview != profile.equipped(knight.id, _picker_slot)
    _equip_button.visible = changes
    _refresh_upgrade_button()
    _refresh_recycle_button()
    _rebuild_puppet()
    queue_redraw()


## « Améliorer · 16 éclats » sous une pièce qui peut encore monter ; grisé s'il manque des éclats.
func _refresh_upgrade_button() -> void:
    var upgradable := is_picker_open() and _preview != null and not _preview.def.starter \
        and _preview.level < PowerBudget.MAX_LEVEL
    _upgrade_button.visible = upgradable
    if upgradable:
        _upgrade_button.text = "Améliorer · %d éclats" % PowerBudget.upgrade_cost(_preview.level)
        _upgrade_button.disabled = not profile.can_upgrade(_preview.uid)


## « Recycler +12 » sous une pièce ni portée ni de départ ; après une touche, « Confirmer ? ».
func _refresh_recycle_button() -> void:
    var recyclable := is_picker_open() and _preview != null and profile.can_recycle(_preview.uid)
    _recycle_button.visible = recyclable
    if not recyclable:
        _recycle_armed = false
        return
    var value := PowerBudget.shard_value(_preview.rarity, _preview.level)
    _recycle_button.text = "Confirmer ?" if _recycle_armed else "Recycler +%d" % value
    var border := Palette.LOSS if _recycle_armed else Palette.QUIET ## armé, le bouton se cerne de rouge sourd
    _recycle_button.add_theme_stylebox_override("normal", UiStyle.box(Palette.DUSK, border, 3 if _recycle_armed else 2))


func _small_button(text: String, primary: bool, button_size: Vector2, x: float, action: Callable) -> Button:
    var button := UiStyle.make_button(text, primary, button_size)
    button.add_theme_font_size_override("font_size", 24)
    button.position = Vector2(x, BUTTONS_TOP)
    button.pressed.connect(action)
    add_child(button)
    return button


func _rebuild_puppet() -> void:
    if _puppet != null:
        _puppet.queue_free()
    _puppet = KnightPuppet.new()
    var halo: Array[Vector2] = [Vector2(-2, -2)]
    var trying := _preview if is_picker_open() else null
    _puppet.setup(knight.id, Palette.CYAN, halo, true, _preview_look(trying))
    _puppet.position = Vector2(PICKER_PUPPET_X if is_picker_open() else SLOTS_PUPPET_X, FEET_Y)
    _puppet.scale = Vector2.ONE * PUPPET_SCALE
    _puppet.z_index = 5
    _puppet.auto_idle = true
    add_child(_puppet)
