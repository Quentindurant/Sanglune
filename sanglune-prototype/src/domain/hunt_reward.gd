class_name HuntReward
extends RefCounted
## Une récompense de la Chasse : l'une des trois proposées après un duel gagné, ou le butin de fin.
## Une bénédiction ne dure que la Chasse ; une pièce et des éclats se gardent, même si la Chasse échoue.
## Le soin efface les blessures ; la larme de lune rejoue un duel perdu, une fois.

enum Kind { BLESSING, PIECE, SHARDS, HEAL, TEAR }

var kind: int
var blessing_id: StringName ## BLESSING
var def: ItemDef ## PIECE : le modèle proposé
var rarity: int = Rarity.Tier.CROISSANT ## PIECE
var shards := 0 ## SHARDS, ou éclats rendus par une pièce déjà possédée
var item: OwnedItem ## PIECE, une fois prise : la pièce rangée dans l'inventaire
var duplicate := false ## PIECE déjà possédée au même rang ou mieux : changée en éclats


static func blessing(id: StringName) -> HuntReward:
    var reward := HuntReward.new()
    reward.kind = Kind.BLESSING
    reward.blessing_id = id
    return reward


static func piece(p_def: ItemDef, p_rarity: int) -> HuntReward:
    var reward := HuntReward.new()
    reward.kind = Kind.PIECE
    reward.def = p_def
    reward.rarity = p_rarity
    return reward


static func shard_pile(amount: int) -> HuntReward:
    var reward := HuntReward.new()
    reward.kind = Kind.SHARDS
    reward.shards = amount
    return reward


static func of_kind(p_kind: int) -> HuntReward:
    var reward := HuntReward.new()
    reward.kind = p_kind
    return reward


## Se garde après la Chasse (pièce, éclats), ou ne vaut que pour elle (bénédiction, soin, larme).
func is_permanent() -> bool:
    return kind == Kind.PIECE or kind == Kind.SHARDS


func has_new_piece() -> bool:
    return kind == Kind.PIECE and item != null and not duplicate


## Range la récompense permanente dans le profil. Une pièce déjà possédée, au même rang ou mieux, devient des éclats.
func grant(profile: PlayerProfile) -> void:
    match kind:
        Kind.SHARDS:
            profile.add_shards(shards)
        Kind.PIECE:
            if not profile.owns_at_least(def.id, rarity):
                item = profile.add_item(def.id, rarity)
            if item == null:
                duplicate = true
                item = OwnedItem.new(0, def, rarity)
                shards = PowerBudget.shard_value(rarity, PowerBudget.MIN_LEVEL)
                profile.add_shards(shards)
