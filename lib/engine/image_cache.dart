import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../data/asset_store.dart';

/// Cache des images décodées de la médiathèque. Le rendu écran et l'export
/// raster utilisent les mêmes images décodées, gage d'un rendu identique.
class DesignImageCache extends ChangeNotifier {
  DesignImageCache(this._store, {this.maxDimension = 4096});

  final AssetStore _store;
  final int maxDimension;
  final Map<String, ui.Image> _images = {};
  final Map<String, Future<ui.Image?>> _pending = {};
  final Set<String> _failed = {};

  ui.Image? peek(String id) => _images[id];

  bool hasFailed(String id) => _failed.contains(id);

  /// Image décodée si disponible ; sinon lance le chargement et notifie.
  ui.Image? get(String id) {
    final image = _images[id];
    if (image != null) return image;
    if (!_failed.contains(id)) unawaited(load(id));
    return null;
  }

  Future<ui.Image?> load(String id) {
    final cached = _images[id];
    if (cached != null) return Future.value(cached);
    return _pending.putIfAbsent(id, () async {
      try {
        final bytes = await _store.read(id);
        if (bytes == null) {
          _failed.add(id);
          return null;
        }
        final image = await decode(bytes, maxDimension: maxDimension);
        _images[id] = image;
        return image;
      } catch (_) {
        _failed.add(id);
        return null;
      } finally {
        _pending.remove(id);
        notifyListeners();
      }
    });
  }

  Future<void> ensureLoaded(Iterable<String> ids) async {
    await Future.wait(ids.toSet().map(load));
  }

  void evict(String id) {
    _images.remove(id)?.dispose();
    _failed.remove(id);
  }

  static Future<ui.Image> decode(
    Uint8List bytes, {
    int maxDimension = 4096,
  }) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    int? targetWidth;
    int? targetHeight;
    if (descriptor.width > maxDimension || descriptor.height > maxDimension) {
      if (descriptor.width >= descriptor.height) {
        targetWidth = maxDimension;
      } else {
        targetHeight = maxDimension;
      }
    }
    final codec = await descriptor.instantiateCodec(
      targetWidth: targetWidth,
      targetHeight: targetHeight,
    );
    final frame = await codec.getNextFrame();
    codec.dispose();
    descriptor.dispose();
    buffer.dispose();
    return frame.image;
  }

  @override
  void dispose() {
    for (final image in _images.values) {
      image.dispose();
    }
    _images.clear();
    super.dispose();
  }
}
