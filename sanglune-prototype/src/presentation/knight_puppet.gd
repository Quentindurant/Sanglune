class_name KnightPuppet
extends Node2D
## Pantin squelettal d'un chevalier : un Skeleton2D dont les os (Bone2D) portent des pièces rigides en noir pur.
## Des copies rouges du même squelette, décalées vers la lune et glissées derrière, dessinent le liseré.
## Seuls l'œil, les runes, la lueur de préparation et la traînée de l'arme sont en couleur : la couleur, c'est le gameplay.
## L'origine du nœud est au milieu des pieds ; scale.x à -1 retourne le chevalier vers la gauche.

const SMOOTHING := 0.45 ## part du chemin vers la pose cible parcourue à chaque frame
const TRAIL_POINTS := 8
const FLASH_FRAMES := 4
const FLASH_COLOR := Color("#e9dff0")
const RUNE_DIM := 0.18

var knight_id: StringName
var accent: Color = Palette.CYAN
var auto_idle := false ## l'accueil et les cartes laissent le pantin respirer tout seul
var base_scale := 1.0 ## la taille du chevalier en duel : un seigneur peut être plus grand

var _spec: Dictionary
var _body: Dictionary = {} ## nom de l'os -> Bone2D, squelette noir
var _rims: Array[Dictionary] = [] ## un squelette rouge par décalage de liseré
var _rim_nodes: Array[Skeleton2D] = []
var _fill_parts: Array[Polygon2D] = []
var _runes: Array[Polygon2D] = []
var _glow: Polygon2D
var _tip: Node2D
var _trail: Line2D
var _pose: Dictionary = {}
var _time := 0.0
var _walk_cycle := 0.0
var _last_x := 0
var _following := false
var _phase_key := Vector2i(-1, -1)
var _phase_total := 1
var _flash_left := 0


## À appeler avant l'ajout à l'arbre. rim_offsets : décalages du liseré, en pixels, vers la source de lumière.
## look : les pièces de silhouette de l'équipement porté (Loadout.look).
func setup(p_knight_id: StringName, p_accent: Color, rim_offsets: Array[Vector2] = [], show_runes: bool = true,
        look: Dictionary = {}) -> void:
    knight_id = p_knight_id
    accent = p_accent
    _spec = KnightBuild.dressed(knight_id, look)
    for offset in rim_offsets:
        var rim := Skeleton2D.new()
        rim.position = offset
        rim.z_index = -1
        add_child(rim)
        _rim_nodes.append(rim)
        _rims.append(_build_rig(rim, Palette.RIM, false))
    var body := Skeleton2D.new()
    add_child(body)
    _body = _build_rig(body, Palette.SILHOUETTE, true)
    for rune in _runes:
        rune.visible = show_runes
    _trail = Line2D.new()
    _trail.top_level = true
    _trail.z_index = 2
    _trail.width = 11.0
    _trail.joint_mode = Line2D.LINE_JOINT_ROUND
    _trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
    var fade := Gradient.new()
    fade.set_color(0, Color(accent, 0.0))
    fade.set_color(1, Color(accent, 0.9))
    _trail.gradient = fade
    add_child(_trail)
    show_pose(KnightPose.GUARD)


func _process(delta: float) -> void:
    if auto_idle:
        _time += delta
        show_pose(KnightPose.idle(_time))


## Pose immédiate, sans transition (écrans de menu, tests).
func show_pose(pose: Dictionary) -> void:
    _pose = pose.duplicate()
    _apply(_pose)


func current_pose() -> Dictionary:
    return _pose


## Suit le chevalier du domaine pour une frame : position, regard, pose, traînée, lueur.
## feet : position des pieds dans le repère du parent. outcome : 1 manche gagnée, -1 perdue, 0 en cours.
func follow(f: Fighter, feet: Vector2, outcome: int = 0) -> void:
    _time += 1.0 / Engine.physics_ticks_per_second
    if not _following:
        _following = true
        _last_x = f.x
    position = feet
    scale = Vector2(f.facing(), 1.0) * base_scale
    var progress := _progress(f)
    var target := KnightPose.target(f, progress, _rest_pose(f), outcome)
    _pose = KnightPose.blend(_pose, target, SMOOTHING) if not _pose.is_empty() else target
    _apply(_pose)
    _update_glow(f, progress)
    _update_trail(f)
    _update_runes(f.rune)
    _update_flash()
    modulate.a = 0.22 if f.is_intangible() else (0.55 if f.is_invulnerable() else 1.0) ## le Spectre dissipé, presque invisible


## Les décalages du liseré suivent la lune : à appeler quand le chevalier bouge.
func light_from(source_global: Vector2, distance: float) -> void:
    for rim in _rim_nodes:
        var toward := (source_global - global_position).normalized() * distance
        rim.position = Vector2(toward.x * signf(scale.x), toward.y) / maxf(absf(scale.y), 0.01)


## Éclair d'impact : le pantin blanchit quelques frames.
func flash() -> void:
    _flash_left = FLASH_FRAMES
    _set_fill(FLASH_COLOR)


func tip_global() -> Vector2:
    return _tip.global_position


## Le milieu du torse, là où partent les étincelles d'un coup reçu.
func chest_global() -> Vector2:
    var torso: Node2D = _body["torso"]
    return torso.to_global(Vector2(0, -_spec["torso"] * 0.55))


func trail_size() -> int:
    return _trail.get_point_count()


func _rest_pose(f: Fighter) -> Dictionary:
    var dx := f.x - _last_x
    _last_x = f.x
    if f.is_free() and dx != 0:
        _walk_cycle += absf(dx) * 0.006 * signf(dx * f.facing())
        return KnightPose.walk(_walk_cycle)
    return KnightPose.idle(_time)


## Avancement de la phase en cours : la durée totale est relevée au premier passage dans la phase.
func _progress(f: Fighter) -> float:
    var key := Vector2i(f.action, f.phase)
    if key != _phase_key:
        _phase_key = key
        _phase_total = maxi(f.phase_frames + 1, 1)
    return 1.0 - float(f.phase_frames) / _phase_total


func _apply(pose: Dictionary) -> void:
    for rig in [_body] + _rims:
        _apply_to(rig, pose)


func _apply_to(rig: Dictionary, pose: Dictionary) -> void:
    var drop_f := _leg_drop(pose["thigh_f"], pose["shin_f"])
    var drop_b := _leg_drop(pose["thigh_b"], pose["shin_b"])
    rig["hips"].position = Vector2(pose["body_dx"], -maxf(drop_f, drop_b))
    rig["torso"].rotation = pose["lean"]
    rig["head"].rotation = pose["head"]
    rig["shoulder_f"].rotation = pose["upper_f"] - pose["lean"]
    rig["elbow_f"].rotation = pose["fore_f"] - pose["upper_f"]
    rig["hand_f"].rotation = pose["weapon_f"] - pose["fore_f"]
    rig["shoulder_b"].rotation = pose["upper_b"] - pose["lean"]
    rig["elbow_b"].rotation = pose["fore_b"] - pose["upper_b"]
    rig["hand_b"].rotation = pose["weapon_b"] - pose["fore_b"]
    rig["hip_f"].rotation = pose["thigh_f"]
    rig["knee_f"].rotation = pose["shin_f"] - pose["thigh_f"]
    rig["foot_f"].rotation = -pose["shin_f"]
    rig["hip_b"].rotation = pose["thigh_b"]
    rig["knee_b"].rotation = pose["shin_b"] - pose["thigh_b"]
    rig["foot_b"].rotation = -pose["shin_b"]


## Hauteur des hanches au-dessus du pied pour ces angles : les pieds restent posés au sol.
func _leg_drop(thigh: float, shin: float) -> float:
    return _spec["thigh"] * cos(thigh) + _spec["shin"] * cos(shin) + KnightBuild.FOOT_HEIGHT


func _build_rig(skeleton: Skeleton2D, fill: Color, details: bool) -> Dictionary:
    var s := _spec
    var bones := {}
    var hips := _bone(skeleton, bones, "hips", Vector2.ZERO)
    _leg(hips, bones, "_b", Vector2(-3, 0), fill, details)
    var torso := _bone(hips, bones, "torso", Vector2.ZERO)
    if s["cape"] != &"none":
        _part(torso, KnightBuild.cape(s), fill, details)
    _part(torso, KnightBuild.torso(s), fill, details)
    if s["pauldrons"]:
        _part(torso, KnightBuild.pauldrons(s), fill, details)
    var head := _bone(torso, bones, "head", Vector2(0, -s["torso"] - 2))
    _part(head, KnightBuild.helmet(s["helmet"]), fill, details)
    for shape in KnightBuild.crest(s["crest"], s["helmet"]):
        _part(head, shape, fill, details)
    _arm(torso, bones, "_b", s["off_hand"], fill, details)
    _leg(hips, bones, "_f", Vector2(3, 0), fill, details)
    _arm(torso, bones, "_f", s["weapon"], fill, details)
    if details:
        _decorate(bones)
    return bones


func _leg(hips: Node2D, bones: Dictionary, suffix: String, at: Vector2, fill: Color, details: bool) -> void:
    var hip := _bone(hips, bones, "hip" + suffix, at)
    _part(hip, KnightBuild.limb(_spec["thigh"], _spec["limb_w"] * 1.1), fill, details)
    var knee := _bone(hip, bones, "knee" + suffix, Vector2(0, _spec["thigh"]))
    _part(knee, KnightBuild.limb(_spec["shin"], _spec["limb_w"]), fill, details)
    var foot := _bone(knee, bones, "foot" + suffix, Vector2(0, _spec["shin"]))
    _part(foot, KnightBuild.foot(), fill, details)


func _arm(torso: Node2D, bones: Dictionary, suffix: String, held: StringName, fill: Color, details: bool) -> void:
    var shoulder := _bone(torso, bones, "shoulder" + suffix, Vector2(0, -_spec["torso"] + 8))
    _part(shoulder, KnightBuild.limb(_spec["upper"], _spec["limb_w"]), fill, details)
    var elbow := _bone(shoulder, bones, "elbow" + suffix, Vector2(0, _spec["upper"]))
    _part(elbow, KnightBuild.limb(_spec["fore"], _spec["limb_w"] * 0.9), fill, details)
    var hand := _bone(elbow, bones, "hand" + suffix, Vector2(0, _spec["fore"]))
    _part(hand, KnightBuild.circle(Vector2(0, 2), _spec["limb_w"] * 0.5, 8), fill, details)
    for shape in KnightBuild.weapon(held):
        _part(hand, shape, fill, details)


## L'œil, trois runes sur le torse (la jauge), la lueur de préparation et la pointe de l'arme : seulement sur le squelette noir.
func _decorate(bones: Dictionary) -> void:
    var eye := _colored(bones["head"], KnightBuild.eye(_spec["helmet"]), accent)
    eye.z_index = 1
    for i in Fighter.MAX_RUNE:
        var rune := _colored(bones["torso"], KnightBuild.diamond(Vector2(-2, -_spec["torso"] * (0.72 - i * 0.16)), 4.5), accent)
        rune.z_index = 1
        _runes.append(rune)
    var tip_at := KnightBuild.weapon_tip(_spec["weapon"])
    _glow = _colored(bones["hand_f"], KnightBuild.circle(tip_at, 6.5), Color(accent, 0.0))
    _glow.z_index = 1
    _tip = Node2D.new()
    _tip.position = tip_at
    bones["hand_f"].add_child(_tip)


func _bone(parent: Node, bones: Dictionary, bone_name: String, at: Vector2) -> Bone2D:
    var bone := Bone2D.new()
    bone.name = bone_name
    bone.position = at
    bone.set_autocalculate_length_and_angle(false)
    bone.rest = Transform2D(0.0, at)
    parent.add_child(bone)
    bones[bone_name] = bone
    return bone


func _part(bone: Node, shape: PackedVector2Array, fill: Color, details: bool) -> Polygon2D:
    var part := _colored(bone, shape, fill)
    if details:
        _fill_parts.append(part)
    return part


func _colored(bone: Node, shape: PackedVector2Array, color: Color) -> Polygon2D:
    var polygon := Polygon2D.new()
    polygon.polygon = shape
    polygon.color = color
    bone.add_child(polygon)
    return polygon


## La pointe de l'arme s'allume pendant la préparation d'un coup : un danger se lit avant d'arriver.
func _update_glow(f: Fighter, progress: float) -> void:
    var preparing := CombatAction.is_attack(f.action) and f.phase == Fighter.Phase.STARTUP
    _glow.color = Color(accent, 0.25 + 0.7 * progress) if preparing else Color(accent, 0.0)


## La traînée suit la pointe pendant le coup, puis s'efface en quelques frames.
func _update_trail(f: Fighter) -> void:
    if CombatAction.is_attack(f.action) and f.phase == Fighter.Phase.ACTIVE:
        _trail.add_point(_tip.global_position)
        if _trail.get_point_count() > TRAIL_POINTS:
            _trail.remove_point(0)
    elif _trail.get_point_count() > 0:
        _trail.remove_point(0)


func _update_runes(charge: int) -> void:
    for i in _runes.size():
        _runes[i].color = accent if i < charge else Color(accent, RUNE_DIM)


func _update_flash() -> void:
    if _flash_left <= 0:
        return
    _flash_left -= 1
    if _flash_left == 0:
        _set_fill(Palette.SILHOUETTE)


func _set_fill(color: Color) -> void:
    for part in _fill_parts:
        part.color = color
