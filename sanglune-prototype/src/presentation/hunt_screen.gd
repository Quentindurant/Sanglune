class_name HuntScreen
extends Control
## La Chasse, depuis l'accueil. Sans Chasse en cours : trois nuits à choisir, puis « Partir ».
## Pendant une Chasse : le chemin des sept duels (le chevalier sur le duel à disputer, les deux seigneurs qui attendent),
## ses bénédictions, ses blessures et sa larme ; « Combattre », « Abandonner » (deux touches) et « Accueil ».

signal start_requested(difficulty: int)
signal fight_requested
signal forfeit_requested
signal home_requested
signal bestiary_requested

const VIEW := Vector2(1280, 720)
const CARD_SIZE := Vector2(340, 360)
const CARD_TOP := 170.0
const CARD_GAP := 45.0
const PATH_Y := 360.0
const PATH_LEFT := 160.0
const PATH_STEP := 160.0
const NODE_RADIUS := 18.0
const BOSS_RADIUS := 28.0
const PUPPET_SCALE := 0.62
const FACE_OFF := 64.0 ## sur le nœud d'un seigneur, le chevalier et lui se font face
const BUTTON_TOP := 620.0
const BUTTON_HEIGHT := 76.0
const CHIP_SIZE := 20

var profile: PlayerProfile
var hunt: Hunt ## la Chasse en cours, ou null : on choisit une nuit
var cards: Array[HuntNightCard] = []
var selected_level := HuntDifficulty.Level.PENOMBRE
var _start_button: Button
var _forfeit_button: Button
var _confirming := false
var _puppet: KnightPuppet
var _boss_puppets := {} ## indice du duel -> pantin du seigneur
var _time := 0.0


func _init(p_profile: PlayerProfile) -> void:
    profile = p_profile
    hunt = profile.hunt


func _ready() -> void:
    InputBindings.register()
    set_anchors_preset(Control.PRESET_FULL_RECT)
    var home := UiStyle.make_button("Accueil", false, Vector2(200, BUTTON_HEIGHT))
    home.position = Vector2(40, BUTTON_TOP)
    home.pressed.connect(home_requested.emit)
    add_child(home)
    if hunt == null:
        _build_night_choice()
    else:
        _build_path()


func _process(delta: float) -> void:
    _time += delta
    queue_redraw()


## Choisit une nuit ; une nuit fermée se montre mais ne se choisit pas.
func select_level(level: int) -> void:
    if not HuntDifficulty.is_valid(level):
        return
    selected_level = level
    for card in cards:
        card.selected = card.level == level
    if _start_button != null:
        _start_button.disabled = not profile.hunt_unlocked(level)


func start() -> void:
    if hunt == null and profile.hunt_unlocked(selected_level):
        start_requested.emit(selected_level)


func fight() -> void:
    if hunt != null and hunt.state == Hunt.State.FIGHTING:
        fight_requested.emit()


## Première touche : demande confirmation ; seconde : abandonne la Chasse.
func forfeit() -> void:
    if hunt == null:
        return
    if not _confirming:
        _confirming = true
        _forfeit_button.text = "Confirmer ?"
        _forfeit_button.add_theme_stylebox_override("normal", UiStyle.box(Palette.DUSK, Palette.LOSS, 3))
        return
    forfeit_requested.emit()


func is_confirming_forfeit() -> bool:
    return _confirming


func go_back() -> bool:
    home_requested.emit()
    return true


func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("frappe"):
        if hunt == null:
            start()
        else:
            fight()
        get_viewport().set_input_as_handled()


func _build_night_choice() -> void:
    var levels := HuntDifficulty.all()
    var total := CARD_SIZE.x * levels.size() + CARD_GAP * (levels.size() - 1)
    var x := (VIEW.x - total) / 2
    for level in levels:
        var card := HuntNightCard.new(level, CARD_SIZE, profile.hunt_record(level), profile.hunt_unlocked(level))
        card.position = Vector2(x, CARD_TOP)
        card.pressed.connect(select_level.bind(level))
        add_child(card)
        cards.append(card)
        x += CARD_SIZE.x + CARD_GAP
    _start_button = UiStyle.make_button("Partir", true, Vector2(330, BUTTON_HEIGHT))
    _start_button.position = Vector2(VIEW.x - 40 - 330, BUTTON_TOP)
    _start_button.pressed.connect(start)
    add_child(_start_button)
    var bestiary := UiStyle.make_button("Bestiaire · %d/%d" % [profile.bestiary.size(), Boss.ids().size()], false, Vector2(300, BUTTON_HEIGHT))
    bestiary.position = Vector2((VIEW.x - 300) / 2, BUTTON_TOP)
    bestiary.pressed.connect(bestiary_requested.emit)
    add_child(bestiary)
    select_level(_suggested_level())
    if not OS.has_feature("mobile"):
        _start_button.grab_focus.call_deferred()


## La nuit proposée d'office : la plus dure qu'on a ouverte sans l'avoir finie, sinon la plus dure ouverte.
func _suggested_level() -> int:
    var best := HuntDifficulty.Level.PENOMBRE
    for level in HuntDifficulty.all():
        if profile.hunt_unlocked(level):
            best = level
            if profile.hunt_record(level) < Hunt.LENGTH:
                return level
    return best


func _build_path() -> void:
    var fight_button := UiStyle.make_button("Combattre", true, Vector2(330, BUTTON_HEIGHT))
    fight_button.position = Vector2(VIEW.x - 40 - 330, BUTTON_TOP)
    fight_button.pressed.connect(fight)
    add_child(fight_button)
    _forfeit_button = UiStyle.make_button("Abandonner", false, Vector2(260, BUTTON_HEIGHT))
    _forfeit_button.position = Vector2(260, BUTTON_TOP)
    _forfeit_button.pressed.connect(forfeit)
    add_child(_forfeit_button)
    _puppet = KnightPuppet.new()
    var halo: Array[Vector2] = [Vector2(-2, -2)]
    _puppet.setup(hunt.knight_id, Palette.CYAN, halo, true, profile.look(hunt.knight_id))
    var x := _node_x(hunt.index) - (FACE_OFF if hunt.is_boss() else 0.0)
    _puppet.position = Vector2(x, PATH_Y - BOSS_RADIUS - 6)
    _puppet.scale = Vector2.ONE * PUPPET_SCALE
    _puppet.z_index = 5
    _puppet.auto_idle = true
    add_child(_puppet)
    for i in Hunt.BOSS_DUELS:
        if i >= hunt.index:
            _add_boss_puppet(i)
    if not OS.has_feature("mobile"):
        fight_button.grab_focus.call_deferred()


## Le seigneur d'un duel, debout au-dessus de son nœud, tourné vers le chevalier. Le Reflet a les traits du joueur.
func _add_boss_puppet(i: int) -> void:
    var boss := hunt.boss_id(i)
    var mirror := Boss.rule(boss, Boss.Rule.MIRROR) > 0
    var knight_id := hunt.knight_id if mirror else Boss.knight_id(boss)
    var look := profile.look(hunt.knight_id) if mirror else Boss.look(boss)
    var puppet := KnightPuppet.new()
    var rim: Array[Vector2] = [Vector2(2, -2)]
    puppet.setup(knight_id, Palette.FOE_RED, rim, true, look)
    var x := _node_x(i) + (FACE_OFF if i == hunt.index else 0.0)
    puppet.position = Vector2(x, PATH_Y - BOSS_RADIUS - 6)
    puppet.scale = Vector2(-1, 1) * PUPPET_SCALE * Boss.scale(boss)
    puppet.z_index = 4
    puppet.auto_idle = true
    add_child(puppet)
    _boss_puppets[i] = puppet


func _node_x(i: int) -> float:
    return PATH_LEFT + PATH_STEP * i


func _draw() -> void:
    _draw_sky()
    draw_string(UiStyle.TITLE_FONT, Vector2(0, 84), "La Chasse", HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 64, Palette.INK)
    if hunt == null:
        HuntView.centered(self, 124, 0, VIEW.x, "%d duels · une récompense à choisir après chacun" % Hunt.LENGTH, 24, Palette.QUIET)
        return
    HuntView.centered(self, 124, 0, VIEW.x, HuntDifficulty.display_name(hunt.difficulty), 26, Palette.QUIET)
    if hunt.tear_just_used:
        HuntView.centered(self, 164, 0, VIEW.x, "La larme de lune te relève", 26, Palette.CYAN)
    _draw_path()
    _draw_opponent()
    var rows_y := 548.0 if hunt.is_boss() else 512.0
    _draw_blessings(Vector2(VIEW.x / 2, rows_y))
    _draw_status(Vector2(VIEW.x / 2, rows_y + (36.0 if hunt.is_boss() else 54.0)))


func _draw_sky() -> void:
    var points := PackedVector2Array([Vector2.ZERO, Vector2(VIEW.x, 0), VIEW, Vector2(0, VIEW.y)])
    draw_polygon(points, PackedColorArray([Palette.NIGHT, Palette.NIGHT, Palette.DUSK, Palette.DUSK]))
    draw_circle(Vector2(VIEW.x - 150, 120), 70, Color(Palette.MOON, 0.10))
    draw_circle(Vector2(VIEW.x - 150, 120), 44, Color(Palette.MOON, 0.55))


## Les sept duels : faits en argent, celui à disputer en cyan qui pulse, les seigneurs cornus en rouge.
func _draw_path() -> void:
    for i in range(1, Hunt.LENGTH):
        var done := i <= hunt.index
        draw_line(Vector2(_node_x(i - 1), PATH_Y), Vector2(_node_x(i), PATH_Y), Color(Palette.SILVER if done else Palette.QUIET, 0.8 if done else 0.3), 3.0)
    for i in Hunt.LENGTH:
        var center := Vector2(_node_x(i), PATH_Y)
        var boss := hunt.is_boss(i)
        var radius := BOSS_RADIUS if boss else NODE_RADIUS
        if boss:
            HuntView.draw_horns(self, center, radius, Palette.FOE_RED if i > hunt.index else Palette.SILVER)
        if i < hunt.index:
            draw_circle(center, radius, Palette.SILVER)
        elif i == hunt.index:
            var pulse := 0.5 + 0.5 * sin(_time * 4.0)
            draw_circle(center, radius + 8 + pulse * 5, Color(Palette.CYAN, 0.18))
            draw_circle(center, radius, Palette.NIGHT)
            draw_arc(center, radius, 0, TAU, 40, Palette.CYAN, 4.0)
        else:
            draw_circle(center, radius, Palette.NIGHT)
            draw_arc(center, radius, 0, TAU, 40, Palette.FOE_RED if boss else Color(Palette.QUIET, 0.6), 2.5)


## Le duel à disputer : son rang et le chevalier de l'ombre ; devant un seigneur, son nom, son surnom et sa règle.
func _draw_opponent() -> void:
    if hunt.is_boss():
        var boss := hunt.boss_id()
        draw_string(UiStyle.TITLE_FONT, Vector2(0, 446), Boss.display_name(boss), HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 40, Palette.FOE_RED)
        HuntView.centered(self, 476, 0, VIEW.x, Boss.epithet(boss), 22, Palette.QUIET)
        HuntView.centered(self, 506, 0, VIEW.x, Boss.hint(boss), 22, Palette.INK)
        return
    var shadow := hunt.opponent()
    var where := "Duel %d / %d" % [hunt.index + 1, Hunt.LENGTH]
    HuntView.centered(self, 440, 0, VIEW.x, "%s · %s" % [where, shadow.knight.display_name], 28, Palette.INK)


## Les bénédictions de la Chasse, une rune par bénédiction, avec ×2 ou ×3 quand on l'a prise plusieurs fois.
func _draw_blessings(center: Vector2) -> void:
    var distinct: Array[StringName] = []
    for id in hunt.blessings:
        if not id in distinct:
            distinct.append(id)
    if distinct.is_empty():
        return
    var font := UiStyle.TEXT_FONT
    var labels := []
    var total := 0.0
    for id in distinct:
        var count := hunt.blessing_count(id)
        var text := Blessing.display_name(id) + (" ×%d" % count if count > 1 else "")
        labels.append(text)
        total += 30 + font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, CHIP_SIZE).x + 26
    var x := center.x - (total - 26) / 2
    for i in distinct.size():
        HuntView.draw_rune(self, Vector2(x + 10, center.y - 7), 12, Blessing.is_trait(distinct[i]))
        draw_string(font, Vector2(x + 30, center.y), labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, CHIP_SIZE, Palette.CYAN)
        x += 30 + font.get_string_size(labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, CHIP_SIZE).x + 26


## Les blessures et la larme de lune, s'il y en a.
func _draw_status(center: Vector2) -> void:
    var parts := []
    if hunt.wounds > 0:
        parts.append(["wound", "Blessure" + (" ×%d" % hunt.wounds if hunt.wounds > 1 else ""), Palette.LOSS])
    if hunt.has_tear:
        parts.append(["tear", "Larme de lune", Palette.CYAN])
    if parts.is_empty():
        return
    var font := UiStyle.TEXT_FONT
    var total := 0.0
    for part: Array in parts:
        total += 30 + font.get_string_size(part[1], HORIZONTAL_ALIGNMENT_LEFT, -1, CHIP_SIZE).x + 30
    var x := center.x - (total - 30) / 2
    for part: Array in parts:
        if part[0] == "wound":
            HuntView.draw_wound(self, Vector2(x + 10, center.y - 7), 9)
        else:
            HuntView.draw_tear(self, Vector2(x + 10, center.y - 8), 12)
        draw_string(font, Vector2(x + 30, center.y), part[1], HORIZONTAL_ALIGNMENT_LEFT, -1, CHIP_SIZE, part[2])
        x += 30 + font.get_string_size(part[1], HORIZONTAL_ALIGNMENT_LEFT, -1, CHIP_SIZE).x + 30
