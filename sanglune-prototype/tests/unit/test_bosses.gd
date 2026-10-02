extends GutTest
## Les seigneurs de la Chasse : le catalogue, le tirage, le bestiaire, et la règle de chaque seigneur en duel.


## Un duel où le joueur (gauche, Veilleur nu) affronte un seigneur (droite) avec sa règle seule.
func _duel_against(boss: StringName, left_bonus: StatBonus = null) -> Duel:
    var duel := Duel.new(KnightClass.starter(), KnightClass.by_id(Boss.knight_id(boss)), null, null, left_bonus, Boss.bonus_of(boss))
    duel.skip_intro()
    return duel


## Un coup de Frappe du joueur qui touche à coup sûr : collés, le seigneur immobile et de face.
func _player_hits(duel: Duel) -> void:
    duel.left.x = 4000
    duel.right.x = 4800
    duel.left.request(CombatAction.Kind.FRAPPE)
    for i in 30:
        duel.step(null, null)


func _right_hits(duel: Duel) -> void:
    duel.left.x = 4000
    duel.right.x = 4800
    duel.right.request(CombatAction.Kind.FRAPPE)
    for i in 30:
        duel.step(null, null)


func _rule(boss: StringName) -> Dictionary:
    return Boss.data(boss)["rules"]


# --- Le catalogue ---

func test_many_unique_lords() -> void:
    assert_gte(Boss.ids().size(), 15)
    var names := []
    for id in Boss.ids():
        var entry := Boss.data(id)
        assert_false(entry["name"] in names, "deux seigneurs n'ont jamais le même nom")
        names.append(entry["name"])
        assert_ne(Boss.epithet(id), "")
        assert_ne(Boss.hint(id), "", "chaque seigneur dit comment le battre")
        assert_not_null(KnightClass.by_id(Boss.knight_id(id)))
        assert_false(_rule(id).is_empty(), "chaque seigneur a sa règle")


func test_every_rule_has_its_lord() -> void:
    var used := {}
    for id in Boss.ids():
        for which: int in _rule(id):
            used[which] = true
    for which: int in Boss.Rule.values():
        assert_true(used.has(which), "règle %s sans seigneur" % Boss.Rule.keys()[which])


func test_every_lord_silhouette_is_drawable() -> void:
    for id in Boss.ids():
        var spec := KnightBuild.dressed(Boss.knight_id(id), Boss.look(id))
        var look := Boss.look(id)
        if look.has("crest"):
            assert_eq(spec["crest"], look["crest"], "%s : cimier reconnu" % id)
            assert_false(KnightBuild.crest(spec["crest"], spec["helmet"]).is_empty())
        if look.has("cape"):
            assert_eq(spec["cape"], look["cape"])
            assert_gt(KnightBuild.cape(spec).size(), 3)


# --- Le tirage et le bestiaire ---

func test_two_different_lords_per_hunt() -> void:
    for seed_value in range(1, 60):
        var hunt := Hunt.new(HuntDifficulty.Level.NUIT, seed_value)
        assert_eq(hunt.bosses.size(), 2)
        assert_ne(hunt.bosses[0], hunt.bosses[1])
        assert_true(hunt.is_boss(Hunt.BOSS_DUELS[0]))
        assert_true(hunt.is_boss(Hunt.LENGTH - 1))
        assert_false(hunt.is_boss(0))


func test_recent_lords_do_not_come_back_at_once() -> void:
    var profile := PlayerProfile.new()
    var previous: Array[StringName] = []
    for n in 6:
        var hunt := profile.start_hunt(HuntDifficulty.Level.PENOMBRE, 100 + n)
        for id in hunt.bosses:
            assert_false(id in previous, "un seigneur de la Chasse précédente ne revient pas aussitôt")
        previous = hunt.bosses.duplicate()
        hunt.forfeit()
        hunt.conclude(profile)
    assert_eq(profile.recent_bosses.size(), Boss.RECENT_MEMORY)


func test_unknown_lords_come_more_often() -> void:
    var defeated := Boss.ids().slice(0, 12)
    var unseen := 0
    for seed_value in 300:
        var picked := Boss.pick(RngRandomSource.new(seed_value + 1), 1, [], defeated)
        if not picked[0] in defeated:
            unseen += 1
    assert_gt(unseen, 300 * 3 / 15 * 2 / 2, "trois inconnus sortent bien plus souvent que leur part")


func test_beating_a_lord_fills_the_bestiary_once() -> void:
    var profile := PlayerProfile.new()
    var hunt := profile.start_hunt(HuntDifficulty.Level.PENOMBRE, 4)
    for i in Hunt.BOSS_DUELS[0]:
        hunt.record_duel(true)
        hunt.choose(0, profile)
    var lord := hunt.boss_id()
    var shards := profile.shards
    hunt.record_duel(true, 0, profile)
    assert_eq(hunt.boss_just_beaten, lord)
    assert_true(lord in profile.bestiary)
    assert_true(lord in hunt.first_kills)
    assert_eq(profile.shards, shards + Boss.FIRST_KILL_SHARDS, "le premier triomphe rapporte des éclats")
    assert_false(profile.defeat_boss(lord), "une seule fois au bestiaire")


func test_after_a_lord_the_keepsake_is_a_rarer_piece() -> void:
    for seed_value in range(1, 30):
        var hunt := Hunt.new(HuntDifficulty.Level.PENOMBRE, seed_value)
        hunt.index = Hunt.BOSS_DUELS[0]
        hunt.record_duel(true)
        var keep := hunt.offer()[2]
        assert_eq(keep.kind, HuntReward.Kind.PIECE)
        assert_gte(keep.rarity, Rarity.Tier.QUARTIER, "la Pénombre ne donne que du Croissant ou du Quartier : une phase de plus")


func test_lords_and_bestiary_are_saved_and_checked() -> void:
    var profile := PlayerProfile.new()
    var hunt := profile.start_hunt(HuntDifficulty.Level.NUIT, 9)
    profile.defeat_boss(&"bastion")
    var data: Dictionary = JSON.parse_string(JSON.stringify(profile.to_dict()))
    var back := PlayerProfile.from_dict(data)
    assert_eq(back.hunt.bosses, hunt.bosses)
    assert_eq(back.bestiary, [&"bastion"] as Array[StringName])
    assert_eq(back.recent_bosses, profile.recent_bosses)
    var tampered := hunt.to_dict()
    tampered["bosses"] = ["bastion", "bastion"]
    assert_null(Hunt.from_dict(tampered), "deux fois le même seigneur")
    tampered["bosses"] = ["dragon", "bastion"]
    assert_null(Hunt.from_dict(tampered))
    var junk := PlayerProfile.from_dict({"version": 2, "items": [], "bestiary": ["sablier", "x", "sablier", 3]})
    assert_eq(junk.bestiary, [&"sablier"] as Array[StringName])


func test_a_hunt_saved_before_the_lords_gets_lords_from_its_seed() -> void:
    var old := Hunt.new(HuntDifficulty.Level.NUIT, 55).to_dict()
    old.erase("bosses")
    old.erase("first_kills")
    var back := Hunt.from_dict(old)
    assert_not_null(back)
    assert_eq(back.bosses, Hunt.new(HuntDifficulty.Level.NUIT, 55).bosses)


# --- Les seigneurs en Chasse ---

func test_a_lord_fights_with_his_knight_his_rule_and_a_guardian_strength() -> void:
    var hunt := Hunt.new(HuntDifficulty.Level.NUIT, 21)
    var i := Hunt.LENGTH - 1
    var lord := hunt.boss_id(i)
    var shadow := hunt.opponent(i, Loadout.new(KnightClass.VEILLEUR))
    assert_eq(shadow.boss, lord)
    assert_true(shadow.guardian)
    if Boss.rule(lord, Boss.Rule.MIRROR) == 0:
        assert_eq(shadow.knight.id, Boss.knight_id(lord))
    for which: int in _rule(lord):
        assert_eq(hunt.enemy_bonus(i).rules.get(which), _rule(lord)[which])


func test_the_mirror_takes_your_knight_and_gear() -> void:
    var hunt := Hunt.new(HuntDifficulty.Level.NUIT, 1, KnightClass.COLOSSE)
    hunt.bosses.assign([&"reflet", &"bastion"])
    var gear := PlayerProfile.new().loadout(KnightClass.COLOSSE)
    var shadow := hunt.opponent(Hunt.BOSS_DUELS[0], gear)
    assert_eq(shadow.knight.id, KnightClass.COLOSSE)
    assert_eq(shadow.gear, gear)


# --- Chaque règle ---

func test_rune_regen_fills_the_veneur_runes_alone() -> void:
    var duel := _duel_against(&"grand_veneur")
    for i in _rule(&"grand_veneur")[Boss.Rule.RUNE_REGEN]:
        duel.step(null, null)
    assert_eq(duel.right.rune, 1)
    assert_eq(duel.left.rune, 0)


func test_thorns_hurt_the_attacker() -> void:
    var duel := _duel_against(&"dame_aux_ronces")
    var mine := duel.left.hp
    _player_hits(duel)
    assert_lt(duel.right.hp, duel.right.max_hp())
    assert_lt(duel.left.hp, mine, "les ronces griffent celui qui frappe")


func test_super_armor_takes_the_blow_without_flinching() -> void:
    var duel := _duel_against(&"colosse_de_fer")
    duel.left.x = 4000
    duel.right.x = 4800
    duel.right.request(CombatAction.Kind.FRAPPE)
    duel.step(null, null)
    assert_eq(duel.right.phase, Fighter.Phase.STARTUP)
    duel.right.take_hit(50, Fighter.HITSTUN)
    assert_ne(duel.right.phase, Fighter.Phase.STUNNED, "le Colosse de Fer ne bronche pas")
    assert_eq(duel.right.hp, duel.right.max_hp() - 75, "mais il encaisse, et plus fort")


func test_the_iron_colossus_is_bigger_and_slower() -> void:
    var duel := _duel_against(&"colosse_de_fer")
    assert_lt(duel.right.walk_speed(), FighterStats.resolve(KnightClass.by_id(KnightClass.COLOSSE)).walk_speed)
    assert_gt(Boss.scale(&"colosse_de_fer"), 1.2)


func test_super_armor_ends_when_the_blow_lands() -> void:
    var duel := _duel_against(&"colosse_de_fer")
    duel.right.request(CombatAction.Kind.FRAPPE)
    duel.step(null, null)
    duel.right.phase = Fighter.Phase.ACTIVE
    duel.right.take_hit(50, Fighter.HITSTUN)
    assert_eq(duel.right.phase, Fighter.Phase.STUNNED, "pendant le coup lui-même, il peut être interrompu")


func test_lifesteal_heals_the_leech() -> void:
    var duel := _duel_against(&"sangsue")
    duel.right.hp = 500
    _right_hits(duel)
    assert_gt(duel.right.hp, 500)
    assert_lt(duel.left.hp, duel.left.max_hp())


func test_the_shield_drinks_three_blows_per_round() -> void:
    var duel := _duel_against(&"bastion")
    assert_eq(duel.right.shield, 2)
    _player_hits(duel)
    assert_eq(duel.right.shield, 1)
    assert_eq(duel.right.hp, duel.right.max_hp(), "l'égide boit le coup")
    duel.right.shield = 0
    duel.left.phase = Fighter.Phase.IDLE
    duel.left.action = CombatAction.Kind.NONE
    _player_hits(duel)
    assert_lt(duel.right.hp, duel.right.max_hp(), "égide brisée, les coups portent")


func test_the_three_crowned_king_must_be_beaten_three_times() -> void:
    var duel := _duel_against(&"roi_aux_trois_couronnes")
    assert_eq(duel.rounds_needed[-1], 3)
    assert_eq(duel.rounds_needed[1], 2)
    for round_n in 2:
        duel.right.hp = 0
        duel.step(null, null)
        assert_eq(duel.match_winner, 0, "deux manches ne suffisent pas")
        duel.skip_intro()
    duel.right.hp = 0
    duel.step(null, null)
    assert_eq(duel.match_winner, -1)


func test_the_shapeshifter_changes_knight_each_round() -> void:
    var duel := _duel_against(&"changeforme")
    var seen := [duel.right.knight.id]
    for round_n in 1:
        duel.left.hp = 0
        duel.step(null, null)
        for i in Duel.ROUND_OVER_FRAMES + 1:
            duel.step(null, null)
        seen.append(duel.right.knight.id)
    assert_ne(seen[0], seen[1])
    assert_eq(seen, [Boss.shapes(KnightClass.VEILLEUR)[0], Boss.shapes(KnightClass.VEILLEUR)[1]])


func test_the_moon_strikes_the_mark_unless_you_leave_it() -> void:
    var duel := _duel_against(&"pretresse_de_sang")
    duel.left.x = 2000
    duel.right.x = 8000
    var every: int = _rule(&"pretresse_de_sang")[Boss.Rule.MOON_STRIKE]
    for i in every:
        duel.step(null, null)
    assert_gt(duel.left.danger_left, 0, "la marque est posée sous le joueur")
    for i in Boss.MOON_WARNING:
        duel.step(null, null)
    assert_eq(duel.left.hp, duel.left.max_hp() - Boss.MOON_DAMAGE, "resté sur la marque : touché")
    var dodged := _duel_against(&"pretresse_de_sang")
    dodged.left.x = 2000
    dodged.right.x = 8000
    for i in every:
        dodged.step(null, null)
    dodged.left.x = 2000 + Boss.MOON_RADIUS + 200
    for i in Boss.MOON_WARNING:
        dodged.step(null, null)
    assert_eq(dodged.left.hp, dodged.left.max_hp(), "sorti de la marque : épargné")


func test_the_ai_jumps_out_of_the_moon() -> void:
    var me := Fighter.new(-1, 3000)
    var foe := Fighter.new(1, 9000)
    me.danger_x = 3000
    me.danger_left = 20
    assert_eq(AiBrain.new(1, 1, 1.0).counter_to(me, foe, 6000), CombatAction.Kind.SAUT)


func test_the_sandglass_wins_at_the_time_limit() -> void:
    var duel := _duel_against(&"sablier")
    assert_eq(duel.round_frames, _rule(&"sablier")[Boss.Rule.SANDGLASS] * Duel.FPS)
    duel.right.hp = 1
    duel.round_time_left = 1
    duel.step(null, null)
    assert_eq(duel.wins[1], 1, "au temps, le Sablier l'emporte même presque mort")


func test_the_undying_regenerates_when_left_alone() -> void:
    var duel := _duel_against(&"increvable")
    duel.right.hp = 400
    for i in Boss.REGEN_DELAY - 10:
        duel.step(null, null)
    assert_eq(duel.right.hp, 400, "pas avant deux secondes de calme")
    for i in 120:
        duel.step(null, null)
    assert_gt(duel.right.hp, 400)


func test_the_fury_hits_harder_below_half() -> void:
    var duel := _duel_against(&"furie")
    var calm := duel.right.damage(CombatAction.Kind.FRAPPE)
    assert_false(duel.right.is_enraged())
    duel.right.hp = duel.right.max_hp() / 2
    assert_true(duel.right.is_enraged())
    assert_gt(duel.right.damage(CombatAction.Kind.FRAPPE), calm)


func test_the_viper_poisons() -> void:
    var duel := _duel_against(&"vipere")
    _right_hits(duel)
    assert_true(duel.left.is_poisoned())
    var after_bite := duel.left.hp
    for i in 60:
        duel.step(null, null)
    assert_lt(duel.left.hp, after_bite, "le venin ronge")


func test_the_black_dawn_starts_with_its_ultimate_ready() -> void:
    var duel := _duel_against(&"aube_noire")
    assert_eq(duel.right.rune, Fighter.MAX_RUNE)


func test_the_spectre_fades_one_second_in_five() -> void:
    var duel := _duel_against(&"spectre")
    var intangible := 0
    for i in Boss.INTANGIBLE_CYCLE:
        duel.step(null, null)
        if duel.right.is_intangible():
            intangible += 1
            assert_true(duel.right.is_invulnerable())
    assert_eq(intangible, Boss.INTANGIBLE_FRAMES)
