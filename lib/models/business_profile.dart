import 'package:flutter/painting.dart';

import '../core/color_utils.dart';
import '../core/ids.dart';

class SocialLink {
  const SocialLink({required this.network, required this.url});

  final String network;
  final String url;

  Map<String, dynamic> toJson() => {'network': network, 'url': url};

  factory SocialLink.fromJson(Object? raw) {
    if (raw is String) return SocialLink(network: 'Lien', url: raw);
    final map = raw is Map ? raw : const {};
    return SocialLink(
      network: map['network'] as String? ?? 'Lien',
      url: map['url'] as String? ?? '',
    );
  }
}

/// Fiche d'identité professionnelle, réutilisable dans toutes les créations.
class BusinessProfile {
  BusinessProfile({
    String? id,
    required this.name,
    this.contactName = '',
    this.jobTitle = '',
    this.slogan = '',
    this.description = '',
    this.activity = '',
    this.services = const [],
    this.address = '',
    this.phone = '',
    this.email = '',
    this.website = '',
    this.bookingUrl = '',
    this.portfolioUrl = '',
    this.catalogUrl = '',
    this.socials = const [],
    this.hours = '',
    this.brandColors = const [],
    this.logoAssetId,
    DateTime? updatedAt,
  }) : id = id ?? newId('profile'),
       updatedAt = updatedAt ?? DateTime.now();

  final String id;

  /// Nom de l'activité ou de l'entreprise.
  final String name;
  final String contactName;
  final String jobTitle;
  final String slogan;
  final String description;

  /// Secteur d'activité (ex. « réparation informatique »).
  final String activity;
  final List<String> services;
  final String address;
  final String phone;
  final String email;
  final String website;
  final String bookingUrl;
  final String portfolioUrl;
  final String catalogUrl;
  final List<SocialLink> socials;
  final String hours;
  final List<Color> brandColors;
  final String? logoAssetId;
  final DateTime updatedAt;

  static BusinessProfile example() => BusinessProfile(
    id: 'profile-exemple',
    name: 'TechCare Réparations',
    contactName: 'Alex Martin',
    jobTitle: 'Technicien informatique',
    activity: 'Réparation et dépannage informatique',
    slogan: 'Ton PC, notre obsession.',
    description: 'Réparation, dépannage et conseil informatique à domicile.',
    services: const [
      'Diagnostic',
      'Réparation',
      'Récupération de données',
      'Installation',
    ],
    address: '12 rue des Lilas, 69003 Lyon',
    phone: '06 12 34 56 78',
    email: 'contact@techcare-repair.fr',
    website: 'techcare-repair.fr',
    hours: 'Lun–Ven 9h–19h, Sam 10h–16h',
    brandColors: const [
      Color(0xFF7545FF),
      Color(0xFF24C9C2),
      Color(0xFFFFAA45),
    ],
  );

  BusinessProfile copyWith({
    String? id,
    String? name,
    String? contactName,
    String? jobTitle,
    String? slogan,
    String? description,
    String? activity,
    List<String>? services,
    String? address,
    String? phone,
    String? email,
    String? website,
    String? bookingUrl,
    String? portfolioUrl,
    String? catalogUrl,
    List<SocialLink>? socials,
    String? hours,
    List<Color>? brandColors,
    Object? logoAssetId = _keep,
    DateTime? updatedAt,
  }) => BusinessProfile(
    id: id ?? this.id,
    name: name ?? this.name,
    contactName: contactName ?? this.contactName,
    jobTitle: jobTitle ?? this.jobTitle,
    slogan: slogan ?? this.slogan,
    description: description ?? this.description,
    activity: activity ?? this.activity,
    services: services ?? this.services,
    address: address ?? this.address,
    phone: phone ?? this.phone,
    email: email ?? this.email,
    website: website ?? this.website,
    bookingUrl: bookingUrl ?? this.bookingUrl,
    portfolioUrl: portfolioUrl ?? this.portfolioUrl,
    catalogUrl: catalogUrl ?? this.catalogUrl,
    socials: socials ?? this.socials,
    hours: hours ?? this.hours,
    brandColors: brandColors ?? this.brandColors,
    logoAssetId: identical(logoAssetId, _keep)
        ? this.logoAssetId
        : logoAssetId as String?,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// Champs insérables automatiquement dans une création.
  Map<String, String> get insertableFields => {
    'Nom de l’activité': name,
    'Slogan': slogan,
    'Contact': [contactName, jobTitle].where((s) => s.isNotEmpty).join(' — '),
    'Description': description,
    'Prestations': services.join(' • '),
    'Adresse': address,
    'Téléphone': phone,
    'E-mail': email,
    'Site internet': website,
    'Horaires': hours,
    'Réseaux sociaux': socials.map((s) => '${s.network} : ${s.url}').join('\n'),
  }..removeWhere((_, value) => value.trim().isEmpty);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'contactName': contactName,
    'jobTitle': jobTitle,
    'slogan': slogan,
    'description': description,
    'activity': activity,
    'services': services,
    'address': address,
    'phone': phone,
    'email': email,
    'website': website,
    'bookingUrl': bookingUrl,
    'portfolioUrl': portfolioUrl,
    'catalogUrl': catalogUrl,
    'socials': socials.map((s) => s.toJson()).toList(),
    'hours': hours,
    'brandColors': brandColors.map(colorToHex).toList(),
    if (logoAssetId != null) 'logoAssetId': logoAssetId,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory BusinessProfile.fromJson(Map<String, dynamic> json) =>
      BusinessProfile(
        id: json['id'] as String?,
        name: json['name'] as String? ?? 'Mon activité',
        contactName: json['contactName'] as String? ?? '',
        jobTitle: json['jobTitle'] as String? ?? '',
        slogan: json['slogan'] as String? ?? '',
        description: json['description'] as String? ?? '',
        activity: json['activity'] as String? ?? '',
        services: ((json['services'] as List?) ?? const [])
            .whereType<String>()
            .toList(),
        address: json['address'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        email: json['email'] as String? ?? '',
        website: json['website'] as String? ?? '',
        bookingUrl: json['bookingUrl'] as String? ?? '',
        portfolioUrl: json['portfolioUrl'] as String? ?? '',
        catalogUrl: json['catalogUrl'] as String? ?? '',
        socials: ((json['socials'] as List?) ?? const [])
            .map(SocialLink.fromJson)
            .where((s) => s.url.isNotEmpty)
            .toList(),
        hours: json['hours'] as String? ?? '',
        brandColors: ((json['brandColors'] as List?) ?? const [])
            .map(parseHexColor)
            .whereType<Color>()
            .toList(),
        logoAssetId: json['logoAssetId'] as String?,
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
      );
}

const _keep = Object();
