import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app_services.dart';
import 'app/providers.dart';
import 'app/pubulotron_app.dart';
import 'ui/theme.dart';
import 'ui/widgets/robopub.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final services = await AppServices.open();
    runApp(
      ProviderScope(
        overrides: [servicesProvider.overrideWithValue(services)],
        child: const PubulotronApp(),
      ),
    );
  } catch (error, stack) {
    debugPrintStack(stackTrace: stack, label: '$error');
    runApp(StartupErrorApp(error: error));
  }
}

/// Affiché si la base locale ne peut pas être ouverte.
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: PubTheme.light(),
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const RoboPub(size: 120, mood: RoboMood.worried),
                const SizedBox(height: 16),
                const Text(
                  'Pubulotron ne peut pas démarrer',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'La base de données locale est inaccessible. Vérifiez l’espace disque et les droits du dossier de l’application.',
                ),
                const SizedBox(height: 8),
                SelectableText('$error', style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
