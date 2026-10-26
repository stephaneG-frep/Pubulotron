#!/bin/sh
set -eu

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
bundle="$project_root/build/linux/x64/release/bundle"
staging="$project_root/build/deb-stage"

if [ ! -x "$bundle/pubulotron" ]; then
  printf '%s\n' 'Linux release bundle not found. Run: flutter build linux --release' >&2
  exit 1
fi

install -d "$staging/DEBIAN" "$staging/usr/bin" "$staging/usr/lib/pubulotron" \
  "$staging/usr/share/applications"
cp -a "$bundle/." "$staging/usr/lib/pubulotron/"
install -m 644 "$project_root/packaging/linux/control" "$staging/DEBIAN/control"
install -m 755 "$project_root/packaging/linux/pubulotron" "$staging/usr/bin/pubulotron"
install -m 644 "$project_root/packaging/linux/pubulotron.desktop" \
  "$staging/usr/share/applications/pubulotron.desktop"
chmod 755 "$staging/usr/lib/pubulotron/pubulotron"

dpkg-deb --build --root-owner-group "$staging" \
  "$project_root/dist/Pubulotron-linux-amd64.deb"
