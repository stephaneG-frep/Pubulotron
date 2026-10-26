#!/bin/sh
# Compare le rendu de l'aperçu (PNG Flutter) et celui du PDF vectoriel
# (tramé par Poppler à la même résolution). Requiert pdftoppm et ImageMagick.
set -eu

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
out=${1:-"$project_root/build/fidelity"}
mkdir -p "$out"

cd "$project_root"
FIDELITY_OUT="$out" flutter test test/render_fidelity_test.dart test/pdf_export_test.dart

pdftoppm -r 254 -f 1 -l 1 -png "$out/export.pdf" "$out/pdf"
pdf_png=$(ls "$out"/pdf-*1.png | head -n 1)
# Pixels qui diffèrent de plus de 25 % (au-delà de l'anticrénelage).
diff=$(compare -metric AE -fuzz 25% "$out/flutter.png" "$pdf_png" "$out/diff.png" 2>&1 || true)
total=$(identify -format '%[fx:w*h]' "$out/flutter.png")
printf 'Pixels différents : %s sur %s\n' "$diff" "$total"
convert "$out/flutter.png" "$pdf_png" +append "$out/comparaison.png"
printf 'Comparaison visuelle : %s\n' "$out/comparaison.png"
