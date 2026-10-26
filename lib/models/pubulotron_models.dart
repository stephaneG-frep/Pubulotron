import 'package:flutter/material.dart';

class BusinessProfile {
  BusinessProfile({
    required this.id,
    required this.name,
    required this.slogan,
    this.description = '',
    this.services = const <String>[],
    this.address = '',
    this.phone = '',
    this.email = '',
    this.website = '',
    this.socials = const <String>[],
    this.hours = '',
    this.brandColors = const <Color>[],
  });

  final String id;
  final String name;
  final String slogan;
  final String description;
  final List<String> services;
  final String address;
  final String phone;
  final String email;
  final String website;
  final List<String> socials;
  final String hours;
  final List<Color> brandColors;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'slogan': slogan,
    'description': description,
    'services': services,
    'address': address,
    'phone': phone,
    'email': email,
    'website': website,
    'socials': socials,
    'hours': hours,
    'brandColors': brandColors.map((color) => color.toARGB32()).toList(),
  };

  factory BusinessProfile.fromJson(
    Map<String, dynamic> json,
  ) => BusinessProfile(
    id:
        json['id'] as String? ??
        'profile-${DateTime.now().millisecondsSinceEpoch}',
    name: json['name'] as String? ?? 'Mon activité',
    slogan: json['slogan'] as String? ?? '',
    description: json['description'] as String? ?? '',
    services: List<String>.from(json['services'] as List? ?? const <String>[]),
    address: json['address'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
    email: json['email'] as String? ?? '',
    website: json['website'] as String? ?? '',
    socials: List<String>.from(json['socials'] as List? ?? const <String>[]),
    hours: json['hours'] as String? ?? '',
    brandColors: ((json['brandColors'] as List?) ?? const <int>[])
        .map((value) => Color(value as int))
        .toList(),
  );
}

class DesignConcept {
  DesignConcept({
    required this.title,
    required this.style,
    required this.palette,
    required this.slogan,
    required this.summary,
    this.provider = 'local',
  });

  final String title;
  final String style;
  final String palette;
  final String slogan;
  final String summary;
  final String provider;

  Map<String, dynamic> toJson() => {
    'title': title,
    'style': style,
    'palette': palette,
    'slogan': slogan,
    'summary': summary,
    'provider': provider,
  };

  factory DesignConcept.fromJson(Map<String, dynamic> json) => DesignConcept(
    title: json['title'] as String? ?? 'Concept',
    style: json['style'] as String? ?? 'Premium',
    palette: json['palette'] as String? ?? '',
    slogan: json['slogan'] as String? ?? '',
    summary: json['summary'] as String? ?? '',
    provider: json['provider'] as String? ?? 'local',
  );
}

class TemplateCard {
  const TemplateCard({
    required this.id,
    required this.title,
    required this.category,
    required this.accent,
    required this.tag,
    required this.icon,
    required this.description,
  });

  final String id;
  final String title;
  final String category;
  final Color accent;
  final String tag;
  final IconData icon;
  final String description;
}

class GraphicProject {
  GraphicProject({
    required this.id,
    required this.name,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
    required this.elements,
  });

  final String id;
  final String name;
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<CreativeElement> elements;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'elements': elements.map((element) => element.toJson()).toList(),
  };

  factory GraphicProject.fromJson(Map<String, dynamic> json) => GraphicProject(
    id:
        json['id'] as String? ??
        'project-${DateTime.now().millisecondsSinceEpoch}',
    name: json['name'] as String? ?? 'Projet',
    description: json['description'] as String? ?? '',
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    updatedAt:
        DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
    elements: ((json['elements'] as List?) ?? const <Map<String, dynamic>>[])
        .map(
          (raw) =>
              CreativeElement.fromJson(Map<String, dynamic>.from(raw as Map)),
        )
        .toList(),
  );
}

class CreativeElement {
  CreativeElement(
    this.name,
    this.x,
    this.y,
    this.width,
    this.height,
    this.color,
    this.kind, {
    this.rotation = 0,
    this.opacity = 1,
    this.imagePath,
    this.locked = false,
    this.textContent,
    this.fontSize = 16,
  });

  String id = DateTime.now().microsecondsSinceEpoch.toString();
  String name;
  double x;
  double y;
  double width;
  double height;
  Color color;
  String kind;
  double rotation;
  double opacity;
  String? imagePath;
  bool locked;
  String? textContent;
  double fontSize;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'rotation': rotation,
    'opacity': opacity,
    'color': color.toARGB32(),
    'kind': kind,
    'imagePath': imagePath,
    'locked': locked,
    'textContent': textContent,
    'fontSize': fontSize,
  };

  factory CreativeElement.fromJson(Map<String, dynamic> json) =>
      CreativeElement(
          json['name'] as String? ?? 'Element',
          (json['x'] as num?)?.toDouble() ?? 0.0,
          (json['y'] as num?)?.toDouble() ?? 0.0,
          (json['width'] as num?)?.toDouble() ?? 120,
          (json['height'] as num?)?.toDouble() ?? 60,
          Color((json['color'] as num?)?.toInt() ?? 0xFF7545FF),
          json['kind'] as String? ?? 'text',
          rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
          opacity: (json['opacity'] as num?)?.toDouble() ?? 1,
          imagePath: json['imagePath'] as String?,
          locked: json['locked'] as bool? ?? false,
          textContent: json['textContent'] as String?,
          fontSize: (json['fontSize'] as num?)?.toDouble() ?? 16,
        )
        ..id =
            json['id'] as String? ??
            DateTime.now().microsecondsSinceEpoch.toString();
}

class PrintLayoutSpec {
  PrintLayoutSpec({
    required this.paperWidthMm,
    required this.paperHeightMm,
    required this.cardWidthMm,
    required this.cardHeightMm,
    required this.marginMm,
    required this.gapMm,
    required this.bleedMm,
    required this.copies,
    this.duplex = false,
    this.orientation = 'portrait',
  });

  final double paperWidthMm;
  final double paperHeightMm;
  final double cardWidthMm;
  final double cardHeightMm;
  final double marginMm;
  final double gapMm;
  final double bleedMm;
  final int copies;
  final bool duplex;
  final String orientation;

  Map<String, dynamic> toJson() => {
    'paperWidthMm': paperWidthMm,
    'paperHeightMm': paperHeightMm,
    'cardWidthMm': cardWidthMm,
    'cardHeightMm': cardHeightMm,
    'marginMm': marginMm,
    'gapMm': gapMm,
    'bleedMm': bleedMm,
    'copies': copies,
    'duplex': duplex,
    'orientation': orientation,
  };
}
