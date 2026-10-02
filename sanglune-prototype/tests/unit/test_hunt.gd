extends GutTest
## La Chasse : sept duels, des récompenses au choix, trois nuits de difficulté, blessures, soin et larme de lune.


func _hunt(level: int = HuntDifficulty.Level.NUIT, seed_value: int = 4242) -> Hunt:
    return Hunt.new(level, seed_value, KnightClass.VEILLEUR)


## Gagne le duel en cours et passe à l'offre ; rounds_lost : manches perdues pendant ce duel.
func _win(hunt: Hunt, rounds_lost: int = 0) -> void:
    hunt.begin_duel()
    hunt.record_duel(true, rounds_lost)


func _kinds(choices: Array[HuntReward]) -> Array[int]:
    var kinds: Array[int] = []
    for reward in choices:
        kinds.append(reward.kind)
    return kinds


## Une Chasse arrêtée sur une offre qui contient ce genre de récompense (on essaie des graines jusqu'à en trouver une).
## Renvoie [chasse, indice du choix], ou [null, -1].
func _hunt_offering(kind: int, profile: PlayerProfile) -> Array:
    for seed_value in range(1, 200):
        var hunt := _hunt(HuntDifficulty.Level.NUIT, seed_value)
        for step in Hunt.LENGTH - 1:
            _win(hunt)
            var found := _kinds(hunt.offer()).find(kind)
            if found >= 0:
                return [hunt, found]
            hunt.choose(0, profile)
    return [null, -1]


# --- Les ombres et la difficulté ---

func test_seven_duels_and_a_lord_at_the_end() -> void:
    var hunt := _hunt()
    for i in Hunt.LENGTH - 1:
        assert_false(hunt.is_last(i))
        assert_eq(hunt.opponent(i).guardian, hunt.is_boss(i), "seuls les seigneurs ont la force d'un gardien")
    assert_true(hunt.is_last(Hunt.LENGTH - 1))
    assert_true(hunt.opponent(Hunt.LENGTH - 1).guardian, "le dernier seigneur a la force d'un gardien")


func test_each_duel_is_harder_than_the_last() -> void:
    for level in HuntDifficulty.all():
        var hunt := _hunt(level)
        for i in range(1, Hunt.LENGTH):
            assert_gt(HuntDifficulty.palier_of(level, i), HuntDifficulty.palier_of(level, i - 1))
            if not hunt.is_boss(i - 1):
                assert_true(hunt.opponent(i).reaction_frames <= hunt.opponent(i - 1).reaction_frames, "l'IA ne ralentit jamais")


func test_harder_nights_bring_stronger_shadows() -> void:
    var easy := _hunt(HuntDifficulty.Level.PENOMBRE)
    var mid := _hunt(HuntDifficulty.Level.NUIT)
    var hard := _hunt(HuntDifficulty.Level.LUNE_DE_SANG)
    for i in Hunt.LENGTH:
        assert_lt(HuntDifficulty.palier_of(HuntDifficulty.Level.PENOMBRE, i), HuntDifficulty.palier_of(HuntDifficulty.Level.NUIT, i))
        assert_lt(HuntDifficulty.palier_of(HuntDifficulty.Level.NUIT, i), HuntDifficulty.palier_of(HuntDifficulty.Level.LUNE_DE_SANG, i))
    assert_true(easy.opponent(0).accuracy < mid.opponent(0).accuracy)
    assert_true(mid.opponent(0).accuracy < hard.opponent(0).accuracy)


func test_the_same_seed_gives_the_same_shadows_another_seed_new_ones() -> void:
    var a := _hunt(HuntDifficulty.Level.NUIT, 11)
    var b := _hunt(HuntDifficulty.Level.NUIT, 11)
    var c := _hunt(HuntDifficulty.Level.NUIT, 98765)
    var same := true
    var differs := false
    for i in Hunt.LENGTH:
        same = same and a.opponent(i).knight.id == b.opponent(i).knight.id and a.opponent(i).power() == b.opponent(i).power()
        differs = differs or a.opponent(i).knight.id != c.opponent(i).knight.id
    assert_true(same, "on retrouve les mêmes ombres en revenant dans le jeu")
    assert_true(differs, "une nouvelle Chasse, de nouvelles ombres")


func test_shadow_blessings_depend_on_the_night() -> void:
    var last := Hunt.LENGTH - 1
    var dusk := _hunt(HuntDifficulty.Level.PENOMBRE)
    assert_true(dusk.enemy_bonus(0).is_empty())
    assert_eq(dusk.enemy_bonus(last).mods, Boss.bonus_of(dusk.boss_id(last)).mods, "en Pénombre, le seigneur n'a que sa règle")
    var night := _hunt(HuntDifficulty.Level.NUIT)
    assert_true(night.enemy_bonus(0).is_empty())
    assert_ne(night.enemy_bonus(last).mods, Boss.bonus_of(night.boss_id(last)).mods, "le seigneur de la Nuit est béni en plus")
    var blood := _hunt(HuntDifficulty.Level.LUNE_DE_SANG)
    assert_false(blood.enemy_bonus(0).is_empty(), "en Lune de sang, chaque ombre est bénie")
    assert_true(blood.enemy_bonus(0).traits.is_empty(), "les ombres ne reçoivent que des caractéristiques")


# --- Les duels ---

func test_a_victory_opens_the_choice_and_a_defeat_ends_the_hunt() -> void:
    var hunt := _hunt()
    _win(hunt)
    assert_eq(hunt.state, Hunt.State.CHOOSING)
    hunt.choose(0, PlayerProfile.new())
    assert_eq(hunt.index, 1)
    assert_eq(hunt.state, Hunt.State.FIGHTING)
    hunt.begin_duel()
    hunt.record_duel(false)
    assert_eq(hunt.state, Hunt.State.LOST)
    assert_true(hunt.is_over())


func test_beating_the_last_lord_wins_the_hunt() -> void:
    var hunt := _hunt()
    var profile := PlayerProfile.new()
    for i in Hunt.LENGTH - 1:
        _win(hunt)
        hunt.choose(0, profile)
    assert_true(hunt.is_last())
    _win(hunt)
    assert_eq(hunt.state, Hunt.State.WON)
    assert_true(hunt.offer().is_empty(), "pas d'offre après le dernier seigneur : le butin de fin")


func test_each_lost_round_leaves_a_wound_until_healed() -> void:
    var hunt := _hunt()
    var base := FighterStats.resolve(KnightClass.starter()).max_hp
    _win(hunt, 1)
    assert_eq(hunt.wounds, 1)
    assert_lt(FighterStats.resolve(KnightClass.starter(), null, hunt.player_bonus()).max_hp, base, "une blessure retire de la vie")
    var heal := _kinds(hunt.offer()).find(HuntReward.Kind.HEAL)
    assert_gt(heal, -1, "blessé, on se voit proposer un soin")
    hunt.choose(heal, PlayerProfile.new())
    assert_eq(hunt.wounds, 0)


func test_wounds_are_capped() -> void:
    var hunt := _hunt()
    var profile := PlayerProfile.new()
    for i in 4:
        _win(hunt, 1)
        var choices := hunt.offer()
        hunt.choose(_kinds(choices).find(HuntReward.Kind.BLESSING), profile)
    assert_eq(hunt.wounds, Hunt.MAX_WOUNDS)


func test_a_tear_of_the_moon_replays_one_lost_duel() -> void:
    var profile := PlayerProfile.new()
    var found := _hunt_offering(HuntReward.Kind.TEAR, profile)
    var hunt: Hunt = found[0]
    var tear: int = found[1]
    assert_gt(tear, -1, "une larme finit par être proposée")
    hunt.choose(tear, profile)
    var duel := hunt.index
    hunt.begin_duel()
    hunt.record_duel(false)
    assert_eq(hunt.state, Hunt.State.FIGHTING, "la larme relève le chevalier")
    assert_true(hunt.tear_just_used)
    assert_eq(hunt.index, duel, "on rejoue le même duel")
    assert_false(hunt.has_tear)
    hunt.begin_duel()
    hunt.record_duel(false)
    assert_eq(hunt.state, Hunt.State.LOST, "une seule fois")


func test_forfeit_ends_the_hunt_even_with_a_tear() -> void:
    var hunt := _hunt()
    hunt.has_tear = true
    hunt.forfeit()
    assert_eq(hunt.state, Hunt.State.LOST)


# --- Les offres ---

func test_three_choices_the_last_one_is_kept() -> void:
    var hunt := _hunt()
    _win(hunt)
    var choices := hunt.offer()
    assert_eq(choices.size(), 3)
    assert_eq(choices[0].kind, HuntReward.Kind.BLESSING)
    assert_true(choices[2].is_permanent(), "toujours une récompense à garder")
    assert_false(choices[0].is_permanent())


func test_the_offer_never_changes_for_the_same_duel() -> void:
    var hunt := _hunt()
    _win(hunt)
    var first := hunt.offer()
    var again := Hunt.from_dict(hunt.to_dict()).offer()
    for i in 3:
        assert_eq(first[i].kind, again[i].kind)
        assert_eq(first[i].blessing_id, again[i].blessing_id)
        assert_eq(first[i].rarity, again[i].rarity)
        assert_eq(first[i].shards, again[i].shards)


func test_two_blessings_offered_together_are_different() -> void:
    for seed_value in range(1, 40):
        var hunt := _hunt(HuntDifficulty.Level.NUIT, seed_value)
        _win(hunt)
        var choices := hunt.offer()
        if choices[1].kind == HuntReward.Kind.BLESSING:
            assert_ne(choices[0].blessing_id, choices[1].blessing_id)


func test_a_blessing_is_never_offered_beyond_its_limit() -> void:
    var profile := PlayerProfile.new()
    for seed_value in range(1, 25):
        var hunt := _hunt(HuntDifficulty.Level.PENOMBRE, seed_value)
        for i in Hunt.LENGTH - 1:
            _win(hunt)
            for reward in hunt.offer():
                if reward.kind == HuntReward.Kind.BLESSING:
                    assert_lt(hunt.blessing_count(reward.blessing_id), Blessing.max_stack(reward.blessing_id))
            hunt.choose(0, profile)


func test_a_blessing_strengthens_the_knight_for_the_hunt_only() -> void:
    var hunt := _hunt()
    hunt.blessings.append(&"sang_vif")
    hunt.blessings.append(&"echo")
    var knight := KnightClass.starter()
    var blessed := FighterStats.resolve(knight, null, hunt.player_bonus())
    assert_gt(blessed.max_hp, FighterStats.resolve(knight).max_hp)
    assert_true(blessed.has_trait(GearTrait.Trait.ECHO), "un trait prêté par la Chasse")
    assert_eq(blessed.power, PowerBudget.BASE_POWER, "les bénédictions ne comptent pas dans la puissance")


func test_blessings_stack() -> void:
    var one: Array[StringName] = [&"lame_affutee"]
    var two: Array[StringName] = [&"lame_affutee", &"lame_affutee"]
    assert_eq(Blessing.bonus_of(two).mods[GearStat.Stat.POWER], 2 * Blessing.bonus_of(one).mods[GearStat.Stat.POWER])


func test_choosing_a_blessing_keeps_it() -> void:
    var hunt := _hunt()
    _win(hunt)
    var id := hunt.offer()[0].blessing_id
    var reward := hunt.choose(0, PlayerProfile.new())
    assert_eq(reward.blessing_id, id)
    assert_eq(hunt.blessing_count(id), 1)


func test_a_piece_goes_to_the_inventory_for_good() -> void:
    var profile := PlayerProfile.new()
    var found := _hunt_offering(HuntReward.Kind.PIECE, profile)
    var hunt: Hunt = found[0]
    var at: int = found[1]
    assert_gt(at, -1)
    var before := profile.items.size()
    var reward := hunt.choose(at, profile)
    assert_true(reward.def.fits(KnightClass.VEILLEUR), "une pièce pour le chevalier de la Chasse")
    if reward.duplicate:
        assert_gt(reward.shards, 0)
    else:
        assert_eq(profile.items.size(), before + 1)
        assert_eq(reward.item.rarity, reward.rarity)


func test_shards_go_to_the_profile() -> void:
    var profile := PlayerProfile.new()
    var found := _hunt_offering(HuntReward.Kind.SHARDS, profile)
    var hunt: Hunt = found[0]
    var at: int = found[1]
    assert_gt(at, -1)
    var before := profile.shards
    var reward := hunt.choose(at, profile)
    assert_eq(profile.shards, before + reward.shards)


func test_pieces_offered_follow_the_night() -> void:
    for seed_value in range(1, 30):
        for level in HuntDifficulty.all():
            var hunt := _hunt(level, seed_value)
            _win(hunt)
            var keep := hunt.offer()[2]
            if keep.kind == HuntReward.Kind.PIECE:
                var weights: Array = HuntDifficulty.value(level, "offer_rarity")
                assert_gt(weights[keep.rarity], 0, "une rareté que cette nuit peut donner")


func test_an_impossible_choice_is_refused() -> void:
    var hunt := _hunt()
    assert_null(hunt.choose(0, PlayerProfile.new()), "pas d'offre avant d'avoir gagné")
    _win(hunt)
    assert_null(hunt.choose(3, PlayerProfile.new()))
    assert_null(hunt.choose(-1, PlayerProfile.new()))
    assert_eq(hunt.index, 0)


# --- La fin et le profil ---

func test_beating_the_last_lord_brings_a_rare_piece_and_unlocks_the_blood_moon() -> void:
    var profile := PlayerProfile.new()
    assert_false(profile.hunt_unlocked(HuntDifficulty.Level.LUNE_DE_SANG))
    var hunt := profile.start_hunt(HuntDifficulty.Level.NUIT, 77)
    for i in Hunt.LENGTH - 1:
        _win(hunt)
        hunt.choose(0, profile)
    _win(hunt)
    var shards := profile.shards
    var end := hunt.conclude(profile)
    assert_true(end.won)
    assert_eq(end.duels_won, Hunt.LENGTH)
    assert_true(end.reward.rarity >= Rarity.Tier.GIBBEUSE, "le butin de la Nuit est au moins Gibbeuse")
    assert_eq(profile.shards, shards + end.shards + (end.reward.shards if end.reward.duplicate else 0))
    assert_eq(end.unlocked, HuntDifficulty.Level.LUNE_DE_SANG)
    assert_true(profile.hunt_unlocked(HuntDifficulty.Level.LUNE_DE_SANG))
    assert_null(profile.hunt, "la Chasse finie est oubliée")
    assert_eq(profile.hunt_record(HuntDifficulty.Level.NUIT), Hunt.LENGTH)


func test_a_defeat_pays_shards_for_each_duel_won_and_keeps_the_record() -> void:
    var profile := PlayerProfile.new()
    var hunt := profile.start_hunt(HuntDifficulty.Level.PENOMBRE, 5)
    for i in 3:
        _win(hunt)
        hunt.choose(0, profile)
    hunt.begin_duel()
    hunt.record_duel(false)
    var shards := profile.shards
    var end := hunt.conclude(profile)
    assert_false(end.won)
    assert_null(end.reward)
    assert_eq(end.duels_won, 3)
    assert_eq(end.shards, 3 * HuntDifficulty.value(HuntDifficulty.Level.PENOMBRE, "shards_per_duel"))
    assert_eq(profile.shards, shards + end.shards)
    assert_true(end.new_record)
    assert_eq(profile.hunt_record(HuntDifficulty.Level.PENOMBRE), 3)
    var worse := profile.start_hunt(HuntDifficulty.Level.PENOMBRE, 6)
    worse.forfeit()
    assert_false(worse.conclude(profile).new_record)
    assert_eq(profile.hunt_record(HuntDifficulty.Level.PENOMBRE), 3, "le record ne baisse jamais")


func test_a_locked_night_or_a_second_hunt_is_refused() -> void:
    var profile := PlayerProfile.new()
    assert_null(profile.start_hunt(HuntDifficulty.Level.LUNE_DE_SANG, 1), "Lune de sang demande d'avoir fini la Nuit")
    var hunt := profile.start_hunt(HuntDifficulty.Level.PENOMBRE, 1)
    assert_not_null(hunt)
    assert_eq(hunt.knight_id, profile.knight_id, "on part avec le chevalier actif")
    assert_null(profile.start_hunt(HuntDifficulty.Level.NUIT, 1), "une Chasse à la fois")


func test_every_step_of_the_hunt_is_saved() -> void:
    var store := MemoryProfileStore.new()
    var profile := PlayerProfile.new()
    profile.changed.connect(func() -> void: store.save_profile(profile))
    var hunt := profile.start_hunt(HuntDifficulty.Level.NUIT, 31)
    _win(hunt, 1)
    assert_eq(store.saved["hunt"]["state"], "choosing")
    assert_eq(store.saved["hunt"]["wounds"], 1)
    hunt.choose(0, profile)
    hunt.begin_duel()
    assert_true(store.saved["hunt"]["in_duel"], "un duel commencé est noté")


func test_the_hunt_round_trips_through_the_save() -> void:
    var profile := PlayerProfile.new()
    var hunt := profile.start_hunt(HuntDifficulty.Level.NUIT, 999)
    _win(hunt, 1)
    hunt.choose(0, profile)
    _win(hunt)
    profile.hunt_records[HuntDifficulty.Level.PENOMBRE] = 4
    var data: Dictionary = JSON.parse_string(JSON.stringify(profile.to_dict()))
    var back := PlayerProfile.from_dict(data)
    assert_not_null(back.hunt)
    assert_eq(back.hunt.to_dict(), hunt.to_dict())
    assert_eq(back.hunt_record(HuntDifficulty.Level.PENOMBRE), 4)
    assert_eq(back.hunt.offer()[0].blessing_id, hunt.offer()[0].blessing_id, "la même offre attend")
    assert_not_null(back.hunt.choose(0, back), "la Chasse relue continue")
    assert_eq(back.hunt.index, 2)


func test_a_tampered_hunt_is_dropped() -> void:
    var good := _hunt()
    _win(good)
    var cases := [
        {"difficulty": "jour"}, {"seed": 0}, {"seed": 3.5}, {"knight": "dragon"}, {"index": 7}, {"index": -1},
        {"wounds": 9}, {"tear": "oui"}, {"state": "won"}, {"blessings": ["sang_vif", "sang_vif"]},
        {"blessings": ["inconnue"]}, {"in_duel": 1},
    ]
    for change: Dictionary in cases:
        var data := good.to_dict()
        data.merge(change, true)
        assert_null(Hunt.from_dict(data), "refusé : %s" % str(change))
    var stacked := Hunt.new(HuntDifficulty.Level.NUIT, 3)
    stacked.index = 5
    stacked.blessings.assign([&"echo", &"echo"])
    assert_null(Hunt.from_dict(stacked.to_dict()), "un trait ne se prend qu'une fois")
    assert_null(Hunt.from_dict("n'importe quoi"))


func test_a_tampered_record_is_bounded() -> void:
    var profile := PlayerProfile.from_dict({"version": 2, "items": [], "hunt_records": {"nuit": 500, "jour": 3, "penombre": "x"}})
    assert_eq(profile.hunt_record(HuntDifficulty.Level.NUIT), Hunt.LENGTH)
    assert_eq(profile.hunt_record(HuntDifficulty.Level.PENOMBRE), 0)


func test_a_duel_with_bonuses_uses_them() -> void:
    var bonus := StatBonus.new()
    bonus.add_mod(GearStat.Stat.HP, 200)
    bonus.add_trait(GearTrait.Trait.AUBE_ROUGE)
    var duel := Duel.new(KnightClass.starter(), KnightClass.starter(), null, null, bonus)
    assert_gt(duel.left.max_hp(), duel.right.max_hp())
    assert_eq(duel.left.rune, 1, "Aube rouge prêtée par la Chasse")
    assert_eq(duel.right.rune, 0)
