import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/robopub.dart';

class HelpTopic {
  const HelpTopic(this.icon, this.title, this.steps, this.example);

  final IconData icon;
  final String title;
  final List<String> steps;
  final String example;
}

const helpTopics = [
  HelpTopic(
    Icons.contact_page_outlined,
    'Créer une carte de visite',
    [
      'Ouvrez « Nouvelle création » et choisissez « Carte de visite » (85 × 55 mm).',
      'Partez d’une page blanche, d’un modèle (Bibliothèque) ou demandez quatre propositions à l’IA.',
      'Dans l’atelier, cliquez sur un texte pour le sélectionner, puis modifiez-le dans « Propriétés ».',
      'Ajoutez un verso depuis les propriétés de la page (cliquez dans le vide pour les afficher).',
    ],
    'Exemple : modèle « Carte futuriste » (Informatique) › Utiliser avec ma fiche › le nom, le téléphone et le QR code de votre site sont insérés automatiquement.',
  ),
  HelpTopic(
    Icons.auto_awesome,
    'Utiliser l’IA',
    [
      'Dans « Paramètres IA », choisissez OpenAI, Claude, Gemini ou Mistral, collez votre clé API puis « Tester la connexion ».',
      'Dans « Création avec l’IA », décrivez le support, le style, les couleurs et le message.',
      'L’agent propose quatre designs entièrement éditables : ouvrez celui qui vous plaît.',
      'Dans l’atelier, l’onglet « Agent IA » modifie la création à votre demande ; chaque modification s’annule en un clic.',
    ],
    'Exemple : « Crée-moi un flyer A5 pour mon activité de jardinage, avec des couleurs vertes et une promotion de 15 %. » puis « Agrandis le titre et mets le numéro de téléphone en orange. »',
  ),
  HelpTopic(
    Icons.design_services,
    'Modifier un design',
    [
      'Glissez un élément pour le déplacer : des repères roses apparaissent quand il s’aligne sur la page ou sur un autre élément (Alt pour désactiver).',
      'Tirez les poignées pour redimensionner (Maj pour garder les proportions), la poignée ronde pour tourner.',
      'Maj + clic pour sélectionner plusieurs éléments, puis alignez-les ou répartissez-les.',
      'Calques : réordonnez, masquez, verrouillez. Ctrl+Z / Ctrl+Y pour annuler / rétablir, Ctrl+D pour dupliquer.',
    ],
    'Exemple : sélectionnez le fond et verrouillez-le pour ne plus le déplacer par erreur.',
  ),
  HelpTopic(
    Icons.add_photo_alternate_outlined,
    'Insérer une image',
    [
      'Onglet « Insérer » › « Importer une photo » (ou « Importer un logo »).',
      'L’image est copiée dans la médiathèque de l’application : elle reste disponible même si le fichier d’origine est déplacé.',
      'Dans les propriétés, choisissez le cadrage (Remplir, Entière, Étirer) et l’arrondi des coins.',
      'Un emplacement photo vide (proposé par l’IA ou un modèle) se remplit avec « Choisir une image ».',
    ],
    'Astuce : enregistrez votre logo dans « Mon activité » pour l’insérer en un clic dans toutes vos créations.',
  ),
  HelpTopic(
    Icons.qr_code_2,
    'Ajouter un QR code',
    [
      'Onglet « Insérer » › « Générer un QR code », ou rubrique « Générateur de QR codes ».',
      'Choisissez le type : site internet, réservation, coordonnées (vCard), portfolio, catalogue, réseau social ou texte.',
      'Gardez des modules foncés sur fond clair et une taille d’au moins 15 à 20 mm à l’impression.',
    ],
    'Exemple : QR « Coordonnées » sur le verso d’une carte de visite : vos clients enregistrent votre contact en le scannant.',
  ),
  HelpTopic(
    Icons.save_outlined,
    'Sauvegarder un projet',
    [
      'Chaque modification est enregistrée automatiquement sur l’appareil (indicateur « Enregistré » en haut de l’atelier).',
      'Ctrl+S ou menu Exporter › « Enregistrer maintenant » force l’enregistrement.',
      '« Mes projets » permet de renommer, dupliquer ou supprimer vos projets.',
      '« Sauvegarde ZIP » crée une archive complète (projets, fiches, modèles, images) à conserver en lieu sûr.',
    ],
    'Les projets se rouvrent à l’identique après la fermeture de l’application.',
  ),
  HelpTopic(
    Icons.picture_as_pdf_outlined,
    'Exporter un PDF',
    [
      'Dans l’atelier, menu « Exporter » › « PDF vectoriel » : le PDF a les dimensions exactes du support.',
      '« PDF avec fond perdu 3 mm » pour un imprimeur professionnel.',
      'Les textes, formes, dégradés et QR codes restent vectoriels ; les images gardent leur pleine résolution.',
      'PNG et JPEG : choisissez la résolution (300 ppp pour l’impression, taille exacte pour les réseaux sociaux).',
    ],
    'Sur Android, « Partager » envoie directement le fichier par e-mail, messagerie ou vers votre imprimeur.',
  ),
  HelpTopic(
    Icons.grid_view,
    'Imprimer plusieurs cartes sur une feuille',
    [
      'Ouvrez « Imprimerie PDF » et choisissez la création.',
      'Réglez le papier (A4, A3, A5, Lettre US ou personnalisé), l’orientation (Auto choisit la meilleure), le nombre d’exemplaires, les marges, l’espacement et le fond perdu.',
      'Le nombre de cartes par feuille et de feuilles est calculé automatiquement ; vérifiez l’aperçu de chaque feuille.',
      'Activez les traits de découpe et, si besoin, le recto verso (choisissez le même bord de retournement dans votre imprimante).',
    ],
    'Exemple : 100 cartes 85 × 55 mm, A4, marges 10 mm → 10 cartes par feuille (2 × 5), 10 feuilles.',
  ),
  HelpTopic(
    Icons.restore,
    'Restaurer une sauvegarde',
    [
      '« Mes projets » › « Restaurer / importer » puis choisissez l’archive ZIP.',
      'Les projets, fiches, modèles et images de l’archive sont ajoutés ; les éléments déjà présents (même identifiant) sont remplacés.',
      'Les archives d’un seul projet (menu Exporter › « Archive du projet ») s’importent de la même façon.',
    ],
    'Astuce : sauvegardez sur votre téléphone, restaurez sur votre ordinateur Linux, et inversement.',
  ),
];

const offlineFeatures = [
  ('Création manuelle et atelier graphique', true),
  ('Bibliothèque de modèles', true),
  ('Modification des créations', true),
  ('Sauvegarde, restauration et archives ZIP', true),
  ('Générateur de QR codes', true),
  ('Export PDF, PNG, JPEG et impression', true),
  ('Imprimerie multipose', true),
  ('Pack publicitaire hors ligne (depuis la fiche)', true),
  ('Création et modification par l’IA', false),
  ('Test de connexion aux fournisseurs IA', false),
];

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SectionPage(
      title: 'Mode d’emploi',
      subtitle:
          'Tout ce qu’il faut savoir pour fabriquer des pubs qui ont du génie.',
      icon: Icons.menu_book_outlined,
      accent: PubColors.turquoise,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const RoboPub(size: 90),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Bonjour, je suis RoboPub ! Pubulotron fonctionne sans Internet pour tout ce qui concerne la création, '
                    'l’impression et la sauvegarde. Seules les fonctions d’IA ont besoin d’une connexion et d’une clé API.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        for (final topic in helpTopics)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              child: ExpansionTile(
                leading: Icon(topic.icon, color: PubColors.violet),
                title: Text(
                  topic.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < topic.steps.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 11,
                            backgroundColor: PubColors.violet,
                            foregroundColor: Colors.white,
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(topic.steps[i])),
                        ],
                      ),
                    ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: PubColors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.lightbulb_outline,
                          color: PubColors.orange,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(topic.example)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        PanelCard(
          title: 'Disponible hors ligne ?',
          child: Column(
            children: [
              for (final (label, offline) in offlineFeatures)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    offline ? Icons.offline_pin : Icons.cloud_outlined,
                    color: offline ? PubColors.turquoise : PubColors.orange,
                  ),
                  title: Text(label),
                  trailing: Text(offline ? 'Hors ligne' : 'Internet + clé API'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PanelCard(
          title: 'Raccourcis clavier (ordinateur)',
          child: Wrap(
            spacing: 18,
            runSpacing: 6,
            children: const [
              Text('Ctrl+Z / Ctrl+Y : annuler / rétablir'),
              Text('Ctrl+C / X / V : copier / couper / coller'),
              Text('Ctrl+D : dupliquer'),
              Text('Suppr : supprimer'),
              Text('Flèches : déplacer de 0,5 mm (Maj : 5 mm)'),
              Text('Ctrl+molette ou Ctrl+ +/- : zoom'),
              Text('Ctrl+G : grille'),
              Text('Ctrl+S : enregistrer'),
              Text('Double-clic sur un texte : le modifier'),
            ],
          ),
        ),
      ],
    );
  }
}
