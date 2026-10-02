extends SceneTree
## Captures d'écran de la Chasse (hors jeu, pour la revue) : choix des nuits, chemin, offre, duel, fin.
## Lancer avec un affichage (pas en --headless) : godot --path . -s tools/capture_hunt.gd -- <dossier>

var out_dir := "user://captures"


func _initialize() -> void:
    var args := OS.get_cmdline_user_args()
    if not args.is_empty():
        out_dir = args[0]
    DirAccess.make_dir_recursive_absolute(out_dir)
    InputBindings.register()
    _run.call_deferred()


func _run() -> void:
    var profile := PlayerProfile.new()
    profile.hunt_records[HuntDifficulty.Level.PENOMBRE] = Hunt.LENGTH
    profile.hunt_records[HuntDifficulty.Level.NUIT] = 4
    for id: StringName in [&"grand_veneur", &"colosse_de_fer", &"pretresse_de_sang", &"bastion", &"spectre", &"furie"]:
        profile.defeat_boss(id)
    await _shot(HuntScreen.new(profile), "chasse_nuits")
    var bestiary := BestiaryScreen.new(profile)
    root.add_child(bestiary)
    bestiary.select(&"colosse_de_fer")
    root.remove_child(bestiary)
    await _shot(bestiary, "bestiaire")

    var hunt := profile.start_hunt(HuntDifficulty.Level.NUIT, 4242)
    hunt.bosses.assign([&"colosse_de_fer", &"pretresse_de_sang"])
    for i in 3:
        hunt.record_duel(true, 1 if i == 1 else 0)
        hunt.choose(0, profile)
    hunt.has_tear = true
    await _shot(HuntScreen.new(profile), "chasse_seigneur")

    var shadow := hunt.opponent(-1, profile.loadout(hunt.knight_id))
    var arena: Arena = load("res://scenes/arena.tscn").instantiate()
    arena.configure(KnightClass.by_id(hunt.knight_id), shadow.knight, profile.loadout(hunt.knight_id), shadow.gear, profile.look(hunt.knight_id))
    arena.set_hunt_duel(hunt, shadow)
    await _shot(arena, "duel_colosse_de_fer", 150)

    hunt.record_duel(true, 0, profile)
    await _shot(HuntOfferScreen.new(profile, hunt), "chasse_offre_seigneur")
    hunt.choose(0, profile)
    hunt.index = Hunt.LENGTH - 1
    var priestess := hunt.opponent(-1, profile.loadout(hunt.knight_id))
    var arena2: Arena = load("res://scenes/arena.tscn").instantiate()
    arena2.configure(KnightClass.by_id(hunt.knight_id), priestess.knight, profile.loadout(hunt.knight_id), priestess.gear, profile.look(hunt.knight_id))
    arena2.set_hunt_duel(hunt, priestess)
    root.add_child(arena2)
    for i in 150:
        await process_frame
    arena2.duel.left.x = 3000
    arena2.moon_mark = {"x": 3000, "frames": 20}
    root.remove_child(arena2)
    await _shot(arena2, "duel_pretresse_marque", 4)

    var winner := PlayerProfile.new()
    var won := winner.start_hunt(HuntDifficulty.Level.NUIT, 77)
    for i in Hunt.LENGTH - 1:
        won.record_duel(true, 0, winner)
        won.choose(0, winner)
    won.record_duel(true, 0, winner)
    await _shot(HuntEndScreen.new(winner, won.conclude(winner), winner.knight_id), "chasse_fin")
    var gallery := PlayerProfile.new()
    for id in Boss.ids():
        gallery.defeat_boss(id)
    await _shot(BestiaryScreen.new(gallery), "bestiaire_complet")
    quit()


func _shot(node: Node, file_name: String, frames: int = 20) -> void:
    root.add_child(node)
    for i in frames:
        await process_frame
    var image := root.get_texture().get_image()
    image.save_png("%s/%s.png" % [out_dir, file_name])
    node.queue_free()
    await process_frame
