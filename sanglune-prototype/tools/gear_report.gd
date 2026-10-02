extends SceneTree
## Rapport d'équilibrage de l'équipement : un chevalier qui porte une pièce affronte le même chevalier sans rien.
## Deux IA identiques, moyenne sur les deux côtés de l'arène. À rareté égale, toutes les pièces devraient
## donner à peu près le même avantage : une pièce très au-dessus des autres est trop forte pour son budget.
## La dernière ligne de chaque chevalier mesure l'équipement complet au maximum (cible : environ 75 %).
##
## Lancer : godot --headless --path . -s tools/gear_report.gd

const MATCHES_PER_SIDE := 40
const MAX_FRAMES := 60 * 60 * 10
const RARITY := Rarity.Tier.QUARTIER


func _initialize() -> void:
    for knight in KnightClass.all():
        print("%s" % knight.display_name)
        for def in ItemCatalog.all():
            if def.starter or not def.fits(knight.id):
                continue
            var gear := Loadout.new(knight.id)
            gear.wear(OwnedItem.new(1, def, RARITY))
            print("  %-22s %s" % [def.display_name, _percent(_rate(knight, gear))])
        print("  %-22s %s" % ["Tout au maximum", _percent(_rate(knight, _full_kit(knight)))])
    quit()


## La meilleure pièce Gibbeuse de chaque emplacement au niveau 10.
func _full_kit(knight: KnightClass) -> Loadout:
    var gear := Loadout.new(knight.id)
    var uid := 1
    for def in ItemCatalog.all():
        if def.starter or not def.fits(knight.id) or gear.piece(def.slot) != null:
            continue
        gear.wear(OwnedItem.new(uid, def, Rarity.Tier.GIBBEUSE, PowerBudget.MAX_LEVEL))
        uid += 1
    return gear


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


func _percent(rate: float) -> String:
    return "%d %%" % roundi(100.0 * rate)
