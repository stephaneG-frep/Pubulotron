# Mode d'emploi Pubulotron

## 1. Démarrer une création

- Ouvrez la section "Nouvelle création".
- Rédigez un brief créatif clair.
- Sélectionnez le format souhaité (carte, flyer, affiche, etc.).

## 2. Générer des concepts IA

1. Ouvrir "Création avec l'IA".
2. Renseigner le brief.
3. Sélectionner le fournisseur AI.
4. Saisir la clé API si nécessaire.
5. Cliquer sur "Régénérer les concepts".
6. Comparer les quatre aperçus, conçus dans des styles distincts (Futuriste, Premium, Digital et Pop).
7. Cliquer sur "Ouvrir ce design" ou "Modifier" pour charger ses calques dans l'atelier.

Sans clé utilisable ou sans connexion, quatre compositions locales restent disponibles; elles sont signalées comme telles. Une clé API valide permet de demander les idées rédactionnelles au fournisseur sélectionné.

### Paramètres du fournisseur IA

1. Ouvrir "Paramètres IA", choisir OpenAI, Claude, Gemini ou Mistral, puis saisir la clé API.
2. Cliquer sur "Tester la connexion" pour vérifier la clé auprès du fournisseur sélectionné. Ce test vérifie l'accès aux modèles sans lancer de génération.
3. Cliquer sur "Sauvegarder les paramètres" pour conserver le fournisseur et la clé dans le stockage sécurisé de l'appareil. La clé reste masquée et est restaurée au prochain démarrage.
4. Le test utilise les valeurs actuellement affichées; sauvegardez-les pour les retrouver la prochaine fois.
5. Si le test signale un problème réseau ou DNS, vérifiez que le téléphone est connecté à Internet et qu'aucun VPN, DNS privé ou filtrage réseau ne bloque le fournisseur.

## 3. Atelier graphique

- Ajouter du texte, des formes et des images.
- Importer des photos depuis la galerie.
- Déplacer les éléments sur le canevas.
- Sélectionner un élément pour l'ajuster.
- Utiliser la grille et les guides pour aligner.
- Sauvegarder le projet en local.

## 3.1 Modèles

- Ouvrir "Modèles" pour parcourir les aperçus réels.
- Les modèles Carte de visite, Flyer salon, Menu restaurant et Affiche promo chargent des compositions distinctes, avec leurs propres couleurs, calques et textes.
- Les coordonnées et l'identité de l'activité sont insérées dans les compositions.
- Choisir "Utiliser ce modèle" pour ouvrir et modifier sa composition dans l'atelier.
- Choisir "Commencer avec une page blanche" pour créer un canevas vide.

## 4. Gestion des projets

- Les projets sont enregistrés localement dans la base SQLite de l'application.
- Vous pouvez exporter une archive ZIP depuis le système de projets.
- La restauration locale est prise en charge dans la logique de sauvegarde actuelle.

## 5. Imprimerie PDF

1. Ouvrir "Imprimerie PDF" : l'aperçu reprend les éléments présents dans l'atelier.
2. Choisir le papier (A4, A3, A5 ou Lettre US), l'orientation et les dimensions du support en millimètres.
3. Indiquer le nombre d'exemplaires, les marges, l'espacement et le fond perdu.
4. Activer ou désactiver les traits de découpe. Les paramètres qui empêchent un placement sûr sont signalés avant l'impression.
5. Cliquer sur "Exporter PDF". La fenêtre d'impression permet de choisir l'imprimante ou d'enregistrer le document PDF.

Le moteur positionne les créations à l'échelle sans les étirer pour les faire tenir sur la feuille. Les textes et formes sont conservés en vectoriel; les photos restent des images raster. L'export recto verso avec un visuel distinct au verso n'est pas encore pris en charge.

## 6. Bonnes pratiques

- Rédiger des briefs précis et orientés business.
- Vérifier les coordonnées avant export.
- Tester plusieurs concepts avant finalisation.
- Préparer les visuels pour le print et les réseaux sociaux.
