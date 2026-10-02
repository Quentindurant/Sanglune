class_name HuntOfferScreen
extends Control
## Après un duel gagné de la Chasse : trois récompenses côte à côte. Toucher une carte la choisit, « Prendre » la garde.
## Une pièce neuve peut s'équiper tout de suite ; « Continuer » ramène au chemin de la Chasse.

signal continue_requested
signal home_requested

const VIEW := Vector2(1280, 720)
const CARD_SIZE := Vector2(360, 400)
const CARD_TOP := 162.0
const CARD_GAP := 30.0
const BUTTON_TOP := 620.0
const BUTTON_HEIGHT := 76.0

var profile: PlayerProfile
var hunt: Hunt
var cards: Array[HuntRewardCard] = []
var choice := -1
var taken: HuntReward ## la récompense prise, ou null
var _take_button: Button
var _equip_button: Button


func _init(p_profile: PlayerProfile, p_hunt: Hunt) -> void:
    profile = p_profile
    hunt = p_hunt


func _ready() -> void:
    InputBindings.register()
    set_anchors_preset(Control.PRESET_FULL_RECT)
    var choices := hunt.offer()
    var total := CARD_SIZE.x * choices.size() + CARD_GAP * (choices.size() - 1)
    var x := (VIEW.x - total) / 2
    for i in choices.size():
        var reward := choices[i]
        var owned := hunt.blessing_count(reward.blessing_id) if reward.kind == HuntReward.Kind.BLESSING else 0
        var card := HuntRewardCard.new(reward, CARD_SIZE, owned, hunt.wounds)
        card.position = Vector2(x, CARD_TOP)
        card.pressed.connect(select.bind(i))
        add_child(card)
        cards.append(card)
        x += CARD_SIZE.x + CARD_GAP
    var home := UiStyle.make_button("Accueil", false, Vector2(200, BUTTON_HEIGHT))
    home.position = Vector2(40, BUTTON_TOP)
    home.pressed.connect(home_requested.emit)
    add_child(home)
    _take_button = UiStyle.make_button("Prendre", true, Vector2(330, BUTTON_HEIGHT))
    _take_button.position = Vector2(VIEW.x - 40 - 330, BUTTON_TOP)
    _take_button.pressed.connect(take)
    _take_button.disabled = true
    add_child(_take_button)


func _process(_delta: float) -> void:
    queue_redraw()


func select(index: int) -> void:
    if taken != null or index < 0 or index >= cards.size():
        return
    choice = index
    for i in cards.size():
        cards[i].selected = i == index
    _take_button.disabled = false
    if not OS.has_feature("mobile"):
        _take_button.grab_focus()


## Garde la récompense choisie. Une pièce neuve laisse le temps de l'équiper ; sinon on repart aussitôt.
func take() -> void:
    if taken != null:
        continue_requested.emit()
        return
    if choice < 0:
        return
    taken = hunt.choose(choice, profile)
    if taken == null:
        return
    if not taken.has_new_piece():
        continue_requested.emit()
        return
    for i in cards.size():
        cards[i].disabled = true
        cards[i].modulate.a = 1.0 if i == choice else 0.35
    _take_button.text = "Continuer"
    _equip_button = UiStyle.make_button("Équiper", false, Vector2(230, BUTTON_HEIGHT))
    _equip_button.position = Vector2(VIEW.x - 40 - 330 - 20 - 230, BUTTON_TOP)
    _equip_button.pressed.connect(equip)
    add_child(_equip_button)


func equip() -> void:
    if taken == null or not taken.has_new_piece():
        return
    profile.equip(hunt.knight_id, taken.item.uid)
    _equip_button.text = "Équipé"
    _equip_button.disabled = true


func is_equipped() -> bool:
    return taken != null and taken.has_new_piece() and profile.equipped(hunt.knight_id, taken.item.def.slot) == taken.item


func go_back() -> bool:
    home_requested.emit()
    return true


func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, VIEW), Palette.NIGHT)
    draw_circle(Vector2(VIEW.x / 2, 360), 330, Color(Palette.MOON, 0.05))
    draw_string(UiStyle.TITLE_FONT, Vector2(0, 80), "Victoire", HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 60, Palette.INK)
    var line := "Duel %d / %d gagné · choisis ta récompense" % [hunt.index + 1, Hunt.LENGTH]
    if hunt.boss_just_beaten != &"":
        line = "%s vaincu · choisis ta récompense" % Boss.display_name(hunt.boss_just_beaten)
    if taken != null: ## la Chasse est déjà passée au duel suivant
        var next := Boss.display_name(hunt.boss_id()) if hunt.is_boss() else "duel %d / %d" % [hunt.index + 1, Hunt.LENGTH]
        line = "Prochain : %s" % next
    HuntView.centered(self, 120, 0, VIEW.x, line, 24, Palette.QUIET)
    if taken == null and hunt.boss_just_beaten in hunt.first_kills:
        HuntView.centered(self, 146, 0, VIEW.x, "Nouveau au bestiaire · +%d éclats" % Boss.FIRST_KILL_SHARDS, 20, Palette.CYAN)
