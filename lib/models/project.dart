import '../core/ids.dart';
import 'design_document.dart';

/// Projet sauvegardé : un document plus ses métadonnées.
class Project {
  Project({
    String? id,
    required this.name,
    required this.document,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.brief = '',
    this.profileId,
    this.packId,
    this.packRole,
  }) : id = id ?? newId('proj'),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  final String id;
  final String name;
  final DesignDocument document;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Brief ou description d'origine (demande IA, notes).
  final String brief;
  final String? profileId;

  /// Identifiant du pack publicitaire auquel appartient le projet.
  final String? packId;

  /// Support dans le pack (carte, flyer, affiche…).
  final String? packRole;

  Project copyWith({
    String? id,
    String? name,
    DesignDocument? document,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? brief,
    String? profileId,
    String? packId,
    String? packRole,
  }) => Project(
    id: id ?? this.id,
    name: name ?? this.name,
    document: document ?? this.document,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    brief: brief ?? this.brief,
    profileId: profileId ?? this.profileId,
    packId: packId ?? this.packId,
    packRole: packRole ?? this.packRole,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'brief': brief,
    if (profileId != null) 'profileId': profileId,
    if (packId != null) 'packId': packId,
    if (packRole != null) 'packRole': packRole,
    'document': document.toJson(),
  };

  factory Project.fromJson(Map<String, dynamic> json) => Project(
    id: json['id'] as String?,
    name: json['name'] as String? ?? 'Projet',
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
    brief: json['brief'] as String? ?? json['description'] as String? ?? '',
    profileId: json['profileId'] as String?,
    packId: json['packId'] as String?,
    packRole: json['packRole'] as String?,
    document: DesignDocument.fromJson(
      Map<String, dynamic>.from(json['document'] as Map? ?? const {}),
    ),
  );
}

/// Modèle personnalisé enregistré par l'utilisateur.
class CustomTemplate {
  CustomTemplate({
    String? id,
    required this.name,
    required this.category,
    required this.document,
    this.description = '',
    DateTime? createdAt,
  }) : id = id ?? newId('tpl'),
       createdAt = createdAt ?? DateTime.now();

  final String id;
  final String name;
  final String category;
  final String description;
  final DesignDocument document;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'description': description,
    'createdAt': createdAt.toIso8601String(),
    'document': document.toJson(),
  };

  factory CustomTemplate.fromJson(Map<String, dynamic> json) => CustomTemplate(
    id: json['id'] as String?,
    name: json['name'] as String? ?? 'Modèle',
    category: json['category'] as String? ?? 'Mes modèles',
    description: json['description'] as String? ?? '',
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    document: DesignDocument.fromJson(
      Map<String, dynamic>.from(json['document'] as Map? ?? const {}),
    ),
  );
}
