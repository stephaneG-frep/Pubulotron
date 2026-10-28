import 'dart:ui';

import '../core/color_utils.dart';
import '../engine/text_layout.dart';
import '../layout/layout_engine.dart';
import '../models/design_document.dart';
import '../models/design_element.dart';
import '../models/project.dart';

/// Modification répercutable sur d'autres créations.
sealed class SyncChange {
  const SyncChange();

  /// Description lisible (« Téléphone : 06… → 07… »).
  String get label;

  /// Clé d'unicité.
  String get key;
}

class TextSyncChange extends SyncChange {
  const TextSyncChange(this.oldText, this.newText, {this.role});

  final String oldText;
  final String newText;
  final String? role;

  static String fieldName(String? role, String text) {
    final r = (role ?? '').toLowerCase();
    if (r.contains('phone') || RegExp(r'^\+?[\d\s.()-]{8,}$').hasMatch(text)) {
      return 'Téléphone';
    }
    if (r.contains('email') || r.contains('mail') || text.contains('@')) {
      return 'E-mail';
    }
    if (r.contains('web') ||
        r.contains('site') ||
        RegExp(r'^(https?://)?[\w-]+(\.[\w-]+)+(/\S*)?$').hasMatch(text)) {
      return 'Site internet';
    }
    if (r.contains('place') || r.contains('address') || r.contains('adresse')) {
      return 'Adresse';
    }
    if (r.contains('slogan')) return 'Slogan';
    if (r.contains('headline') || r.contains('name')) return 'Nom / titre';
    return 'Texte';
  }

  @override
  String get label =>
      '${fieldName(role, oldText)} : « $oldText » remplacé par « $newText »';

  @override
  String get key => 'text|$oldText|$newText';
}

class QrSyncChange extends SyncChange {
  const QrSyncChange(this.oldData, this.newData);

  final String oldData;
  final String newData;

  @override
  String get label =>
      'QR code : ${_short(oldData)} remplacé par ${_short(newData)}';

  @override
  String get key => 'qr|$oldData|$newData';
}

class ImageSyncChange extends SyncChange {
  const ImageSyncChange(this.oldAsset, this.newAsset, {this.logo = false});

  final String oldAsset;
  final String newAsset;
  final bool logo;

  @override
  String get label => logo ? 'Logo remplacé' : 'Image remplacée';

  @override
  String get key => 'image|$oldAsset|$newAsset';
}

class ColorSyncChange extends SyncChange {
  const ColorSyncChange(this.oldColor, this.newColor);

  final Color oldColor;
  final Color newColor;

  @override
  String get label =>
      'Couleur ${colorToHex(oldColor)} remplacée par ${colorToHex(newColor)}';

  @override
  String get key => 'color|${oldColor.toARGB32()}|${newColor.toARGB32()}';
}

String _short(String s) {
  final t = s.replaceAll('\n', ' ');
  return t.length > 32 ? '${t.substring(0, 31)}…' : t;
}

/// Résultat de l'application à une création cible.
class SyncPreview {
  const SyncPreview({
    required this.project,
    required this.document,
    required this.matches,
  });

  final Project project;

  /// Document après synchronisation.
  final DesignDocument document;

  /// Nombre d'éléments modifiés par changement (clé → nombre).
  final Map<String, int> matches;

  int get total => matches.values.fold(0, (a, b) => a + b);

  bool get affected => total > 0;
}

/// Détection et application des modifications entre déclinaisons.
///
/// Les éléments correspondants sont retrouvés par leur contenu (valeur
/// identique ou segment d'une ligne de coordonnées) et leurs propriétés
/// sémantiques (QR, logo, couleurs), jamais par leur position dans les
/// calques. Seul le contenu change : la composition de chaque format est
/// conservée.
class SyncEngine {
  static final RegExp _separator = RegExp(r'\s*(?:\n|·|•|\||\s-\s)\s*');

  /// Créations liées : même pack (déclinaisons) ou même groupe de variantes.
  static List<Project> siblings(Project project, Iterable<Project> all) => [
    for (final p in all)
      if (p.id != project.id &&
          ((project.packId != null && p.packId == project.packId) ||
              (project.variantGroupId != null &&
                  p.variantGroupId == project.variantGroupId)))
        p,
  ];

  static List<SyncChange> detect(DesignDocument before, DesignDocument after) {
    final result = <String, SyncChange>{};
    void add(SyncChange c) => result.putIfAbsent(c.key, () => c);

    for (var i = 0; i < after.pages.length && i < before.pages.length; i++) {
      final oldById = {for (final e in before.pages[i].elements) e.id: e};
      for (final e in after.pages[i].elements) {
        final o = oldById[e.id];
        if (o == null) continue;
        if (e.type == ElementType.text && e.text.trim() != o.text.trim()) {
          for (final c in _textChanges(o.text, e.text, e.role ?? o.role)) {
            add(c);
          }
        }
        if (e.type == ElementType.qr &&
            e.qrData != o.qrData &&
            o.qrData.isNotEmpty &&
            e.qrData.isNotEmpty) {
          add(QrSyncChange(o.qrData, e.qrData));
        }
        if (e.type == ElementType.image &&
            o.assetId != null &&
            e.assetId != null &&
            e.assetId != o.assetId) {
          final logo =
              (e.role ?? '').contains('logo') ||
              e.name.toLowerCase().contains('logo');
          add(ImageSyncChange(o.assetId!, e.assetId!, logo: logo));
        }
        for (final (a, b) in _colorPairs(o, e)) {
          if (a != b) add(ColorSyncChange(a, b));
        }
      }
      final bgOld = before.pages[i].background.stops;
      final bgNew = after.pages[i].background.stops;
      if (bgOld.length == bgNew.length) {
        for (var k = 0; k < bgOld.length; k++) {
          if (bgOld[k] != bgNew[k]) add(ColorSyncChange(bgOld[k], bgNew[k]));
        }
      }
    }
    return result.values.toList();
  }

  static List<(Color, Color)> _colorPairs(DesignElement o, DesignElement e) {
    final pairs = <(Color, Color)>[];
    if (o.type != ElementType.shape && o.type != ElementType.image) {
      pairs.add((o.color, e.color));
    }
    final of = o.fill;
    final ef = e.fill;
    if (of != null && ef != null && of.stops.length == ef.stops.length) {
      for (var i = 0; i < of.stops.length; i++) {
        pairs.add((of.stops[i], ef.stops[i]));
      }
    }
    if (o.strokeColor != null && e.strokeColor != null) {
      pairs.add((o.strokeColor!, e.strokeColor!));
    }
    return pairs;
  }

  static List<TextSyncChange> _textChanges(
    String oldText,
    String newText,
    String? role,
  ) {
    final oldParts = oldText.trim().split(_separator);
    final newParts = newText.trim().split(_separator);
    if (oldParts.length == newParts.length && oldParts.length > 1) {
      return [
        for (var i = 0; i < oldParts.length; i++)
          if (oldParts[i].trim() != newParts[i].trim() &&
              oldParts[i].trim().length >= 3)
            TextSyncChange(oldParts[i].trim(), newParts[i].trim(), role: role),
      ];
    }
    final old = oldText.trim();
    if (old.length < 3) return const [];
    return [TextSyncChange(old, newText.trim(), role: role)];
  }

  /// Applique [changes] à [project] et compte les éléments touchés.
  static SyncPreview apply(Project project, List<SyncChange> changes) {
    final counts = <String, int>{};
    final pages = <DesignPage>[];
    for (final page in project.document.pages) {
      var background = page.background;
      final elements = <DesignElement>[];
      for (final original in page.elements) {
        var e = original;
        for (final change in changes) {
          final (next, hit) = _applyOne(e, change);
          if (hit) {
            counts[change.key] = (counts[change.key] ?? 0) + 1;
            e = next;
          }
        }
        if (e.type == ElementType.text &&
            e.text != original.text &&
            !e.locked) {
          // Le nouveau texte doit tenir dans le cadre existant.
          if (TextLayoutEngine.layout(e).overflows(e.height)) e = fitText(e);
        }
        elements.add(e);
      }
      for (final change in changes) {
        if (change is ColorSyncChange &&
            background.stops.contains(change.oldColor)) {
          background = background.mapColors(
            (c) => c == change.oldColor ? change.newColor : c,
          );
          counts[change.key] = (counts[change.key] ?? 0) + 1;
        }
      }
      pages.add(page.copyWith(elements: elements, background: background));
    }
    final doc = project.document.copyWith(pages: pages);
    return SyncPreview(project: project, document: doc, matches: counts);
  }

  static (DesignElement, bool) _applyOne(DesignElement e, SyncChange change) {
    switch (change) {
      case TextSyncChange(:final oldText, :final newText):
        if (e.type != ElementType.text || !e.text.contains(oldText)) {
          return (e, false);
        }
        return (e.copyWith(text: e.text.replaceAll(oldText, newText)), true);
      case QrSyncChange(:final oldData, :final newData):
        if (e.type != ElementType.qr || e.qrData != oldData) return (e, false);
        return (e.copyWith(qrData: newData), true);
      case ImageSyncChange(:final oldAsset, :final newAsset):
        if (e.type != ElementType.image || e.assetId != oldAsset) {
          return (e, false);
        }
        return (e.copyWith(assetId: newAsset), true);
      case ColorSyncChange(:final oldColor, :final newColor):
        Color swap(Color c) => c == oldColor ? newColor : c;
        var hit = false;
        var next = e;
        if (e.color == oldColor &&
            e.type != ElementType.shape &&
            e.type != ElementType.image) {
          next = next.copyWith(color: newColor);
          hit = true;
        }
        final fill = e.fill;
        if (fill != null && fill.stops.contains(oldColor)) {
          next = next.copyWith(fill: fill.mapColors(swap));
          hit = true;
        }
        if (e.strokeColor == oldColor) {
          next = next.copyWith(strokeColor: newColor);
          hit = true;
        }
        return (next, hit);
    }
  }

  /// Aperçu pour plusieurs cibles (seules celles réellement touchées sont utiles).
  static List<SyncPreview> previewAll(
    Iterable<Project> targets,
    List<SyncChange> changes,
  ) => [for (final t in targets) apply(t, changes)];
}
