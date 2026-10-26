import 'package:barcode/barcode.dart';

import '../models/business_profile.dart';

enum QrKind { website, booking, contact, portfolio, catalog, social, text }

extension QrKindLabel on QrKind {
  String get label => switch (this) {
    QrKind.website => 'Site internet',
    QrKind.booking => 'Page de réservation',
    QrKind.contact => 'Coordonnées (vCard)',
    QrKind.portfolio => 'Portfolio',
    QrKind.catalog => 'Catalogue',
    QrKind.social => 'Réseau social',
    QrKind.text => 'Texte libre',
  };
}

class QrPayload {
  /// Normalise une adresse web : ajoute https:// si nécessaire.
  static String normalizeUrl(String input) {
    final value = input.trim();
    if (value.isEmpty) return '';
    final lower = value.toLowerCase();
    if (lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('mailto:') ||
        lower.startsWith('tel:')) {
      return value;
    }
    return 'https://$value';
  }

  static String _escape(String value) => value
      .replaceAll(r'\', r'\\')
      .replaceAll(';', r'\;')
      .replaceAll(',', r'\,')
      .replaceAll('\n', r'\n');

  /// vCard 3.0, lisible par les applications Contacts d'Android et iOS.
  static String vCard(BusinessProfile profile) {
    final lines = <String>['BEGIN:VCARD', 'VERSION:3.0'];
    final person = profile.contactName.trim();
    if (person.isNotEmpty) {
      final parts = person.split(RegExp(r'\s+'));
      final last = parts.length > 1 ? parts.last : '';
      final first = parts.length > 1
          ? parts.sublist(0, parts.length - 1).join(' ')
          : parts.first;
      lines.add('N:${_escape(last)};${_escape(first)};;;');
      lines.add('FN:${_escape(person)}');
    } else {
      lines.add('N:${_escape(profile.name)};;;;');
      lines.add('FN:${_escape(profile.name)}');
    }
    if (profile.name.isNotEmpty) lines.add('ORG:${_escape(profile.name)}');
    if (profile.jobTitle.isNotEmpty) {
      lines.add('TITLE:${_escape(profile.jobTitle)}');
    }
    if (profile.phone.isNotEmpty) {
      lines.add(
        'TEL;TYPE=WORK,VOICE:${profile.phone.replaceAll(RegExp(r'[^0-9+]'), '')}',
      );
    }
    if (profile.email.isNotEmpty) {
      lines.add('EMAIL;TYPE=WORK:${profile.email.trim()}');
    }
    if (profile.website.isNotEmpty) {
      lines.add('URL:${normalizeUrl(profile.website)}');
    }
    if (profile.address.isNotEmpty) {
      lines.add('ADR;TYPE=WORK:;;${_escape(profile.address)};;;;');
    }
    if (profile.slogan.isNotEmpty) lines.add('NOTE:${_escape(profile.slogan)}');
    lines.add('END:VCARD');
    return lines.join('\n');
  }

  /// Contenu proposé par défaut pour un type de QR code et un profil.
  static String forKind(
    QrKind kind,
    BusinessProfile profile, {
    String custom = '',
  }) {
    if (custom.trim().isNotEmpty && kind != QrKind.contact) {
      return kind == QrKind.text ? custom.trim() : normalizeUrl(custom);
    }
    return switch (kind) {
      QrKind.website => normalizeUrl(profile.website),
      QrKind.booking => normalizeUrl(
        profile.bookingUrl.isNotEmpty ? profile.bookingUrl : profile.website,
      ),
      QrKind.contact => vCard(profile),
      QrKind.portfolio => normalizeUrl(profile.portfolioUrl),
      QrKind.catalog => normalizeUrl(profile.catalogUrl),
      QrKind.social => normalizeUrl(
        profile.socials.isEmpty ? '' : profile.socials.first.url,
      ),
      QrKind.text => custom.trim(),
    };
  }

  static Barcode barcode() =>
      Barcode.qrCode(errorCorrectLevel: BarcodeQRCorrectionLevel.medium);

  static bool isEncodable(String data) =>
      data.isNotEmpty && barcode().isValid(data);

  /// Matrice du QR code (modules noirs) en coordonnées unitaires 0..1.
  static List<BarcodeBar> modules(String data) {
    if (!isEncodable(data)) return const [];
    return barcode()
        .make(data, width: 1, height: 1)
        .whereType<BarcodeBar>()
        .where((bar) => bar.black)
        .toList();
  }

  static String svg(String data, {double size = 300, int color = 0x000000}) =>
      barcode().toSvg(
        data,
        width: size,
        height: size,
        drawText: false,
        color: color,
      );
}
