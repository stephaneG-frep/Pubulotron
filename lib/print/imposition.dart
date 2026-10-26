import 'dart:math' as math;
import 'dart:ui';

enum SheetOrientation { portrait, landscape, auto }

/// Bord de retournement choisi dans le pilote d'impression recto verso.
enum DuplexFlip { longEdge, shortEdge }

class PrintLayoutException implements Exception {
  const PrintLayoutException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Paramètres d'impression multipose.
class PrintSettings {
  const PrintSettings({
    this.paperId = 'A4',
    this.paperWidthMm = 210,
    this.paperHeightMm = 297,
    this.orientation = SheetOrientation.auto,
    this.copies = 10,
    this.marginMm = 10,
    this.gapMm = 0,
    this.bleedMm = 0,
    this.cutMarks = true,
    this.duplex = false,
    this.flip = DuplexFlip.longEdge,
    this.center = true,
  });

  final String paperId;
  final double paperWidthMm;
  final double paperHeightMm;
  final SheetOrientation orientation;
  final int copies;
  final double marginMm;
  final double gapMm;
  final double bleedMm;
  final bool cutMarks;
  final bool duplex;
  final DuplexFlip flip;

  /// Centre la grille sur la feuille (sinon calée sur la marge haut-gauche).
  final bool center;

  PrintSettings copyWith({
    String? paperId,
    double? paperWidthMm,
    double? paperHeightMm,
    SheetOrientation? orientation,
    int? copies,
    double? marginMm,
    double? gapMm,
    double? bleedMm,
    bool? cutMarks,
    bool? duplex,
    DuplexFlip? flip,
    bool? center,
  }) => PrintSettings(
    paperId: paperId ?? this.paperId,
    paperWidthMm: paperWidthMm ?? this.paperWidthMm,
    paperHeightMm: paperHeightMm ?? this.paperHeightMm,
    orientation: orientation ?? this.orientation,
    copies: copies ?? this.copies,
    marginMm: marginMm ?? this.marginMm,
    gapMm: gapMm ?? this.gapMm,
    bleedMm: bleedMm ?? this.bleedMm,
    cutMarks: cutMarks ?? this.cutMarks,
    duplex: duplex ?? this.duplex,
    flip: flip ?? this.flip,
    center: center ?? this.center,
  );

  Map<String, dynamic> toJson() => {
    'paperId': paperId,
    'paperWidthMm': paperWidthMm,
    'paperHeightMm': paperHeightMm,
    'orientation': orientation.name,
    'copies': copies,
    'marginMm': marginMm,
    'gapMm': gapMm,
    'bleedMm': bleedMm,
    'cutMarks': cutMarks,
    'duplex': duplex,
    'flip': flip.name,
    'center': center,
  };

  factory PrintSettings.fromJson(Map<String, dynamic> json) {
    double d(String k, double f) => (json[k] as num?)?.toDouble() ?? f;
    return PrintSettings(
      paperId: json['paperId'] as String? ?? 'A4',
      paperWidthMm: d('paperWidthMm', 210),
      paperHeightMm: d('paperHeightMm', 297),
      orientation: SheetOrientation.values.firstWhere(
        (o) => o.name == json['orientation'],
        orElse: () => SheetOrientation.auto,
      ),
      copies: (json['copies'] as num?)?.toInt() ?? 10,
      marginMm: d('marginMm', 10),
      gapMm: d('gapMm', 0),
      bleedMm: d('bleedMm', 0),
      cutMarks: json['cutMarks'] as bool? ?? true,
      duplex: json['duplex'] as bool? ?? false,
      flip: DuplexFlip.values.firstWhere(
        (f) => f.name == json['flip'],
        orElse: () => DuplexFlip.longEdge,
      ),
      center: json['center'] as bool? ?? true,
    );
  }
}

class ImpositionSlot {
  const ImpositionSlot({
    required this.copyIndex,
    required this.sheet,
    required this.column,
    required this.row,
    required this.trim,
  });

  final int copyIndex;
  final int sheet;
  final int column;
  final int row;

  /// Zone de coupe (format fini) sur la feuille, en mm.
  final Rect trim;
}

class CutMark {
  const CutMark(this.from, this.to);
  final Offset from;
  final Offset to;
}

/// Résultat du calcul de disposition.
class Imposition {
  Imposition._({
    required this.sheetWidthMm,
    required this.sheetHeightMm,
    required this.cardWidthMm,
    required this.cardHeightMm,
    required this.columns,
    required this.rows,
    required this.copies,
    required this.bleedMm,
    required this.gapMm,
    required this.gridRect,
    required this.landscape,
    required this.mirrorBackHorizontally,
    required this.slots,
    required this.cutMarks,
  });

  /// Distance entre le bord du fond perdu et le début d'un trait de coupe.
  static const double cutMarkOffset = 1.5;
  static const double cutMarkMaxLength = 5;
  static const double cutMarkMinLength = 2;

  final double sheetWidthMm;
  final double sheetHeightMm;
  final double cardWidthMm;
  final double cardHeightMm;
  final int columns;
  final int rows;
  final int copies;
  final double bleedMm;
  final double gapMm;

  /// Emprise de la grille (fonds perdus compris).
  final Rect gridRect;
  final bool landscape;

  /// Verso miroir gauche-droite (sinon haut-bas).
  final bool mirrorBackHorizontally;
  final List<ImpositionSlot> slots;
  final List<CutMark> cutMarks;

  int get perSheet => columns * rows;

  int get sheetCount => (copies / perSheet).ceil();

  /// Exemplaires imprimés sur la dernière feuille.
  int get lastSheetCount => copies - (sheetCount - 1) * perSheet;

  /// Taux d'utilisation du papier (format fini).
  double get paperUsage =>
      perSheet * cardWidthMm * cardHeightMm / (sheetWidthMm * sheetHeightMm);

  Iterable<ImpositionSlot> slotsForSheet(int sheet) =>
      slots.where((s) => s.sheet == sheet);

  /// Position du verso correspondant à un emplacement, pour que recto et
  /// verso se superposent après retournement de la feuille.
  Rect backTrim(Rect front) => mirrorBackHorizontally
      ? Rect.fromLTWH(
          sheetWidthMm - front.left - front.width,
          front.top,
          front.width,
          front.height,
        )
      : Rect.fromLTWH(
          front.left,
          sheetHeightMm - front.top - front.height,
          front.width,
          front.height,
        );

  static Imposition compute({
    required PrintSettings settings,
    required double cardWidthMm,
    required double cardHeightMm,
  }) {
    final s = settings;
    final values = [
      s.paperWidthMm,
      s.paperHeightMm,
      cardWidthMm,
      cardHeightMm,
      s.marginMm,
      s.gapMm,
      s.bleedMm,
    ];
    if (values.any((v) => !v.isFinite)) {
      throw const PrintLayoutException(
        'Les dimensions doivent être des nombres valides.',
      );
    }
    if (s.paperWidthMm <= 0 || s.paperHeightMm <= 0) {
      throw const PrintLayoutException(
        'Le format de papier doit être positif.',
      );
    }
    if (cardWidthMm <= 0 || cardHeightMm <= 0) {
      throw const PrintLayoutException(
        'Le format de la création doit être positif.',
      );
    }
    if (s.marginMm < 0 || s.gapMm < 0 || s.bleedMm < 0) {
      throw const PrintLayoutException(
        'Marges, espacement et fond perdu ne peuvent pas être négatifs.',
      );
    }
    if (s.copies < 1) {
      throw const PrintLayoutException(
        'Le nombre d’exemplaires doit être au moins 1.',
      );
    }
    if (s.copies > 100000) {
      throw const PrintLayoutException(
        'Nombre d’exemplaires trop élevé (maximum 100 000).',
      );
    }

    Imposition build(bool landscape) {
      final short = math.min(s.paperWidthMm, s.paperHeightMm);
      final long = math.max(s.paperWidthMm, s.paperHeightMm);
      final sheetW = landscape ? long : short;
      final sheetH = landscape ? short : long;
      final cellW = cardWidthMm + 2 * s.bleedMm;
      final cellH = cardHeightMm + 2 * s.bleedMm;
      const eps = 1e-6;
      final cols =
          ((sheetW - 2 * s.marginMm + s.gapMm + eps) / (cellW + s.gapMm))
              .floor();
      final rows =
          ((sheetH - 2 * s.marginMm + s.gapMm + eps) / (cellH + s.gapMm))
              .floor();
      if (cols < 1 || rows < 1) {
        String f(double v) => v == v.roundToDouble()
            ? v.toStringAsFixed(0)
            : v.toStringAsFixed(1);
        final usableW = math.max(0.0, sheetW - 2 * s.marginMm);
        final usableH = math.max(0.0, sheetH - 2 * s.marginMm);
        throw PrintLayoutException(
          'La création (${f(cellW)} × ${f(cellH)} mm avec le fond perdu) ne tient pas dans la zone '
          'imprimable de la feuille (${f(usableW)} × ${f(usableH)} mm). '
          'Choisissez un papier plus grand, l’orientation automatique ou des marges plus petites.',
        );
      }
      final gridW = cols * cellW + (cols - 1) * s.gapMm;
      final gridH = rows * cellH + (rows - 1) * s.gapMm;
      final originX = s.center ? (sheetW - gridW) / 2 : s.marginMm;
      final originY = s.center ? (sheetH - gridH) / 2 : s.marginMm;
      final grid = Rect.fromLTWH(originX, originY, gridW, gridH);

      final perSheet = cols * rows;
      final slots = <ImpositionSlot>[
        for (var i = 0; i < s.copies; i++)
          () {
            final pos = i % perSheet;
            final c = pos % cols;
            final r = pos ~/ cols;
            return ImpositionSlot(
              copyIndex: i,
              sheet: i ~/ perSheet,
              column: c,
              row: r,
              trim: Rect.fromLTWH(
                originX + c * (cellW + s.gapMm) + s.bleedMm,
                originY + r * (cellH + s.gapMm) + s.bleedMm,
                cardWidthMm,
                cardHeightMm,
              ),
            );
          }(),
      ];

      final marks = <CutMark>[];
      if (s.cutMarks) {
        final available = math.min(grid.left, grid.top);
        final length = math.min(cutMarkMaxLength, available - cutMarkOffset);
        if (length < cutMarkMinLength) {
          throw PrintLayoutException(
            'Marge insuffisante pour les traits de découpe : prévoyez au moins '
            '${(cutMarkOffset + cutMarkMinLength).toStringAsFixed(1)} mm autour des créations.',
          );
        }
        final xs = <double>{};
        final ys = <double>{};
        for (var c = 0; c < cols; c++) {
          final left = originX + c * (cellW + s.gapMm) + s.bleedMm;
          xs.addAll([left, left + cardWidthMm]);
        }
        for (var r = 0; r < rows; r++) {
          final top = originY + r * (cellH + s.gapMm) + s.bleedMm;
          ys.addAll([top, top + cardHeightMm]);
        }
        for (final x in xs) {
          marks.add(
            CutMark(
              Offset(x, grid.top - cutMarkOffset - length),
              Offset(x, grid.top - cutMarkOffset),
            ),
          );
          marks.add(
            CutMark(
              Offset(x, grid.bottom + cutMarkOffset),
              Offset(x, grid.bottom + cutMarkOffset + length),
            ),
          );
        }
        for (final y in ys) {
          marks.add(
            CutMark(
              Offset(grid.left - cutMarkOffset - length, y),
              Offset(grid.left - cutMarkOffset, y),
            ),
          );
          marks.add(
            CutMark(
              Offset(grid.right + cutMarkOffset, y),
              Offset(grid.right + cutMarkOffset + length, y),
            ),
          );
        }
      }

      final longEdge = s.flip == DuplexFlip.longEdge;
      return Imposition._(
        sheetWidthMm: sheetW,
        sheetHeightMm: sheetH,
        cardWidthMm: cardWidthMm,
        cardHeightMm: cardHeightMm,
        columns: cols,
        rows: rows,
        copies: s.copies,
        bleedMm: s.bleedMm,
        gapMm: s.gapMm,
        gridRect: grid,
        landscape: landscape,
        mirrorBackHorizontally: landscape ? !longEdge : longEdge,
        slots: slots,
        cutMarks: marks,
      );
    }

    switch (s.orientation) {
      case SheetOrientation.portrait:
        return build(false);
      case SheetOrientation.landscape:
        return build(true);
      case SheetOrientation.auto:
        Imposition? portrait;
        Imposition? landscape;
        PrintLayoutException? error;
        try {
          portrait = build(false);
        } on PrintLayoutException catch (e) {
          error = e;
        }
        try {
          landscape = build(true);
        } on PrintLayoutException catch (e) {
          error ??= e;
        }
        if (portrait == null && landscape == null) throw error!;
        if (portrait == null) return landscape!;
        if (landscape == null) return portrait;
        return landscape.perSheet > portrait.perSheet ? landscape : portrait;
    }
  }
}
