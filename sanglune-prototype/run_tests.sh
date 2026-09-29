#!/usr/bin/env bash
# Lance tous les tests unitaires sans ouvrir l'éditeur.
# Variable GODOT : chemin du binaire (par défaut "godot"), par exemple
#   GODOT="flatpak run org.godotengine.Godot" ./run_tests.sh
set -euo pipefail
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")"
$GODOT --headless --path . --import
$GODOT --headless --path . -s addons/gut/gut_cmdln.gd
