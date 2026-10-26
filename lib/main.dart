import 'dart:async' show TimeoutException;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import 'models/pubulotron_models.dart';
import 'repositories/project_repository.dart';
import 'services/ai_service.dart';
import 'services/ai_design_service.dart';
import 'services/pdf_service.dart';
import 'services/template_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
    databaseFactory = databaseFactoryFfi;
  }
  runApp(const PubulotronApp());
}

class PubulotronApp extends StatelessWidget {
  const PubulotronApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF7545FF),
      brightness: Brightness.dark,
    );

    return MaterialApp(
      title: 'Pubulotron',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        cardTheme: const CardThemeData(elevation: 0, margin: EdgeInsets.zero),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF111827),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      home: const PubulotronShell(),
    );
  }
}

class PubulotronShell extends StatefulWidget {
  const PubulotronShell({super.key});

  @override
  State<PubulotronShell> createState() => _PubulotronShellState();
}

class _PubulotronShellState extends State<PubulotronShell> {
  static const _storage = FlutterSecureStorage();
  static const List<String> _providers = [
    'OpenAI',
    'Claude',
    'Gemini',
    'Mistral',
  ];

  final _promptController = TextEditingController(
    text: 'Je suis réparateur informatique. Crée-moi une carte de visite futuriste avec un fond bleu électrique, mon téléphone, mon email et un QR code vers mon site internet.',
  );
  final _companyController = TextEditingController(
    text: 'TechCare Réparations',
  );
  final _sloganController = TextEditingController(
    text: 'Ton PC, notre obsession.',
  );
  final _phoneController = TextEditingController(text: '+33 6 12 34 56 78');
  final _emailController = TextEditingController(
    text: 'contact@techcare-repair.fr',
  );
  final _websiteController = TextEditingController(text: 'techcare-repair.fr');
  final _qrController = TextEditingController(
    text: 'https://techcare-repair.fr',
  );
  final _copiesController = TextEditingController(text: '12');
  final _cardWidthController = TextEditingController(text: '85');
  final _cardHeightController = TextEditingController(text: '55');
  final _marginController = TextEditingController(text: '12');
  final _gapController = TextEditingController(text: '6');
  final _bleedController = TextEditingController(text: '2');
  final _apiKeyController = TextEditingController();

  final _picker = ImagePicker();
  final _projectRepository = ProjectRepository();
  final List<GraphicProject> _savedProjects = <GraphicProject>[];
  final List<DesignConcept> _concepts = <DesignConcept>[];
  final List<CreativeElement> _canvasElements = <CreativeElement>[];
  final List<List<CreativeElement>> _history = <List<CreativeElement>>[];
  final List<TemplateCard> _templates = TemplateService.catalog;

  BusinessProfile _profile = BusinessProfile(
    id: 'default-profile',
    name: 'TechCare Réparations',
    slogan: 'Ton PC, notre obsession.',
    description: 'Service de réparation informatique et conseil digital.',
    services: ['Diagnostics', 'Réparations', 'Mises à jour', 'Conseils'],
    phone: '+33 6 12 34 56 78',
    email: 'contact@techcare-repair.fr',
    website: 'techcare-repair.fr',
    hours: 'Lun-Ven, 9h-18h',
    brandColors: const [
      Color(0xFF7545FF),
      Color(0xFF24C9C2),
      Color(0xFFFFAA45),
    ],
  );

  int _selectedIndex = 0;
  int _selectedCanvasIndex = -1;
  String _selectedProvider = _providers.first;
  String _apiKey = '';
  String? _aiConnectionMessage;
  bool _isTestingAiConnection = false;
  bool _darkMode = true;
  bool _showGrid = true;
  bool _showGuides = true;
  bool _cutMarks = true;
  String _paperSize = 'A4';
  String _orientation = 'portrait';
  DesignConcept? _selectedConcept;

  @override
  void initState() {
    super.initState();
    _seedCanvas();
    _loadAiSettings();
    _loadProfiles();
    _loadProjects();
    _generateConcepts();
  }

  @override
  void dispose() {
    _promptController.dispose();
    _companyController.dispose();
    _sloganController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _qrController.dispose();
    _copiesController.dispose();
    _cardWidthController.dispose();
    _cardHeightController.dispose();
    _marginController.dispose();
    _gapController.dispose();
    _bleedController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  void _seedCanvas() {
    _canvasElements
      ..clear()
      ..addAll([
        CreativeElement(
          'Titre',
          0.12,
          0.14,
          240,
          54,
          const Color(0xFF7545FF),
          'text',
          textContent: 'TechCare',
        ),
        CreativeElement(
          'Slogan',
          0.16,
          0.34,
          260,
          42,
          const Color(0xFF24C9C2),
          'text',
          textContent: 'Ton PC, notre obsession.',
        ),
        CreativeElement(
          'Photo',
          0.56,
          0.18,
          170,
          170,
          const Color(0xFF17213B),
          'image',
          imagePath: null,
        ),
        CreativeElement(
          'CTA',
          0.26,
          0.68,
          210,
          54,
          const Color(0xFFFF6384),
          'cta',
          textContent: 'Réparation express',
        ),
        CreativeElement(
          'Contact',
          0.08,
          0.78,
          260,
          64,
          const Color(0xFFAA8CFF),
          'text',
          textContent: '+33 6 12 34 56 78',
        ),
      ]);
    _selectedCanvasIndex = 0;
  }

  BusinessProfile _currentProfile() {
    return BusinessProfile(
      id: _profile.id,
      name: _companyController.text.trim().isEmpty
          ? _profile.name
          : _companyController.text.trim(),
      slogan: _sloganController.text.trim(),
      description: _profile.description,
      services: _profile.services,
      address: _profile.address,
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      website: _websiteController.text.trim(),
      socials: _profile.socials,
      hours: _profile.hours,
      brandColors: _profile.brandColors,
    );
  }

  void _applyTemplate(TemplateCard template) {
    final profile = _currentProfile();
    final dimensions = switch (template.id) {
      'business-card' => ('85', '55'),
      'salon-flyer' => ('148', '210'),
      'restaurant-menu' => ('210', '297'),
      'sale-poster' => ('297', '420'),
      _ => ('85', '55'),
    };
    _pushHistory();
    setState(() {
      _canvasElements
        ..clear()
        ..addAll(TemplateService.createElements(template.id, profile));
      _selectedCanvasIndex = -1;
      _cardWidthController.text = dimensions.$1;
      _cardHeightController.text = dimensions.$2;
      _selectedIndex = 2;
    });
  }

  void _startBlankCanvas() {
    _pushHistory();
    setState(() {
      _canvasElements.clear();
      _selectedCanvasIndex = -1;
      _cardWidthController.text = '85';
      _cardHeightController.text = '55';
      _selectedIndex = 2;
    });
  }

  Future<void> _loadAiSettings() async {
    try {
      final values = await Future.wait([
        _storage.read(key: 'pubulotron_api_key'),
        _storage.read(key: 'pubulotron_ai_provider'),
      ]);
      if (mounted) {
        setState(() {
          _apiKey = values[0] ?? '';
          _apiKeyController.text = _apiKey;
          if (_providers.contains(values[1])) {
            _selectedProvider = values[1]!;
          }
        });
      }
      if (_apiKey.isNotEmpty) await _generateConcepts();
    } on MissingPluginException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Stockage sécurisé indisponible : $error')),
        );
      }
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible de charger les paramètres IA : $error'),
          ),
        );
      }
    }
  }

  Future<void> _saveAiSettings() async {
    final apiKey = _apiKeyController.text.trim();
    try {
      if (apiKey.isEmpty) {
        await _storage.delete(key: 'pubulotron_api_key');
      } else {
        await _storage.write(key: 'pubulotron_api_key', value: apiKey);
      }
      await _storage.write(
        key: 'pubulotron_ai_provider',
        value: _selectedProvider,
      );
      if (!mounted) return;
      setState(() {
        _apiKey = apiKey;
        _aiConnectionMessage = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paramètres IA sauvegardés en sécurité.')),
      );
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Échec de la sauvegarde des paramètres IA : $error'),
        ),
      );
    }
  }

  Future<void> _testAiConnection() async {
    setState(() {
      _isTestingAiConnection = true;
      _aiConnectionMessage = null;
    });
    try {
      await AiService.testConnection(_selectedProvider, _apiKeyController.text);
      if (!mounted) return;
      setState(() {
        _aiConnectionMessage = 'Connexion réussie avec $_selectedProvider.';
      });
    } on SocketException {
      if (!mounted) return;
      setState(() {
        _aiConnectionMessage = 'Connexion réseau impossible. Vérifiez Internet et la résolution DNS du téléphone.';
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _aiConnectionMessage = 'Le fournisseur IA ne répond pas. Réessayez dans quelques instants.';
      });
    } on HttpException catch (error) {
      if (!mounted) return;
      setState(() {
        _aiConnectionMessage = 'Échec de la connexion : ${error.message}';
      });
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() {
        _aiConnectionMessage = error.message;
      });
    } on http.ClientException {
      if (!mounted) return;
      setState(() {
        _aiConnectionMessage = 'Impossible de joindre le fournisseur. Vérifiez Internet, le DNS ou un éventuel filtrage réseau.';
      });
    } on Exception {
      if (!mounted) return;
      setState(() {
        _aiConnectionMessage = 'Impossible de contacter le fournisseur. Vérifiez le réseau et la clé API.';
      });
    } finally {
      if (mounted) setState(() => _isTestingAiConnection = false);
    }
  }

  Future<void> _loadProfiles() async {
    final profiles = await _projectRepository.loadProfiles();
    if (!mounted || profiles.isEmpty) return;
    final first = profiles.first;
    setState(() {
      _profile = first;
      _companyController.text = first.name;
      _sloganController.text = first.slogan;
      _phoneController.text = first.phone;
      _emailController.text = first.email;
      _websiteController.text = first.website;
    });
  }

  Future<void> _saveProfile() async {
    final profile = BusinessProfile(
      id: _profile.id,
      name: _companyController.text.trim().isNotEmpty
          ? _companyController.text.trim()
          : 'Mon activité',
      slogan: _sloganController.text.trim(),
      description: _profile.description,
      services: _profile.services,
      address: _profile.address,
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      website: _websiteController.text.trim(),
      socials: _profile.socials,
      hours: _profile.hours,
      brandColors: _profile.brandColors,
    );
    _profile = profile;
    await _projectRepository.saveProfile(profile);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil professionnel sauvegardé.')),
      );
    }
  }

  Future<void> _loadProjects() async {
    final projects = await _projectRepository.loadProjects();
    if (!mounted) return;
    setState(() {
      _savedProjects
        ..clear()
        ..addAll(projects);
    });
  }

  Future<void> _saveCurrentProject() async {
    final project = GraphicProject(
      id: const Uuid().v4(),
      name: _companyController.text.trim().isNotEmpty
          ? _companyController.text.trim()
          : 'Projet sans titre',
      description: _promptController.text.trim(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      elements: List<CreativeElement>.from(_canvasElements),
    );
    await _projectRepository.saveProject(project);
    await _loadProjects();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Projet enregistré localement.')),
      );
    }
  }

  Future<void> _pickAndAddImage() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final element = CreativeElement(
      file.name,
      0.55,
      0.22,
      180,
      180,
      const Color(0xFF17213B),
      'image',
      imagePath: file.path,
    );
    setState(() {
      _canvasElements.add(element);
      _selectedCanvasIndex = _canvasElements.length - 1;
    });
  }

  void _pushHistory() {
    _history.add(
      List<CreativeElement>.from(
        _canvasElements.map(
          (element) => CreativeElement(
            element.name,
            element.x,
            element.y,
            element.width,
            element.height,
            element.color,
            element.kind,
            rotation: element.rotation,
            opacity: element.opacity,
            imagePath: element.imagePath,
            locked: element.locked,
            textContent: element.textContent,
            fontSize: element.fontSize,
          )..id = element.id,
        ),
      ),
    );
    if (_history.length > 20) {
      _history.removeAt(0);
    }
  }

  void _undo() {
    if (_history.isEmpty) return;
    final previous = _history.removeLast();
    setState(() {
      _canvasElements
        ..clear()
        ..addAll(previous);
      _selectedCanvasIndex = _canvasElements.isEmpty ? -1 : 0;
    });
  }

  void _addTextElement() {
    _pushHistory();
    setState(() {
      _canvasElements.add(
        CreativeElement(
          'Texte',
          0.24,
          0.26,
          220,
          60,
          const Color(0xFF7545FF),
          'text',
          textContent: 'Votre texte ici',
        ),
      );
      _selectedCanvasIndex = _canvasElements.length - 1;
    });
  }

  void _addShape() {
    _pushHistory();
    setState(() {
      _canvasElements.add(
        CreativeElement(
          'Forme',
          0.36,
          0.44,
          160,
          80,
          const Color(0xFFFFAA45),
          'shape',
        ),
      );
      _selectedCanvasIndex = _canvasElements.length - 1;
    });
  }

  void _duplicateSelected() {
    final index = _selectedCanvasIndex;
    if (index < 0 || index >= _canvasElements.length) return;
    _pushHistory();
    final element = _canvasElements[index];
    final clone = CreativeElement(
      '${element.name} copie',
      (element.x + 0.04).clamp(0.0, 1.0),
      (element.y + 0.04).clamp(0.0, 1.0),
      element.width,
      element.height,
      element.color,
      element.kind,
      rotation: element.rotation,
      opacity: element.opacity,
      imagePath: element.imagePath,
      locked: element.locked,
      textContent: element.textContent,
      fontSize: element.fontSize,
    );
    setState(() {
      _canvasElements.insert(index + 1, clone);
      _selectedCanvasIndex = index + 1;
    });
  }

  void _deleteSelected() {
    final index = _selectedCanvasIndex;
    if (index < 0 || index >= _canvasElements.length) return;
    _pushHistory();
    setState(() {
      _canvasElements.removeAt(index);
      _selectedCanvasIndex = index > 0 ? index - 1 : 0;
    });
  }

  Future<void> _generateConcepts() async {
    final concepts = await AiService.generateConcepts(
      _promptController.text,
      _selectedProvider,
      _apiKey,
    );
    if (!mounted) return;
    setState(() {
      _concepts
        ..clear()
        ..addAll(concepts);
      if (concepts.isNotEmpty) {
        _selectedConcept = concepts.first;
      }
    });
  }

  void _applyAiConcept(DesignConcept concept, int index) {
    _pushHistory();
    setState(() {
      _selectedConcept = concept;
      _canvasElements
        ..clear()
        ..addAll(
          AiDesignService.createComposition(
            concept: concept,
            profile: _currentProfile(),
            variant: index,
          ),
        );
      _selectedCanvasIndex = -1;
      _selectedIndex = 2;
      _cardWidthController.text = '85';
      _cardHeightController.text = '55';
    });
  }

  Future<void> _exportPdf() async {
    const paperDimensions = {
      'A4': (210.0, 297.0),
      'A3': (297.0, 420.0),
      'A5': (148.0, 210.0),
      'Lettre US': (215.9, 279.4),
    };
    double parseDimension(TextEditingController controller, String label) {
      final value = double.tryParse(controller.text.replaceAll(',', '.'));
      if (value == null || !value.isFinite) {
        throw ArgumentError('$label doit être un nombre valide.');
      }
      return value;
    }

    try {
      final (paperWidth, paperHeight) = paperDimensions[_paperSize]!;
      final spec = PrintLayoutSpec(
        paperWidthMm: paperWidth,
        paperHeightMm: paperHeight,
        cardWidthMm: parseDimension(_cardWidthController, 'La largeur'),
        cardHeightMm: parseDimension(_cardHeightController, 'La hauteur'),
        marginMm: parseDimension(_marginController, 'La marge'),
        gapMm: parseDimension(_gapController, 'L’espacement'),
        bleedMm: parseDimension(_bleedController, 'Le fond perdu'),
        copies: int.tryParse(_copiesController.text) ?? 0,
        duplex: false,
        orientation: _orientation,
      );
      final layout = PrintLayoutService.calculateLayout(
        spec,
        cutMarks: _cutMarks,
      );
      await PrintLayoutService.printMultiples(
        spec: spec,
        elements: _canvasElements,
        cutMarks: _cutMarks,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'PDF prêt : ${layout.placements.length} exemplaires, ${layout.pageCount} feuille(s), '
            '${layout.columns} × ${layout.rows} par feuille.',
          ),
        ),
      );
    } on ArgumentError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Paramètres d’impression invalides : ${error.message}'),
        ),
      );
    } on FileSystemException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Impossible de charger une image du projet : ${error.message}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Échec de la génération PDF : $error')),
      );
    }
  }

  Future<void> _restoreFromBackup() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final repo = ProjectRepository();
    await repo.restoreProjectFromArchive(File(file.path));
    await _loadProjects();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Projet restauré depuis l’archive.')),
      );
    }
  }

  List<NavigationRailDestination> get _railDestinations => const [
    NavigationRailDestination(
      icon: Icon(Icons.add_box_outlined),
      label: Text('Nouvelle création'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.auto_awesome),
      label: Text('Création avec l\'IA'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.design_services_outlined),
      label: Text('Atelier graphique'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.grid_view_rounded),
      label: Text('Modèles'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.folder_copy_outlined),
      label: Text('Mes projets'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.collections_bookmark_outlined),
      label: Text('Pack publicitaire'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.picture_as_pdf_outlined),
      label: Text('Imprimerie PDF'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.business_center_outlined),
      label: Text('Mon activité'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.settings_applications_outlined),
      label: Text('Paramètres IA'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.help_center_outlined),
      label: Text('Mode d\'emploi'),
    ),
  ];

  Widget _buildDestinationBody() {
    final screens = <Widget>[
      _buildNewCreationScreen(),
      _buildAiCreationScreen(),
      _buildStudioScreen(),
      _buildTemplateScreen(),
      _buildProjectsScreen(),
      _buildPackScreen(),
      _buildPrintScreen(),
      _buildIdentityScreen(),
      _buildAiSettingsScreen(),
      _buildHelpScreen(),
    ];
    return screens[_selectedIndex];
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 760;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF101828),
        foregroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.smart_toy_rounded, color: Color(0xFF24C9C2)),
            SizedBox(width: 12),
            Text('Pubulotron'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => setState(() => _darkMode = !_darkMode),
            icon: Icon(
              _darkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
          ),
        ],
      ),
      body: isWide
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (index) =>
                      setState(() => _selectedIndex = index),
                  extended: true,
                  backgroundColor: const Color(0xFF111827),
                  destinations: _railDestinations,
                ),
                const VerticalDivider(width: 1),
                Expanded(child: _buildDestinationBody()),
              ],
            )
          : SafeArea(
              child: Column(
                children: [
                  SizedBox(
                    height: 82,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      itemCount: _railDestinations.length,
                      itemBuilder: (context, index) {
                        final item = _railDestinations[index];
                        return GestureDetector(
                          onTap: () => setState(() => _selectedIndex = index),
                          child: Container(
                            width: 140,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: index == _selectedIndex
                                  ? const Color(0xFF7545FF)
                                        .withValues(alpha: 0.18)
                                  : const Color(0xFF1F2937),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                item.icon,
                                const SizedBox(width: 8),
                                Flexible(child: item.label),
                              ],
                            ),
                          ),
                        );
                      },
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 8),
                    ),
                  ),
                  Expanded(child: _buildDestinationBody()),
                ],
              ),
            ),
    );
  }

  Widget _buildDashboardCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return SizedBox(
      width: 180,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withValues(alpha: 0.65)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMascotCard() {
    return Container(
      width: 220,
      height: 190,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF7545FF), Color(0xFF24C9C2)],
        ),
        borderRadius: BorderRadius.all(Radius.circular(24)),
      ),
      child: Stack(
        children: [
          const Positioned(
            right: 12,
            top: 12,
            child: CircleAvatar(backgroundColor: Colors.white24, radius: 28),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'RoboPub',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Le robot qui transforme\nvos idées en visuels brillants.',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          Positioned(
            right: 24,
            bottom: 18,
            child: Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.smart_toy_rounded,
                size: 42,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewCreationScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nouvelle création',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Démarrez depuis une idée, un besoin marketing ou un brief métier.',
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildDashboardCard(
                title: 'Projets actifs',
                value: '${_savedProjects.length}',
                icon: Icons.folder_special_outlined,
                color: const Color(0xFF7545FF),
              ),
              _buildDashboardCard(
                title: 'Concepts IA',
                value: '${_concepts.length}',
                icon: Icons.auto_awesome,
                color: const Color(0xFF24C9C2),
              ),
              _buildDashboardCard(
                title: 'Impressions',
                value: '12',
                icon: Icons.print_outlined,
                color: const Color(0xFFFFAA45),
              ),
            ],
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth > 720;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: wide ? 2 : 1,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111827),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Brief créatif',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _promptController,
                            minLines: 4,
                            maxLines: 6,
                            decoration: InputDecoration(
                              hintText: 'Décrivez le format, les couleurs, le message et les éléments à intégrer…',
                              hintStyle: const TextStyle(color: Colors.white38),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () =>
                                    setState(() => _selectedIndex = 1),
                                icon: const Icon(Icons.auto_awesome),
                                label: const Text('Créer 4 concepts'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () =>
                                    setState(() => _selectedIndex = 2),
                                icon: const Icon(
                                  Icons.design_services_outlined,
                                ),
                                label: const Text('Ouvrir l’atelier'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (wide) ...[const SizedBox(width: 20), _buildMascotCard()],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAiCreationScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Création avec l’IA',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Générez des concepts réalistes, adaptés au brief, puis modifiez-les dans l’atelier.',
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _concepts.asMap().entries.map((entry) {
              final index = entry.key;
              final concept = entry.value;
              final selected = _selectedConcept == concept;
              return GestureDetector(
                onTap: () => setState(() => _selectedConcept = concept),
                child: Container(
                  width: 280,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: selected
                        ? const LinearGradient(
                            colors: [Color(0xFF7545FF), Color(0xFF24C9C2)],
                          )
                        : const LinearGradient(
                            colors: [Color(0xFF111827), Color(0xFF1F2937)],
                          ),
                    borderRadius: BorderRadius.circular(22),
                    border: selected
                        ? Border.all(
                            color: Colors.white.withValues(alpha: 0.8),
                            width: 1.2,
                          )
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAiDesignPreview(concept, index),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            concept.title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Chip(label: Text(concept.style)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        concept.summary,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Palette : ${concept.palette}',
                        style: const TextStyle(
                          color: Color(0xFF24C9C2),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Slogan : ${concept.slogan}',
                        style: const TextStyle(
                          color: Color(0xFFFFAA45),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        concept.provider == 'local'
                            ? 'Généré localement • disponible hors ligne'
                            : 'Proposé par ${concept.provider}',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        children: [
                          FilledButton.tonal(
                            onPressed: () => _applyAiConcept(concept, index),
                            child: const Text('Ouvrir ce design'),
                          ),
                          TextButton(
                            onPressed: () => _applyAiConcept(concept, index),
                            child: const Text('Modifier'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _generateConcepts,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Régénérer les concepts'),
          ),
        ],
      ),
    );
  }

  Widget _buildAiDesignPreview(DesignConcept concept, int variant) {
    final elements = AiDesignService.createComposition(
      concept: concept,
      profile: _currentProfile(),
      variant: variant,
    );

    return AspectRatio(
      aspectRatio: 320 / 360,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ColoredBox(
          color: const Color(0xFF101828),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final scaleX = constraints.maxWidth / 320;
              final scaleY = constraints.maxHeight / 360;
              return Stack(
                clipBehavior: Clip.hardEdge,
                children: elements.map((element) {
                  return Positioned(
                    left: element.x * 320 * scaleX,
                    top: element.y * 360 * scaleY,
                    width: element.width * scaleX,
                    height: element.height * scaleY,
                    child: Transform.rotate(
                      angle: element.rotation,
                      child: Opacity(
                        opacity: element.opacity.clamp(0.0, 1.0),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: element.color.withValues(
                              alpha: element.kind == 'shape' ? 1 : 0.9,
                            ),
                            borderRadius: BorderRadius.circular(
                              element.kind == 'image' ? 18 : 12,
                            ),
                          ),
                          child: element.kind == 'shape'
                              ? null
                              : Padding(
                                  padding: const EdgeInsets.all(2),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      element.textContent ?? element.name,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: element.fontSize,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildStudioScreen() {
    final selectedElement =
        _selectedCanvasIndex >= 0 &&
            _selectedCanvasIndex < _canvasElements.length
        ? _canvasElements[_selectedCanvasIndex]
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Atelier graphique',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Données visuelles et éléments modifiables, avec historique, étirement, rotation et alignements.',
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _addTextElement,
                icon: const Icon(Icons.title),
                label: const Text('Texte'),
              ),
              FilledButton.tonal(
                onPressed: _pickAndAddImage,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.image),
                    SizedBox(width: 8),
                    Text('Photo'),
                  ],
                ),
              ),
              FilledButton.tonal(
                onPressed: _addShape,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.category),
                    SizedBox(width: 8),
                    Text('Forme'),
                  ],
                ),
              ),
              FilledButton.tonal(
                onPressed: () => setState(() => _showGrid = !_showGrid),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.grid_3x3),
                    SizedBox(width: 8),
                    Text('Grille'),
                  ],
                ),
              ),
              FilledButton.tonal(
                onPressed: () => setState(() => _showGuides = !_showGuides),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.timeline),
                    SizedBox(width: 8),
                    Text('Guides'),
                  ],
                ),
              ),
              FilledButton.tonal(
                onPressed: _duplicateSelected,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.copy_all),
                    SizedBox(width: 8),
                    Text('Dupliquer'),
                  ],
                ),
              ),
              FilledButton.tonal(
                onPressed: _deleteSelected,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.delete_outline),
                    SizedBox(width: 8),
                    Text('Supprimer'),
                  ],
                ),
              ),
              FilledButton.tonal(
                onPressed: _undo,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.undo),
                    SizedBox(width: 8),
                    Text('Undo'),
                  ],
                ),
              ),
              FilledButton.tonal(
                onPressed: _saveCurrentProject,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.save),
                    SizedBox(width: 8),
                    Text('Sauvegarder'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            height: 520,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xFF101828),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: const Color(0xFF7545FF).withValues(alpha: 0.25),
              ),
            ),
            child: Stack(
              children: [
                if (_showGrid)
                  ...List.generate(12, (index) {
                    return Positioned.fill(
                      child: IgnorePointer(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final x = constraints.maxWidth / 12 * index;
                            return Container(
                              decoration: BoxDecoration(
                                border: Border(
                                  left: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.08),
                                  ),
                                ),
                              ),
                              margin: EdgeInsets.fromLTRB(x, 0, 0, 0),
                            );
                          },
                        ),
                      ),
                    );
                  }),
                if (_showGuides)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 240,
                    child: Container(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                ..._canvasElements.asMap().entries.map((entry) {
                  final index = entry.key;
                  final element = entry.value;
                  final selected = index == _selectedCanvasIndex;
                  return Positioned(
                    left: element.x * 320,
                    top: element.y * 360,
                    width: element.width,
                    height: element.height,
                    child: GestureDetector(
                      onScaleUpdate: (details) {
                        if (element.locked) return;
                        setState(() {
                          element.width = (element.width * details.scale).clamp(
                            40.0,
                            340.0,
                          );
                          element.height = (element.height * details.scale)
                              .clamp(30.0, 260.0);
                          element.rotation += details.rotation * 0.08;
                        });
                      },
                      onTap: () => setState(() => _selectedCanvasIndex = index),
                      child: Listener(
                        onPointerMove: (event) {
                          if (!selected || element.locked) return;
                          setState(() {
                            element.x = (element.x + event.delta.dx / 320)
                                .clamp(0.0, 1.0);
                            element.y = (element.y + event.delta.dy / 360)
                                .clamp(0.0, 1.0);
                          });
                        },
                        child: Transform.rotate(
                          angle: element.rotation,
                          child: Opacity(
                            opacity: element.opacity,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              padding: const EdgeInsets.all(10),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: element.kind == 'shape'
                                    ? element.color
                                    : element.color.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(
                                  element.kind == 'image' ? 18 : 12,
                                ),
                                border: selected
                                    ? Border.all(color: Colors.white, width: 2)
                                    : null,
                              ),
                              child: element.kind == 'image'
                                  ? (element.imagePath != null
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                            child: Image.file(
                                              File(element.imagePath!),
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                              height: double.infinity,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.image_outlined,
                                            color: Colors.white,
                                            size: 48,
                                          ))
                                  : Text(
                                      element.textContent ?? element.name,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: element.fontSize,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (selectedElement != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sélection : ${selectedElement.name}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (value) =>
                        setState(() => selectedElement.name = value),
                    decoration: const InputDecoration(
                      labelText: 'Nom de l’élément',
                    ),
                    controller:
                        TextEditingController(text: selectedElement.name)
                          ..selection = TextSelection.collapsed(
                            offset: selectedElement.name.length,
                          ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: selectedElement.opacity,
                          min: 0.2,
                          max: 1,
                          onChanged: (value) =>
                              setState(() => selectedElement.opacity = value),
                        ),
                      ),
                      Text(
                        '${selectedElement.opacity.toStringAsFixed(2)} op.',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => setState(
                          () =>
                              selectedElement.locked = !selectedElement.locked,
                        ),
                        icon: Icon(
                          selectedElement.locked ? Icons.lock : Icons.lock_open,
                        ),
                        label: Text(
                          selectedElement.locked
                              ? 'Verrouillé'
                              : 'Déverrouiller',
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () =>
                            setState(() => selectedElement.rotation += 0.2),
                        icon: const Icon(Icons.rotate_right),
                        label: const Text('Tourner'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTemplatePreview(TemplateCard template) {
    final elements = TemplateService.createElements(
      template.id,
      _currentProfile(),
    );

    return AspectRatio(
      aspectRatio: 320 / 360,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ColoredBox(
          color: const Color(0xFF101828),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final scaleX = constraints.maxWidth / 320;
              final scaleY = constraints.maxHeight / 360;
              return Stack(
                clipBehavior: Clip.hardEdge,
                children: elements.map((element) {
                  return Positioned(
                    left: element.x * 320 * scaleX,
                    top: element.y * 360 * scaleY,
                    width: element.width * scaleX,
                    height: element.height * scaleY,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: element.color.withValues(
                          alpha: element.kind == 'shape' ? 1 : 0.9,
                        ),
                        borderRadius: BorderRadius.circular(
                          element.kind == 'image' ? 18 : 12,
                        ),
                      ),
                      child: element.kind == 'shape'
                          ? null
                          : element.kind == 'image'
                          ? Icon(
                              Icons.add_photo_alternate_outlined,
                              color: Colors.white.withValues(alpha: 0.8),
                              size: 22,
                            )
                          : Padding(
                              padding: const EdgeInsets.all(2),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  element.textContent ?? element.name,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTemplateScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bibliothèque de modèles',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Chaque modèle charge une composition différente, entièrement modifiable dans l’atelier.',
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _startBlankCanvas,
            icon: const Icon(Icons.note_add_outlined),
            label: const Text('Commencer avec une page blanche'),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: _templates.map((template) {
              return Container(
                width: 220,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTemplatePreview(template),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                template.accent,
                                template.accent.withValues(alpha: 0.6),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            template.icon,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const Spacer(),
                        Chip(label: Text(template.tag)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      template.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      template.category,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      template.description,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.tonal(
                      onPressed: () => _applyTemplate(template),
                      child: const Text('Utiliser ce modèle'),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectsScreen() {
    final projectList = _savedProjects.isEmpty
        ? <GraphicProject>[]
        : _savedProjects;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mes projets',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 20),
          if (projectList.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Aucun projet enregistré pour le moment. Sauvegardez votre première création pour la retrouver ici.',
              ),
            )
          else
            ...projectList.map((project) {
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF7545FF), Color(0xFF24C9C2)],
                        ),
                        borderRadius: BorderRadius.all(Radius.circular(18)),
                      ),
                      child: const Icon(
                        Icons.design_services,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            project.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            project.description,
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () async {
                        await _projectRepository.deleteProject(project.id);
                        await _loadProjects();
                      },
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _restoreFromBackup,
            icon: const Icon(Icons.restore),
            label: const Text('Restaurer archive ZIP'),
          ),
        ],
      ),
    );
  }

  Widget _buildPackScreen() {
    final offers = [
      'Carte de visite premium',
      'Flyer A5 promo',
      'Affiche évènement',
      'Pack réseaux sociaux',
      'Mini dépliant',
      'Carte fidélité',
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pack publicitaire',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Générez une campagne cohérente sur plusieurs supports à partir d’un même brief.',
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: offers.map((offer) {
              return ChoiceChip(
                label: Text(offer),
                selected: offer == 'Flyer A5 promo',
                onSelected: (_) {},
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Générateur de QR code',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _qrController,
                  decoration: const InputDecoration(hintText: 'https://...'),
                ),
                const SizedBox(height: 12),
                Center(
                  child: QrImageView(
                    data: _qrController.text,
                    version: QrVersions.auto,
                    size: 180,
                    backgroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrintScreen() {
    Widget numberField(TextEditingController controller, String label) {
      return SizedBox(
        width: 145,
        child: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: label),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Imprimerie PDF',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Le PDF reprend les calques de la création et les place à l’échelle sur les feuilles.',
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Aperçu de la création actuelle',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: AspectRatio(
                      aspectRatio: 85 / 55,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final scaleX = constraints.maxWidth / 320;
                            final scaleY = constraints.maxHeight / 360;
                            return ColoredBox(
                              color: const Color(0xFF101828),
                              child: Stack(
                                clipBehavior: Clip.hardEdge,
                                children: _canvasElements.map((element) {
                                  return Positioned(
                                    left: element.x * 320 * scaleX,
                                    top: element.y * 360 * scaleY,
                                    width: element.width * scaleX,
                                    height: element.height * scaleY,
                                    child: Transform.rotate(
                                      angle: element.rotation,
                                      child: Opacity(
                                        opacity: element.opacity.clamp(
                                          0.0,
                                          1.0,
                                        ),
                                        child:
                                            element.kind == 'image' &&
                                                element.imagePath != null
                                            ? Image.file(
                                                File(element.imagePath!),
                                                fit: BoxFit.cover,
                                              )
                                            : Container(
                                                alignment: Alignment.center,
                                                padding: const EdgeInsets.all(
                                                  4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: element.color,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: element.kind == 'shape'
                                                    ? null
                                                    : Text(
                                                        element.textContent ??
                                                            element.name,
                                                        textAlign:
                                                            TextAlign.center,
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          fontSize:
                                                              element.fontSize,
                                                        ),
                                                      ),
                                              ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 145,
                      child: DropdownButtonFormField<String>(
                        initialValue: _paperSize,
                        decoration: const InputDecoration(labelText: 'Papier'),
                        items: const ['A4', 'A3', 'A5', 'Lettre US']
                            .map(
                              (paper) => DropdownMenuItem(
                                value: paper,
                                child: Text(paper),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) setState(() => _paperSize = value);
                        },
                      ),
                    ),
                    SizedBox(
                      width: 145,
                      child: DropdownButtonFormField<String>(
                        initialValue: _orientation,
                        decoration: const InputDecoration(
                          labelText: 'Orientation',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'portrait',
                            child: Text('Portrait'),
                          ),
                          DropdownMenuItem(
                            value: 'landscape',
                            child: Text('Paysage'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _orientation = value);
                          }
                        },
                      ),
                    ),
                    numberField(_copiesController, 'Exemplaires'),
                    numberField(_cardWidthController, 'Largeur (mm)'),
                    numberField(_cardHeightController, 'Hauteur (mm)'),
                    numberField(_marginController, 'Marge (mm)'),
                    numberField(_gapController, 'Espacement (mm)'),
                    numberField(_bleedController, 'Fond perdu (mm)'),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Traits de découpe'),
                  value: _cutMarks,
                  onChanged: (value) => setState(() => _cutMarks = value),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _exportPdf,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Exporter PDF'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentityScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mon activité professionnelle',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 20),
          Card(
            color: const Color(0xFF111827),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  TextField(
                    controller: _companyController,
                    decoration: const InputDecoration(
                      labelText: 'Nom de l’activité',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _sloganController,
                    decoration: const InputDecoration(labelText: 'Slogan'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phoneController,
                    decoration: const InputDecoration(labelText: 'Téléphone'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _websiteController,
                    decoration: const InputDecoration(
                      labelText: 'Site internet',
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _saveProfile,
                    icon: const Icon(Icons.save),
                    label: const Text('Sauvegarder le profil'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiSettingsScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Paramètres IA',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 20),
          Card(
            color: const Color(0xFF111827),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Fournisseur AI',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedProvider,
                    dropdownColor: const Color(0xFF111827),
                    items: _providers
                        .map(
                          (provider) => DropdownMenuItem(
                            value: provider,
                            child: Text(provider),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedProvider = value;
                          _aiConnectionMessage = null;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Clé API',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _apiKeyController,
                    obscureText: true,
                    onChanged: (value) {
                      _apiKey = value;
                      setState(() => _aiConnectionMessage = null);
                    },
                    decoration: const InputDecoration(hintText: 'sk-…'),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'La clé et le fournisseur sont conservés localement dans le stockage sécurisé.',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: _saveAiSettings,
                        icon: const Icon(Icons.lock_outline),
                        label: const Text('Sauvegarder les paramètres'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _isTestingAiConnection
                            ? null
                            : _testAiConnection,
                        icon: _isTestingAiConnection
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.wifi_tethering),
                        label: const Text('Tester la connexion'),
                      ),
                    ],
                  ),
                  if (_aiConnectionMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _aiConnectionMessage!,
                      style: TextStyle(
                        color: _aiConnectionMessage!.startsWith('Connexion')
                            ? const Color(0xFF24C9C2)
                            : const Color(0xFFFF6384),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpScreen() {
    final steps = [
      '1. Rédigez un brief clair avec le format, les couleurs et les objectifs.',
      '2. Générez 4 concepts IA et choisissez le meilleur design.',
      '3. Ajustez les éléments directement dans l’atelier graphique.',
      '4. Exportez vers PDF, partagez sur les réseaux ou imprimez votre visuel.',
      '5. Sauvegardez régulièrement votre projet pour retrouver vos créations.',
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mode d’emploi',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 20),
          ...steps.map(
            (step) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(step, style: const TextStyle(fontSize: 16)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
