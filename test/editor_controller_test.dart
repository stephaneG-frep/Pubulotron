import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pubulotron/editor/editor_controller.dart';
import 'package:pubulotron/engine/geometry.dart';
import 'package:pubulotron/models/design_document.dart';
import 'package:pubulotron/models/design_element.dart';
import 'package:pubulotron/models/fill.dart';
import 'package:pubulotron/models/project.dart';

DesignElement text(
  String id, {
  double x = 10,
  double y = 10,
  bool locked = false,
}) => DesignElement(
  id: id,
  type: ElementType.text,
  text: id,
  x: x,
  y: y,
  width: 20,
  height: 8,
  locked: locked,
);

EditorController controllerWith(
  List<DesignElement> elements, {
  List<Project>? saved,
}) => EditorController(
  project: Project(
    name: 'Test',
    document: DesignDocument(
      widthMm: 85,
      heightMm: 55,
      pages: [DesignPage(elements: elements)],
    ),
  ),
  onSave: saved == null ? null : (p) async => saved.add(p),
  autosaveDelay: const Duration(milliseconds: 10),
);

void main() {
  test('add, modify, undo and redo', () {
    final c = controllerWith([]);
    c.addElement(text('a'));
    expect(c.page.elements, hasLength(1));
    expect(c.selection, {'a'});
    c.updateElement(
      'a',
      (e) => e.copyWith(text: 'Bonjour', color: const Color(0xFFFF0000)),
    );
    expect(c.page.elementById('a')!.text, 'Bonjour');
    c.undo();
    expect(c.page.elementById('a')!.text, 'a');
    c.redo();
    expect(c.page.elementById('a')!.text, 'Bonjour');
    c.undo();
    c.undo();
    expect(c.page.elements, isEmpty);
    expect(c.canUndo, isFalse);
    expect(c.canRedo, isTrue);
  });

  test('a drag gesture is a single undo step and snaps to the page centre', () {
    final c = controllerWith([text('a', x: 10, y: 10)]);
    c.select('a');
    c.beginMove();
    c.dragMove(const Offset(5, 0));
    c.dragMove(const Offset(10, 0));
    c.dragMove(
      const Offset(22, 0),
    ); // centre de l'élément à 42 → aimanté à 42,5
    expect(c.activeGuides, isNotEmpty);
    c.endTransaction();
    expect(c.page.elementById('a')!.x, closeTo(32.5, 1e-9));
    expect(c.activeGuides, isEmpty);
    c.undo();
    expect(c.page.elementById('a')!.x, 10);
  });

  test(
    'locked elements cannot be moved, deleted or edited by bulk actions',
    () {
      final c = controllerWith([text('a', locked: true), text('b', x: 40)]);
      c.selectAll();
      c.beginMove();
      c.dragMove(const Offset(5, 5), snap: false);
      c.endTransaction();
      expect(c.page.elementById('a')!.x, 10);
      expect(c.page.elementById('b')!.x, 45);
      c.deleteSelected();
      expect(c.page.elements.map((e) => e.id), ['a']);
      c.select('a');
      c.nudge(1, 0);
      expect(c.page.elementById('a')!.x, 10);
      c.lockSelected(false);
      c.nudge(1, 0);
      expect(c.page.elementById('a')!.x, 11);
    },
  );

  test('duplicate, copy/paste and layer ordering', () {
    final c = controllerWith([text('a'), text('b'), text('c')]);
    c.select('a');
    c.duplicateSelected();
    expect(c.page.elements, hasLength(4));
    final copy = c.page.elements.last;
    expect(copy.id, isNot('a'));
    expect(copy.x, 13);
    expect(c.selection, {copy.id});

    c.select('a');
    c.bringToFront();
    expect(c.page.elements.last.id, 'a');
    c.sendToBack();
    expect(c.page.elements.first.id, 'a');
    c.bringForward();
    expect(c.page.elements[1].id, 'a');
    c.reorderLayer(1, 3);
    expect(c.page.elements[3].id, 'a');

    c.select('b');
    c.copySelection();
    c.paste();
    expect(c.page.elements.where((e) => e.text == 'b'), hasLength(2));
  });

  test('resize and rotate through handles', () {
    final c = controllerWith([text('a')]);
    c.beginResize('a');
    c.dragResize(ResizeHandle.bottomRight, const Offset(10, 2));
    c.endTransaction();
    final e = c.page.elementById('a')!;
    expect([e.width, e.height], [30, 10]);
    c.beginRotate('a');
    c.dragRotate(Offset(e.center.dx + 10, e.center.dy));
    c.endTransaction();
    expect(c.page.elementById('a')!.rotation, 90);
    c.undo();
    expect(c.page.elementById('a')!.rotation, 0);
  });

  test('alignment, distribution and backgrounds', () {
    final c = controllerWith([
      text('a', x: 2),
      text('b', x: 30, y: 30),
      text('c', x: 60, y: 5),
    ]);
    c.selectAll();
    c.align(AlignMode.top);
    expect(c.page.elements.map((e) => e.y).toSet(), {5});
    c.select('a');
    c.align(AlignMode.centerH);
    expect(c.page.elementById('a')!.x, closeTo(32.5, 1e-9));
    c.setBackground(
      Fill.linear(const Color(0xFF000000), const Color(0xFFFFFFFF)),
    );
    expect(c.page.background.isGradient, isTrue);
  });

  test('recto verso pages', () {
    final c = controllerWith([text('a')]);
    c.addBackPage(copyFront: true);
    expect(c.document.isDuplex, isTrue);
    expect(c.pageIndex, 1);
    expect(c.page.elements.single.id, isNot('a'));
    c.addElement(text('verso'));
    expect(c.document.back!.elements, hasLength(2));
    expect(c.document.front.elements, hasLength(1));
    c.setPage(0);
    expect(c.page.elements.single.id, 'a');
    c.removeBackPage();
    expect(c.document.isDuplex, isFalse);
  });

  test('autosave persists the latest state', () async {
    final saved = <Project>[];
    final c = controllerWith([], saved: saved);
    c.addElement(text('a'));
    c.rename('Nouveau nom');
    expect(c.saveState, SaveState.pending);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(saved, isNotEmpty);
    expect(saved.last.name, 'Nouveau nom');
    expect(saved.last.document.front.elements.single.id, 'a');
    expect(c.saveState, SaveState.saved);
  });

  test('save errors are reported, not swallowed', () async {
    final c = EditorController(
      project: Project(
        name: 'x',
        document: DesignDocument.blank(widthMm: 10, heightMm: 10),
      ),
      onSave: (_) async => throw Exception('disque plein'),
    );
    c.addElement(text('a'));
    await c.saveNow();
    expect(c.saveState, SaveState.error);
    expect(c.saveError, contains('disque plein'));
  });
}
