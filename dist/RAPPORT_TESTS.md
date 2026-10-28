# Rapport de tests — Pubulotron 2.1.0

Date : 27 octobre 2026 (version 2.1.0) · Flutter 3.47.2 · Dart 3.13.2 · Ubuntu 22.04 (Lubuntu), x86-64.

Tous les résultats ci-dessous proviennent d'exécutions réelles. Rien n'est extrapolé.

## Synthèse

| Contrôle | Commande | Résultat |
|---|---|---|
| Dépendances | `flutter pub get` | OK |
| Format | `dart format --set-exit-if-changed lib test` | OK |
| Analyse statique | `flutter analyze` | **0 problème** |
| Tests automatisés | `flutter test` | **119 réussis, 0 échec**, 2 ignorés volontairement (captures d'écran, activées par `SCREENSHOTS_OUT`) |
| Fidélité aperçu / PDF | `sh tool/check_fidelity.sh` | 1,27 % des pixels diffèrent de plus de 25 % (contours anticrénelés et tramage des dégradés), aucun décalage géométrique |
| Compilation Linux | `flutter build linux --release` | OK, application lancée et affichée sous X11 |
| Compilation Android ARM64 | `flutter build apk --release --target-platform android-arm64` | OK (voir la section Livrables) |

## Version 2.1 : tests des nouvelles fonctions

Fichiers `studio_v21_test.dart` (22 tests de services) et `app_v21_test.dart` (6 tests d'interface sur l'application complète).

| Exigence | Tests |
|---|---|
| 1. Génération de plusieurs variantes | 5 variantes Claude simulées, chacune enregistrée à sa production, numérotation, style, progression ; variantes hors ligne de compositions distinctes (similarité < 0,86) ; détection des compositions trop proches ; lecture des directions IA ; galerie complète dans l'interface (génération, deuxième série, comparaison, duplication). |
| 2. Conservation des créations précédentes | Une deuxième série dans le même groupe continue la numérotation (3, 4) sans modifier les variantes existantes en base. |
| 3. Modification indépendante d'une variante | Modifier une variante en base laisse les autres intactes. |
| 4. Synchronisation des coordonnées | Changement du téléphone sur la carte d'un pack de 5 formats : les 4 autres sont mis à jour, sans qu'aucun élément ne bouge ni ne change de taille ; segment d'une ligne de coordonnées, QR code, logo et couleur ; parcours complet dans l'interface (bandeau, confirmation, application). |
| 5. Synchronisation sélective | Seule la création choisie change ; point de restauration puis version « Synchronisation » dans son historique ; « Uniquement cette création » ne touche à rien dans l'interface. |
| 6. Restauration d'une version | Restaurer la version 2 crée la version 6 ; la version 5 reste disponible ; restauration depuis le panneau d'historique. |
| 7. Conservation des médias | Une ancienne version garde la référence et le fichier de son logo ; sauvegarde ZIP puis restauration : 2 versions et l'image retrouvées. |
| 8. Amélioration IA sans écrasement | Document original inchangé ; téléphone et contenu du QR rétablis malgré l'IA ; élément supprimé sans autorisation rétabli ; changements de style autorisés appliqués ; mode Conseils sans aucune modification dans l'interface. |
| 9. Gestion des erreurs réseau | Coupure réseau pendant une série : les variantes produites sont conservées et l'échec est signalé ; clé refusée : arrêt immédiat ; erreur réseau pendant l'amélioration : erreur typée, rien n'est modifié ; modèle refusant les images : nouvelle tentative sans image, limite expliquée. |
| 10. Sauvegarde et réouverture | Variante et historique relus après fermeture et réouverture de la base ; base de la version 2.0 (schéma 3) migrée vers le schéma 4. |

Autres tests ajoutés : politique de l'historique (fusion des retouches rapprochées, versions forcées, rétention gardant la version initiale), résumé des changements en français, analyse locale (contraste WCAG, taille, marge, QR), envoi de l'image du rendu à l'IA.

**Non-régression** : les 91 tests de la version 2.0 passent toujours. Ils couvrent l'éditeur, les gestes et calques, les QR codes, la sauvegarde, la génération IA, l'export PDF et l'impression multipose (100 cartes, 26 pages recto verso). Un seul test a été adapté, pour faire défiler le mode d'emploi devenu plus long ; l'application, elle, n'avait pas régressé.

**Défauts trouvés par les tests de la 2.1 et corrigés** :
1. Le bandeau de synchronisation figeait sa référence au premier accès, donc après la modification : aucune modification n'était jamais proposée.
2. Un mot de trois lettres (« bad », « fab ») renvoyé par l'IA était lu comme une couleur `#RGB`.
3. La mesure de similarité ignorait les grands aplats de couleur.
4. La barre d'outils de l'atelier débordait sur ordinateur (68 px) et sur téléphone (8 px) après l'ajout des nouveaux boutons.
5. Les créations antérieures à la 2.1 n'avaient pas de version d'origine dans l'historique.

## Détail par fichier (socle 2.0)

| Fichier | Tests | Ce qui est vérifié |
|---|---|---|
| `models_test.dart` | 8 | Sérialisation JSON complète (document, éléments, remplissages, projet, fiche, réglages), valeurs invalides ramenées à des valeurs sûres, redimensionnement proportionnel, **conversion des projets de la version 1**. |
| `geometry_test.dart` | 16 | Redimensionnement par poignées (y compris sur un élément tourné, proportions, taille minimale), rotation aimantée, magnétisme (centre, bords, grille), alignement et répartition, fond perdu, tracés vectoriels, cadrage d'image, **QR codes** (contenus des 7 types, vCard échappée, matrice déterministe, SVG). |
| `imposition_test.dart` | 10 | **Calcul des dispositions** : 100 cartes sur A4 (2 × 5, 10 feuilles), orientation automatique, paysage, fond perdu et espacement, centrage, traits de coupe hors des créations, marge insuffisante, **recto verso** (miroir bord long et bord court, portrait et paysage), papier personnalisé, erreurs de saisie. Chaque test vérifie que les cartes ne sont ni déformées, ni superposées, ni hors de la feuille. |
| `pdf_export_test.dart` | 3 | **Export multipose** : 100 cartes recto verso donnent 26 pages A4 (595,28 × 841,89 pt) ; PDF au format exact (85 × 55 mm) et avec fond perdu (91 × 61 mm) ; pack de plusieurs créations ; image manquante signalée sans plantage. |
| `render_fidelity_test.dart` | 1 | PNG à la taille physique exacte (85 × 55 mm à 254 ppp = 850 × 550 px), JPEG, PDF de 2 pages ; fichiers écrits pour la comparaison pixel à pixel. |
| `export_test.dart` | 4 | **ZIP de plusieurs créations** (un PDF et un PNG par face, noms uniques, publication réseaux sociaux en 1080 × 1080 px exactement), noms de fichiers sûrs, saisie de texte regroupée en une seule étape d'annulation, fabrique d'éléments adaptée au format. |
| `editor_controller_test.dart` | 9 | **Modification d'un élément** puis annuler/rétablir, glisser-déposer en une seule étape avec aimantation, éléments verrouillés protégés, duplication, copier-coller, ordre des calques, poignées de redimensionnement et de rotation, alignement, dégradé de fond, **recto verso**, sauvegarde automatique, erreurs de sauvegarde remontées. |
| `persistence_test.dart` | 7 | **Création, sauvegarde et réouverture d'un projet** après fermeture de la base, duplication, renommage, suppression, plusieurs fiches, modèles personnels, réglages, **migration d'une base de la version 1**, **sauvegarde et restauration ZIP** (projets, fiches, modèles, réglages, images ; réimport sans doublon), archive d'un projet, archives invalides refusées, protection contre les chemins malveillants dans une archive. |
| `ai_test.dart` | 20 | **Gestion des erreurs IA** : validation des designs (types inconnus, textes vides, polices et pictogrammes hors catalogue, QR sans contenu, géométrie aberrante), JSON entouré de texte ou de balises Markdown, réponses inexploitables, opérations de modification (mise à jour, ajout, suppression, réordonnancement, fond, élément verrouillé, image conservée), réponses de conseil ; format exact des requêtes **OpenAI, Anthropic, Gemini, Mistral** ; clé absente, 401, 404, 429, 400, réseau, réponse illisible ; nouvelle tentative sur erreur serveur ; refus et troncature ; reprise sans option refusée par Anthropic ; liste des modèles ; génération complète avec nouvel essai après une réponse invalide ; identité graphique du pack. |
| `templates_test.dart` | 3 | 22 modèles dans les 10 catégories : aucun texte ne déborde de son cadre ni ne sort de la page ; **pack** de 5 supports partageant typographies et identité ; styles et palettes déduits du brief. |
| `app_test.dart` | 9 | Interface complète sur base SQLite temporaire : tableau de bord et navigation, **création → modification → sauvegarde → fermeture → réouverture**, modèle de la bibliothèque, paramètres IA (clé dans le trousseau), **création IA de bout en bout** avec un fournisseur simulé, erreur sans clé et générateur hors ligne, imprimerie, fiches professionnelles, mise en page téléphone. |
| `visual_tour_test.dart` | 2 (ignorés) | Captures de chaque rubrique (ordinateur et téléphone) et génération de l'icône de l'application, avec les vraies polices. Exécutés manuellement : aucune erreur de mise en page. |

## Contrôles visuels effectués

- **Aperçu contre PDF** : la même carte (dégradés linéaire et radial, étoile tournée, textes en Ubuntu gras, Liberation Serif italique et texte tourné, QR code, pictogramme, photo) rendue par Flutter et par Poppler à partir du PDF est superposable. Les écarts relevés sont des pixels de contour.
- **Planche multipose** : 8 cartes par A4 avec fond perdu de 2 mm, traits de coupe dans les marges, page verso en miroir.
- **Modèles et pack** : les 22 modèles et les 5 supports d'un pack ont été rendus et contrôlés à l'œil.
- **Écrans** : les 12 rubriques ont été capturées sur ordinateur (1440 × 960) et sur téléphone (412 × 892). Cinq défauts ont été trouvés et corrigés : débordements du menu « Papier », de la barre d'outils mobile, de la barre de l'atelier sur téléphone et de l'indicateur d'enregistrement, et une flèche absente de la police d'interface.
- **Application Linux réelle** : lancée sous X11 ; fenêtre « Pubulotron », tableau de bord affiché, base créée dans `~/.local/share/com.example.pubulotron/`.

## Défauts trouvés par les tests et corrigés

1. Fermeture de l'application avec un projet ouvert : `onDispose` lisait `state` (interdit par Riverpod 3), ce qui risquait de faire perdre la dernière sauvegarde.
2. Archive ZIP : deux créations de même nom produisaient un fichier sans extension (`Nom_2$1`).
3. Pictogrammes proposés par l'IA sous un nom composé (ex. `laptop_chromebook`) non reconnus.
4. Les quatre débordements d'interface listés ci-dessus.

## Non testé, et pourquoi

| Point | Raison | Couverture existante |
|---|---|---|
| Appels réels aux API OpenAI, Anthropic, Gemini et Mistral | Aucune clé API disponible pendant le développement | Requêtes et réponses simulées pour les 4 fournisseurs, conformes à leur documentation |
| Installation de l'APK sur un appareil Android | Aucun appareil ni émulateur ARM64 connecté | APK construit, métadonnées vérifiées (`aapt2`) |
| Sélecteurs de fichiers natifs, partage Android, boîte d'impression | Dialogues système impossibles à piloter en test automatisé | Code de repli testé ; portail xdg (KDE) présent sur la machine |
| Impression physique recto verso | Pas d'imprimante dans l'environnement | Géométrie du miroir testée ; le guide recommande un essai sur une feuille |
