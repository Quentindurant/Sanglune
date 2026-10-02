class_name ScriptedRandomSource
extends RandomSource
## Un hasard écrit d'avance, pour les tests : rend les valeurs dans l'ordre (ramenées sous count), puis 0.

var values: Array[int] = []
var _next := 0


func _init(p_values: Array[int] = []) -> void:
    values = p_values


func below(count: int) -> int:
    if count <= 1 or _next >= values.size():
        _next += 1
        return 0
    var value := posmod(values[_next], count)
    _next += 1
    return value
