# Sanglune, prototype gris

Un seul objectif pour ce jalon : savoir si un duel de 30 secondes est fun au tactile, avec des rectangles.
Si la réponse est non, on corrige le combat avant de dessiner le moindre chevalier.

## Lancer le jeu sur Debian 13

1. Installe Godot 4.7 : `flatpak install flathub org.godotengine.Godot`, ou télécharge-le sur godotengine.org.
2. Dans Godot, choisis « Importer » et sélectionne `project.godot`.
3. Appuie sur F5.

Le jeu s'ouvre sur l'accueil : ton chevalier devant la lune rouge, « Jouer », « Chasse » et « Chevaliers ».
« Chevaliers » permet d'en choisir un autre ; le choix est retenu, même après avoir fermé le jeu.
Tu joues le chevalier de gauche (liseré cyan) contre l'ombre du palier atteint (liseré rouge).
En duel, le bouton II met en pause. En fin de match, le reliquaire : « Combat suivant » (ou « Réessayer ») relance le Chemin, « Accueil » y ramène.
Sur Android, le bouton retour suit la même logique : pause en duel, retour à l'accueil ailleurs, sortie du jeu depuis l'accueil.

| Action | Clavier | Tactile |
| --- | --- | --- |
| Lancer le duel du palier depuis l'accueil | J ou Entrée | Jouer |
| Partir en Chasse, choisir une récompense | flèches, Entrée | Chasse, toucher une nuit ou une carte, Partir ou Prendre |
| Changer de chevalier | Chevaliers, puis Q et D, puis J | Chevaliers, toucher la carte, Choisir |
| Équiper un chevalier | Chevaliers, flèches pour viser, Entrée | Chevaliers, toucher la carte, Équiper |
| Reculer, avancer | Q et D, ou les flèches | joystick à gauche ou à droite |
| Sauter | Z ou flèche du haut | joystick vers le haut (en biais pour sauter avec élan) |
| Esquiver | S, flèche du bas ou Espace | joystick vers le bas (en arrière, ou du côté où il penche) |
| Frappe (en l'air : Plongeon) | J | Frappe |
| Parade | L | Parade |
| Ultime (trois runes allumées) | I | Ultime |
| Pause, reprendre | Échap | bouton II, puis Reprendre |
| Fin de match (reliquaire) | J combat suivant, Échap accueil | Combat suivant ou Réessayer, Équiper, Accueil |

Le joystick se pose là où le pouce gauche touche, dans le coin bas gauche. La souris simule le tactile : tout se teste aussi sur PC.

## Lancer les tests

```bash
./run_tests.sh
# avec Godot en flatpak :
GODOT="flatpak run org.godotengine.Godot" ./run_tests.sh
```

Les tests utilisent GUT (licence MIT), inclus dans `addons/gut`. Dans l'éditeur, le panneau GUT les lance aussi.

## Tester sur ton téléphone Android

Le jeu se tient en paysage. C'est une version de test signée avec une clé de débogage, hors Play Store :
Android et Play Protect préviennent que l'appli est inconnue, c'est normal.

### Installer un APK déjà construit

- **Par câble :** active le débogage USB sur le téléphone (Paramètres, À propos du téléphone, touche sept fois « Numéro de build », puis Options pour les développeurs, Débogage USB), branche-le, puis :

  ```bash
  sudo apt install adb
  adb install -r export/sanglune-prototype.apk
  ```

- **Sans câble :** copie le fichier `.apk` sur le téléphone (Drive, mail, câble en mode fichiers), ouvre-le depuis l'appli Fichiers et autorise l'installation depuis cette source quand Android le demande.

Pour mettre à jour, réinstalle le nouvel APK par-dessus. Si Android refuse (« signature différente »), ne désinstalle pas à la main :
la sauvegarde partirait avec. Lance plutôt, téléphone branché :

```bash
bash tools/mettre-a-jour.sh export/sanglune-0.10.0.apk
```

Le script copie la sauvegarde, désinstalle, installe le nouvel APK et remet la sauvegarde (possible parce que ce sont des versions de test).
La clé de signature des versions de test est rangée dans `export/debug.keystore` (hors dépôt) : les prochaines versions la réutilisent, la mise à jour par-dessus remarche.

### Construire l'APK toi-même

Le préréglage d'export « Android » est déjà dans `export_presets.cfg` : arm64, plein écran, aucune permission demandée, tests et outils exclus.

1. Prends le binaire officiel de Godot 4.7 sur godotengine.org : la version flatpak a souvent du mal à lancer Java et le SDK du système.
2. Installe un JDK : `sudo apt install openjdk-21-jdk-headless`.
3. Installe le SDK Android : les « command line tools » de developer.android.com, puis `sdkmanager "platform-tools" "build-tools;35.0.0"`. Android Studio fait aussi l'affaire.
4. Dans Godot : Éditeur, Gérer les modèles d'export, Télécharger et installer.
5. Dans Godot : Éditeur, Paramètres de l'éditeur, Export, Android : renseigne le chemin du SDK Android et celui du JDK (`/usr/lib/jvm/java-21-openjdk-amd64`). Godot crée seul la clé de débogage.
6. Projet, Exporter, préréglage « Android », Exporter le projet en gardant « Exporter en mode débogage » coché.
   Téléphone branché en USB, le bouton Android en haut à droite de l'éditeur installe et lance le jeu en un clic.

Les clés de signature restent hors du dépôt : Godot les range dans les paramètres de l'éditeur, jamais dans `export_presets.cfg`.

## Les règles du prototype

Le triangle naît des timings :

- la **Parade** bloque la Frappe et laisse l'attaquant exposé, mais elle ne protège que de face ;
- le **Plongeon** (Frappe en l'air) tombe du ciel et brise la Parade ; sauter par-dessus un chevalier qui pare, c'est aussi le prendre à revers ;
- la **Frappe** est rapide : elle cueille un chevalier en l'air et interrompt un coup qui se prépare.

L'**Esquive** est un bond rapide pendant lequel aucun coup ne touche, suivi d'une reprise où l'on peut être puni.
Le **Saut** passe par-dessus l'adversaire : on change de côté, et on se retourne tout seul. Un coup ne touche que devant soi.

Chaque coup réussi allume une rune. À trois runes, l'**Ultime** de ton arme est prêt : il traverse la Parade et vide les runes.
Chaque ultime a sa parade : sortir de portée, sauter, esquiver, ou frapper pendant sa préparation.

| Ultime | Arme | Effet | Comment l'éviter |
| --- | --- | --- | --- |
| Lame de lune | Épée longue (Veilleur) | Grande entaille, longue portée | Esquiver, ou frapper pendant la préparation |
| Moisson | Hallebarde (Faucheuse) | Fauchage à très longue portée, repousse loin | Esquiver, ou rester très loin |
| Danse des lames | Dagues (Rôdeuse) | S'élance, intouchable, trois coups | Esquiver en arrière avant l'élan |
| Séisme | Masse (Colosse) | Onde au sol, long étourdissement | Sauter par-dessus l'onde |

L'ultime vient de l'arme : avec l'équipement, changer d'arme changera d'ultime.

Quand deux corps se chevauchent après une réception, ils s'écartent en douceur.
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

Chaque chevalier se reconnaît à sa carrure, son casque et son arme : c'est le test de silhouette de la planche.

## L'équipement

Chaque chevalier a quatre emplacements : arme, heaume, armure, talisman. L'armurerie s'ouvre depuis l'écran Chevaliers (« Équiper ») :
toucher un emplacement montre ses pièces, toucher une pièce l'essaie sur le pantin, « Équiper » la pose.

- **Chaque pièce est un compromis.** Elle renforce une ou deux caractéristiques et en affaiblit une. À rareté et niveau égaux,
  gains moins pertes valent toujours autant de points (`power_budget.gd`) : on choisit un style, pas un chiffre.
- **La rareté se lit à la lune** : Croissant (un gain), Quartier, Gibbeuse (deux gains, plus forts), Pleine lune (en plus, un trait).
- **Les traits** (`gear_trait.gd`), un par modèle de pièce, éveillés seulement en Pleine lune ; deux pièces au même trait ne le doublent pas :
  Riposte (après une esquive, la Frappe part plus vite), Garde lunaire (une parade réussie allume une rune),
  Chute lourde (un plongeon qui touche étourdit plus longtemps), Aube rouge (chaque manche commence avec une rune),
  Dernier souffle (sous un quart de sa vie, on frappe plus fort), Écho (un ultime qui touche rend une rune).
- **L'arme appartient au chevalier et donne l'ultime.** Elle change de forme dans sa famille, jamais de famille.
- **L'équipement se voit** : cimier ou cornes, cape, épaulières, forme de l'arme. La carrure et le casque ne changent jamais.
- **La puissance** (100 sans rien) résume l'équipement porté ; elle servira à apparier les joueurs en PvP.
- Un nouveau joueur reçoit une poignée de pièces pour essayer.
- **Améliorer** une pièce (dans la liste d'un emplacement) lui fait gagner un niveau contre des éclats : 8 × son niveau.
- **Recycler** une pièce ni portée ni de départ la change en éclats (selon sa rareté, plus la moitié de ses améliorations).
  Deux touches : la première demande confirmation.
- **La garde-robe** (bouton « Garde-robe » de l'armurerie, `wardrobe.gd`) : pour l'arme, le heaume et l'armure, montrer
  la pièce portée, une apparence déjà gagnée (gardée même après recyclage) ou rien. Elle ne change rien au combat.

## La Chasse

« Chasse » sur l'accueil : sept duels d'affilée contre des ombres tirées au hasard, de plus en plus fortes.
Au 4e duel et au 7e, un **seigneur** unique. Une défaite termine la Chasse (`hunt.gd`).

### Les seigneurs (`boss.gd`)

Quinze seigneurs, chacun avec son nom, sa silhouette (bois de cerf, couronne, épines, auréole, voile, manteau, taille)
et **sa règle de combat**. Chaque Chasse en tire deux, jamais ceux des dernières Chasses, et plus souvent ceux qu'on n'a jamais vaincus.
Sur le chemin, ils attendent au-dessus de leur duel ; devant l'un d'eux, son nom, son surnom et comment le battre.

| Seigneur | Règle | Comment le battre |
| --- | --- | --- |
| Le Grand Veneur | ses runes s'allument seules | garder son esquive pour l'ultime |
| La Dame aux Ronces | chaque coup reçu griffe l'attaquant | frapper peu, frapper juste |
| Le Colosse de Fer | géant, ne bronche pas quand il prépare un coup, mais encaisse plus fort | esquiver puis punir, ou frapper fort |
| La Sangsue | ses coups la soignent | ne lui laisser aucune ouverture |
| Le Bastion | son égide boit deux coups par manche | user l'égide, puis frapper |
| Le Roi aux trois couronnes | il faut le vaincre trois fois | tenir la distance |
| Le Changeforme | change de chevalier à chaque manche | s'adapter |
| Le Reflet | ton chevalier et ton équipement | te battre toi-même |
| La Prêtresse de Sang | la lune frappe le sol sous toi | sauter, esquiver ou quitter la marque |
| Le Sablier | manches de 25 secondes, le temps joue pour lui | attaquer vite |
| L'Increvable | se soigne s'il n'est pas touché | ne pas le laisser souffler |
| La Furie | sous la moitié de sa vie, plus forte et plus vive | l'achever vite |
| La Vipère | son venin ronge après chaque morsure | éviter les échanges |
| L'Aube Noire | son ultime est prêt dès le début de chaque manche | l'esquiver d'abord |
| Le Spectre | intangible une seconde sur cinq | frapper quand il est net |

- Après un seigneur, la récompense à garder est toujours une pièce, d'une phase de lune de plus.
- Le **bestiaire** (bouton « Bestiaire » du choix des nuits) montre les seigneurs vaincus ; les autres ne sont qu'une ombre et « ? ».
  Le premier triomphe sur un seigneur rapporte 30 éclats.
- Les règles passent par `StatBonus.rules` : `Fighter` et `Duel` les appliquent sans rien savoir de la Chasse.
  Pour la force de chaque seigneur (une minute environ) : `godot --headless --path . -s tools/boss_report.gd`.


- **Trois nuits** (`hunt_difficulty.gd`) : **Pénombre** (pour découvrir), **Nuit** (le vrai défi), **Lune de sang** (s'ouvre en finissant une Nuit).
  Plus la nuit est dure, plus les ombres sont vives et équipées, et meilleur est le butin. Et chaque duel est plus dur que le précédent.
  En Lune de sang, chaque ombre porte une bénédiction ; les seigneurs en portent dès la Nuit.
- **Après chaque duel gagné, une récompense parmi trois** : une **bénédiction** (`blessing.gd`), qui ne dure que la Chasse,
  une deuxième bénédiction, ou à sa place un **soin** si l'on est blessé ou parfois une **larme de lune**,
  et une récompense **à garder** : une pièce pour ton chevalier ou des éclats. Ce qui se garde reste acquis même si la Chasse échoue.
  Le haut de chaque carte le dit : « Pour la Chasse » en cyan, « À garder » en argent.
- **Les bénédictions** : six renforts de caractéristique (Sang vif, Lame affûtée, Bras long, Pas de loup, Peau de pierre, Cœur de lune),
  cumulables trois fois, et les six traits des Pleines lunes, prêtés une fois. Bien plus forts qu'une pièce : c'est le plaisir de la Chasse.
- **Les blessures** : chaque manche perdue dans un duel gagné retire 10 % de vie jusqu'au soin (trois au plus).
- **La larme de lune** rejoue un duel perdu, une fois.
- **Le butin du dernier seigneur** : une pièce rare (Quartier ou mieux en Pénombre, Gibbeuse ou mieux en Nuit, souvent Pleine lune en Lune de sang)
  et des éclats. Une défaite rapporte des éclats selon les duels gagnés. Le record de chaque nuit est gardé.
- **Pas de triche à la relance** : tout découle d'une graine tirée au départ. Revenir dans le jeu redonne les mêmes ombres et la même offre ;
  quitter en plein duel (pause, « Abandonner », ou jeu fermé) compte comme une défaite.

Pour la pente de chaque nuit (une IA « joueur » sur chaque nuit, avec chaque chevalier, nu puis équipé ; trois minutes environ) :

```bash
godot --headless --path . -s tools/hunt_report.gd
```

Les forces se règlent dans `DATA` de `src/domain/hunt_difficulty.gd` (paliers des ombres, bénédictions des ombres, butin),
les bénédictions dans `CATALOG` de `src/domain/blessing.gd`, blessures, larme et offres dans les constantes de `src/domain/hunt.gd`.

## Le Chemin des ombres et le butin

« Jouer » lance le duel du palier atteint. Chaque palier a toujours la même ombre (chevalier, équipement, vivacité),
pour qu'on puisse la retenter et l'apprendre ; tous les cinq paliers, un gardien plus fort (`shadow_path.gd`).

- **Victoire** : un reliquaire s'ouvre, une pièce pour ton chevalier (tirée dans `loot_table.gd` : Croissant 60 %,
  Quartier 28 %, Gibbeuse 10 %, Pleine lune 2 %), 4 éclats, et le palier suivant. Un gardien donne au moins une Gibbeuse ;
  dès le palier 20, les gardiens portent des Pleines lunes, avec leurs traits.
- **Défaite** : 3 éclats, on garde le palier, et l'écran montre ta puissance face à celle de l'ombre.
- **Pièce déjà possédée** (même modèle, même rang ou mieux) : changée en éclats.
- **Garanties** : une Gibbeuse au plus tard au dixième reliquaire (l'anneau autour de la lune se remplit),
  une Pleine lune au plus tard au quarantième.

Le hasard passe par un port (`random_source.gd`) : le téléphone aujourd'hui, le serveur demain, un hasard écrit d'avance dans les tests.

Le plan complet est dans le document « Sanglune, plan de l'équipement » du projet.

### Régler l'équilibrage

- Les frames, dégâts et portées de base, esquive, saut et plongeon compris : `src/domain/combat_action.gd`.
- Les ultimes (préparation, coups, portée, étourdissement, élan) : `CATALOG` dans `src/domain/ultimate.gd`.
- La hauteur et la durée du saut : `JUMP_VELOCITY` et `GRAVITY` dans `src/domain/fighter.gd`. La hauteur à partir de laquelle on passe par-dessus l'autre : `CROSS_HEIGHT` dans `src/domain/duel.gd`.
- Ce que chaque chevalier change à cette base (allonge, vitesse, puissance, vie, marche) : `ROSTER` dans `src/domain/knight_class.gd`.
- Les pièces d'équipement : `DEFINITIONS` dans `src/domain/item_catalog.gd`. Le budget des raretés et des niveaux : `rarity.gd` et `power_budget.gd`.
  Ce que vaut un point de budget pour chaque caractéristique : `PER_POINT` dans `src/domain/gear_stat.gd`.
- Pour vérifier qu'un réglage ne casse pas un chevalier, lance le rapport IA contre IA (une trentaine de secondes) :

```bash
godot --headless --path . -s tools/balance_report.gd
```

Il donne le taux de victoire de chaque paire. C'est un repère grossier, l'IA ne joue pas comme un humain : les playtests décident.

Pour l'équipement, deux rapports (deux et cinq minutes environ) :

```bash
godot --headless --path . -s tools/gear_report.gd          # chaque pièce, puis l'équipement complet au maximum
godot --headless --path . -s tools/gear_weights_report.gd  # ce que vaut +15 % de chaque caractéristique
```

L'IA profite mal de la marche, de l'esquive et de la force de l'ultime : les pièces qui misent dessus paraissent faibles
dans ces rapports et se jugent en jeu.

Pour la pente du Chemin des ombres (une IA « joueur » contre l'ombre de chaque palier, une minute et demie) :

```bash
godot --headless --path . -s tools/path_report.gd
```
Le niveau de l'IA se règle dans `AiBrain.new(graine, temps_de_reaction, precision)`, appelé dans `arena.gd`.

## Animation

Chaque chevalier est un pantin squelettal : un `Skeleton2D` dont les os (`Bone2D`) portent des pièces rigides en noir pur.
Les poses ne sont pas des images : ce sont des angles par os (`knight_pose.gd`), interpolés selon l'avancement de la phase en cours.
Le dessin suit donc exactement les frames du domaine : ce qui touche à l'écran est ce qui touche dans les règles.

- Préparation, coup, suite du geste et retour en garde pour la Frappe et pour chaque ultime ; parade, saut, plongeon, esquive, étourdissement.
- Marche calée sur la distance parcourue, respiration en garde, genou à terre pour le vaincu et arme levée pour le vainqueur de la manche.
- Liseré rouge : une copie rouge du squelette, décalée vers la lune et glissée derrière le corps.
- Couleur réservée au gameplay : l'œil, les trois runes du torse (la jauge), la lueur de l'arme qui se prépare et sa traînée.
- Impacts : le chevalier touché blanchit, des étincelles de la couleur de l'attaquant, l'écran tremble selon la force du coup.

Pour retoucher : les proportions, casques et armes sont dans `knight_build.gd`, les poses dans `knight_pose.gd`.
Pour la vertical slice, il suffira de remplacer les polygones par des pièces dessinées : les os et les poses restent.

## Architecture

Hexagonale, pour que les règles restent testables sans écran et prêtes pour le réseau.

- `src/domain` : les règles pures (actions, classes de chevaliers, chevalier en combat, duel, IA, équipement, profil du joueur). Aucune dépendance aux nœuds Godot.
  L'équipement : `item_catalog.gd` (les pièces), `owned_item.gd` (une pièce possédée), `loadout.gd` (ce que porte un chevalier),
  `fighter_stats.gd` (la classe ajustée par l'équipement, calculée une fois par duel, en entiers).
  Le Chemin et le butin : `shadow_path.gd` et `shadow_opponent.gd` (les ombres), `loot_table.gd`, `reliquary.gd` et `duel_reward.gd` (ce que rapporte un duel).
  La Chasse : `hunt.gd` (la partie, ses offres et sa sauvegarde), `hunt_difficulty.gd` (les trois nuits), `blessing.gd` (les bénédictions),
  `hunt_reward.gd` (une récompense), `hunt_end.gd` (le bilan), `boss.gd` (les seigneurs et leurs règles), `stat_bonus.gd` (ce qu'un duel ajoute à l'équipement : bénédictions et blessures).
- `src/ports` : les contrats. `intent_source.gd` fournit une intention par frame, `profile_store.gd` charge et sauvegarde le profil,
  `random_source.gd` fournit le hasard du butin (`rng_random_source.gd` sur le téléphone, `scripted_random_source.gd` dans les tests).
- `src/adapters` : le joueur (clavier et tactile), l'IA, les touches, la sauvegarde locale du profil. Plus tard, un adaptateur Nakama pour le PvP et la sauvegarde en ligne.
- `src/presentation` : l'affichage, rien d'autre. `game_flow.gd` enchaîne les écrans, `home_screen.gd` l'accueil, `knight_select.gd` et `knight_card.gd` l'écran Chevaliers, `armory_screen.gd`, `gear_piece_button.gd` et `gear_view.gd` l'armurerie, `wardrobe_screen.gd` la garde-robe, `reliquary_screen.gd` la fin de duel, `hunt_screen.gd` (nuits et chemin), `hunt_offer_screen.gd`, `hunt_reward_card.gd`, `hunt_night_card.gd`, `hunt_end_screen.gd`, `bestiary_screen.gd`, `bestiary_card.gd` et `hunt_view.gd` la Chasse, `arena.gd` le duel (avec `arena_stage.gd` pour le décor et `arena_hud.gd` pour ce qui se lit par-dessus), `knight_puppet.gd`, `knight_pose.gd` et `knight_build.gd` l'animation des chevaliers, `palette.gd` et `ui_style.gd` les couleurs et polices de la planche.
- `assets/fonts` : Grenze et Grenze Gotisch, sous licence SIL Open Font License (fichiers OFL à côté).
- `tests/unit` : un fichier de tests par feature.
- `tools` : les outils de développement, hors du jeu.

Le profil (chevalier actif, pièces possédées, équipement de chaque chevalier, éclats, palier, garanties, garde-robe, Chasse en cours et records) est sauvegardé en JSON dans le dossier privé
de l'appli, sur le téléphone uniquement. Aucune donnée personnelle n'est collectée. À la relecture, tout est revalidé :
une pièce inconnue, une rareté ou un niveau hors bornes, une pièce portée par le mauvais chevalier sont écartés.
Un profil de l'ancienne version garde son chevalier et reçoit les pièces offertes.

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
