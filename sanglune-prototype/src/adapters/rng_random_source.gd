class_name RngRandomSource
extends RandomSource
## Le hasard du téléphone. Avec une graine, toujours le même tirage (outils, rapports) ; sans graine, imprévisible.

var _rng := RandomNumberGenerator.new()


func _init(seed_value: int = -1) -> void:
    if seed_value < 0:
        _rng.randomize()
    else:
        _rng.seed = seed_value


func below(count: int) -> int:
    if count <= 1:
        return 0
    return _rng.randi_range(0, count - 1)
