class_name Hunt
extends RefCounted
## La Chasse : sept duels d'affilée contre des ombres de plus en plus fortes. Au milieu et au bout, deux seigneurs
## uniques (Boss), chacun avec sa règle de combat, différents de ceux des dernières Chasses.
## Après chaque duel gagné, on choisit une récompense parmi trois : une bénédiction pour la Chasse,
## une pièce ou des éclats à garder, parfois un soin ou une larme de lune. Une défaite termine la Chasse.
## Chaque manche perdue dans un duel gagné laisse une blessure (moins de vie jusqu'au soin).
##
## Tout découle de la graine tirée au départ : les ombres et les offres sont les mêmes si l'on quitte le jeu
## et qu'on revient, pour qu'on ne puisse pas relancer une offre. Quitter en plein duel compte comme une défaite.

signal changed ## à chaque étape, pour que la sauvegarde suive

enum State { FIGHTING, CHOOSING, WON, LOST }

const LENGTH := 7
const MAX_WOUNDS := 3
const WOUND_HP := -100 ## pour mille de vie en moins par blessure
const TEAR_CHANCE := 20 ## sur 100 : une larme de lune prend la place de la deuxième bénédiction
const PIECE_CHANCE := 60 ## sur 100 : la récompense à garder est une pièce plutôt que des éclats
const SEED_LIMIT := 2147483646
const SALT_SHADOW := 1
const SALT_SHADOW_BLESSING := 2
const SALT_OFFER := 3
const SALT_FINAL := 4
const SALT_BOSSES := 5
const BOSS_DUELS: Array[int] = [3, LENGTH - 1] ## les duels contre un seigneur
const STATE_KEYS := {State.FIGHTING: "fighting", State.CHOOSING: "choosing"}

var difficulty: int
var hunt_seed: int
var knight_id: StringName ## le chevalier choisi au départ, pour toute la Chasse
var index := 0 ## le duel en cours : 0 pour le premier, LENGTH - 1 pour le dernier seigneur
var bosses: Array[StringName] = [] ## les deux seigneurs de cette Chasse, dans l'ordre des duels BOSS_DUELS
var first_kills: Array[StringName] = [] ## les seigneurs vaincus pour la première fois pendant cette Chasse
var blessings: Array[StringName] = [] ## une même bénédiction peut y figurer plusieurs fois
var wounds := 0
var has_tear := false
var state: int = State.FIGHTING
var in_duel := false ## un duel est en cours : s'il est interrompu, il compte comme perdu
var tear_just_used := false ## le dernier duel était perdu, la larme de lune le fait rejouer
var boss_just_beaten: StringName = &"" ## le seigneur du dernier duel gagné, ou rien


func _init(p_difficulty: int = HuntDifficulty.Level.PENOMBRE, p_seed: int = 1,
        p_knight_id: StringName = KnightClass.VEILLEUR) -> void:
    difficulty = p_difficulty
    hunt_seed = clampi(p_seed, 1, SEED_LIMIT)
    knight_id = p_knight_id
    bosses = Boss.pick(RngRandomSource.new(_mix(0, SALT_BOSSES)), BOSS_DUELS.size())


## Tire les seigneurs en écartant ceux des dernières Chasses et en préférant ceux qu'on n'a jamais vaincus.
func pick_bosses(recent: Array[StringName], defeated: Array[StringName]) -> void:
    bosses = Boss.pick(RngRandomSource.new(_mix(0, SALT_BOSSES)), BOSS_DUELS.size(), recent, defeated)


func is_over() -> bool:
    return state == State.WON or state == State.LOST


## Le dernier duel : son seigneur vaincu, la Chasse est accomplie.
func is_last(duel_index: int = -1) -> bool:
    return (index if duel_index < 0 else duel_index) == LENGTH - 1


func is_boss(duel_index: int = -1) -> bool:
    return boss_id(duel_index) != &""


## Le seigneur d'un duel, ou &"" pour une ombre ordinaire.
func boss_id(duel_index: int = -1) -> StringName:
    var slot := BOSS_DUELS.find(index if duel_index < 0 else duel_index)
    return bosses[slot] if slot >= 0 and slot < bosses.size() else &""


## L'ombre d'un duel de la Chasse (par défaut, celui à disputer). Un seigneur a la force d'un gardien et son chevalier ;
## le Reflet prend celui du joueur et son équipement (player_gear), le Changeforme se bat sans équipement.
func opponent(duel_index: int = -1, player_gear: Loadout = null) -> ShadowOpponent:
    var i := index if duel_index < 0 else duel_index
    var palier := HuntDifficulty.palier_of(difficulty, i)
    var boss := boss_id(i)
    if boss == &"":
        return ShadowPath.build(palier, false, _mix(i, SALT_SHADOW))
    var mirror := Boss.rule(boss, Boss.Rule.MIRROR) > 0
    var knight := KnightClass.by_id(knight_id if mirror else Boss.knight_id(boss))
    var shadow := ShadowPath.build(palier, true, _mix(i, SALT_SHADOW), knight)
    shadow.boss = boss
    if mirror and player_gear != null:
        shadow.gear = player_gear
    if Boss.rule(boss, Boss.Rule.SHAPESHIFT) > 0:
        shadow.gear = Loadout.new(knight.id)
    return shadow


## Les bénédictions de l'ombre : aucune en Pénombre, les seigneurs en portent dès la Nuit, toutes en Lune de sang.
## Un seigneur ajoute sa règle, ses caractéristiques et ses traits.
func enemy_bonus(duel_index: int = -1) -> StatBonus:
    var i := index if duel_index < 0 else duel_index
    var field := "boss_blessings" if is_boss(i) else "shadow_blessings"
    var count: int = HuntDifficulty.value(difficulty, field)
    var rng := RngRandomSource.new(_mix(i, SALT_SHADOW_BLESSING))
    var taken: Array[StringName] = []
    for n in count:
        var id := _pick_blessing(rng, taken, false)
        if id != &"":
            taken.append(id)
    var bonus := Blessing.bonus_of(taken)
    if is_boss(i):
        Boss.bonus_of(boss_id(i), bonus)
    return bonus


## Ce que la Chasse ajoute au joueur : ses bénédictions, moins ses blessures.
func player_bonus() -> StatBonus:
    var bonus := Blessing.bonus_of(blessings)
    bonus.add_mod(GearStat.Stat.HP, WOUND_HP * wounds)
    return bonus


func blessing_count(id: StringName) -> int:
    return blessings.count(id)


## Le duel commence : s'il ne se termine pas (jeu quitté), il comptera comme perdu.
func begin_duel() -> void:
    if state != State.FIGHTING:
        return
    in_duel = true
    changed.emit()


## L'issue du duel en cours. rounds_lost : manches perdues, chacune laisse une blessure si le duel est gagné.
## profile : un seigneur vaincu entre au bestiaire, et la première fois rapporte Boss.FIRST_KILL_SHARDS éclats.
func record_duel(won: bool, rounds_lost: int = 0, profile: PlayerProfile = null) -> void:
    if state != State.FIGHTING:
        return
    in_duel = false
    tear_just_used = false
    boss_just_beaten = &""
    if won:
        wounds = clampi(wounds + rounds_lost, 0, MAX_WOUNDS)
        if is_boss():
            boss_just_beaten = boss_id()
            if profile != null and profile.defeat_boss(boss_just_beaten):
                first_kills.append(boss_just_beaten)
                profile.add_shards(Boss.FIRST_KILL_SHARDS)
        state = State.WON if is_last() else State.CHOOSING
    elif has_tear:
        has_tear = false
        tear_just_used = true
    else:
        state = State.LOST
    changed.emit()


## Abandonner : la Chasse s'arrête comme sur une défaite, sans larme.
func forfeit() -> void:
    if is_over():
        return
    in_duel = false
    state = State.LOST
    changed.emit()


## Les trois récompenses proposées après le duel gagné : toujours les mêmes pour ce duel de cette Chasse.
## La première est une bénédiction ; la deuxième aussi, sauf un soin si l'on est blessé ou parfois une larme ;
## la troisième se garde : une pièce pour ce chevalier, ou des éclats ; après un seigneur, toujours une pièce, plus rare.
func offer() -> Array[HuntReward]:
    var choices: Array[HuntReward] = []
    if state != State.CHOOSING:
        return choices
    var rng := RngRandomSource.new(_mix(index, SALT_OFFER))
    var first := _pick_blessing(rng, blessings, true)
    choices.append(HuntReward.blessing(first) if first != &"" else _keepsake(rng))
    var tear_roll := rng.below(100)
    if wounds > 0:
        choices.append(HuntReward.of_kind(HuntReward.Kind.HEAL))
    elif not has_tear and tear_roll < TEAR_CHANCE:
        choices.append(HuntReward.of_kind(HuntReward.Kind.TEAR))
    else:
        var second := _pick_blessing(rng, blessings, true, first)
        choices.append(HuntReward.blessing(second) if second != &"" else HuntReward.shard_pile(_offer_shards()))
    choices.append(_keepsake(rng, is_boss()))
    return choices


## Prend la récompense choisie (0, 1 ou 2) et passe au duel suivant. Renvoie null si le choix est impossible.
func choose(choice: int, profile: PlayerProfile) -> HuntReward:
    var choices := offer()
    if choice < 0 or choice >= choices.size():
        return null
    var reward := choices[choice]
    match reward.kind:
        HuntReward.Kind.BLESSING:
            blessings.append(reward.blessing_id)
        HuntReward.Kind.HEAL:
            wounds = 0
        HuntReward.Kind.TEAR:
            has_tear = true
        _:
            reward.grant(profile)
    index += 1
    state = State.FIGHTING
    changed.emit()
    return reward


## La fin de la Chasse : le butin (une pièce rare et des éclats si le dernier seigneur est tombé,
## des éclats selon les duels gagnés sinon), le record et la nuit qui s'ouvre peut-être.
## Le profil retient le record et oublie la Chasse.
func conclude(profile: PlayerProfile) -> HuntEnd:
    var end := HuntEnd.new()
    if not is_over():
        return end
    end.won = state == State.WON
    end.difficulty = difficulty
    end.duels_won = LENGTH if end.won else index
    end.first_kills = first_kills.duplicate()
    for i in BOSS_DUELS.size():
        if BOSS_DUELS[i] < end.duels_won and i < bosses.size():
            end.bosses_beaten.append(bosses[i])
    var locked_before: Array[int] = []
    for level in HuntDifficulty.all():
        if not profile.hunt_unlocked(level):
            locked_before.append(level)
    if end.won:
        var rng := RngRandomSource.new(_mix(LENGTH, SALT_FINAL))
        var def := LootTable.roll_piece(rng, knight_id)
        var rarity := HuntDifficulty.roll_rarity(HuntDifficulty.value(difficulty, "final_rarity"), rng)
        end.reward = HuntReward.piece(def, rarity)
        end.reward.grant(profile)
        end.shards = HuntDifficulty.value(difficulty, "final_shards")
    else:
        end.shards = HuntDifficulty.value(difficulty, "shards_per_duel") * end.duels_won
    profile.add_shards(end.shards)
    end.new_record = end.duels_won > profile.hunt_record(difficulty)
    profile.close_hunt(difficulty, end.duels_won)
    for level in locked_before:
        if profile.hunt_unlocked(level):
            end.unlocked = level
    return end


func to_dict() -> Dictionary:
    var stored_blessings := []
    for id in blessings:
        stored_blessings.append(String(id))
    return {
        "difficulty": HuntDifficulty.key(difficulty), "seed": hunt_seed, "knight": String(knight_id),
        "index": index, "blessings": stored_blessings, "wounds": wounds, "tear": has_tear,
        "state": STATE_KEYS.get(state, "fighting"), "in_duel": in_duel,
        "bosses": bosses.map(func(id: StringName) -> String: return String(id)),
        "first_kills": first_kills.map(func(id: StringName) -> String: return String(id)),
    }


## Relit une Chasse sauvegardée. Renvoie null si quoi que ce soit est invalide : le fichier a pu être modifié.
static func from_dict(data: Variant) -> Hunt:
    if not data is Dictionary:
        return null
    var level := HuntDifficulty.from_key(data.get("difficulty"))
    var seed_value: Variant = OwnedItem.whole_number(data.get("seed"))
    var stored_knight: Variant = data.get("knight")
    var stored_index: Variant = OwnedItem.whole_number(data.get("index"))
    var stored_wounds: Variant = OwnedItem.whole_number(data.get("wounds"))
    var stored_state: Variant = data.get("state")
    if level < 0 or not seed_value is int or seed_value < 1 or seed_value > SEED_LIMIT:
        return null
    if not stored_knight is String or KnightClass.by_id(StringName(stored_knight)) == null:
        return null
    if not stored_index is int or stored_index < 0 or stored_index >= LENGTH:
        return null
    if not stored_wounds is int or stored_wounds < 0 or stored_wounds > MAX_WOUNDS:
        return null
    if not data.get("tear") is bool or not data.get("in_duel") is bool or not stored_state in STATE_KEYS.values():
        return null
    if not data.get("blessings") is Array or data["blessings"].size() > stored_index:
        return null
    var hunt := Hunt.new(level, seed_value, StringName(stored_knight))
    for entry: Variant in data["blessings"]:
        if not Blessing.is_valid(entry):
            return null
        var id := StringName(entry)
        if hunt.blessing_count(id) >= Blessing.max_stack(id):
            return null
        hunt.blessings.append(id)
    hunt.index = stored_index
    hunt.wounds = stored_wounds
    hunt.has_tear = data["tear"]
    hunt.in_duel = data["in_duel"]
    hunt.state = State.CHOOSING if stored_state == STATE_KEYS[State.CHOOSING] else State.FIGHTING
    if hunt.state == State.CHOOSING and (hunt.index >= LENGTH - 1 or hunt.in_duel):
        return null
    if data.has("bosses"): ## une Chasse d'avant les seigneurs garde ceux tirés de sa graine
        var stored_bosses: Variant = data["bosses"]
        if not stored_bosses is Array or stored_bosses.size() != BOSS_DUELS.size():
            return null
        var restored: Array[StringName] = []
        for entry: Variant in stored_bosses:
            if not Boss.is_valid(entry) or StringName(entry) in restored:
                return null
            restored.append(StringName(entry))
        hunt.bosses = restored
    var stored_kills: Variant = data.get("first_kills", [])
    if stored_kills is Array:
        for entry: Variant in stored_kills:
            if Boss.is_valid(entry) and StringName(entry) in hunt.bosses and not StringName(entry) in hunt.first_kills:
                hunt.first_kills.append(StringName(entry))
    return hunt


## Une bénédiction tirée au poids parmi celles qu'on peut encore prendre ; &"" s'il n'en reste aucune.
## with_traits : faux pour les ombres, qui ne reçoivent que des renforts de caractéristiques.
## besides : une bénédiction déjà proposée à côté, à ne pas proposer deux fois.
func _pick_blessing(rng: RandomSource, taken: Array[StringName], with_traits: bool, besides: StringName = &"") -> StringName:
    var pool: Array[StringName] = []
    var total := 0
    for id in Blessing.ids():
        if not with_traits and Blessing.is_trait(id):
            continue
        if id == besides or taken.count(id) >= Blessing.max_stack(id):
            continue
        pool.append(id)
        total += Blessing.weight(id)
    if pool.is_empty():
        return &""
    var roll := rng.below(total)
    for id in pool:
        roll -= Blessing.weight(id)
        if roll < 0:
            return id
    return pool[-1]


## La récompense à garder : une pièce pour le chevalier de la Chasse, ou un tas d'éclats.
## after_boss : un seigneur vient de tomber, c'est toujours une pièce, d'une phase de lune de plus.
func _keepsake(rng: RandomSource, after_boss: bool = false) -> HuntReward:
    var piece_roll := rng.below(100)
    if after_boss or piece_roll < PIECE_CHANCE:
        var def := LootTable.roll_piece(rng, knight_id)
        var rarity := HuntDifficulty.roll_rarity(HuntDifficulty.value(difficulty, "offer_rarity"), rng)
        if after_boss:
            rarity = mini(Rarity.Tier.PLEINE_LUNE, rarity + 1)
        return HuntReward.piece(def, rarity)
    return HuntReward.shard_pile(_offer_shards())


func _offer_shards() -> int:
    return HuntDifficulty.value(difficulty, "offer_shards")


## Une graine propre à un duel et à un usage, tirée de celle de la Chasse : deux duels n'ont rien en commun.
func _mix(duel_index: int, salt: int) -> int:
    var mixed := (hunt_seed * 31 + duel_index * ShadowPath.SEED_STEP + salt * 104729) % SEED_LIMIT
    return mixed + 1
