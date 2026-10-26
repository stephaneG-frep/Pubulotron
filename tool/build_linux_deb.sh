#!/bin/sh
# Construit le paquet Debian/Ubuntu de Pubulotron à partir du bundle Linux.
# Prérequis : flutter build linux --release
set -eu

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
bundle="$project_root/build/linux/x64/release/bundle"
staging="$project_root/build/deb-stage"
version=$(sed -n 's/^version: \([0-9.]*\).*/\1/p' "$project_root/pubspec.yaml")
output="$project_root/dist/Pubulotron-Linux-amd64.deb"

if [ ! -x "$bundle/pubulotron" ]; then
  printf '%s\n' 'Bundle Linux introuvable. Lancez : flutter build linux --release' >&2
  exit 1
fi

rm -rf "$staging"
install -d "$staging/DEBIAN" "$staging/usr/bin" "$staging/usr/lib/pubulotron" \
  "$staging/usr/share/applications" \
  "$staging/usr/share/icons/hicolor/256x256/apps" \
  "$staging/usr/share/icons/hicolor/512x512/apps" \
  "$staging/usr/share/doc/pubulotron"
cp -a "$bundle/." "$staging/usr/lib/pubulotron/"
install -m 755 "$project_root/packaging/linux/pubulotron" "$staging/usr/bin/pubulotron"
install -m 644 "$project_root/packaging/linux/pubulotron.desktop" \
  "$staging/usr/share/applications/pubulotron.desktop"
install -m 644 "$project_root/packaging/icons/pubulotron-256.png" \
  "$staging/usr/share/icons/hicolor/256x256/apps/pubulotron.png"
install -m 644 "$project_root/packaging/icons/pubulotron-512.png" \
  "$staging/usr/share/icons/hicolor/512x512/apps/pubulotron.png"
install -m 644 "$project_root/assets/fonts/LICENSE-DejaVu.txt" \
  "$project_root/assets/fonts/LICENSE-Liberation.txt" \
  "$project_root/assets/fonts/LICENSE-Ubuntu.txt" \
  "$staging/usr/share/doc/pubulotron/"
chmod 755 "$staging/usr/lib/pubulotron/pubulotron"

installed_size=$(du -sk "$staging/usr" | cut -f1)
sed -e "s/^Version: .*/Version: $version/" \
  -e "s/^Installed-Size: .*/Installed-Size: $installed_size/" \
  "$project_root/packaging/linux/control" > "$staging/DEBIAN/control"
install -m 755 "$project_root/packaging/linux/postinst" "$staging/DEBIAN/postinst"
install -m 755 "$project_root/packaging/linux/postinst" "$staging/DEBIAN/postrm"

mkdir -p "$project_root/dist"
dpkg-deb --build --root-owner-group "$staging" "$output"
printf 'Paquet créé : %s\n' "$output"
