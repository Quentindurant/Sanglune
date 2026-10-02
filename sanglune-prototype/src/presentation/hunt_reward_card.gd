class_name HuntRewardCard
extends Button
## Une récompense de la Chasse à toucher : en haut, si elle ne vaut que pour la Chasse ou si elle se garde ;
## au milieu, son dessin ; puis son nom et ce qu'elle fait. Toucher la carte la choisit, « Prendre » confirme.

const BAND_HEIGHT := 46.0
const ICON_Y := 140.0
const NAME_Y := 250.0
const EFFECT_Y := 292.0
const EFFECT_SIZE := 19
const PADDING := 18.0

var reward: HuntReward
var owned := 0 ## combien de fois la Chasse a déjà cette bénédiction
var wounds := 0 ## les blessures qu'efface un soin
var selected := false:
    set(value):
        selected = value
        _restyle()


func _init(p_reward: HuntReward, p_size: Vector2, p_owned: int = 0, p_wounds: int = 0) -> void:
    reward = p_reward
    owned = p_owned
    wounds = p_wounds
    custom_minimum_size = p_size
    size = p_size
    add_theme_stylebox_override("focus", UiStyle.box(Color.TRANSPARENT, Palette.INK, 3))
    _restyle()
    accessibility_name = describe()


## Ce que lit un lecteur d'écran.
func describe() -> String:
    var words := ["À garder" if reward.is_permanent() else "Pour la Chasse", title()]
    var effect := effect_text()
    if effect != "":
        words.append(effect)
    return ", ".join(words)


func title() -> String:
    match reward.kind:
        HuntReward.Kind.BLESSING:
            return Blessing.display_name(reward.blessing_id)
        HuntReward.Kind.PIECE:
            return reward.def.display_name
        HuntReward.Kind.SHARDS:
            return "Éclats"
        HuntReward.Kind.HEAL:
            return "Soin"
        HuntReward.Kind.TEAR:
            return "Larme de lune"
    return ""


## L'effet en mots, quand il ne se dessine pas en flèches.
func effect_text() -> String:
    match reward.kind:
        HuntReward.Kind.BLESSING:
            if Blessing.is_trait(reward.blessing_id):
                return GearTrait.describe(Blessing.gear_trait(reward.blessing_id))
            var parts := []
            var effect := Blessing.mods(reward.blessing_id)
            for stat: int in effect:
                parts.append("%s %s" % [GearStat.LABEL[stat], GearView.percent(effect[stat])])
            return ", ".join(parts)
        HuntReward.Kind.SHARDS:
            return "+%d éclats" % reward.shards
        HuntReward.Kind.HEAL:
            return "Efface tes blessures"
        HuntReward.Kind.TEAR:
            return "Rejoue un duel perdu"
        HuntReward.Kind.PIECE:
            return Rarity.display_name(reward.rarity)
    return ""


func _restyle() -> void:
    var border := Palette.INK if selected else Palette.PURPLE
    var width := 4 if selected else 2
    var bg := Palette.DUSK.lightened(0.08) if selected else Palette.DUSK
    add_theme_stylebox_override("normal", UiStyle.box(bg, border, width))
    add_theme_stylebox_override("hover", UiStyle.box(bg.lightened(0.05), Palette.INK if selected else Palette.QUIET, width))
    add_theme_stylebox_override("pressed", UiStyle.box(bg.lightened(0.1), Palette.INK, 4))
    add_theme_stylebox_override("hover_pressed", UiStyle.box(bg.lightened(0.1), Palette.INK, 4))
    queue_redraw()


func _draw() -> void:
    var color := HuntView.KEPT if reward.is_permanent() else HuntView.TEMPORARY
    var band := Rect2(Vector2(6, 6), Vector2(size.x - 12, BAND_HEIGHT - 6))
    draw_rect(band, Color(color, 0.12))
    HuntView.centered(self, 36, 0, size.x, "À garder" if reward.is_permanent() else "Pour la Chasse", 21, color)
    var icon := Vector2(size.x / 2, ICON_Y)
    match reward.kind:
        HuntReward.Kind.BLESSING:
            HuntView.draw_rune(self, icon, 52, Blessing.is_trait(reward.blessing_id))
        HuntReward.Kind.PIECE:
            GearView.draw_moon(self, icon, 44, reward.rarity)
        HuntReward.Kind.SHARDS:
            GearView.draw_shard(self, icon + Vector2(-16, 6), 30)
            GearView.draw_shard(self, icon + Vector2(18, -8), 38)
        HuntReward.Kind.HEAL:
            HuntView.draw_heal(self, icon, 46)
        HuntReward.Kind.TEAR:
            HuntView.draw_tear(self, icon, 52)
    HuntView.centered(self, NAME_Y, PADDING, size.x - PADDING * 2, title(), 30, Palette.INK)
    _draw_effect()
    if reward.kind == HuntReward.Kind.BLESSING and owned > 0:
        HuntView.centered(self, size.y - 22, 0, size.x, "Déjà ×%d" % owned, 19, Palette.QUIET)
    if reward.kind == HuntReward.Kind.HEAL and wounds > 0:
        for i in wounds:
            HuntView.draw_wound(self, Vector2(size.x / 2 + (i - (wounds - 1) / 2.0) * 28, size.y - 30), 9)


func _draw_effect() -> void:
    var width := size.x - PADDING * 2
    match reward.kind:
        HuntReward.Kind.BLESSING:
            var lines := HuntView.blessing_lines(reward.blessing_id)
            if not lines[1].is_empty():
                var line_width := GearView.effect_line_width(lines[1], EFFECT_SIZE)
                GearView.draw_effect_line(self, Vector2((size.x - line_width) / 2, EFFECT_Y), lines[1], EFFECT_SIZE, true)
            else:
                draw_multiline_string(UiStyle.TEXT_FONT, Vector2(PADDING, EFFECT_Y), lines[2], HORIZONTAL_ALIGNMENT_CENTER,
                    width, EFFECT_SIZE, 3, Palette.QUIET)
        HuntReward.Kind.PIECE:
            var item := OwnedItem.new(0, reward.def, reward.rarity)
            var y := EFFECT_Y
            for row: Array in GearView.effect_rows(item, EFFECT_SIZE, width):
                var line_width := GearView.effect_line_width(row[0], EFFECT_SIZE)
                GearView.draw_effect_line(self, Vector2((size.x - line_width) / 2, y), row[0], EFFECT_SIZE, row[1])
                y += 27
            if item.gear_trait() != GearTrait.Trait.NONE:
                HuntView.centered(self, y, PADDING, width, GearTrait.display_name(item.gear_trait()), EFFECT_SIZE, Palette.MOON)
        _:
            HuntView.centered(self, EFFECT_Y, PADDING, width, effect_text(), 22, Palette.QUIET)
