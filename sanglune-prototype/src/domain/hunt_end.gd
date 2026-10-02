class_name HuntEnd
extends RefCounted
## Ce qu'une Chasse terminée a rapporté, pour l'écran de fin.

var won := false ## le seigneur du bout de la Chasse est tombé
var difficulty: int = HuntDifficulty.Level.PENOMBRE
var duels_won := 0
var reward: HuntReward ## la pièce du seigneur, ou null après une défaite
var shards := 0 ## éclats de fin (sans ceux d'une pièce en double, comptés dans reward)
var new_record := false
var unlocked := -1 ## la difficulté que cette Chasse vient d'ouvrir, ou -1
var bosses_beaten: Array[StringName] = [] ## les seigneurs vaincus pendant cette Chasse
var first_kills: Array[StringName] = [] ## ceux qui entrent au bestiaire
