# Installation de Pubulotron

## Android ARM64

1. Transférer `Pubulotron-android-arm64.apk` sur le téléphone.
2. Ouvrir le fichier et autoriser l'installation depuis cette source si Android le demande.
3. Installer puis lancer Pubulotron.

## Linux amd64

Le paquet Debian installe le bundle Flutter complet, son lanceur et un raccourci d'application. Il nécessite Ubuntu ou une distribution Debian compatible sur architecture amd64, avec GTK 3 et libsecret disponibles.

```bash
sudo apt install ./Pubulotron-linux-amd64.deb
```

L'application est ensuite accessible depuis le menu graphique ou en lançant `pubulotron` dans un terminal.

Le bundle Linux non empaqueté est également produit par `flutter build linux --release` dans `build/linux/x64/release/bundle/`.

## Compilation depuis les sources

Prérequis : Flutter installé, SDK Android pour l'APK et les dépendances de compilation Flutter Linux pour le bundle desktop.

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release --target-platform android-arm64
flutter build linux --release
bash tool/build_linux_deb.sh
```

Le paquet `.deb` de cette livraison cible `amd64`; il ne convient pas aux systèmes Linux ARM64.
