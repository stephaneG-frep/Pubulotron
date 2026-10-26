# Installation de Pubulotron

## Prérequis

- Android : appareil ARM64 avec Android 8 ou plus.
- Linux : Ubuntu / Lubuntu 22.04+ ou distribution Debian compatible.
- SDK Flutter si vous souhaitez recompiler le projet.

## Android APK

1. Copier le fichier `Pubulotron-android-arm64.apk` depuis le dossier `dist/` vers le téléphone.
2. Ouvrir le fichier depuis le gestionnaire de fichiers.
3. Autoriser l'installation depuis une source inconnue.
4. Installer puis lancer Pubulotron.

## Linux (bundle binaire)

Le projet a été compilé en bundle Linux, mais un vrai paquet Debian (`.deb`) n'a pas pu être créé dans cet environnement car la commande de packaging système a été bloquée par des restrictions de permissions. Le binaire généré est disponible dans le dossier de build Flutter :

`build/linux/x64/release/bundle/pubulotron`

Pour créer un `.deb` sur une machine autorisée :

```bash
mkdir -p /tmp/pubulotron-deb/usr/bin
cp build/linux/x64/release/bundle/pubulotron /tmp/pubulotron-deb/usr/bin/pubulotron
chmod 755 /tmp/pubulotron-deb/usr/bin/pubulotron
mkdir -p /tmp/pubulotron-deb/DEBIAN
cat > /tmp/pubulotron-deb/DEBIAN/control <<'EOF'
Package: pubulotron
Version: 1.0.0
Section: graphics
Priority: optional
Architecture: amd64
Maintainer: Pubulotron <contact@pubulotron.local>
Description: Studio graphique intelligent pour cartes, flyers et visuels publicitaires.
EOF

dpkg-deb --build /tmp/pubulotron-deb ./Pubulotron-linux.deb
```

## Reconstruction depuis le code source

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release --target-platform android-arm64
flutter build linux --release
```
