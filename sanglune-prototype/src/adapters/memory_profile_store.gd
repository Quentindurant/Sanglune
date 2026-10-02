class_name MemoryProfileStore
extends ProfileStore
## Sauvegarde en mémoire, pour les tests : rien n'est écrit sur le disque.

var saved: Dictionary = {}
var save_count := 0


func load_profile() -> PlayerProfile:
    return PlayerProfile.from_dict(saved)


func save_profile(profile: PlayerProfile) -> void:
    saved = profile.to_dict()
    save_count += 1
