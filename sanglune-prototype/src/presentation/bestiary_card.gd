class_name BestiaryCard
extends Button
## Un seigneur du bestiaire : vaincu, sa silhouette noire au liseré rouge et son nom ; inconnu, une ombre éteinte et « ? ».

const PUPPET_FEET := Vector2(0.5, 0.7) ## position des pieds, en part de la carte
const PUPPET_SCALE := 0.3

var boss: StringName
var known := false
var selected := false:
    set(value):
        selected = value
        _restyle()


func _init(p_boss: StringName, p_size: Vector2, p_known: bool) -> void:
    boss = p_boss
    known = p_known
    custom_minimum_size = p_size
    size = p_size
    clip_contents = true
    add_theme_stylebox_override("focus", UiStyle.box(Color.TRANSPARENT, Palette.INK, 3))
    _restyle()
    accessibility_name = Boss.display_name(boss) if known else "Seigneur inconnu"


func _ready() -> void:
    var puppet := KnightPuppet.new()
    var rim: Array[Vector2] = []
    if known:
        rim.append(Vector2(2, -2))
    puppet.setup(Boss.knight_id(boss), Palette.FOE_RED, rim, known, Boss.look(boss))
    puppet.position = size * PUPPET_FEET
    puppet.scale = Vector2(-1, 1) * PUPPET_SCALE * Boss.scale(boss)
    puppet.auto_idle = known
    if not known:
        puppet.modulate = Color(Palette.PURPLE, 0.7) ## une ombre éteinte : on devine la forme, pas le nom
    add_child(puppet)


func _restyle() -> void:
    var border := Palette.MOON if selected else (Palette.PURPLE if known else Color(Palette.PURPLE, 0.5))
    var width := 3 if selected else 2
    var bg := Palette.DUSK if known else Palette.NEAREST_SET
    add_theme_stylebox_override("normal", UiStyle.box(bg, border, width))
    add_theme_stylebox_override("hover", UiStyle.box(bg.lightened(0.05), Palette.MOON if selected else Palette.QUIET, width))
    add_theme_stylebox_override("pressed", UiStyle.box(bg.lightened(0.1), Palette.MOON, 3))
    add_theme_stylebox_override("hover_pressed", UiStyle.box(bg.lightened(0.1), Palette.MOON, 3))
    queue_redraw()


func _draw() -> void:
    var label := Boss.display_name(boss) if known else "?"
    var font_size := 17 if label.length() > 20 else 19
    HuntView.centered(self, size.y - 14, 4, size.x - 8, label, font_size, Palette.INK if known else Palette.QUIET)
