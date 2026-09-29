extends SceneTree
## Rapport d'équilibrage : deux IA identiques s'affrontent pour chaque paire de chevaliers.
## Chaque case donne le taux de victoire du chevalier de la ligne contre celui de la colonne,
## moyenné sur les deux côtés de l'arène. Un miroir vaut 50 % par définition.
## C'est un repère grossier (l'IA ne joue pas comme un humain) : il sert à repérer un chevalier cassé
## après un réglage dans knight_class.gd, pas à remplacer les playtests.
##
## Lancer : godot --headless --path . -s tools/balance_report.gd

const MATCHES_PER_SIDE := 100
const MAX_FRAMES := 60 * 60 * 10


func _initialize() -> void:
    var knights := KnightClass.all()
    var rates := _matchup_rates(knights)
    var header := "%-14s" % ""
    for knight in knights:
        header += "%-14s" % knight.display_name
    print(header + "moyenne")
    for i in knights.size():
        var line := "%-14s" % knights[i].display_name
        var total := 0.0
        for j in knights.size():
            total += rates[i][j]
            line += "%-14s" % _percent(rates[i][j])
        print(line + _percent(total / knights.size()))
    quit()


func _matchup_rates(knights: Array[KnightClass]) -> Array:
    var rates := []
    for i in knights.size():
        rates.append([])
        rates[i].resize(knights.size())
        rates[i][i] = 0.5
    for i in knights.size():
        for j in range(i + 1, knights.size()):
            var rate := (_left_win_rate(knights[i], knights[j]) + 1.0 - _left_win_rate(knights[j], knights[i])) / 2.0
            rates[i][j] = rate
            rates[j][i] = 1.0 - rate
    return rates


func _left_win_rate(left_knight: KnightClass, right_knight: KnightClass) -> float:
    var wins := 0
    for i in MATCHES_PER_SIDE:
        var duel := Duel.new(left_knight, right_knight)
        var left_ai := AiBrain.new(i * 2 + 1)
        var right_ai := AiBrain.new(i * 2 + 1000)
        var frames := 0
        while duel.state != Duel.State.MATCH_OVER and frames < MAX_FRAMES:
            duel.step(left_ai.decide(duel.left, duel.right), right_ai.decide(duel.right, duel.left))
            frames += 1
        if duel.match_winner < 0:
            wins += 1
    return float(wins) / MATCHES_PER_SIDE


func _percent(rate: float) -> String:
    return "%d %%" % roundi(100.0 * rate)
