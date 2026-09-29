extends GutTest
## Intégration : deux IA vont au bout d'un match, pour chaque paire de chevaliers, sans blocage ni boucle infinie.

const MAX_FRAMES := 60 * 60 * 10 ## dix minutes de jeu, très au-delà d'un match normal


func _play(seed: int, left_knight: KnightClass, right_knight: KnightClass) -> Duel:
    var duel := Duel.new(left_knight, right_knight)
    var a := AiBrain.new(seed)
    var b := AiBrain.new(seed + 100)
    var frames := 0
    while duel.state != Duel.State.MATCH_OVER and frames < MAX_FRAMES:
        duel.step(a.decide(duel.left, duel.right), b.decide(duel.right, duel.left))
        frames += 1
    return duel


func test_two_ais_finish_a_match() -> void:
    for seed in [1, 2, 3]:
        var duel := _play(seed, null, null)
        assert_eq(duel.state, Duel.State.MATCH_OVER, "graine %d" % seed)
        assert_eq(duel.wins[duel.match_winner], Duel.ROUNDS_TO_WIN)


func test_every_pairing_of_knights_finishes() -> void:
    var seed := 10
    for left_knight in KnightClass.all():
        for right_knight in KnightClass.all():
            seed += 1
            var duel := _play(seed, left_knight, right_knight)
            assert_eq(duel.state, Duel.State.MATCH_OVER, "%s contre %s" % [left_knight.display_name, right_knight.display_name])
