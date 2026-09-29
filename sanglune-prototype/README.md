# Sanglune, prototype gris

Un seul objectif pour ce jalon : savoir si un duel de 30 secondes est fun au tactile, avec des rectangles.
Si la réponse est non, on corrige le combat avant de dessiner le moindre chevalier.

## Lancer le jeu sur Debian 13

1. Installe Godot 4.7 : `flatpak install flathub org.godotengine.Godot`, ou télécharge-le sur godotengine.org.
2. Dans Godot, choisis « Importer » et sélectionne `project.godot`.
3. Appuie sur F5.

Le jeu s'ouvre sur le choix du chevalier. Touche une carte, puis « Combattre ».
Tu joues le chevalier de gauche (liseré cyan) contre l'ombre (liseré rouge), qui tire son chevalier au hasard.
En fin de match : « Rejouer » garde les deux mêmes chevaliers, « Changer de chevalier » revient au choix.

| Action | Clavier | Tactile |
| --- | --- | --- |
| Choisir son chevalier | Q et D, ou les flèches | toucher la carte |
| Lancer le duel | J ou Entrée | Combattre |
| Reculer, avancer | Q et D, ou les flèches | boutons < et > |
| Frappe | J | Frappe |
| Estoc | K | Estoc |
| Parade | L | Parade |
| Rune (jauge pleine) | I | Rune |
| Rejouer, changer de chevalier | J, Échap | boutons de fin de match |

La souris simule le tactile : tu peux cliquer les boutons ronds sur PC.

## Lancer les tests

```bash
./run_tests.sh
# avec Godot en flatpak :
GODOT="flatpak run org.godotengine.Godot" ./run_tests.sh
```

Les tests utilisent GUT (licence MIT), inclus dans `addons/gut`. Dans l'éditeur, le panneau GUT les lance aussi.

## Tester sur ton téléphone Android

Il faut les modèles d'export, un JDK et le SDK Android : suis la page « Exporting for Android » de la documentation Godot.
Une fois configuré, le bouton de déploiement en un clic envoie le jeu sur le téléphone branché en USB.

## Les règles du prototype

Le triangle naît des timings, sans règle spéciale :

- la Frappe est rapide, elle touche avant qu'un Estoc parte ;
- l'Estoc traverse la Parade et brise la garde ;
- la Parade bloque la Frappe et laisse l'attaquant exposé.

Chaque coup réussi charge la rune d'un segment. À trois segments, la Rune frappe fort et ignore la Parade.
Deux manches gagnantes, 60 secondes maximum par manche. Au temps, le plus de vie l'emporte ; une égalité rejoue la manche.

### Les quatre chevaliers

| Chevalier | Arme | Atout | Point faible |
| --- | --- | --- | --- |
| Le Veilleur | Épée longue et écu | Équilibré, idéal pour apprendre | Ne domine nulle part |
| La Faucheuse | Hallebarde | Allonge maximale | Lente à la reprise |
| La Rôdeuse | Deux dagues | Vitesse maximale | Doit coller sa cible |
| Le Colosse | Masse d'armes et plaques | Chaque coup brise la garde | Le plus lent |

Une seule exception au triangle : tous les coups du Colosse brisent la parade.
Contre lui, parer ne sert à rien, il faut le prendre de vitesse avec une Frappe.

En gris, chaque chevalier se reconnaît déjà à sa carrure, son casque et son arme au repos.
C'est le test de silhouette de la planche, avant le moindre dessin.

### Régler l'équilibrage

- Les frames, dégâts et portées de base : `src/domain/combat_action.gd`.
- Ce que chaque chevalier change à cette base (allonge, vitesse, puissance, vie, marche) : `ROSTER` dans `src/domain/knight_class.gd`.
- Pour vérifier qu'un réglage ne casse pas un chevalier, lance le rapport IA contre IA (une trentaine de secondes) :

```bash
godot --headless --path . -s tools/balance_report.gd
```

Il donne le taux de victoire de chaque paire. C'est un repère grossier, l'IA ne joue pas comme un humain : les playtests décident.
Le niveau de l'IA se règle dans `AiBrain.new(graine, temps_de_reaction, precision)`, appelé dans `arena.gd`.

## Architecture

Hexagonale, pour que les règles restent testables sans écran et prêtes pour le réseau.

- `src/domain` : les règles pures (actions, classes de chevaliers, chevalier en combat, duel, IA). Aucune dépendance aux nœuds Godot.
- `src/ports/intent_source.gd` : le contrat d'entrée, une intention par frame.
- `src/adapters` : le joueur (clavier et tactile), l'IA, les touches. Plus tard, un adaptateur Nakama pour le PvP.
- `src/presentation` : l'affichage, rien d'autre. `game_flow.gd` enchaîne les écrans, `knight_select.gd` et `knight_card.gd` font l'écran de choix, `arena.gd` le duel, `knight_look.gd` les silhouettes grises, `palette.gd` les couleurs de la planche.
- `tests/unit` : un fichier de tests par feature.
- `tools` : les outils de développement, hors du jeu.

Le duel tourne à pas fixe de 60 frames par seconde, avec des positions entières en millimètres.
C'est la base dont le rollback netcode aura besoin plus tard.

## Grille de playtest (la porte « le duel est fun »)

Fais jouer cinq personnes, sans rien leur expliquer, puis note :

- Après trois duels, peuvent-elles expliquer le triangle avec leurs mots ?
- Relancent-elles un duel sans qu'on leur demande ?
- Les boutons tombent-ils sous les pouces, sans regarder l'écran ?
- Un coup reçu leur paraît-il juste ou injuste ?
- Reconnaissent-elles les quatre chevaliers à leur seule silhouette ?
- Un chevalier leur paraît-il injouable, ou au contraire imbattable ?

Si trois personnes sur cinq relancent seules, la porte est franchie : on passe à la vertical slice.
