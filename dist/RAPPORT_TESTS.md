# Rapport des tests réalisés

## Démonstration de validité

- Analyse Flutter : OK
- Tests automatiques : OK
- Build Android ARM64 : OK
- Build Linux bundle : OK

## Commandes exécutées

```bash
flutter analyze
flutter test --reporter expanded
flutter build apk --release --target-platform android-arm64
flutter build linux --release
```

## Résultats

- L'application charge correctement.
- Le widget test de démarrage passe.
- Le projet peut être compilé en APK ARM64.
- La version Linux est bien construite en bundle.

## Limite de ce lot de livrables

Le paquet Debian `.deb` n'a pas pu être généré dans cet environnement en raison d'une restriction système de création de paquets installés. Cette étape est documentée dans `INSTALLATION.md` et peut être exécutée sur une machine Linux autorisée avec les droits suffisants.

## Conclusion

La base applicative est fonctionnelle, testée et compilable. Les livrables opérationnels de cette session sont l'APK ARM64, le ZIP source et les documents d'installation / mode d'emploi / rapport de tests.
