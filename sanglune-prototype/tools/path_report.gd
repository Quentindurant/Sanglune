extends SceneTree
## Rapport du Chemin des ombres : une IA « joueur » (vivacité par défaut, 12 frames, 70 %) affronte l'ombre de chaque palier.
## Deux colonnes : le joueur sans équipement, puis équipé comme l'ombre du palier précédent (une progression ordinaire).
## Repère grossier : un vrai joueur apprend, l'IA non. Sert à vérifier que la pente monte sans mur.
##
## Lancer : godot --headless --path . -s tools/path_report.gd

const MATCHES := 40
const MAX_FRAMES := 60 * 60 * 10


func _initialize() -> void:
    print("palier  ombre                    puissance  joueur nu  joueur équipé")
    for palier in range(1, 21):
        var shadow := ShadowPath.opponent(palier)
        var knight := KnightClass.starter()
        var equipped := ShadowPath.opponent(maxi(1, palier - 1 if not ShadowPath.is_guardian(palier - 1) else palier - 2))
        var gear := Loadout.new(knight.id)
        for piece in equipped.gear.pieces():
            if not piece.def.is_weapon():
                gear.wear(piece)
        print("%-7d %-24s %-10d %-10s %s" % [palier, ("Gardien · " if shadow.guardian else "") + shadow.knight.display_name,
            shadow.power(), _percent(_rate(knight, null, shadow)), _percent(_rate(knight, gear, shadow))])
    quit()


func _rate(knight: KnightClass, gear: Loadout, shadow: ShadowOpponent) -> float:
    var wins := 0
    for i in MATCHES:
        var duel := Duel.new(knight, shadow.knight, gear, shadow.gear)
        var me := AiBrain.new(i * 2 + 1)
        var them := AiBrain.new(i * 2 + 1000, shadow.reaction_frames, shadow.accuracy)
        var frames := 0
        while duel.state != Duel.State.MATCH_OVER and frames < MAX_FRAMES:
            duel.step(me.decide(duel.left, duel.right), them.decide(duel.right, duel.left))
            frames += 1
        if duel.match_winner < 0:
            wins += 1
    return float(wins) / MATCHES


func _percent(rate: float) -> String:
    return "%d %%" % roundi(100.0 * rate)
