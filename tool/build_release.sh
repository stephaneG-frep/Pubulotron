#!/bin/sh
# Chaîne de livraison complète de Pubulotron :
# contrôles qualité, compilations Linux et Android ARM64, paquet .deb,
# archive des sources, copie de la documentation dans dist/.
set -eu

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project_root"
dist="$project_root/dist"
mkdir -p "$dist"

step() { printf '\n=== %s ===\n' "$1"; }

step 'Dépendances'
flutter pub get

step 'Format'
dart format --output=none --set-exit-if-changed lib test

step 'Analyse statique'
flutter analyze

step 'Tests'
flutter test

step 'Compilation Linux (release)'
flutter build linux --release
sh tool/build_linux_deb.sh

step 'Compilation Android ARM64 (release)'
flutter build apk --release --target-platform android-arm64
cp build/app/outputs/flutter-apk/app-release.apk "$dist/Pubulotron-Android-arm64.apk"

step 'Archive des sources'
rm -f "$dist/Pubulotron-Source.zip"
# Fichiers suivis et nouveaux fichiers non ignorés, sans les binaires livrés.
git ls-files --cached --others --exclude-standard \
  | grep -v -E '^(dist/|Pubulotron\.zip$)' \
  | zip -q -@ "$dist/Pubulotron-Source.zip"

step 'Documentation'
cp README.md "$dist/README.md"
cp docs/INSTALLATION.md docs/GUIDE_UTILISATEUR.md docs/RAPPORT_TESTS.md "$dist/"

step 'Livrables'
ls -l "$dist"
sha256sum "$dist"/*.apk "$dist"/*.deb "$dist"/*.zip > "$dist/SHA256SUMS.txt"
cat "$dist/SHA256SUMS.txt"
