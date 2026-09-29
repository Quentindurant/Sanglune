class_name GameFlow
extends Node
## Enchaîne les écrans du prototype : choix du chevalier, duel contre l'ombre, puis retour au choix.

const ARENA_SCENE := preload("res://scenes/arena.tscn")

var current_screen: Node
var _last_pick: StringName = KnightClass.VEILLEUR
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
    InputBindings.register()
    _rng.randomize()
    show_knight_select()


## L'écran de choix s'ouvre sur le dernier chevalier joué.
func show_knight_select() -> void:
    var select := KnightSelect.new(_last_pick)
    select.confirmed.connect(start_duel)
    _swap(select)


## Lance un duel contre l'ombre, qui tire son chevalier au hasard.
func start_duel(player_knight: KnightClass) -> void:
    _last_pick = player_knight.id
    var arena: Arena = ARENA_SCENE.instantiate()
    arena.configure(player_knight, KnightClass.pick_random(_rng))
    arena.change_knight_requested.connect(show_knight_select)
    _swap(arena)


func _swap(next_screen: Node) -> void:
    if current_screen != null:
        current_screen.queue_free()
    current_screen = next_screen
    add_child(next_screen)
