class_name Reliquary
extends RefCounted
## Ce que rapporte un duel du Chemin des ombres. Une victoire ouvre un reliquaire (une pièce) et fait monter d'un palier ;
## une défaite rapporte des éclats et garde le palier : le temps passé n'est jamais perdu.
## Une pièce déjà possédée, au même rang ou mieux, se change en éclats (PowerBudget.SHARD_VALUE).

const SHARDS_WIN := 4
const SHARDS_LOSS := 3


static func open(profile: PlayerProfile, won: bool, guardian: bool, rng: RandomSource) -> DuelReward:
    var reward := DuelReward.new()
    reward.won = won
    reward.guardian = guardian
    reward.palier = profile.palier
    if not won:
        reward.shards = SHARDS_LOSS
        profile.add_shards(reward.shards)
        return reward
    var minimum := Rarity.Tier.GIBBEUSE if guardian else Rarity.Tier.CROISSANT
    var rarity := LootTable.roll_rarity(rng, profile.pity, minimum, profile.full_moon_pity)
    var def := LootTable.roll_piece(rng, profile.knight_id)
    profile.set_pity(0 if rarity >= Rarity.Tier.GIBBEUSE else profile.pity + 1)
    profile.set_full_moon_pity(0 if rarity == Rarity.Tier.PLEINE_LUNE else profile.full_moon_pity + 1)
    reward.shards = SHARDS_WIN
    if not profile.owns_at_least(def.id, rarity):
        reward.item = profile.add_item(def.id, rarity)
    if reward.item == null: ## en double, ou inventaire plein
        reward.duplicate = true
        reward.item = OwnedItem.new(0, def, rarity)
        reward.shards += PowerBudget.shard_value(rarity, PowerBudget.MIN_LEVEL)
    profile.add_shards(reward.shards)
    profile.clear_palier()
    return reward
