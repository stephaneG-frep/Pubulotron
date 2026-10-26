# Rapport des tests réalisés

## Vérifications exécutées

- `dart format lib/main.dart lib/services/pdf_service.dart test/pdf_service_test.dart` : OK
- `flutter analyze` : aucune erreur ni avertissement
- `flutter test` : tous les tests passent
- `flutter build apk --release --target-platform android-arm64` : OK
- `flutter build linux --release` : OK
- Création de `Pubulotron-linux-amd64.deb` avec `tool/build_linux_deb.sh` : OK
- Inspection du paquet avec `dpkg-deb --info` et `dpkg-deb --contents` : OK
- Extraction de contrôle du `.deb`, vérification des exécutables et des bibliothèques dynamiques : OK
- Installation et lancement sur le HONOR MTN-NX1M (Android 16, ARM64) : OK; processus actif au premier plan.
- Tests des modèles : les quatre compositions sont distinctes et les textes métier sont personnalisés : OK.
- Tests IA : les quatre variantes (Futuriste, Premium, Digital et Pop) donnent des calques distincts; les coordonnées métier et le corps de texte sont conservés : OK.
- Test d'interface : ouverture d'un concept IA dans l'atelier avec son propre titre et ses calques : OK.
- APK et bundle Linux reconstruits après la correction du parcours IA : OK.
- APK corrigé réinstallé et relancé sur le HONOR MTN-NX1M : OK.
- Paramètres IA : implémentation du chargement et de la sauvegarde sécurisés de la clé et du fournisseur; le champ de clé est prérempli et masqué.
- Test de connexion : requête non générative vers les modèles de chacun des quatre fournisseurs; tests simulés des URL, méthodes, en-têtes, clé manquante et réponse HTTP 401 : OK.
- Test d'interface : présence des actions "Sauvegarder les paramètres" et "Tester la connexion" : OK.
- Vérification finale de cette correction : `flutter analyze` sans problème, `flutter test` réussi, APK ARM64 et paquet Debian amd64 reconstruits : OK.
- APK de cette correction installée et lancée sur le HONOR MTN-NX1M; processus actif : OK.
- Diagnostic de l'échec DNS sur Android : la permission INTERNET n'était déclarée que pour debug/profile, pas dans le manifeste release. Permission ajoutée au manifeste principal; erreurs réseau affichées sans révéler l'URL ni la clé API : OK.

## Tests du moteur PDF

- Calcul multipose A4 : marges, espacement, fond perdu, colonnes, rangées et nombre de feuilles.
- Orientation paysage : dimensions de page correctement orientées.
- Rejet des cartes qui ne tiennent pas sur le papier.
- Rejet de traits de coupe qui sortiraient de la feuille.
- Génération d'un PDF contenant les calques texte et forme, avec police embarquée et accents français.

## Limites vérifiées

- La compilation Linux et l'assemblage du paquet Debian ont réussi, mais l'application graphique Linux n'a pas été testée sur une session de bureau.
- L'impression recto verso avec des calques distincts au verso n'est pas encore implémentée.
- Le texte et les formes du PDF restent vectoriels; les photos importées sont intégrées comme images raster.
