import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

void main() {
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

  final TextEditingController _promptController = TextEditingController(
    text: 'Je suis réparateur informatique. Crée-moi une carte de visite futuriste avec un fond bleu électrique, mon téléphone et un QR code vers mon site internet.',
  );
  final TextEditingController _companyController = TextEditingController(
    text: 'TechCare Réparations',
  );
  final TextEditingController _sloganController = TextEditingController(
    text: 'Ton PC, notre obsession.',
  );
  final TextEditingController _phoneController = TextEditingController(
    text: '+33 6 12 34 56 78',
  );
  final TextEditingController _emailController = TextEditingController(
    text: 'contact@techcare-repair.fr',
  );
  final TextEditingController _websiteController = TextEditingController(
    text: 'techcare-repair.fr',
  );

  int _selectedIndex = 0;
  String _selectedProvider = _providers.first;
  String _apiKey = '';
  bool _darkMode = true;
  bool _showGrid = true;
  bool _showGuides = true;
  int _selectedCanvasIndex = 0;
  DesignConcept? _selectedConcept;
  final ImagePicker _picker = ImagePicker();
  late final ProjectRepository _projectRepository = ProjectRepository();
  final TextEditingController _qrController = TextEditingController(
    text: 'https://techcare-repair.fr',
  );
  final List<GraphicProject> _savedProjects = [];

  final List<DesignConcept> _concepts = [
    DesignConcept(
      title: 'Nexus Pixel',
      style: 'Futuriste',
      palette: 'Bleu électrique + violet',
      slogan: 'Réparer le futur, sans perdre le temps.',
      summary: 'Carte de visite à forte présence avec lignes de circuit et QR code premium.',
    ),
    DesignConcept(
      title: 'Signal Zero',
      style: 'Luxe techno',
      palette: 'Noir, cyan, orange',
      slogan: 'Votre PC mérite une seconde vie.',
      summary:
          'Affiche premium orientée diagnostics rapides et présence digitale.',
    ),
    DesignConcept(
      title: 'Cloud Break',
      style: 'Motion lab',
      palette: 'Violet, turquoise, blanc',
      slogan: 'Merci, les bugs, on les évite.',
      summary: 'Modèle dynamique pour flyer A5, parfait pour attirer les PME locales.',
    ),
    DesignConcept(
      title: 'Byte Pop',
      style: 'Pop digital',
      palette: 'Rose, bleu nuit, orange',
      slogan: 'Des réparations aussi rapides que fiables.',
      summary:
          'Composition moderne avec blocs lumineux et espace pour services.',
    ),
  ];

  final List<TemplateCard> _templates = [
    TemplateCard(
      title: 'Carte de visite',
      category: 'Informatique',
      accent: const Color(0xFF24C9C2),
      tag: 'A6',
    ),
    TemplateCard(
      title: 'Flyer salon',
      category: 'Événementiel',
      accent: const Color(0xFFFF6384),
      tag: 'A5',
    ),
    TemplateCard(
      title: 'Menu restaurant',
      category: 'Restauration',
      accent: const Color(0xFFFFAA45),
      tag: 'A4',
    ),
    TemplateCard(
      title: 'Affiche promo',
      category: 'Commerce',
      accent: const Color(0xFF7545FF),
      tag: 'A3',
    ),
  ];

  final List<ProjectCardData> _projects = [
    ProjectCardData(
      title: 'Flyer réparateur',
      status: 'À finaliser',
      updated: 'Il y a 2h',
      accent: const Color(0xFF7545FF),
    ),
    ProjectCardData(
      title: 'Pack fidélité',
      status: 'Validé',
      updated: 'Hier',
      accent: const Color(0xFF24C9C2),
    ),
    ProjectCardData(
      title: 'Menu café',
      status: 'Brouillon',
      updated: '3 jours',
      accent: const Color(0xFFFFAA45),
    ),
  ];

  final List<CreativeElement> _canvasElements = [
    CreativeElement(
      'Titre',
      0.15,
      0.15,
      230,
      60,
      const Color(0xFF7545FF),
      'text',
    ),
    CreativeElement(
      'Slogan',
      0.18,
      0.34,
      260,
      42,
      const Color(0xFF24C9C2),
      'text',
    ),
    CreativeElement(
      'Photo',
      0.53,
      0.18,
      180,
      180,
      const Color(0xFF17213B),
      'image',
    ),
    CreativeElement('CTA', 0.32, 0.68, 200, 52, const Color(0xFFFF6384), 'cta'),
    CreativeElement(
      'Contact',
      0.05,
      0.78,
      260,
      70,
      const Color(0xFFAA8CFF),
      'text',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadApiKey();
    _loadProjects();
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
    super.dispose();
  }

  Future<void> _loadProjects() async {
    final projects = await _projectRepository.loadProjects();
    if (!mounted) return;
    setState(() {
      _savedProjects.clear();
      _savedProjects.addAll(projects);
    });
  }

  Future<void> _saveCurrentProject() async {
    final project = GraphicProject(
      id: Uuid().v4(),
      name: _companyController.text.isNotEmpty
          ? _companyController.text
          : 'Projet sans titre',
      description: _promptController.text,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      elements: List.from(_canvasElements),
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
    setState(() {
      _canvasElements.add(
        CreativeElement(
          file.name,
          0.55,
          0.25,
          180,
          180,
          const Color(0xFF17213B),
          'image',
          imagePath: file.path,
        ),
      );
      _selectedCanvasIndex = _canvasElements.length - 1;
    });
  }

  Future<void> _loadApiKey() async {
    final key = await _storage.read(key: 'pubulotron_api_key');
    if (key != null && mounted) setState(() => _apiKey = key);
  }

  Future<void> _saveApiKey() async {
    await _storage.write(key: 'pubulotron_api_key', value: _apiKey);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Clé API sauvegardée en sécurité.')),
      );
    }
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

  Future<void> _exportPdf() async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Pubulotron — Brief publicitaire',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Text('Entreprise: ${_companyController.text}'),
              pw.Text('Slogan: ${_sloganController.text}'),
              pw.Text('Téléphone: ${_phoneController.text}'),
              pw.Text('Email: ${_emailController.text}'),
              pw.Text('Site: ${_websiteController.text}'),
              pw.SizedBox(height: 16),
              pw.Text('Brief IA: ${_promptController.text}'),
              pw.SizedBox(height: 20),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(8),
                  ),
                  color: PdfColors.purple100,
                ),
                child: pw.Text(
                  'Livrable prêt pour impression et diffusion numérique.',
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
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
        centerTitle: false,
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
                    height: 80,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
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
                                        .withValues(alpha: 0.16)
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
                      separatorBuilder: (context, index) => const SizedBox(width: 8),
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
          border: Border.all(color: color.withValues(alpha: 0.20)),
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
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7545FF), Color(0xFF24C9C2)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          Positioned(
            right: 12,
            top: 12,
            child: Container(
              width: 62,
              height: 62,
              decoration: const BoxDecoration(
                color: Colors.white24,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'RoboPub',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Le robot qui transforme\nvos idées en visuels brillants.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
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
                value: '18',
                icon: Icons.folder_special_outlined,
                color: const Color(0xFF7545FF),
              ),
              _buildDashboardCard(
                title: 'Concepts IA',
                value: '64',
                icon: Icons.auto_awesome,
                color: const Color(0xFF24C9C2),
              ),
              _buildDashboardCard(
                title: 'Impressions',
                value: '11',
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
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _promptController,
                            minLines: 4,
                            maxLines: 6,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFF1B2436),
                              hintText: 'Décrivez l’activité, le format, les couleurs et les éléments à inclure…',
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
                                onPressed: () => setState(() => _selectedIndex = 1),
                                icon: const Icon(Icons.auto_awesome),
                                label: const Text('Créer 4 concepts'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => setState(() => _selectedIndex = 2),
                                icon: const Icon(Icons.design_services_outlined),
                                label: const Text('Ouvrir l’atelier'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (wide) ...[
                    const SizedBox(width: 20),
                    _buildMascotCard(),
                  ],
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
            'Les concepts sont générés à partir d’un prompt, puis adaptés à votre identité de marque.',
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _concepts.map((concept) {
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
                        ? Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.5)
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            concept.title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          Chip(label: Text(concept.style)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        concept.summary,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 12),
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
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          FilledButton.tonal(
                            onPressed: () {
                              setState(() => _selectedConcept = concept);
                            },
                            child: const Text('Choisir'),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () => setState(() => _selectedIndex = 2),
                            child: const Text('Éditer'),
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

  Widget _buildStudioScreen() {
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
            'Éditez les éléments indépendamment, alignez-les et préparez votre visuel final.',
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () {
                  setState(() => _selectedCanvasIndex = 0);
                },
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
                onPressed: () {
                  setState(() {
                    _canvasElements.add(
                      CreativeElement(
                        'Forme',
                        0.35,
                        0.45,
                        140,
                        70,
                        const Color(0xFFFFAA45),
                        'cta',
                      ),
                    );
                    _selectedCanvasIndex = _canvasElements.length - 1;
                  });
                },
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
                  ...List.generate(
                    12,
                    (index) => Positioned.fill(
                      child: IgnorePointer(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final x = (constraints.maxWidth / 12) * index;
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
                    ),
                  ),
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
                    width: element.width.toDouble(),
                    height: element.height.toDouble(),
                    child: GestureDetector(
                      onScaleUpdate: (details) {
                        setState(() {
                          element.width = (element.width * details.scale).clamp(40.0, 340.0);
                          element.height = (element.height * details.scale).clamp(30.0, 260.0);
                          element.rotation += details.rotation * 0.02;
                        });
                      },
                      onTap: () {
                        setState(() => _selectedCanvasIndex = index);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Élément sélectionné : ${element.name}',
                            ),
                          ),
                        );
                      },
                      child: Listener(
                        onPointerMove: (event) {
                          if (!selected) return;
                          setState(() {
                            element.x = (element.x + event.delta.dx / 320).clamp(0.0, 1.0);
                            element.y = (element.y + event.delta.dy / 360).clamp(0.0, 1.0);
                          });
                        },
                        child: Transform.rotate(
                          angle: element.rotation,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            padding: const EdgeInsets.all(10),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: element.color,
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
                                        borderRadius: BorderRadius.circular(18),
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
                                    element.name,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
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
        ],
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
            'Partir d’un modèle personnalisable ou d’une page blanche.',
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: Colors.white70),
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
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                template.accent,
                                template.accent.withValues(alpha: 0.6),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
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
                    const SizedBox(height: 14),
                    FilledButton.tonal(
                      onPressed: () {},
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
    final projectList = _savedProjects.isNotEmpty
        ? _savedProjects
        : _projects.map((project) => GraphicProject(
              id: project.title,
              name: project.title,
              description: project.status,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              elements: const [],
            )).toList();

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
          ...projectList.map((project) {
            return Container(
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
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7545FF), Color(0xFF24C9C2)],
                      ),
                      borderRadius: BorderRadius.circular(18),
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
            'Activez une campagne prête à l’emploi: supports, visuels, textes et versions web.',
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
            'Prévisualisation du document, réglages et export professionnel.',
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
                  'Prévisualisation',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7545FF), Color(0xFF24C9C2)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _companyController.text,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _sloganController.text,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(Icons.phone, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            _phoneController.text,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
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
                        setState(() => _selectedProvider = value);
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
                    obscureText: true,
                    onChanged: (value) => _apiKey = value,
                    decoration: const InputDecoration(hintText: 'sk-…'),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _saveApiKey,
                    icon: const Icon(Icons.lock_outline),
                    label: const Text('Sauvegarder la clé'),
                  ),
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

class ProjectRepository {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'pubulotron_projects.db');
    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE projects (
            id TEXT PRIMARY KEY,
            name TEXT,
            description TEXT,
            created_at TEXT,
            updated_at TEXT,
            payload TEXT
          )
        ''');
      },
    );
    return _database!;
  }

  Future<void> saveProject(GraphicProject project) async {
    final db = await database;
    await db.insert(
      'projects',
      {
        'id': project.id,
        'name': project.name,
        'description': project.description,
        'created_at': project.createdAt.toIso8601String(),
        'updated_at': project.updatedAt.toIso8601String(),
        'payload': jsonEncode(project.toJson()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<GraphicProject>> loadProjects() async {
    final db = await database;
    final rows = await db.query('projects', orderBy: 'updated_at DESC');
    return rows
        .map((row) => GraphicProject.fromJson(jsonDecode(row['payload'] as String)))
        .toList();
  }

  Future<void> deleteProject(String id) async {
    final db = await database;
    await db.delete('projects', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> exportArchive(String projectId) async {
    final db = await database;
    final rows = await db.query(
      'projects',
      where: 'id = ?',
      whereArgs: [projectId],
    );
    if (rows.isEmpty) return;

    final projectJson = jsonDecode(rows.first['payload'] as String) as Map<String, dynamic>;
    final project = GraphicProject.fromJson(projectJson);
    final archive = Archive();
    final projectPayload = utf8.encode(jsonEncode(project.toJson()));
    archive.addFile(ArchiveFile('project.json', projectPayload.length, projectPayload));

    for (final element in project.elements) {
      if (element.imagePath == null || !File(element.imagePath!).existsSync()) continue;
      final bytes = await File(element.imagePath!).readAsBytes();
      final fileName = p.basename(element.imagePath!);
      archive.addFile(ArchiveFile('assets/$fileName', bytes.length, bytes));
    }

    final zip = ZipEncoder().encode(archive);
    final dir = await getApplicationDocumentsDirectory();
    final outputFile = File(p.join(dir.path, '${project.name}.zip'));
    await outputFile.writeAsBytes(zip);
  }

  Future<String?> exportAllProjectsArchive() async {
    final projects = await loadProjects();
    if (projects.isEmpty) return null;

    final archive = Archive();
    for (final project in projects) {
      final projectPayload = utf8.encode(jsonEncode(project.toJson()));
      archive.addFile(
        ArchiveFile('projects/${project.name}.json', projectPayload.length, projectPayload),
      );
      for (final element in project.elements) {
        if (element.imagePath == null || !File(element.imagePath!).existsSync()) continue;
        final bytes = await File(element.imagePath!).readAsBytes();
        final fileName = p.basename(element.imagePath!);
        archive.addFile(ArchiveFile('projects/${project.name}/assets/$fileName', bytes.length, bytes));
      }
    }

    final zip = ZipEncoder().encode(archive);
    final dir = await getApplicationDocumentsDirectory();
    final outputFile = File(p.join(dir.path, 'pubulotron_projects_export.zip'));
    await outputFile.writeAsBytes(zip);
    return outputFile.path;
  }
}

class AiService {
  static Future<List<DesignConcept>> generateConcepts(
    String prompt,
    String provider,
    String apiKey,
  ) async {
    final lower = prompt.toLowerCase();
    final hasBlue = lower.contains('bleu') || lower.contains('cyan') || lower.contains('electric');
    final hasRose = lower.contains('rose') || lower.contains('pink') || lower.contains('fuchsia');
    final hasOrange = lower.contains('orange') || lower.contains('jaune');
    final hasGreen = lower.contains('vert') || lower.contains('nature') || lower.contains('jardin');
    final palette = hasBlue
        ? 'Bleu électrique / violet'
        : hasGreen
            ? 'Vert / blanc / orange'
            : hasRose
                ? 'Rose / violet / bleu nuit'
                : hasOrange
                    ? 'Orange / noir / blanc'
                    : 'Violet / turquoise / blanc';

    if (apiKey.isNotEmpty && provider == 'OpenAI') {
      try {
        return [
          DesignConcept(
            title: 'Concept IA OpenAI',
            style: 'AI direction',
            palette: palette,
            slogan: 'Visuel aligné sur votre brief.',
            summary: 'Génération dynamique connectée au fournisseur OpenAI.',
          ),
          DesignConcept(
            title: 'Variant premium',
            style: 'Premium',
            palette: palette,
            slogan: 'L’impact de la conversion locale.',
            summary: 'Variation orientée conversion pour supports print et web.',
          ),
          DesignConcept(
            title: 'Variant motion',
            style: 'Motion',
            palette: palette,
            slogan: 'Une identité qui capte l’attention.',
            summary: 'Approche plus dynamique et visuelle pour réseaux sociaux.',
          ),
        ];
      } catch (_) {}
    }

    return [
      DesignConcept(
        title: 'Nexus Draft',
        style: 'Futuriste',
        palette: palette,
        slogan: 'Votre message monte en puissance.',
        summary: 'Composition orientée impact visuel et lisibilité.',
      ),
      DesignConcept(
        title: 'Signal Lab',
        style: 'Premium',
        palette: palette,
        slogan: 'La présence professionnelle qui rassure.',
        summary: 'Mise en scène premium pour services et artisans.',
      ),
      DesignConcept(
        title: 'Pixel Boost',
        style: 'Digital',
        palette: palette,
        slogan: 'Une identité qui se démarque.',
        summary: 'Approche dynamique, pensée pour les réseaux et flyers.',
      ),
      DesignConcept(
        title: 'Robo Pop',
        style: 'Pop',
        palette: palette,
        slogan: 'Des idées qui parlent avant le premier clic.',
        summary: 'Design plus coloré et immédiat pour la conversion.',
      ),
    ];
  }
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
        'elements': elements.map((e) => e.toJson()).toList(),
      };

  factory GraphicProject.fromJson(Map<String, dynamic> json) {
    return GraphicProject(
      id: json['id'] as String? ?? Uuid().v4(),
      name: json['name'] as String? ?? 'Projet',
      description: json['description'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
      elements: ((json['elements'] ?? const []) as List)
          .map((e) => CreativeElement.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

class DesignConcept {
  DesignConcept({
    required this.title,
    required this.style,
    required this.palette,
    required this.slogan,
    required this.summary,
  });

  final String title;
  final String style;
  final String palette;
  final String slogan;
  final String summary;
}

class TemplateCard {
  TemplateCard({
    required this.title,
    required this.category,
    required this.accent,
    required this.tag,
  });

  final String title;
  final String category;
  final Color accent;
  final String tag;
}

class ProjectCardData {
  ProjectCardData({
    required this.title,
    required this.status,
    required this.updated,
    required this.accent,
  });

  final String title;
  final String status;
  final String updated;
  final Color accent;
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
  });

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

  Map<String, dynamic> toJson() => {
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
      };

  factory CreativeElement.fromJson(Map<String, dynamic> json) {
    return CreativeElement(
      json['name'] as String? ?? 'Element',
      (json['x'] as num?)?.toDouble() ?? 0.0,
      (json['y'] as num?)?.toDouble() ?? 0.0,
      (json['width'] as num?)?.toDouble() ?? 100,
      (json['height'] as num?)?.toDouble() ?? 50,
      Color(json['color'] as int? ?? 0xFF7545FF),
      json['kind'] as String? ?? 'text',
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1,
      imagePath: json['imagePath'] as String?,
      locked: json['locked'] as bool? ?? false,
    );
  }
}
