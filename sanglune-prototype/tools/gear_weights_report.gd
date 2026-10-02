extends SceneTree
## Mesure ce que vaut chaque caractéristique d'équipement : un chevalier renforcé de +15 % sur une seule
## caractéristique affronte le même chevalier sans rien, sur les quatre chevaliers. Sert à régler
## GearStat.PER_POINT pour qu'un point de budget pèse à peu près pareil quelle que soit la caractéristique.
##
## Lancer : godot --headless --path . -s tools/gear_weights_report.gd

const MATCHES_PER_SIDE := 80
const MAX_FRAMES := 60 * 60 * 10
const BONUS := 150


class FixedLoadout extends Loadout:
    var fixed := {}

    func modifiers() -> Dictionary:
        return fixed


func _initialize() -> void:
    for stat in GearStat.all():
        var total := 0.0
        for knight in KnightClass.all():
            var gear := FixedLoadout.new(knight.id)
            gear.fixed = {stat: BONUS}
            total += _rate(knight, gear)
        print("%-22s +%d ‰   %d %%" % [GearStat.LABEL[stat], BONUS, roundi(100.0 * total / KnightClass.all().size())])
    quit()


func _rate(knight: KnightClass, gear: Loadout) -> float:
    var wins := 0
    for i in MATCHES_PER_SIDE:
        if _play(Duel.new(knight, knight, gear, null), i) < 0:
            wins += 1
        if _play(Duel.new(knight, knight, null, gear), i) > 0:
            wins += 1
    return float(wins) / (2 * MATCHES_PER_SIDE)


func _play(duel: Duel, seed: int) -> int:
    var left_ai := AiBrain.new(seed * 2 + 1)
    var right_ai := AiBrain.new(seed * 2 + 1000)
    var frames := 0
    while duel.state != Duel.State.MATCH_OVER and frames < MAX_FRAMES:
        duel.step(left_ai.decide(duel.left, duel.right), right_ai.decide(duel.right, duel.left))
        frames += 1
    return duel.match_winner
