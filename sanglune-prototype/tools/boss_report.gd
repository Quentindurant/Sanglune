extends SceneTree
## Rapport des seigneurs : une IA « joueur » (12 frames, 70 %), équipée comme l'ombre du palier 10 et bénie trois fois
## (Sang vif, Lame affûtée, Pas de loup : ce qu'on a souvent au bout d'une Chasse), affronte chaque seigneur
## à la place du dernier duel de la Nuit, avec chacun des quatre chevaliers. Puis le même seigneur en milieu de Pénombre.
## Sert à repérer un seigneur infranchissable ou trop facile. Un humain s'adapte à la règle, l'IA presque pas.
##
## Lancer : godot --headless --path . -s tools/boss_report.gd

const MATCHES_PER_KNIGHT := 10
const MAX_FRAMES := 60 * 60 * 10


func _initialize() -> void:
    print("seigneur                     fin de Nuit   milieu de Pénombre")
    for boss in Boss.ids():
        var late := _rate(boss, HuntDifficulty.Level.NUIT, Hunt.LENGTH - 1)
        var early := _rate(boss, HuntDifficulty.Level.PENOMBRE, Hunt.BOSS_DUELS[0])
        print("%-28s %-13s %s" % [Boss.display_name(boss), _pct(late), _pct(early)])
    quit()


func _rate(boss: StringName, level: int, duel_index: int) -> float:
    var wins := 0
    var total := 0
    var blessings: Array[StringName] = [&"sang_vif", &"lame_affutee", &"pas_de_loup"]
    for knight in KnightClass.all():
        var hunt := Hunt.new(level, 7 + knight.id.length(), knight.id)
        hunt.bosses.assign([boss, boss])
        hunt.blessings = blessings if duel_index == Hunt.LENGTH - 1 else blessings.slice(0, 1)
        var gear := Loadout.new(knight.id)
        for piece in ShadowPath.opponent(10 if level == HuntDifficulty.Level.NUIT else 4).gear.pieces():
            if not piece.def.is_weapon():
                gear.wear(piece)
        var shadow := hunt.opponent(duel_index, gear)
        for n in MATCHES_PER_KNIGHT:
            var duel := Duel.new(knight, shadow.knight, gear, shadow.gear, hunt.player_bonus(), hunt.enemy_bonus(duel_index))
            var me := AiBrain.new(n * 2 + 1)
            var them := AiBrain.new(n * 2 + 1000, shadow.reaction_frames, shadow.accuracy)
            var frames := 0
            while duel.state != Duel.State.MATCH_OVER and frames < MAX_FRAMES:
                duel.step(me.decide(duel.left, duel.right), them.decide(duel.right, duel.left))
                frames += 1
            if duel.match_winner < 0:
                wins += 1
            total += 1
    return float(wins) / total


func _pct(rate: float) -> String:
    return "%d %%" % roundi(100.0 * rate)
