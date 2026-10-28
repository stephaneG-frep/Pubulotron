# Nouveautés de Pubulotron 2.1

Cette version ajoute cinq fonctions au studio. Tout ce qui existait est conservé : éditeur, déplacement tactile, calques, QR codes, sauvegarde, IA, pack publicitaire, export PDF et impression multipose. Vos projets créés avec la version 2.0 s'ouvrent normalement.

## Variante ou déclinaison ?

- Une **variante** est un design différent pour un même format (cinq cartes de visite au style différent).
- Une **déclinaison** est un même design adapté à un autre format (la carte, le flyer, l'affiche d'un même pack).

## 1. Studio de variantes

Rubrique **Studio de variantes**.

1. Décrivez votre besoin, par exemple « Crée cinq cartes de visite différentes pour mon activité de dépannage informatique ».
2. Choisissez le format et le nombre de variantes (2 à 5).
3. Cliquez sur **Générer avec l'IA**, ou sur **Hors ligne (sans IA)**.

Chaque variante suit une direction artistique différente : moderne et minimaliste, futuriste avec dégradés, élégante et professionnelle, colorée et créative, originale et audacieuse.

**Comment l'IA est guidée**
- L'IA reçoit une variante à la fois, avec le résumé des précédentes (polices, fond, emplacement du titre et du QR code). Elle doit s'en distinguer par la disposition, la typographie, les formes, les couleurs et l'emplacement du QR code.
- Si une proposition ressemble trop à une variante existante, Pubulotron redemande automatiquement une composition différente.

**Pendant et après la génération**
- La progression s'affiche (« Variante 3 sur 5 »).
- Chaque variante est enregistrée dès qu'elle est prête : en cas de coupure réseau, celles déjà produites sont conservées.
- Une nouvelle série n'écrase jamais les précédentes. Les séries apparaissent sous forme de pastilles au-dessus de la galerie.

**La galerie**
- Chaque carte montre un aperçu, un numéro et le nom du style.
- **Ouvrir** affiche la variante en grand, recto et verso.
- **Modifier** l'ouvre dans l'atelier.
- **Régénérer** produit une nouvelle composition dans le même style ; l'ancienne reste dans l'historique.
- **Dupliquer** et **Enregistrer comme modèle** sont aussi disponibles.
- **Comparer** : cochez 2 à 5 variantes. Elles s'affichent côte à côte sur ordinateur, en carrousel à balayer sur téléphone.

Chaque variante est une création indépendante : la modifier ne touche pas les autres.

## 2. Synchronisation des formats

Quand vous modifiez, dans l'atelier, une création qui appartient à un pack ou à une série de variantes, Pubulotron repère les modifications qui concernent aussi les autres créations :

- nom, téléphone, e-mail, site, adresse, slogan ou tout autre texte commun ;
- contenu d'un QR code ;
- logo ;
- couleurs.

Un bandeau demande alors : *« Souhaites-tu appliquer cette modification aux autres formats ? »*

- **Uniquement cette création** : rien d'autre ne change.
- **Toutes les déclinaisons** : tout est présélectionné dans la fenêtre de confirmation.
- **Choisir…** : vous cochez vous-même les créations à modifier.

**La fenêtre de confirmation**
- Elle liste les modifications et les créations concernées, avec un aperçu avant/après de chacune.
- Rien n'est modifié sans votre clic sur **Appliquer**.
- Avant toute écriture, un **point de restauration** est créé dans l'historique de chaque création.

**Ce qui change dans chaque format**
- Les éléments correspondants sont retrouvés par leur contenu et leur rôle (téléphone, e-mail…), jamais par leur position.
- Seul le contenu change : la mise en page de chaque format est conservée. Si un nouveau texte est plus long, seule sa taille de police est réduite pour qu'il tienne dans son cadre.

## 3. Historique des versions

Dans l'atelier : bouton **Historique** (horloge), ou **Ctrl+H**.

**Ce qui est enregistré**
- Chaque création garde ses versions, avec la date, une description générée automatiquement (« Modification du texte « … » », « Ajout : QR code », « Changement de couleurs »…) et un aperçu.
- Les opérations notables ont toujours leur propre version : création par IA, modification par l'agent, amélioration, synchronisation, restauration.
- Les retouches rapprochées (moins de 3 minutes) sont regroupées pour limiter la place occupée.

**Ce que vous pouvez faire**
- **Restaurer** une version : l'état actuel est d'abord enregistré, vous pouvez donc revenir à la version la plus récente à tout moment.
- **Dupliquer** une version en nouvelle création.
- **Comparer** deux versions : elles s'affichent côte à côte, avec la liste des différences.
- **Supprimer** une version, ou **nettoyer** les anciennes.

**Conservation**
- L'historique survit à la fermeture de l'application et figure dans les sauvegardes ZIP.
- Les images et logos des anciennes versions restent disponibles.
- Le nombre de versions conservées par création se règle dans **Paramètres IA › Préférences** (30 par défaut). La version initiale est toujours gardée.

## 4. Améliore mon design

Dans l'atelier : bouton **Améliore mon design**.

**Mode Conseils** : analyse sans aucune modification.

- **Sans IA**, une analyse automatique vérifie :
  - le contraste des textes (normes WCAG) ;
  - la taille minimale des textes selon le format ;
  - la marge de sécurité de 3 mm ;
  - les textes superposés ;
  - la taille et la lisibilité du QR code ;
  - le nombre de polices ;
  - la hiérarchie des titres ;
  - les emplacements photo vides.
- **Avec l'IA**, s'y ajoutent des conseils de composition.
- Si le modèle choisi sait lire les images, il reçoit aussi une image du rendu. Sinon, Pubulotron l'indique : l'analyse porte alors sur la structure (positions, tailles, couleurs, textes) et non sur l'apparence exacte.
- Toucher un constat sélectionne l'élément concerné.

**Mode Amélioration automatique** (IA nécessaire). Exemples de demandes :

> Rends cette carte plus professionnelle, mais conserve mes textes et mon QR code.
> Modernise ce flyer avec des couleurs plus dynamiques.
> Améliore la lisibilité et l'équilibre graphique de cette affiche.

L'original et la proposition s'affichent côte à côte. Vous choisissez :

- **Accepter** : l'original reste dans l'historique ;
- **Refuser** ;
- **Modifier davantage** : une nouvelle consigne est appliquée à la proposition ;
- **Enregistrer comme nouvelle variante** : l'original n'est pas touché.

**Garde-fous**, appliqués même si l'IA ne les respecte pas :
- vos coordonnées et le nom de l'activité ne sont jamais modifiés ni inventés ;
- le contenu des QR codes est conservé ;
- un élément important supprimé sans demande explicite est rétabli ;
- avec « conserve mes textes », tous les textes sont protégés.

Chaque élément reste modifiable dans l'éditeur.

## 5. Surprends-moi !

Depuis le tableau de bord : bouton **Surprends-moi !**.

1. Écrivez simplement « Je suis artisan menuisier. », choisissez le format et le nombre de créations.
2. **Proposer des directions artistiques** : l'IA en imagine cinq, adaptées à l'activité (par exemple artisan traditionnel, bois et nature, design contemporain, atelier industriel, création artistique), chacune avec une description et une palette.
3. Cochez celles qui vous plaisent, puis **Créer** : les créations sont générées dans le Studio de variantes, avec les informations de votre fiche, et restent entièrement modifiables.

Sans clé API, les cinq directions par défaut et le générateur hors ligne sont utilisés.
