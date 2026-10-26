/// Conversions d'unités utilisées par tout le moteur graphique.
///
/// Les documents sont décrits en millimètres et les tailles de police en
/// points typographiques (1 pt = 1/72 pouce), comme en imprimerie.
library;

const double mmPerInch = 25.4;
const double pointsPerInch = 72.0;

/// Nombre de points PDF dans un millimètre.
const double pdfPointsPerMm = pointsPerInch / mmPerInch;

/// Millimètres dans un point typographique.
const double mmPerPoint = mmPerInch / pointsPerInch;

double mmToPdf(double mm) => mm * pdfPointsPerMm;

double pointsToMm(double pt) => pt * mmPerPoint;

double mmToPixels(double mm, double dpi) => mm / mmPerInch * dpi;

double pixelsToMm(double px, double dpi) => px / dpi * mmPerInch;

/// Taille en pixels (arrondie) d'une longueur en millimètres à une résolution.
int mmToPixelCount(double mm, double dpi) => mmToPixels(mm, dpi).round();

double degToRad(double degrees) => degrees * 3.141592653589793 / 180.0;

double radToDeg(double radians) => radians * 180.0 / 3.141592653589793;

/// Arrondit à un dixième de millimètre pour l'affichage et les comparaisons.
double roundMm(double value) => (value * 10).roundToDouble() / 10;

String formatMm(double value) {
  final rounded = roundMm(value);
  return rounded == rounded.roundToDouble()
      ? rounded.toStringAsFixed(0)
      : rounded.toStringAsFixed(1);
}
