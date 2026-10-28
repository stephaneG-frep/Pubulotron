# Pubulotron

**La machine à fabriquer des pubs qui ont du génie !**

Pubulotron est un studio publicitaire assisté par intelligence artificielle, développé en Flutter pour **Android (ARM64)** et **Linux (Ubuntu, Lubuntu)**. Il crée cartes de visite, flyers, affiches, dépliants, cartes de fidélité, bons de réduction, menus, étiquettes, invitations et publications pour les réseaux sociaux, puis les exporte en PDF vectoriel, PNG, JPEG ou ZIP, et imprime plusieurs exemplaires par feuille.

## Fonctionnalités

| Rubrique | Contenu |
|---|---|
| Nouvelle création | 19 formats prédéfinis (cartes, flyers A6 à A2, dépliant, menus, étiquettes, formats réseaux sociaux) et format personnalisé. |
| Création avec l'IA | OpenAI, Anthropic Claude, Google Gemini ou Mistral : 4 designs **structurés et entièrement éditables**, validés avant affichage. Générateur hors ligne clairement identifié. |
| Atelier graphique | Textes, photos, logos, formes, pictogrammes, QR codes ; déplacement, redimensionnement, rotation, couleurs, dégradés linéaires ou radiaux, opacité, calques, duplication, verrouillage, alignement, répartition, guides magnétiques, grille, zoom, annuler/rétablir, recto verso, raccourcis clavier, agent IA conversationnel. |
| Bibliothèque de modèles | 22 modèles dans 10 métiers, instanciés avec la fiche professionnelle ; page blanche ; modèles personnels. |
| Mes projets | Sauvegarde automatique SQLite, recherche, renommage, duplication, suppression, sauvegarde et restauration ZIP. |
| Pack publicitaire | Carte, flyer A5, affiche A3, publication et story partageant couleurs, typographies et informations (identité proposée par l'IA ou construite hors ligne). |
| Imprimerie PDF | A4, A3, A5, Lettre US ou papier personnalisé ; orientation automatique ; exemplaires ; marges ; espacement ; fond perdu ; traits de coupe ; recto verso (bord long ou court) ; aperçu de chaque feuille ; PDF vectoriel ; impression système. |
| Mon activité | Plusieurs fiches : logo, slogan, prestations, coordonnées, horaires, réseaux sociaux, couleurs de marque, liens pour QR codes. |
| Paramètres IA | Fournisseur, clé dans le trousseau du système, modèle, test de connexion avec liste des modèles, thème clair/sombre, sauvegarde automatique, résolution par défaut. |
| Mode d'emploi | Neuf guides illustrés d'exemples, tableau des fonctions hors ligne, raccourcis clavier. |
| Générateur de QR codes | Site, réservation, vCard, portfolio, catalogue, réseau social, texte ; insertion, étiquette, export PNG / SVG / PDF. |

Fonctionnent **hors ligne** : création, modèles, modification, sauvegarde, QR codes, exports, impression, pack hors ligne. Seules les fonctions d'IA demandent Internet et une clé API.

## Nouveautés de la version 2.1

| Fonction | Résumé |
|---|---|
| Studio de variantes | 2 à 5 designs réellement différents pour un même format (une direction artistique par variante, génération successive avec progression, contrôle local de similarité), galerie, régénération, duplication, modèle, comparateur de 2 à 5 propositions. |
| Synchronisation des formats | Une modification (coordonnées, slogan, QR code, logo, couleurs) peut être répercutée sur les déclinaisons et variantes liées : choix des créations, aperçu avant/après, confirmation, point de restauration. Correspondance par contenu et rôle sémantique, mise en page conservée. |
| Historique intelligent | Versions persistantes de chaque création (description automatique, aperçu, comparaison, restauration sans perte, duplication, suppression, rétention configurable), incluses dans les sauvegardes. |
| Améliore mon design | Conseils (analyse locale WCAG / tailles / marges / QR, plus IA avec image du rendu si le modèle la lit) et amélioration automatique protégée par des garde-fous, comparée avant/après. |
| Surprends-moi ! | Directions artistiques proposées par l'IA à partir d'une phrase, puis création des variantes choisies. |

Détails : [docs/NOUVEAUTES_2.1.md](docs/NOUVEAUTES_2.1.md).

## Audit de la version précédente et corrections

| Problème constaté | Correction |
|---|---|
| `_generateConcepts()` renvoyait des propositions figées quand l'IA échouait (erreur masquée), et le modèle Claude appelé (`claude-3-5-sonnet-20241022`) a été retiré le 28 octobre 2025. | Vrai client multi-fournisseurs (`lib/ai/`), sortie JSON structurée (schéma natif chez Anthropic, mode JSON chez OpenAI/Mistral/Gemini), validation stricte, erreurs typées affichées. Modèle Claude par défaut : `claude-opus-5-5`. Le générateur hors ligne n'est utilisé que sur demande explicite et porte la mention « sans IA ». |
| `_exportPdf()` ne reproduisait pas la création (coordonnées incohérentes, texte forcé en blanc, ratio 320 × 360 déformé). | Modèle de document en millimètres et un **moteur de rendu unique** (`lib/engine/page_renderer.dart`) avec deux sorties : canevas Flutter (aperçu, PNG, JPEG) et PDF vectoriel. Fidélité vérifiée pixel à pixel (`tool/check_fidelity.sh`). |
| Éditeur incomplet. | Atelier complet (`lib/editor/`, `lib/ui/editor/`). |
| Pas de vraie sauvegarde / restauration. | SQLite versionné avec migration de l'ancien schéma et des anciens projets, médiathèque locale, sauvegarde automatique, archives ZIP complètes ou par projet. |
| Pas d'imposition multipose. | Moteur d'imposition testé (`lib/print/imposition.dart`) et rendu des feuilles commun à l'aperçu et au PDF. |
| QR codes et import d'images à développer (la restauration ouvrait la galerie d'images au lieu d'un ZIP). | Générateur QR (bibliothèque `barcode`, identique à l'écran et dans le PDF), import d'images et de logos via le sélecteur du système. |
| 2 345 lignes dans `lib/main.dart`. | Architecture modulaire ; `main.dart` ne fait plus que démarrer l'application. |

## Architecture

```
lib/
  main.dart                 Démarrage : ouverture de la base, ProviderScope
  app/                      Services, fournisseurs Riverpod, état de création
  core/                     Unités (mm, pt, ppp), couleurs, identifiants
  models/                   Modèles sérialisables : document, élément, remplissage,
                            projet, fiche professionnelle, formats, réglages
  engine/                   Moteur graphique : polices, pictogrammes, géométrie,
                            tracés, mise en page du texte, QR, rendu de page,
                            canevas Flutter et canevas PDF
  editor/                   Contrôleur de l'atelier (historique, gestes,
                            calques, alignement), fabrique d'éléments
  layout/                   Moteur de composition : styles, modèles, pack
  ai/                       Client HTTP des fournisseurs, schémas JSON,
                            validation, génération et modification de designs
  print/                    Imposition multipose, rendu des feuilles, PDF
  export/                   Export PNG/JPEG, fichiers (enregistrer, partager)
  data/                     SQLite, dépôts, médiathèque, sauvegarde ZIP,
                            trousseau des clés, conversion des anciens projets
  variants/                 Directions artistiques, génération de variantes, similarité
  sync/                     Détection et application des modifications entre créations liées
  history/                  Versions persistantes, politique de rétention, résumé des changements
  review/                   Analyse locale, conseils IA, amélioration protégée
  ui/                       Thème, coquille, rubriques, atelier, widgets
```

### Décisions techniques

- **Unités physiques.** Les documents sont en millimètres et les polices en points : aucune dépendance à la taille de l'écran. Les formats « écran » (réseaux sociaux) valent 10 px par mm et s'exportent à 254 ppp pour obtenir la taille exacte en pixels.
- **Un seul code de dessin.** `PageRenderer` dessine sur une interface `DesignCanvas`, implémentée par `FlutterDesignCanvas` et par `PdfDesignCanvas`. Formes, dégradés (shading PDF natif), texte et QR codes restent vectoriels.
- **Texte identique à l'écran et dans le PDF.** La mise en page est calculée une seule fois par le moteur de texte de Flutter (crénage et ligatures désactivés) ; le PDF place chaque ligne sur la ligne de base calculée, avec les mêmes fichiers TTF embarqués (Liberation, Ubuntu, DejaVu).
- **Documents immuables.** Chaque modification produit un nouveau document : historique d'annulation fiable, une seule étape par geste ou par réponse de l'IA.
- **IA structurée.** L'IA renvoie des éléments (type, position en mm, police, couleur…) ou des opérations (`update`, `add`, `delete`, `reorder`, `background`). Tout est validé et normalisé (`ElementSanitizer`) : types inconnus ignorés, valeurs bornées, polices et pictogrammes ramenés au catalogue, éléments verrouillés protégés, avertissements remontés à l'utilisateur.
- **État.** Riverpod 3 pour l'application ; `ChangeNotifier` immuable-par-copie pour l'atelier (mises à jour à haute fréquence pendant les gestes).
- **Historique.** Table `versions` (schéma 4, migration automatique depuis la 2.0) : instantanés complets des documents ; les modifications rapprochées sont fusionnées, les opérations notables (IA, synchronisation, restauration) forcent une nouvelle version.
- **Persistance.** SQLite (sqflite sur Android, sqflite FFI sous Linux). Base dans le dossier de l'application ; une base de la première version trouvée dans `Documents` est copiée (sans être supprimée) puis migrée.
- **Secrets.** Clés API dans le Keystore Android ou libsecret (GNOME Keyring / KWallet), jamais dans la base ni dans les sauvegardes.

## Développement

```sh
flutter pub get
flutter analyze
flutter test                      # 119 tests (+ 2 captures facultatives)
sh tool/check_fidelity.sh         # comparaison aperçu / PDF (pdftoppm + ImageMagick)
SCREENSHOTS_OUT=build/shots flutter test test/visual_tour_test.dart   # captures de chaque écran
sh tool/build_release.sh          # contrôles + APK + .deb + archive source dans dist/
```

## Limites connues

- **Pictogrammes dans le PDF** : la police d'icônes Material fournie par Flutter est au format CFF, que le moteur PDF ne sait pas incorporer. Les pictogrammes y sont donc tramés à 512 × 512 px (plus de 1 000 ppp pour un pictogramme de 10 mm). Tout le reste est vectoriel.
- **Caractères hors police** (émojis, symboles rares) : l'écran utilise les polices de secours du système, le PDF affiche un glyphe vide.
- **Signature Android** : l'APK release est signé avec la clé de débogage locale (installation directe). Une publication sur le Play Store demande une clé de publication dédiée (`android/key.properties`).
- **Identifiant d'application** : `com.example.pubulotron`, conservé pour ne pas perdre les données des installations existantes ; à changer avant toute publication.
- **Fonctions IA** : vérifiées avec des réponses simulées des quatre fournisseurs (format des requêtes, erreurs, validation), mais pas contre les vrais serveurs : aucune clé API n'était disponible pendant le développement.
