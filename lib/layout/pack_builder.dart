import '../core/ids.dart';
import '../models/business_profile.dart';
import '../models/formats.dart';
import '../models/project.dart';
import 'brand_kit.dart';
import 'layout_engine.dart';

/// Support d'un pack publicitaire.
class PackSupport {
  const PackSupport(this.role, this.label, this.format);

  final String role;
  final String label;
  final DesignFormat format;

  static const List<PackSupport> standard = [
    PackSupport('card', 'Carte de visite', DesignFormats.businessCard),
    PackSupport('flyer', 'Flyer A5', DesignFormats.flyerA5),
    PackSupport('poster', 'Affiche A3', DesignFormats.posterA3),
    PackSupport(
      'post',
      'Publication réseaux sociaux',
      DesignFormats.socialPost,
    ),
    PackSupport('story', 'Story', DesignFormats.story),
  ];
}

/// Génère plusieurs supports partageant couleurs, typographies et informations.
class PackBuilder {
  static List<Project> build({
    required BrandKit kit,
    required BusinessProfile profile,
    String brief = '',
    List<PackSupport> supports = PackSupport.standard,
  }) {
    final packId = newId('pack');
    final now = DateTime.now();
    return [
      for (var i = 0; i < supports.length; i++)
        Project(
          name: '${profile.name} — ${supports[i].label}',
          brief: brief,
          profileId: profile.id,
          packId: packId,
          packRole: supports[i].role,
          createdAt: now.add(Duration(milliseconds: i)),
          updatedAt: now.add(Duration(milliseconds: i)),
          document: LayoutEngine.build(
            style: kit.layout,
            widthMm: supports[i].format.widthMm,
            heightMm: supports[i].format.heightMm,
            kit: kit,
            profile: profile,
            formatId: supports[i].format.id,
            duplex: supports[i].format.duplex,
          ),
        ),
    ];
  }
}
