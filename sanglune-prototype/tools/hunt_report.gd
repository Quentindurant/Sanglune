extends SceneTree
## Rapport de la Chasse : une IA « joueur » (vivacité par défaut, 12 frames, 70 %) part en Chasse sur chaque nuit,
## avec chaque chevalier, et prend toujours la première bénédiction proposée (le soin si elle est blessée).
## Donne la part de Chasses qui atteint chaque duel (le 4e et le dernier sont des seigneurs), et la part finie.
## Trois départs : chevalier nu, puis équipé comme l'ombre du palier 10, puis du palier 20 (un joueur qui a avancé).
## Repère grossier : un vrai joueur apprend et choisit mieux, l'IA non.
##
## Lancer : godot --headless --path . -s tools/hunt_report.gd

const HUNTS_PER_KNIGHT := 12
const MAX_FRAMES := 60 * 60 * 10


func _initialize() -> void:
    for gear_palier in [0, 10, 20]:
        print("\n%s" % ("Équipé comme l'ombre du palier %d" % gear_palier if gear_palier > 0 else "Sans équipement"))
        print("nuit            atteint : 2    3    4    5    6    7        Chasse finie")
        for level in HuntDifficulty.all():
            var reached := []
            reached.resize(Hunt.LENGTH + 1)
            reached.fill(0)
            var total := 0
            for knight in KnightClass.all():
                var gear := _gear(knight.id, gear_palier) if gear_palier > 0 else null
                for n in HUNTS_PER_KNIGHT:
                    var won := _run(Hunt.new(level, 1000 + n * 37 + knight.id.length(), knight.id), gear, n)
                    for i in won + 1:
                        reached[i] += 1
                    total += 1
            var line := "%-15s           " % HuntDifficulty.display_name(level)
            for i in range(1, Hunt.LENGTH):
                line += "%-5s" % _pct(reached[i], total)
            line += "    %s" % _pct(reached[Hunt.LENGTH], total)
            print(line)
    quit()


## Joue une Chasse ; renvoie le nombre de duels gagnés.
func _run(hunt: Hunt, gear: Loadout, salt: int) -> int:
    var profile := PlayerProfile.new()
    while not hunt.is_over():
        var shadow := hunt.opponent(-1, gear if gear != null else Loadout.new(hunt.knight_id))
        var knight := KnightClass.by_id(hunt.knight_id)
        var duel := Duel.new(knight, shadow.knight, gear, shadow.gear, hunt.player_bonus(), hunt.enemy_bonus())
        var me := AiBrain.new(salt * 7 + hunt.index * 3 + 1)
        var them := AiBrain.new(salt * 7 + hunt.index * 3 + 1000, shadow.reaction_frames, shadow.accuracy)
        var frames := 0
        while duel.state != Duel.State.MATCH_OVER and frames < MAX_FRAMES:
            duel.step(me.decide(duel.left, duel.right), them.decide(duel.right, duel.left))
            frames += 1
        hunt.begin_duel()
        hunt.record_duel(duel.match_winner < 0, duel.wins[1], profile)
        if hunt.state == Hunt.State.CHOOSING:
            var choices := hunt.offer()
            var pick := 0
            for i in choices.size():
                if choices[i].kind == HuntReward.Kind.HEAL:
                    pick = i
            hunt.choose(pick, profile)
    return Hunt.LENGTH if hunt.state == Hunt.State.WON else hunt.index


func _gear(knight_id: StringName, palier: int) -> Loadout:
    var gear := Loadout.new(knight_id)
    for piece in ShadowPath.opponent(palier).gear.pieces():
        if not piece.def.is_weapon():
            gear.wear(piece)
    return gear


func _pct(count: int, total: int) -> String:
    return "%d%%" % roundi(100.0 * count / maxf(total, 1))
