import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../engine/geometry.dart';
import '../models/design_document.dart';
import '../models/design_element.dart';
import '../models/fill.dart';
import '../models/project.dart';

enum SaveState { saved, pending, saving, error }

typedef ProjectSaver = Future<void> Function(Project project);

/// État et opérations de l'atelier graphique.
///
/// Le document est immuable : chaque modification produit un nouveau
/// document, ce qui rend l'historique (annuler / rétablir) fiable.
class EditorController extends ChangeNotifier {
  EditorController({
    required this._project,
    this.onSave,
    this.autosave = true,
    this.autosaveDelay = const Duration(milliseconds: 1200),
  });

  Project _project;
  final ProjectSaver? onSave;
  bool autosave;
  final Duration autosaveDelay;

  static const int maxHistory = 120;

  final List<DesignDocument> _undo = [];
  final List<DesignDocument> _redo = [];
  DesignDocument? _transactionBase;
  Timer? _saveTimer;
  bool _disposed = false;

  int _pageIndex = 0;
  Set<String> _selection = {};
  List<DesignElement> _clipboard = const [];

  // Affichage
  double zoom = 1;
  bool showGrid = false;
  bool snapToGrid = false;
  bool smartGuides = true;
  double gridMm = 5;
  List<SnapGuide> activeGuides = const [];

  SaveState saveState = SaveState.saved;
  String? saveError;

  // Glisser-déposer en cours
  Map<String, Rect> _dragOrigin = const {};
  DesignElement? _resizeOrigin;

  Project get project => _project;
  DesignDocument get document => _project.document;
  int get pageIndex => _pageIndex.clamp(0, document.pages.length - 1);
  DesignPage get page => document.pages[pageIndex];
  Size get pageSize => document.sizeMm;
  Set<String> get selection => _selection;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  bool get hasClipboard => _clipboard.isNotEmpty;
  bool get isDirty => saveState != SaveState.saved;

  List<DesignElement> get selectedElements =>
      page.elements.where((e) => _selection.contains(e.id)).toList();

  DesignElement? get singleSelection {
    if (_selection.length != 1) return null;
    return page.elementById(_selection.first);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // ------------------------------------------------------------- historique

  void _commit(DesignDocument next, {bool record = true}) {
    if (identical(next, document)) return;
    if (record) {
      _undo.add(document);
      if (_undo.length > maxHistory) _undo.removeAt(0);
      _redo.clear();
    }
    _project = _project.copyWith(document: next, updatedAt: DateTime.now());
    _pruneSelection();
    _scheduleSave();
    _notify();
  }

  void _pruneSelection() {
    final ids = page.elements.map((e) => e.id).toSet();
    _selection = _selection.where(ids.contains).toSet();
  }

  void _commitPage(DesignPage next, {bool record = true}) =>
      _commit(document.replacePage(pageIndex, next), record: record);

  void _commitElements(List<DesignElement> elements, {bool record = true}) =>
      _commitPage(page.copyWith(elements: elements), record: record);

  void undo() {
    if (_undo.isEmpty) return;
    _redo.add(document);
    _project = _project.copyWith(
      document: _undo.removeLast(),
      updatedAt: DateTime.now(),
    );
    _pageIndex = pageIndex;
    _pruneSelection();
    _scheduleSave();
    _notify();
  }

  void redo() {
    if (_redo.isEmpty) return;
    _undo.add(document);
    _project = _project.copyWith(
      document: _redo.removeLast(),
      updatedAt: DateTime.now(),
    );
    _pruneSelection();
    _scheduleSave();
    _notify();
  }

  /// Regroupe une série de modifications (geste continu) en une seule étape.
  void beginTransaction() {
    _transactionBase ??= document;
  }

  void endTransaction() {
    final base = _transactionBase;
    _transactionBase = null;
    activeGuides = const [];
    _dragOrigin = const {};
    _resizeOrigin = null;
    if (base != null && !identical(base, document)) {
      _undo.add(base);
      if (_undo.length > maxHistory) _undo.removeAt(0);
      _redo.clear();
    }
    _notify();
  }

  bool get _inTransaction => _transactionBase != null;

  // ------------------------------------------------------------ sauvegarde

  void _scheduleSave() {
    saveState = SaveState.pending;
    if (!autosave || onSave == null) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(autosaveDelay, () => unawaited(saveNow()));
  }

  Future<void> saveNow() async {
    _saveTimer?.cancel();
    final saver = onSave;
    if (saver == null) return;
    final snapshot = _project;
    saveState = SaveState.saving;
    _notify();
    try {
      await saver(snapshot);
      if (identical(_project, snapshot)) saveState = SaveState.saved;
      saveError = null;
    } catch (error) {
      saveState = SaveState.error;
      saveError = '$error';
    }
    _notify();
  }

  // ------------------------------------------------------------ sélection

  void select(String? id, {bool additive = false}) {
    if (id == null) {
      _selection = {};
    } else if (additive) {
      _selection = {..._selection}..toggle(id);
    } else {
      _selection = {id};
    }
    _notify();
  }

  void selectAll() {
    _selection = page.elements.where((e) => e.visible).map((e) => e.id).toSet();
    _notify();
  }

  void clearSelection() => select(null);

  // ------------------------------------------------------------ pages

  void setPage(int index) {
    _pageIndex = index.clamp(0, document.pages.length - 1);
    _selection = {};
    _notify();
  }

  void addBackPage({bool copyFront = false}) {
    if (document.isDuplex) return;
    final front = document.front;
    final back = DesignPage(
      name: 'Verso',
      background: front.background,
      elements: copyFront
          ? front.elements.map((e) => e.duplicate()).toList()
          : const [],
    );
    _commit(document.copyWith(pages: [front, back]));
    _pageIndex = 1;
    _selection = {};
    _notify();
  }

  void removeBackPage() {
    if (!document.isDuplex) return;
    _commit(document.copyWith(pages: [document.front]));
    _pageIndex = 0;
    _notify();
  }

  // ------------------------------------------------------------ éléments

  void addElement(DesignElement element, {bool select = true}) {
    _commitElements([...page.elements, element]);
    if (select) {
      _selection = {element.id};
      _notify();
    }
  }

  /// Ajoute un élément centré sur la page.
  void addCentered(DesignElement element) {
    final x = (pageSize.width - element.width) / 2;
    final y = (pageSize.height - element.height) / 2;
    addElement(element.copyWith(x: x, y: y));
  }

  void updateElement(
    String id,
    DesignElement Function(DesignElement) change, {
    bool record = true,
  }) {
    var changed = false;
    final elements = [
      for (final e in page.elements)
        if (e.id == id)
          () {
            changed = true;
            return change(e);
          }()
        else
          e,
    ];
    if (changed) _commitElements(elements, record: record && !_inTransaction);
  }

  /// Modifie tous les éléments sélectionnés (ignorés s'ils sont verrouillés,
  /// sauf pour le verrouillage lui-même).
  void updateSelected(
    DesignElement Function(DesignElement) change, {
    bool includeLocked = false,
  }) {
    if (_selection.isEmpty) return;
    _commitElements([
      for (final e in page.elements)
        if (_selection.contains(e.id) && (includeLocked || !e.locked))
          change(e)
        else
          e,
    ], record: !_inTransaction);
  }

  void deleteSelected() {
    if (_selection.isEmpty) return;
    final remaining = page.elements
        .where((e) => !_selection.contains(e.id) || e.locked)
        .toList();
    if (remaining.length == page.elements.length) return;
    _commitElements(remaining);
    _selection = {};
    _notify();
  }

  void duplicateSelected() {
    final selected = selectedElements;
    if (selected.isEmpty) return;
    final copies = selected.map((e) => e.duplicate(offset: 3)).toList();
    _commitElements([...page.elements, ...copies]);
    _selection = copies.map((e) => e.id).toSet();
    _notify();
  }

  void copySelection() {
    _clipboard = selectedElements;
    _notify();
  }

  void cutSelection() {
    copySelection();
    deleteSelected();
  }

  void paste() {
    if (_clipboard.isEmpty) return;
    final copies = _clipboard.map((e) => e.duplicate(offset: 3)).toList();
    _clipboard = copies;
    _commitElements([...page.elements, ...copies]);
    _selection = copies.map((e) => e.id).toSet();
    _notify();
  }

  void toggleLock(String id) =>
      updateElement(id, (e) => e.copyWith(locked: !e.locked));

  void toggleVisible(String id) =>
      updateElement(id, (e) => e.copyWith(visible: !e.visible));

  void lockSelected(bool locked) =>
      updateSelected((e) => e.copyWith(locked: locked), includeLocked: true);

  // ------------------------------------------------------------ calques

  /// Déplace un calque (index dans la liste du bas vers le haut).
  void reorderLayer(int oldIndex, int newIndex) {
    final elements = [...page.elements];
    if (oldIndex < 0 || oldIndex >= elements.length) return;
    final element = elements.removeAt(oldIndex);
    elements.insert(newIndex.clamp(0, elements.length), element);
    _commitElements(elements);
  }

  void bringToFront() => _restack(
    (list, selected) => [
      ...list.where((e) => !selected.contains(e)),
      ...selected,
    ],
  );

  void sendToBack() => _restack(
    (list, selected) => [
      ...selected,
      ...list.where((e) => !selected.contains(e)),
    ],
  );

  void bringForward() => _step(1);

  void sendBackward() => _step(-1);

  void _restack(
    List<DesignElement> Function(List<DesignElement>, List<DesignElement>)
    order,
  ) {
    final selected = selectedElements;
    if (selected.isEmpty) return;
    _commitElements(order(page.elements, selected));
  }

  void _step(int direction) {
    final elements = [...page.elements];
    final indices = [
      for (var i = 0; i < elements.length; i++)
        if (_selection.contains(elements[i].id)) i,
    ];
    if (indices.isEmpty) return;
    final ordered = direction > 0 ? indices.reversed : indices;
    var moved = false;
    for (final i in ordered) {
      final j = i + direction;
      if (j < 0 ||
          j >= elements.length ||
          _selection.contains(elements[j].id)) {
        continue;
      }
      final tmp = elements[j];
      elements[j] = elements[i];
      elements[i] = tmp;
      moved = true;
    }
    if (moved) _commitElements(elements);
  }

  // ------------------------------------------------------------ alignement

  void align(AlignMode mode, {bool toPage = false}) {
    final selected = selectedElements;
    if (selected.isEmpty) return;
    final aligned = {
      for (final e in alignElements(selected, mode, pageSize, toPage: toPage))
        e.id: e,
    };
    _commitElements([for (final e in page.elements) aligned[e.id] ?? e]);
  }

  void distribute({required bool horizontal}) {
    final selected = selectedElements;
    if (selected.length < 3) return;
    final placed = {
      for (final e in distributeElements(selected, horizontal: horizontal))
        e.id: e,
    };
    _commitElements([for (final e in page.elements) placed[e.id] ?? e]);
  }

  void nudge(double dx, double dy) =>
      updateSelected((e) => e.copyWith(x: e.x + dx, y: e.y + dy));

  // ------------------------------------------------------------ gestes

  void beginMove() {
    beginTransaction();
    _dragOrigin = {
      for (final e in selectedElements)
        if (!e.locked) e.id: e.rect,
    };
  }

  /// Déplace la sélection de [totalDelta] (mm) depuis le début du geste.
  void dragMove(Offset totalDelta, {bool snap = true}) {
    if (_dragOrigin.isEmpty) return;
    var delta = totalDelta;
    final group = _dragOrigin.values
        .reduce((a, b) => a.expandToInclude(b))
        .shift(delta);
    if (snap && (smartGuides || snapToGrid)) {
      final others = page.elements
          .where((e) => e.visible && !_dragOrigin.containsKey(e.id))
          .map(rotatedBounds);
      final result = computeSnap(
        moving: group,
        page: pageSize,
        others: others,
        threshold: 1.6 / zoom.clamp(0.25, 4),
        gridMm: snapToGrid ? gridMm : null,
        guides: smartGuides,
      );
      delta += result.offset;
      activeGuides = result.guides;
    } else {
      activeGuides = const [];
    }
    _commitElements([
      for (final e in page.elements)
        if (_dragOrigin[e.id] case final origin?)
          e.copyWith(x: origin.left + delta.dx, y: origin.top + delta.dy)
        else
          e,
    ], record: false);
  }

  void beginResize(String id) {
    beginTransaction();
    _resizeOrigin = page.elementById(id);
  }

  void dragResize(
    ResizeHandle handle,
    Offset totalDelta, {
    bool keepAspect = false,
  }) {
    final origin = _resizeOrigin;
    if (origin == null || origin.locked) return;
    final square =
        origin.type == ElementType.qr || origin.type == ElementType.icon;
    final rect = resizeRotatedRect(
      rect: origin.rect,
      rotation: origin.rotation,
      handle: handle,
      delta: totalDelta,
      keepAspect:
          keepAspect ||
          square ||
          (origin.type == ElementType.image && handle.isCorner),
      minSize: 1,
    );
    updateElement(
      origin.id,
      (e) => e.copyWith(
        x: rect.left,
        y: rect.top,
        width: rect.width,
        height: rect.height,
      ),
      record: false,
    );
  }

  void beginRotate(String id) {
    beginTransaction();
    _resizeOrigin = page.elementById(id);
  }

  void dragRotate(Offset pointerMm, {bool snap = true}) {
    final origin = _resizeOrigin;
    if (origin == null || origin.locked) return;
    final angle = rotationFromPointer(origin.center, pointerMm, snap: snap);
    updateElement(
      origin.id,
      (e) => e.copyWith(rotation: angle > 180 ? angle - 360 : angle),
      record: false,
    );
  }

  // ------------------------------------------------------------ document

  void setBackground(Fill fill) => _commitPage(page.copyWith(background: fill));

  /// Remplace la face courante (modification par l'agent IA) : une étape.
  void replacePage(DesignPage next) {
    _commitPage(next);
    _pruneSelection();
    _notify();
  }

  void replaceDocument(DesignDocument next) {
    _commit(next);
    _pageIndex = math.min(_pageIndex, next.pages.length - 1);
    _selection = {};
    _notify();
  }

  void resizeDocument(
    double widthMm,
    double heightMm, {
    String? formatId,
    bool scaleContent = true,
  }) {
    if (widthMm <= 0 || heightMm <= 0) return;
    final resized = document.resized(
      widthMm,
      heightMm,
      scaleContent: scaleContent,
    );
    _commit(resized.copyWith(formatId: formatId ?? 'custom'));
  }

  void rename(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == _project.name) return;
    _project = _project.copyWith(name: trimmed, updatedAt: DateTime.now());
    _scheduleSave();
    _notify();
  }

  // ------------------------------------------------------------ vue

  void setZoom(double value) {
    zoom = value.clamp(0.2, 6.0);
    _notify();
  }

  void toggleGrid() {
    showGrid = !showGrid;
    _notify();
  }

  void toggleSnapToGrid() {
    snapToGrid = !snapToGrid;
    _notify();
  }

  void toggleSmartGuides() {
    smartGuides = !smartGuides;
    _notify();
  }

  void setGridSize(double mm) {
    gridMm = mm.clamp(1, 50);
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _saveTimer?.cancel();
    if (saveState != SaveState.saved && onSave != null) {
      unawaited(onSave!(_project).catchError((_) {}));
    }
    super.dispose();
  }
}

extension on Set<String> {
  void toggle(String id) {
    if (!remove(id)) add(id);
  }
}
