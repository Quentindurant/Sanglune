class_name ShadowOpponent
extends RefCounted
## L'ombre d'un palier : son chevalier, son équipement et le niveau de son IA.

var palier: int
var guardian: bool
var boss: StringName = &"" ## un seigneur de la Chasse (Boss), ou rien
var knight: KnightClass
var gear: Loadout
var reaction_frames: int ## frames entre deux décisions de l'IA : moins, c'est plus vif
var accuracy: float ## probabilité de jouer la bonne réponse


func power() -> int:
    return gear.power()
