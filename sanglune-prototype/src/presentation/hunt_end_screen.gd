class_name HuntEndScreen
extends Control
## Fin d'une Chasse. Le dernier seigneur tombé : la pièce rare apparaît, déjà essayée sur le pantin qui lève l'arme,
## « Équiper » la pose. Sinon : jusqu'où l'on est allé, les éclats gagnés et le record.
## Les seigneurs vaincus sont rappelés, ceux qui entrent au bestiaire marqués. Une nuit qui s'ouvre s'annonce. « Nouvelle Chasse » ramène au choix des nuits, « Accueil » à l'accueil.

signal again_requested
signal home_requested

const VIEW := Vector2(1280, 720)
const FEET_Y := 600.0
const PUPPET_X := 300.0
const PUPPET_SCALE := 1.5
const CARD_SIZE := Vector2(560, 150)
const CARD_POSITION := Vector2(620, 200)
const BUTTON_TOP := 620.0
const BUTTON_HEIGHT := 76.0

var profile: PlayerProfile
var end: HuntEnd
var knight_id: StringName
var _equip_button: Button
var _card: GearPieceButton


func _init(p_profile: PlayerProfile, p_end: HuntEnd, p_knight_id: StringName) -> void:
    profile = p_profile
    end = p_end
    knight_id = p_knight_id


func _ready() -> void:
    InputBindings.register()
    set_anchors_preset(Control.PRESET_FULL_RECT)
    var again := UiStyle.make_button("Nouvelle Chasse", true, Vector2(330, BUTTON_HEIGHT))
    again.position = Vector2(VIEW.x - 40 - 330, BUTTON_TOP)
    again.pressed.connect(again_requested.emit)
    add_child(again)
    var home := UiStyle.make_button("Accueil", false, Vector2(200, BUTTON_HEIGHT))
    home.position = Vector2(40, BUTTON_TOP)
    home.pressed.connect(home_requested.emit)
    add_child(home)
    if end.reward != null:
        var card_size := Vector2(CARD_SIZE.x, maxf(CARD_SIZE.y, GearPieceButton.needed_height(end.reward.item, CARD_SIZE.x, false)))
        _card = GearPieceButton.new(end.reward.item, card_size)
        _card.position = CARD_POSITION
        _card.mouse_filter = Control.MOUSE_FILTER_IGNORE
        _card.focus_mode = Control.FOCUS_NONE
        _card.modulate.a = 0.5 if end.reward.duplicate else 1.0
        add_child(_card)
        if end.reward.has_new_piece():
            _equip_button = UiStyle.make_button("Équiper", false, Vector2(230, BUTTON_HEIGHT))
            _equip_button.position = Vector2(VIEW.x - 40 - 330 - 20 - 230, BUTTON_TOP)
            _equip_button.pressed.connect(equip)
            add_child(_equip_button)
    var puppet := KnightPuppet.new()
    var halo: Array[Vector2] = [Vector2(-2, -2)]
    var trying := end.reward.item if end.reward != null and end.reward.has_new_piece() else null
    puppet.setup(knight_id, Palette.CYAN, halo, true, profile.look(knight_id, trying))
    puppet.position = Vector2(PUPPET_X, FEET_Y)
    puppet.scale = Vector2.ONE * PUPPET_SCALE
    puppet.z_index = 5
    puppet.show_pose(KnightPose.merge(KnightPose.GUARD, KnightPose.VICTORY) if end.won else KnightPose.GUARD)
    add_child(puppet)
    if not OS.has_feature("mobile"):
        again.grab_focus.call_deferred()


func equip() -> void:
    if end.reward == null or not end.reward.has_new_piece():
        return
    profile.equip(knight_id, end.reward.item.uid)
    _equip_button.text = "Équipé"
    _equip_button.disabled = true


func is_equipped() -> bool:
    return end.reward != null and end.reward.has_new_piece() and profile.equipped(knight_id, end.reward.item.def.slot) == end.reward.item


func go_back() -> bool:
    home_requested.emit()
    return true


func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("frappe"):
        again_requested.emit()
        get_viewport().set_input_as_handled()


func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, VIEW), Palette.NIGHT)
    draw_circle(Vector2(PUPPET_X, 400), 230, Color(Palette.MOON, 0.16 if end.won else 0.08))
    draw_line(Vector2(PUPPET_X - 140, FEET_Y), Vector2(PUPPET_X + 140, FEET_Y), Color(Palette.QUIET, 0.35), 2.0)
    var title := "Chasse accomplie" if end.won else "Fin de la Chasse"
    draw_string(UiStyle.TITLE_FONT, Vector2(CARD_POSITION.x, 96), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 60, Palette.INK)
    var where := "%s · %d / %d" % [HuntDifficulty.display_name(end.difficulty), end.duels_won, Hunt.LENGTH]
    draw_string(UiStyle.TEXT_FONT, Vector2(CARD_POSITION.x, 140), where, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Palette.QUIET)
    var y: float = CARD_POSITION.y + (_card.size.y + 60.0 if _card != null else 40.0)
    if end.reward != null and end.reward.duplicate:
        draw_string(UiStyle.TEXT_FONT, Vector2(CARD_POSITION.x, y - 24), "Déjà possédée : changée en éclats", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Palette.QUIET)
        y += 16
    var shards := end.shards + (end.reward.shards if end.reward != null and end.reward.duplicate else 0)
    GearView.draw_shard(self, Vector2(CARD_POSITION.x + 10, y - 10), 11.0)
    draw_string(UiStyle.TEXT_FONT, Vector2(CARD_POSITION.x + 30, y), "+%d éclats" % shards, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Palette.INK)
    y += 56
    if end.new_record:
        draw_string(UiStyle.TEXT_FONT, Vector2(CARD_POSITION.x, y), "Nouveau record", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Palette.CYAN)
        y += 48
    if end.unlocked >= 0:
        GearView.draw_moon(self, Vector2(CARD_POSITION.x + 16, y - 10), 16, HuntView.night_phase(end.unlocked))
        draw_string(UiStyle.TEXT_FONT, Vector2(CARD_POSITION.x + 44, y), "%s s'ouvre" % HuntDifficulty.display_name(end.unlocked),
            HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Palette.MOON)
        y += 48
    for boss in end.bosses_beaten:
        var c := Vector2(CARD_POSITION.x + 10, y - 9)
        draw_colored_polygon(PackedVector2Array([c + Vector2(0, -8), c + Vector2(7, 0), c + Vector2(0, 8), c + Vector2(-7, 0)]), Palette.FOE_RED)
        var text := Boss.display_name(boss) + (" · nouveau au bestiaire" if boss in end.first_kills else "")
        draw_string(UiStyle.TEXT_FONT, Vector2(CARD_POSITION.x + 30, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24,
            Palette.CYAN if boss in end.first_kills else Palette.QUIET)
        y += 36
