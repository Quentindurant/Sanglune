class_name KnightPicker
extends RefCounted
## Modèle de l'écran de choix, sans nœud Godot : quel chevalier est sélectionné.

var knights: Array[KnightClass] = KnightClass.all()
var index: int = 0


func _init(selected_id: StringName = KnightClass.VEILLEUR) -> void:
    select_id(selected_id)


func selected() -> KnightClass:
    return knights[index]


## Sélectionne par position ; une position hors de la liste est ignorée.
func select_index(position: int) -> void:
    if position >= 0 and position < knights.size():
        index = position


## Sélectionne par identifiant ; un identifiant inconnu est ignoré.
func select_id(knight_id: StringName) -> void:
    for i in knights.size():
        if knights[i].id == knight_id:
            index = i
            return


## Passe au chevalier suivant (1) ou précédent (-1), en bouclant.
func step(direction: int) -> void:
    index = posmod(index + signi(direction), knights.size())
