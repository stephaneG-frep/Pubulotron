import '../models/design_document.dart';
import '../models/design_element.dart';

String _typeLabel(ElementType t) => switch (t) {
  ElementType.text => 'texte',
  ElementType.shape => 'forme',
  ElementType.image => 'image',
  ElementType.qr => 'QR code',
  ElementType.icon => 'pictogramme',
};

String _short(String text) {
  final t = text.replaceAll('\n', ' ').trim();
  return t.length > 28 ? '${t.substring(0, 27)}…' : t;
}

/// Décrit en français les différences entre deux états d'un document.
/// Sert de libellé aux versions et au comparateur.
List<String> describeChanges(DesignDocument before, DesignDocument after) {
  final changes = <String>[];
  if (before.widthMm != after.widthMm || before.heightMm != after.heightMm) {
    changes.add('Changement de format');
  }
  if (before.pages.length != after.pages.length) {
    changes.add(
      after.pages.length > before.pages.length
          ? 'Ajout du verso'
          : 'Suppression du verso',
    );
  }
  for (var i = 0; i < after.pages.length; i++) {
    final a = after.pages[i];
    final b = i < before.pages.length ? before.pages[i] : null;
    if (b == null) continue;
    final face = after.pages.length > 1 ? ' (${a.name.toLowerCase()})' : '';
    if (a.background != b.background) changes.add('Changement du fond$face');
    final oldById = {for (final e in b.elements) e.id: e};
    final newById = {for (final e in a.elements) e.id: e};
    for (final e in a.elements) {
      if (!oldById.containsKey(e.id)) {
        changes.add('Ajout : ${_typeLabel(e.type)}$face');
      }
    }
    for (final e in b.elements) {
      if (!newById.containsKey(e.id)) {
        changes.add('Suppression : ${_typeLabel(e.type)}$face');
      }
    }
    var moved = 0;
    var colored = 0;
    var styled = 0;
    for (final e in a.elements) {
      final o = oldById[e.id];
      if (o == null) continue;
      if (e.text != o.text && e.type == ElementType.text) {
        changes.add('Modification du texte « ${_short(e.text)} »$face');
      }
      if (e.qrData != o.qrData && e.type == ElementType.qr) {
        changes.add('Modification du QR code$face');
      }
      if (e.assetId != o.assetId) changes.add('Changement d’image$face');
      if (e.color != o.color ||
          e.fill != o.fill ||
          e.strokeColor != o.strokeColor) {
        colored++;
      }
      if (e.x != o.x ||
          e.y != o.y ||
          e.width != o.width ||
          e.height != o.height ||
          e.rotation != o.rotation) {
        moved++;
      }
      if (e.fontFamily != o.fontFamily ||
          e.fontSize != o.fontSize ||
          e.bold != o.bold ||
          e.italic != o.italic ||
          e.opacity != o.opacity ||
          e.shape != o.shape ||
          e.locked != o.locked ||
          e.visible != o.visible) {
        styled++;
      }
    }
    if (colored > 0) changes.add('Changement de couleurs$face');
    if (moved > 0) {
      changes.add('Mise en page ($moved élément${moved > 1 ? 's' : ''})$face');
    }
    if (styled > 0) {
      changes.add(
        'Style modifié ($styled élément${styled > 1 ? 's' : ''})$face',
      );
    }
    final order = a.elements
        .map((e) => e.id)
        .where(oldById.containsKey)
        .toList();
    final oldOrder = b.elements
        .map((e) => e.id)
        .where(newById.containsKey)
        .toList();
    if (order.join() != oldOrder.join()) changes.add('Ordre des calques$face');
  }
  return changes;
}

/// Libellé court (une ligne) à partir d'une liste de changements.
String summarizeChanges(List<String> changes, {int max = 3}) {
  if (changes.isEmpty) return 'Aucune modification';
  final unique = changes.toSet().toList();
  final head = unique.take(max).join(', ');
  return unique.length > max ? '$head… (+${unique.length - max})' : head;
}
