class_name Palette
extends RefCounted
## Couleurs de la planche Sanglune. Le décor reste désaturé ; la couleur vive est réservée au gameplay.

# Décor, toujours désaturé.
const NIGHT := Color("#140C22")
const DUSK := Color("#2D1A3E") ## valeur moyenne : le fond derrière les combattants, lisible en plein jour
const PURPLE := Color("#4E2440")
const DULL_BLOOD := Color("#6E2A38")
const NEAREST_SET := Color("#1D1027") ## le décor le plus proche ne descend jamais plus sombre

# Lumière de lune.
const MOON := Color("#E5343B")
const RIM := Color("#FF4B3E")
const EMBER := Color("#FF8A3D")

# Combattants et runes : toi en froid, l'adversaire en rouge, quel que soit le skin.
const SILHOUETTE := Color("#000000") ## le noir pur est réservé aux combattants
const SILVER := Color("#D6DEE8")
const CYAN := Color("#6FE7FF")
const FOE_RED := Color("#FF3B30")
const VENOM := Color("#B46CFF") ## le venin d'un seigneur : un violet vif, réservé au gameplay

# Interface.
const INK := Color("#F3E9EC")
const QUIET := Color("#BFB0C9")
const GAIN := SILVER ## ce qu'une pièce renforce
const LOSS := Color("#E8828B") ## ce qu'elle affaiblit : un rouge sourd, lisible sur le fond
