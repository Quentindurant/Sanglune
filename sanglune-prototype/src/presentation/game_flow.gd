class_name GameFlow
extends Node
## Enchaîne les écrans : accueil, chevaliers, armurerie, duel contre l'ombre du palier, reliquaire ;
## et la Chasse : choix de la nuit, chemin des duels, duel, récompense à choisir, fin de Chasse.
## Garde le profil du joueur et le sauvegarde dès qu'il change.
## Le retour (bouton Android ou Échap) est confié à l'écran affiché ; à l'accueil, le retour Android quitte le jeu.

const ARENA_SCENE := preload("res://scenes/arena.tscn")

var store: ProfileStore ## sauvegarde du profil ; à fixer avant l'ajout à l'arbre pour en changer (tests)
var random: RandomSource ## hasard du butin ; à fixer avant l'ajout à l'arbre pour en changer (tests)
var profile: PlayerProfile
var current_screen: Node


func _ready() -> void:
    InputBindings.register()
    if store == null:
        store = LocalProfileStore.new()
    if random == null:
        random = RngRandomSource.new()
    profile = store.load_profile()
    profile.changed.connect(_save_profile)
    _settle_interrupted_hunt()
    show_home()


func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_GO_BACK_REQUEST:
        go_back(true)


func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        go_back(false)
        get_viewport().set_input_as_handled()


func show_home() -> void:
    var gear := profile.loadout(profile.knight_id)
    var hunt_step := profile.hunt.index + 1 if profile.hunt != null else 0
    var home := HomeScreen.new(profile.knight(), profile.look(profile.knight_id), profile.palier, gear.power(), hunt_step)
    home.play_requested.connect(start_duel)
    home.knights_requested.connect(show_knights)
    home.hunt_requested.connect(show_hunt)
    _swap(home)


## selected_id : la carte présélectionnée ; par défaut, le chevalier actif.
func show_knights(selected_id: StringName = &"") -> void:
    var select := KnightSelect.new(selected_id if selected_id != &"" else profile.knight_id)
    select.confirmed.connect(_on_knight_chosen)
    select.equip_requested.connect(func(knight: KnightClass) -> void: show_armory(knight.id))
    select.cancelled.connect(show_home)
    _swap(select)


## L'armurerie d'un chevalier ; en sortant, on retrouve sa carte.
func show_armory(knight_id: StringName) -> void:
    var armory := ArmoryScreen.new(profile, knight_id)
    armory.closed.connect(show_knights.bind(armory.knight.id))
    armory.wardrobe_requested.connect(show_wardrobe.bind(armory.knight.id))
    _swap(armory)


## La garde-robe d'un chevalier ; en sortant, on retrouve son armurerie.
func show_wardrobe(knight_id: StringName) -> void:
    var wardrobe := WardrobeScreen.new(profile, knight_id)
    wardrobe.closed.connect(show_armory.bind(wardrobe.knight.id))
    _swap(wardrobe)


## Lance le duel du palier : l'ombre de ce palier, avec son équipement ; le joueur porte le sien.
func start_duel() -> void:
    var shadow := ShadowPath.opponent(profile.palier)
    var arena: Arena = ARENA_SCENE.instantiate()
    arena.configure(profile.knight(), shadow.knight, profile.loadout(profile.knight_id), shadow.gear,
        profile.look(profile.knight_id))
    arena.set_shadow(shadow)
    arena.report_results = true
    arena.match_finished.connect(_on_match_finished.bind(shadow))
    arena.home_requested.connect(show_home)
    _swap(arena)


## Le reliquaire d'un duel qui vient de finir.
func show_reliquary(reward: DuelReward, shadow_power: int = 0) -> void:
    var screen := ReliquaryScreen.new(profile, reward, shadow_power)
    screen.next_requested.connect(start_duel)
    screen.home_requested.connect(show_home)
    _swap(screen)


## La Chasse : le choix des nuits, ou le chemin de la Chasse en cours (ou son offre, si un choix attend).
func show_hunt() -> void:
    if profile.hunt != null and profile.hunt.state == Hunt.State.CHOOSING:
        show_hunt_offer()
        return
    var screen := HuntScreen.new(profile)
    screen.start_requested.connect(_on_hunt_started)
    screen.fight_requested.connect(start_hunt_duel)
    screen.forfeit_requested.connect(_forfeit_hunt)
    screen.home_requested.connect(show_home)
    screen.bestiary_requested.connect(show_bestiary)
    _swap(screen)


## Le bestiaire des seigneurs ; en sortant, on retrouve la Chasse.
func show_bestiary() -> void:
    var screen := BestiaryScreen.new(profile)
    screen.closed.connect(show_hunt)
    _swap(screen)


## Le duel à disputer de la Chasse : l'ombre de ce duel, ses bénédictions, et celles du joueur.
## Quitter ce duel l'abandonne ; un duel interrompu (jeu fermé) comptera comme perdu.
func start_hunt_duel() -> void:
    var hunt := profile.hunt
    if hunt == null or hunt.state != Hunt.State.FIGHTING:
        show_hunt()
        return
    var shadow := hunt.opponent(-1, profile.loadout(hunt.knight_id))
    var arena: Arena = ARENA_SCENE.instantiate()
    arena.configure(KnightClass.by_id(hunt.knight_id), shadow.knight, profile.loadout(hunt.knight_id), shadow.gear,
        profile.look(hunt.knight_id))
    arena.set_hunt_duel(hunt, shadow)
    arena.match_finished.connect(_on_hunt_duel_finished.bind(arena))
    arena.forfeit_requested.connect(_forfeit_hunt)
    hunt.begin_duel()
    _swap(arena)


func show_hunt_offer() -> void:
    var screen := HuntOfferScreen.new(profile, profile.hunt)
    screen.continue_requested.connect(show_hunt)
    screen.home_requested.connect(show_home)
    _swap(screen)


## quit_if_unhandled : seul le bouton retour d'Android quitte le jeu depuis l'accueil, pas Échap.
func go_back(quit_if_unhandled: bool) -> void:
    var handled: bool = current_screen.has_method("go_back") and current_screen.go_back()
    if not handled and quit_if_unhandled:
        get_tree().quit()


func _on_match_finished(player_won: bool, shadow: ShadowOpponent) -> void:
    show_reliquary(Reliquary.open(profile, player_won, shadow.guardian, random), shadow.power())


func _on_hunt_started(difficulty: int) -> void:
    if profile.start_hunt(difficulty, random.below(Hunt.SEED_LIMIT) + 1) != null:
        start_hunt_duel()


func _on_hunt_duel_finished(player_won: bool, arena: Arena) -> void:
    var hunt := profile.hunt
    hunt.record_duel(player_won, arena.duel.wins[1], profile)
    if hunt.state == Hunt.State.CHOOSING:
        show_hunt_offer()
    elif hunt.is_over():
        _finish_hunt()
    else:
        show_hunt() ## la larme de lune : on rejoue ce duel


func _forfeit_hunt() -> void:
    if profile.hunt == null:
        show_home()
        return
    profile.hunt.forfeit()
    _finish_hunt()


func _finish_hunt() -> void:
    var knight_id := profile.hunt.knight_id
    var screen := HuntEndScreen.new(profile, profile.hunt.conclude(profile), knight_id)
    screen.again_requested.connect(show_hunt)
    screen.home_requested.connect(show_home)
    _swap(screen)


## Le jeu a été fermé en plein duel de Chasse : ce duel compte comme perdu (une larme de lune peut le sauver).
func _settle_interrupted_hunt() -> void:
    var hunt := profile.hunt
    if hunt == null or not hunt.in_duel:
        return
    hunt.record_duel(false)
    if hunt.is_over():
        hunt.conclude(profile)


func _on_knight_chosen(knight: KnightClass) -> void:
    profile.select_knight(knight.id)
    show_home()


func _save_profile() -> void:
    store.save_profile(profile)


func _swap(next_screen: Node) -> void:
    if current_screen != null:
        current_screen.queue_free()
    current_screen = next_screen
    add_child(next_screen)
