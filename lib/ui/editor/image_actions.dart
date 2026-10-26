import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../editor/editor_controller.dart';
import '../../editor/element_factory.dart';
import '../../engine/image_cache.dart';
import '../../models/design_element.dart';
import '../widgets/common.dart';

/// Importe une image dans la médiathèque ; renvoie son identifiant et sa taille.
Future<(String, Size)?> importImage(BuildContext context, WidgetRef ref) async {
  final services = ref.read(servicesProvider);
  try {
    final picked = await services.files.pick(images: true);
    if (picked == null) return null;
    final image = await DesignImageCache.decode(
      picked.bytes,
      maxDimension: 512,
    );
    final size = Size(image.width.toDouble(), image.height.toDouble());
    image.dispose();
    final id = await services.assets.importBytes(
      picked.bytes,
      fileName: picked.name,
    );
    return (id, size);
  } catch (error) {
    if (context.mounted) {
      showMessage(
        context,
        'Image illisible ou format non pris en charge ($error).',
        error: true,
      );
    }
    return null;
  }
}

Future<void> addImage(
  BuildContext context,
  WidgetRef ref,
  EditorController c, {
  bool logo = false,
}) async {
  final imported = await importImage(context, ref);
  if (imported == null) return;
  final (id, size) = imported;
  c.addElement(
    ElementFactory(c.pageSize).image(
      id,
      size,
      name: logo ? 'Logo' : 'Photo',
      role: logo ? 'logo' : 'photo',
      logo: logo,
    ),
  );
}

Future<void> replaceImage(
  BuildContext context,
  WidgetRef ref,
  EditorController c,
  DesignElement e,
) async {
  final imported = await importImage(context, ref);
  if (imported == null) return;
  c.updateElement(e.id, (x) => x.copyWith(assetId: imported.$1));
}

/// Insère le logo de la fiche active.
Future<void> addProfileLogo(
  BuildContext context,
  WidgetRef ref,
  EditorController c,
) async {
  final profile = ref.read(activeProfileProvider);
  final logo = profile?.logoAssetId;
  if (logo == null) {
    showMessage(
      context,
      'Aucun logo dans votre fiche. Ajoutez-le dans « Mon activité ».',
    );
    return;
  }
  final image = await ref.read(servicesProvider).images.load(logo);
  if (image == null) {
    if (context.mounted) {
      showMessage(context, 'Le fichier du logo est introuvable.', error: true);
    }
    return;
  }
  c.addElement(
    ElementFactory(c.pageSize).image(
      logo,
      Size(image.width.toDouble(), image.height.toDouble()),
      name: 'Logo',
      role: 'logo',
      logo: true,
    ),
  );
}
