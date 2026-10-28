import 'package:flutter/material.dart';

import '../app/providers.dart';
import 'theme.dart';

class SectionInfo {
  const SectionInfo(
    this.section,
    this.label,
    this.icon,
    this.color,
    this.description, {
    this.offline = true,
  });

  final AppSection section;
  final String label;
  final IconData icon;
  final Color color;
  final String description;

  /// Utilisable sans connexion Internet.
  final bool offline;
}

const sections = <SectionInfo>[
  SectionInfo(
    AppSection.home,
    'Tableau de bord',
    Icons.space_dashboard_outlined,
    PubColors.violet,
    'Vue d’ensemble',
  ),
  SectionInfo(
    AppSection.newCreation,
    'Nouvelle création',
    Icons.add_box_outlined,
    PubColors.violet,
    'Choisir un format et démarrer',
  ),
  SectionInfo(
    AppSection.aiCreation,
    'Création avec l’IA',
    Icons.auto_awesome,
    PubColors.rose,
    'Quatre designs à partir de votre demande',
    offline: false,
  ),
  SectionInfo(
    AppSection.surprise,
    'Surprends-moi !',
    Icons.celebration_outlined,
    PubColors.orange,
    'Des directions artistiques en une phrase',
    offline: false,
  ),
  SectionInfo(
    AppSection.variants,
    'Studio de variantes',
    Icons.auto_awesome_mosaic_outlined,
    PubColors.rose,
    'Plusieurs designs pour un même format',
  ),
  SectionInfo(
    AppSection.studio,
    'Atelier graphique',
    Icons.design_services_outlined,
    PubColors.turquoise,
    'Modifier chaque élément',
  ),
  SectionInfo(
    AppSection.templates,
    'Bibliothèque de modèles',
    Icons.grid_view_rounded,
    PubColors.turquoise,
    'Modèles par métier',
  ),
  SectionInfo(
    AppSection.projects,
    'Mes projets',
    Icons.folder_copy_outlined,
    PubColors.night,
    'Retrouver, dupliquer, sauvegarder',
  ),
  SectionInfo(
    AppSection.pack,
    'Pack publicitaire',
    Icons.collections_bookmark_outlined,
    PubColors.rose,
    'Tous vos supports assortis',
  ),
  SectionInfo(
    AppSection.print,
    'Imprimerie PDF',
    Icons.local_printshop_outlined,
    PubColors.orange,
    'Plusieurs exemplaires par feuille',
  ),
  SectionInfo(
    AppSection.identity,
    'Mon activité',
    Icons.business_center_outlined,
    PubColors.turquoise,
    'Fiches professionnelles',
  ),
  SectionInfo(
    AppSection.aiSettings,
    'Paramètres IA',
    Icons.settings_suggest_outlined,
    PubColors.violet,
    'Fournisseurs, clés et préférences',
  ),
  SectionInfo(
    AppSection.help,
    'Mode d’emploi',
    Icons.menu_book_outlined,
    PubColors.orange,
    'Guides et exemples',
  ),
  SectionInfo(
    AppSection.qr,
    'Générateur de QR codes',
    Icons.qr_code_2,
    PubColors.night,
    'QR codes intégrables et exportables',
  ),
];

SectionInfo infoFor(AppSection section) =>
    sections.firstWhere((s) => s.section == section);
