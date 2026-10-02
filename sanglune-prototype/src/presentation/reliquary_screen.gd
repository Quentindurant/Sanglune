class_name ReliquaryScreen
extends Control
## Fin d'un duel du Chemin des ombres. Une victoire ouvre un reliquaire : la pièce apparaît, déjà essayée sur le pantin,
## et « Équiper » la pose. Une défaite rapporte des éclats et montre la puissance des deux camps.
## « Combat suivant » (ou « Réessayer ») relance le Chemin, « Accueil » y retourne.

signal next_requested
signal home_requested

const VIEW := Vector2(1280, 720)
const FEET_Y := 600.0
const PUPPET_X := 300.0
const PUPPET_SCALE := 1.5
const RELIQUARY_CENTER := Vector2(900, 262)
const CARD_SIZE := Vector2(560, 150)
const CARD_POSITION := Vector2(620, 340)
const BUTTON_HEIGHT := 76.0
const BUTTON_TOP := 620.0
const OPEN_START := 0.35 ## secondes avant que le couvercle se soulève
const OPEN_TIME := 0.45
const CARD_DELAY := 0.9 ## la pièce apparaît quand le reliquaire est ouvert

var profile: PlayerProfile
var reward: DuelReward
var shadow_power := 0 ## la puissance de l'ombre affrontée, montrée après une défaite
var _card: GearPieceButton
var _equip_button: Button
var _next_button: Button
var _puppet: KnightPuppet
var _time := 0.0


func _init(p_profile: PlayerProfile, p_reward: DuelReward, p_shadow_power: int = 0) -> void:
    profile = p_profile
    reward = p_reward
    shadow_power = p_shadow_power


func _ready() -> void:
    InputBindings.register()
    set_anchors_preset(Control.PRESET_FULL_RECT)
    _build_buttons()
    if reward.item != null:
        var card_size := Vector2(CARD_SIZE.x, maxf(CARD_SIZE.y, GearPieceButton.needed_height(reward.item, CARD_SIZE.x, false)))
        _card = GearPieceButton.new(reward.item, card_size)
        _card.position = CARD_POSITION
        _card.mouse_filter = Control.MOUSE_FILTER_IGNORE
        _card.focus_mode = Control.FOCUS_NONE
        _card.modulate.a = 0.0
        add_child(_card)
    _rebuild_puppet()


func _process(delta: float) -> void:
    _time += delta
    if _card != null:
        var shown := clampf((_time - CARD_DELAY) / 0.3, 0.0, 1.0)
        _card.modulate.a = shown * (0.5 if reward.duplicate else 1.0)
    queue_redraw()


## Saute l'animation (tests, écrans qui défilent vite).
func finish_opening() -> void:
    _time = CARD_DELAY + 1.0
    _process(0.0)


func is_equipped() -> bool:
    return reward.has_new_piece() and profile.equipped(profile.knight_id, reward.item.def.slot) == reward.item


func equip() -> void:
    if not reward.has_new_piece():
        return
    profile.equip(profile.knight_id, reward.item.uid)
    _refresh_equip_button()


func go_back() -> bool:
    home_requested.emit()
    return true


func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("frappe"):
        next_requested.emit()
        get_viewport().set_input_as_handled()


func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, VIEW), Palette.NIGHT)
    draw_circle(Vector2(PUPPET_X, 400), 230, Color(Palette.MOON, 0.1))
    draw_line(Vector2(PUPPET_X - 140, FEET_Y), Vector2(PUPPET_X + 140, FEET_Y), Color(Palette.QUIET, 0.35), 2.0)
    var title := "Victoire" if reward.won else "Défaite"
    draw_string(UiStyle.TITLE_FONT, Vector2(0, 84), title, HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 68, Palette.INK)
    draw_string(UiStyle.TEXT_FONT, Vector2(0, 124), _subtitle(), HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 26, Palette.QUIET)
    if reward.won:
        _draw_reliquary()
        if reward.duplicate and _time > CARD_DELAY:
            draw_string(UiStyle.TEXT_FONT, Vector2(CARD_POSITION.x, CARD_POSITION.y + _card.size.y + 34),
                "Déjà possédée : changée en éclats", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Palette.QUIET)
    else:
        _draw_powers()
    _draw_shards(Vector2(CARD_POSITION.x, 566))
    _draw_guarantee(Vector2(1060, 556))


func _subtitle() -> String:
    if not reward.won:
        return "L'ombre du palier %d t'attend" % reward.palier
    if reward.guardian:
        return "Gardien du palier %d vaincu" % reward.palier
    return "Palier %d franchi" % reward.palier


## Le reliquaire : un coffret à toit pointu dont le toit se soulève, puis la lumière de lune qui en sort.
func _draw_reliquary() -> void:
    var opened := clampf((_time - OPEN_START) / OPEN_TIME, 0.0, 1.0)
    var c := RELIQUARY_CENTER
    if opened > 0.0:
        var rarity := reward.item.rarity if reward.item != null else Rarity.Tier.CROISSANT
        var light := opened * (0.7 + 0.15 * rarity) ## plus la pièce est rare, plus la lumière est vive
        var glow := Color(Palette.MOON, 0.16 * light)
        draw_colored_polygon(PackedVector2Array([c + Vector2(-55, -10), c + Vector2(55, -10), c + Vector2(95, -120), c + Vector2(-95, -120)]), glow)
        draw_circle(c + Vector2(0, -16), 50 * light, Color(Palette.MOON, 0.22 * light))
    var body := PackedVector2Array([c + Vector2(-70, -10), c + Vector2(70, -10), c + Vector2(62, 60), c + Vector2(-62, 60)])
    draw_colored_polygon(body, Palette.SILHOUETTE)
    draw_polyline(_closed(body), Palette.MOON, 2.0)
    draw_rect(Rect2(c + Vector2(-12, 10), Vector2(24, 30)), Color(Palette.MOON, 0.6))
    var hinge := Vector2(-78, -10) ## le toit pivote sur son coin gauche, comme un couvercle
    var tilt := -1.1 * opened
    var lid := PackedVector2Array()
    for point: Vector2 in [Vector2(-78, -10), Vector2(78, -10), Vector2(0, -80)]:
        lid.append(c + hinge + (point - hinge).rotated(tilt))
    draw_colored_polygon(lid, Palette.SILHOUETTE)
    draw_polyline(_closed(lid), Palette.MOON, 2.0)


## Après une défaite : la puissance de l'ombre face à la tienne.
func _draw_powers() -> void:
    var font := UiStyle.TEXT_FONT
    var mine := profile.loadout(profile.knight_id).power()
    draw_string(font, Vector2(CARD_POSITION.x, 260), "Ta puissance", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Palette.QUIET)
    draw_string(font, Vector2(CARD_POSITION.x, 310), str(mine), HORIZONTAL_ALIGNMENT_LEFT, -1, 48, Palette.CYAN)
    if shadow_power > 0:
        draw_string(font, Vector2(CARD_POSITION.x + 300, 260), "L'ombre", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Palette.QUIET)
        draw_string(font, Vector2(CARD_POSITION.x + 300, 310), str(shadow_power), HORIZONTAL_ALIGNMENT_LEFT, -1, 48, Palette.FOE_RED)
    draw_string(font, Vector2(CARD_POSITION.x, 380), "Tes éclats améliorent tes pièces à l'armurerie.", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Palette.QUIET)


## Les éclats gagnés, puis le total.
func _draw_shards(origin: Vector2) -> void:
    GearView.draw_shard(self, origin + Vector2(10, -10), 11.0)
    var font := UiStyle.TEXT_FONT
    var gained := "+%d éclats" % reward.shards
    draw_string(font, origin + Vector2(30, 0), gained, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Palette.INK)
    var x := origin.x + 30 + font.get_string_size(gained, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x + 16
    draw_string(font, Vector2(x, origin.y), "· %d en tout" % profile.shards, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Palette.QUIET)


## La garantie : une lune Gibbeuse entourée d'un anneau qui se remplit à chaque reliquaire sans Gibbeuse ;
## plein, le prochain reliquaire en donne une.
func _draw_guarantee(center: Vector2) -> void:
    GearView.draw_moon(self, center, 15.0, Rarity.Tier.GIBBEUSE)
    var share := float(profile.pity) / LootTable.PITY_LIMIT
    draw_arc(center, 23.0, 0, TAU, 40, Color(Palette.QUIET, 0.3), 3.0)
    if share > 0.0:
        draw_arc(center, 23.0, -PI / 2, -PI / 2 + TAU * share, 40, Palette.MOON, 3.0)
    draw_string(UiStyle.TEXT_FONT, center + Vector2(34, 7), "Vers une Gibbeuse", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Palette.QUIET)


func _build_buttons() -> void:
    var right := VIEW.x - 40
    _next_button = UiStyle.make_button("Combat suivant" if reward.won else "Réessayer", true, Vector2(330, BUTTON_HEIGHT))
    right -= 330
    _next_button.position = Vector2(right, BUTTON_TOP)
    _next_button.pressed.connect(next_requested.emit)
    add_child(_next_button)
    if reward.has_new_piece():
        _equip_button = UiStyle.make_button("Équiper", false, Vector2(230, BUTTON_HEIGHT))
        right -= 230 + 20
        _equip_button.position = Vector2(right, BUTTON_TOP)
        _equip_button.pressed.connect(equip)
        add_child(_equip_button)
        _refresh_equip_button()
    var home := UiStyle.make_button("Accueil", false, Vector2(200, BUTTON_HEIGHT))
    home.position = Vector2(40, BUTTON_TOP)
    home.pressed.connect(home_requested.emit)
    add_child(home)
    if not OS.has_feature("mobile"):
        _next_button.grab_focus.call_deferred()


func _refresh_equip_button() -> void:
    if _equip_button == null:
        return
    var done := is_equipped()
    _equip_button.text = "Équipé" if done else "Équiper"
    _equip_button.disabled = done


## Le chevalier porte déjà la pièce gagnée : on juge la silhouette avant de l'équiper.
func _rebuild_puppet() -> void:
    var look := profile.look(profile.knight_id, reward.item if reward.has_new_piece() else null)
    _puppet = KnightPuppet.new()
    var halo: Array[Vector2] = [Vector2(-2, -2)]
    _puppet.setup(profile.knight_id, Palette.CYAN, halo, true, look)
    _puppet.position = Vector2(PUPPET_X, FEET_Y)
    _puppet.scale = Vector2.ONE * PUPPET_SCALE
    _puppet.z_index = 5
    _puppet.show_pose(KnightPose.merge(KnightPose.GUARD, KnightPose.VICTORY) if reward.won else KnightPose.GUARD)
    add_child(_puppet)


static func _closed(points: PackedVector2Array) -> PackedVector2Array:
    var result := points.duplicate()
    result.append(points[0])
    return result
