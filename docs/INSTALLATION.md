# Installation de Pubulotron 2.1

## Android (téléphones et tablettes ARM64)

Fichier : `Pubulotron-Android-arm64.apk`

1. Copiez l'APK sur l'appareil (câble USB, e-mail, cloud…).
2. Ouvrez-le depuis le gestionnaire de fichiers.
3. Si Android le demande, autorisez l'installation d'applications depuis cette source (*Paramètres › Sécurité › Sources inconnues*, ou l'autorisation proposée par le gestionnaire de fichiers).
4. Lancez **Pubulotron** depuis l'écran d'accueil.

Configuration requise : Android 7.0 ou plus récent, processeur 64 bits (ARM64, soit la quasi-totalité des appareils depuis 2017).

Mise à jour : installez simplement le nouvel APK par-dessus l'ancien ; vos projets sont conservés.

Avec ADB :

```sh
adb install -r Pubulotron-Android-arm64.apk
```

## Linux (Ubuntu, Lubuntu, Debian et dérivées, 64 bits)

Fichier : `Pubulotron-Linux-amd64.deb`

```sh
sudo apt install ./Pubulotron-Linux-amd64.deb
```

`apt` installe automatiquement les dépendances (GTK 3, libsecret). Pubulotron apparaît ensuite dans le menu *Graphisme*, ou se lance avec la commande `pubulotron`.

Dépendances recommandées, installées par défaut sur Ubuntu et Lubuntu :

- **xdg-desktop-portal** avec une implémentation (`-gtk`, `-kde` ou `-lxqt`) : fenêtres « Ouvrir » et « Enregistrer sous ». En leur absence, les exports sont enregistrés dans `~/Documents/Pubulotron`.
- **gnome-keyring** ou **KWallet** : stockage sécurisé des clés API. Sans trousseau actif, l'application fonctionne mais ne peut pas mémoriser de clé.

Désinstallation :

```sh
sudo apt remove pubulotron
```

Vos données restent dans `~/.local/share/com.example.pubulotron/` (base `pubulotron.db` et dossier `media`). Supprimez ce dossier pour tout effacer.

## Première utilisation

1. **Mon activité** : créez votre fiche (nom, coordonnées, logo, couleurs). Elle alimente automatiquement les modèles, l'IA, les QR codes et les packs.
2. **Paramètres IA** (facultatif) : choisissez un fournisseur (OpenAI, Anthropic Claude, Google Gemini ou Mistral), collez votre clé API, puis « Tester la connexion ».
3. **Nouvelle création** : choisissez un format et commencez.

Sans clé API, toutes les fonctions sauf l'IA restent disponibles, y compris hors ligne.

## Mise à jour depuis la version 1

Les projets de la première version sont repris automatiquement. Sous Linux, l'ancienne base (`~/Documents/pubulotron_projects.db`) est copiée dans le nouveau dossier de l'application, sans être supprimée. Les anciens projets sont convertis au format en millimètres, à la dimension d'une carte de visite (85 × 55 mm).

## Mise à jour depuis la version 2.0

Installez simplement la nouvelle version par-dessus (APK ou `.deb`) : projets, fiches, modèles, réglages et clés API sont conservés. La base de données reçoit automatiquement la table d'historique ; la première ouverture d'une création dans l'atelier enregistre son état comme « Version d'origine ».

## Vérifier l'intégrité des fichiers

```sh
sha256sum -c SHA256SUMS.txt
```
