import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../ai/ai_client.dart';
import '../ai/ai_design_service.dart';
import '../data/app_database.dart';
import '../data/asset_store.dart';
import '../data/backup_service.dart';
import '../data/repositories.dart';
import '../data/secret_store.dart';
import '../engine/image_cache.dart';
import '../export/file_service.dart';
import '../history/history_service.dart';
import '../export/raster_exporter.dart';
import '../models/app_settings.dart';
import '../print/pdf_exporter.dart';
import '../review/design_review.dart';
import '../variants/variant_service.dart';

/// Ensemble des services de l'application, créés une seule fois au démarrage.
class AppServices {
  AppServices({
    required this.database,
    required this.assets,
    required this.secrets,
    required this.files,
    required this.initialSettings,
    http.Client? httpClient,
  }) : projects = ProjectRepository(database),
       profiles = ProfileRepository(database),
       templates = TemplateRepository(database),
       settings = SettingsRepository(database),
       versions = VersionRepository(database),
       aiClient = AiClient(httpClient: httpClient) {
    images = DesignImageCache(assets);
    aiDesign = AiDesignService(aiClient);
    history = HistoryService(
      versions,
      policy: HistoryPolicy(maxVersions: initialSettings.historyMaxVersions),
    );
    variants = VariantService(aiDesign);
    review = DesignReviewService(aiDesign);
    backup = BackupService(
      projects: projects,
      profiles: profiles,
      templates: templates,
      settings: settings,
      assets: assets,
      versions: versions,
    );
    pdf = PdfExporter(store: assets);
    raster = RasterExporter(images);
  }

  final AppDatabase database;
  final AssetStore assets;
  final SecretStore secrets;
  final FileService files;
  final AppSettings initialSettings;
  final ProjectRepository projects;
  final ProfileRepository profiles;
  final TemplateRepository templates;
  final SettingsRepository settings;
  final VersionRepository versions;
  final AiClient aiClient;
  late final DesignImageCache images;
  late final AiDesignService aiDesign;
  late final HistoryService history;
  late final VariantService variants;
  late final DesignReviewService review;
  late final BackupService backup;
  late final PdfExporter pdf;
  late final RasterExporter raster;

  static const settingsKey = 'app';
  static const databaseName = 'pubulotron.db';
  static const legacyDatabaseName = 'pubulotron_projects.db';

  /// Ouvre la base locale dans le dossier de l'application.
  static Future<AppServices> open({
    Directory? baseDirectory,
    DatabaseFactory? factory,
    SecretStore? secrets,
    FileService? files,
    http.Client? httpClient,
  }) async {
    final base = baseDirectory ?? await getApplicationSupportDirectory();
    await base.create(recursive: true);
    final dbPath = p.join(base.path, databaseName);
    if (baseDirectory == null) await _migrateLegacyDatabase(dbPath);
    final dbFactory = factory ?? _platformFactory();
    final database = await AppDatabase.open(dbPath, factory: dbFactory);
    final settingsJson = await SettingsRepository(database).read(settingsKey);
    return AppServices(
      database: database,
      assets: AssetStore(Directory(p.join(base.path, 'media'))),
      secrets: secrets ?? const SecureSecretStore(),
      files: files ?? const PlatformFileService(),
      initialSettings: settingsJson == null
          ? const AppSettings()
          : AppSettings.fromJson(settingsJson),
      httpClient: httpClient,
    );
  }

  static DatabaseFactory _platformFactory() {
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      sqfliteFfiInit();
      return databaseFactoryFfi;
    }
    return sqflite.databaseFactorySqflitePlugin;
  }

  /// La première version enregistrait sa base dans le dossier Documents :
  /// elle est copiée (sans être supprimée) pour conserver les projets.
  static Future<void> _migrateLegacyDatabase(String newPath) async {
    try {
      if (await File(newPath).exists()) return;
      final documents = await getApplicationDocumentsDirectory();
      final legacy = File(p.join(documents.path, legacyDatabaseName));
      if (await legacy.exists()) await legacy.copy(newPath);
    } catch (_) {
      // Migration facultative : une erreur ne doit pas bloquer le démarrage.
    }
  }

  Future<void> saveSettings(AppSettings value) =>
      settings.write(settingsKey, value.toJson());

  Future<void> dispose() async {
    aiClient.close();
    images.dispose();
    await database.close();
  }
}
