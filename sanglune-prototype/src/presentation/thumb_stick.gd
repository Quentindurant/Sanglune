class_name ThumbStick
extends Node2D
## Joystick rond pour le pouce gauche : à gauche et à droite pour marcher, vers le haut pour sauter,
## vers le bas pour esquiver (en arrière, ou du côté où il penche).
## Il se pose là où le pouce touche, dans le coin bas gauche : pas besoin de viser.
## Il appuie sur les mêmes actions que le clavier (InputMap) : le reste du jeu ne voit pas la différence.
## Pourquoi pas le VirtualJoystick natif de Godot 4.7 : il faut des seuils distincts, faible pour marcher,
## fort pour sauter ou esquiver, sinon un pouce qui marche un peu de biais déclencherait un saut.

const REST_CENTER := Vector2(185, 585)
const RADIUS := 80.0
const KNOB_RADIUS := 34.0
const DEAD_ZONE := 0.3 ## en deçà, le pouce posé ne fait pas marcher
const VERTICAL_TRIGGER := 0.6 ## au-delà, vers le haut on saute, vers le bas on esquive
const ZONE := Rect2(0, 300, 440, 420) ## où un pouce posé attrape le joystick

var center := REST_CENTER
var knob := Vector2.ZERO ## position du bouton, de -1 à 1 sur chaque axe
var _touch_index := -1
var _held := {} ## action -> appuyée par le joystick
var _enabled := true


## Coupé pendant les menus : il relâche tout ce qu'il tenait.
func set_enabled(enabled: bool) -> void:
    _enabled = enabled
    if not enabled:
        release()


func is_held() -> bool:
    return _touch_index != -1


func release() -> void:
    _touch_index = -1
    center = REST_CENTER
    _set_knob(Vector2.ZERO)


func _exit_tree() -> void:
    release()


func _input(event: InputEvent) -> void:
    if not _enabled:
        return
    if event is InputEventScreenTouch:
        var touch := make_input_local(event) as InputEventScreenTouch
        if touch.pressed and _touch_index == -1 and ZONE.has_point(touch.position):
            _touch_index = touch.index
            center = _clamped_center(touch.position)
            _set_knob(Vector2.ZERO)
        elif not touch.pressed and touch.index == _touch_index:
            release()
    elif event is InputEventScreenDrag and (event as InputEventScreenDrag).index == _touch_index:
        var drag := make_input_local(event) as InputEventScreenDrag
        _set_knob((drag.position - center) / RADIUS)


func _draw() -> void:
    var active := is_held()
    draw_circle(center, RADIUS, Color(Palette.SILHOUETTE, 0.4 if active else 0.28))
    draw_arc(center, RADIUS, 0, TAU, 64, Color(Palette.INK, 0.55 if active else 0.35), 2.0)
    _draw_chevron(Vector2(0, -1), knob.y < -VERTICAL_TRIGGER)
    _draw_chevron(Vector2(0, 1), knob.y > VERTICAL_TRIGGER)
    _draw_chevron(Vector2(-1, 0), knob.x < -DEAD_ZONE)
    _draw_chevron(Vector2(1, 0), knob.x > DEAD_ZONE)
    draw_circle(center + knob * RADIUS, KNOB_RADIUS, Color(Palette.INK, 0.5 if active else 0.3))


## Petites flèches sur le pourtour : elles s'allument quand le pouce pousse dans leur direction.
func _draw_chevron(direction: Vector2, lit: bool) -> void:
    var tip := center + direction * (RADIUS - 10)
    var back := tip - direction * 12
    var side := direction.orthogonal() * 10
    var color := Color(Palette.CYAN, 0.9) if lit else Color(Palette.INK, 0.35)
    draw_polyline(PackedVector2Array([back + side, tip, back - side]), color, 3.0)


func _set_knob(value: Vector2) -> void:
    knob = value.limit_length(1.0)
    _hold("move_right", knob.x > DEAD_ZONE)
    _hold("move_left", knob.x < -DEAD_ZONE)
    _hold("saut", knob.y < -VERTICAL_TRIGGER)
    _hold("esquive", knob.y > VERTICAL_TRIGGER)
    queue_redraw()


func _hold(action: String, pressed: bool) -> void:
    if _held.get(action, false) == pressed:
        return
    _held[action] = pressed
    if pressed:
        Input.action_press(action)
    else:
        Input.action_release(action)


## Le joystick reste entier à l'écran, même si le pouce se pose au bord.
func _clamped_center(point: Vector2) -> Vector2:
    return Vector2(clampf(point.x, RADIUS + 8, ZONE.end.x), clampf(point.y, ZONE.position.y + RADIUS, 720 - RADIUS - 8))
