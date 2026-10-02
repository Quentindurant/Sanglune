class_name LocalProfileStore
extends ProfileStore
## Sauvegarde le profil dans le dossier privé de l'appli (user://). Rien ne quitte l'appareil.
## Format JSON : à la relecture, il ne peut produire que des données simples, jamais d'objet ni de script.

const DEFAULT_PATH := "user://profile.json"
const MAX_BYTES := 256 * 1024 ## au-delà, le fichier n'est pas le nôtre : on repart d'un profil neuf

var path: String


func _init(p_path: String = DEFAULT_PATH) -> void:
    path = p_path


func load_profile() -> PlayerProfile:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null or file.get_length() > MAX_BYTES:
        return PlayerProfile.new()
    var json := JSON.new()
    if json.parse(file.get_as_text()) != OK or not json.data is Dictionary:
        return PlayerProfile.new()
    return PlayerProfile.from_dict(json.data)


func save_profile(profile: PlayerProfile) -> void:
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        push_warning("Profil non sauvegardé : %s" % error_string(FileAccess.get_open_error()))
        return
    file.store_string(JSON.stringify(profile.to_dict()))
