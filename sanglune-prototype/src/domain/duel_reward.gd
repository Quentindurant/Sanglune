class_name DuelReward
extends RefCounted
## Ce qu'un duel du Chemin des ombres a rapporté, pour l'écran du reliquaire.

var won: bool
var guardian: bool ## l'ombre était un gardien
var palier: int ## le palier qui vient d'être disputé
var item: OwnedItem ## la pièce du reliquaire, ou null après une défaite
var duplicate: bool ## pièce déjà possédée : elle a été changée en éclats
var shards: int ## éclats gagnés en tout


func has_new_piece() -> bool:
    return item != null and not duplicate
