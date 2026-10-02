#!/usr/bin/env bash
# Installe un APK de Sanglune sur le téléphone branché, même si sa signature a changé, sans perdre la sauvegarde.
# Copie d'abord la sauvegarde du jeu installé, désinstalle, installe le nouvel APK, puis remet la sauvegarde.
# Ne marche qu'avec les versions de test (APK « debug ») : ce sont les seules dont on peut lire les fichiers.
#
#   bash tools/mettre-a-jour.sh                      # installe export/sanglune-0.10.0.apk
#   bash tools/mettre-a-jour.sh chemin/vers/un.apk
set -euo pipefail

PKG=fr.quentindurant.sanglune
EXPORT="$(cd "$(dirname "$0")/.." && pwd)/export"
APK="${1:-$EXPORT/sanglune-0.10.0.apk}"
mkdir -p "$EXPORT"
SAVE="$EXPORT/profil-sanglune-$(date +%Y%m%d-%H%M%S).json"

[ -f "$APK" ] || { echo "APK introuvable : $APK"; exit 1; }
adb get-state >/dev/null 2>&1 || { echo "Aucun téléphone branché (débogage USB activé ?)"; exit 1; }

if adb shell pm list packages | grep -qx "package:$PKG"; then
    if ! adb shell run-as "$PKG" ls files >/dev/null 2>&1; then
        echo "Impossible de lire la sauvegarde du jeu installé : rien n'est désinstallé."
        echo "Si tu acceptes de perdre ta progression : adb uninstall $PKG && adb install \"$APK\""
        exit 1
    fi
    if adb shell run-as "$PKG" ls files/profile.json >/dev/null 2>&1; then
        adb exec-out run-as "$PKG" cat files/profile.json > "$SAVE"
        echo "Sauvegarde copiée : $SAVE"
    fi
    adb install -r "$APK" 2>/dev/null && { echo "Mis à jour par-dessus, la sauvegarde n'a pas bougé."; exit 0; }
    adb uninstall "$PKG" >/dev/null
fi

adb install "$APK"
if [ -s "$SAVE" ]; then
    adb shell monkey -p "$PKG" 1 >/dev/null 2>&1 || true
    sleep 4
    adb shell am force-stop "$PKG"
    adb exec-in run-as "$PKG" sh -c 'mkdir -p files && cat > files/profile.json' < "$SAVE"
    echo "Sauvegarde remise en place. Tu peux lancer Sanglune."
fi
