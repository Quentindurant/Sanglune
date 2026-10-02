class_name ProfileStore
extends RefCounted
## Port de sauvegarde du profil joueur. Aujourd'hui un fichier sur le téléphone, plus tard le serveur : même contrat.


func load_profile() -> PlayerProfile:
    return PlayerProfile.new()


func save_profile(_profile: PlayerProfile) -> void:
    pass
