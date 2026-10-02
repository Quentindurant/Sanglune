class_name HuntNightCard
extends Button
## Une nuit de Chasse à choisir : sa lune, son nom, sa force en losanges rouges, le meilleur butin du Grand Veneur
## et le record. Une nuit fermée est voilée, avec un cadenas et ce qu'il faut finir pour l'ouvrir.

var level: int
var record := 0
var unlocked := true
var selected := false:
    set(value):
        selected = value
        _restyle()


func _init(p_level: int, p_size: Vector2, p_record: int, p_unlocked: bool) -> void:
    level = p_level
    record = p_record
    unlocked = p_unlocked
    custom_minimum_size = p_size
    size = p_size
    add_theme_stylebox_override("focus", UiStyle.box(Color.TRANSPARENT, Palette.INK, 3))
    _restyle()
    accessibility_name = describe()


func describe() -> String:
    var words := [HuntDifficulty.display_name(level)]
    if not unlocked:
        words.append("fermée, finis d'abord %s" % HuntDifficulty.display_name(HuntDifficulty.requirement(level)))
    elif record >= Hunt.LENGTH:
        words.append("finie")
    elif record > 0:
        words.append("record %d sur %d" % [record, Hunt.LENGTH])
    return ", ".join(words)


func _restyle() -> void:
    var border := Palette.MOON if selected else Palette.PURPLE
    var width := 4 if selected else 2
    add_theme_stylebox_override("normal", UiStyle.box(Palette.DUSK, border, width))
    add_theme_stylebox_override("hover", UiStyle.box(Palette.DUSK.lightened(0.05), Palette.MOON if selected else Palette.QUIET, width))
    add_theme_stylebox_override("pressed", UiStyle.box(Palette.DUSK.lightened(0.1), Palette.MOON, 4))
    add_theme_stylebox_override("hover_pressed", UiStyle.box(Palette.DUSK.lightened(0.1), Palette.MOON, 4))
    queue_redraw()


func _draw() -> void:
    var cx := size.x / 2
    GearView.draw_moon(self, Vector2(cx, 92), 54, HuntView.night_phase(level))
    HuntView.centered(self, 196, 0, size.x, HuntDifficulty.display_name(level), 36, Palette.INK)
    HuntView.draw_danger(self, Vector2(cx, 222), level)
    if not unlocked:
        draw_rect(Rect2(Vector2(4, 4), size - Vector2(8, 8)), Color(Palette.NIGHT, 0.55))
        HuntView.draw_lock(self, Vector2(cx, 274), 18, Palette.QUIET)
        HuntView.centered(self, 330, 0, size.x, "Finis la %s" % HuntDifficulty.display_name(HuntDifficulty.requirement(level)), 22, Palette.QUIET)
        return
    var font := UiStyle.TEXT_FONT
    var loot := "Butin"
    var loot_width := font.get_string_size(loot, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
    var left := cx - (loot_width + 40) / 2
    draw_string(font, Vector2(left, 278), loot, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Palette.QUIET)
    GearView.draw_moon(self, Vector2(left + loot_width + 26, 270), 13, HuntView.best_rarity(level))
    var record_text := "Finie" if record >= Hunt.LENGTH else ("Record %d / %d" % [record, Hunt.LENGTH] if record > 0 else "")
    if record_text != "":
        HuntView.centered(self, 326, 0, size.x, record_text, 22, Palette.CYAN if record >= Hunt.LENGTH else Palette.QUIET)
