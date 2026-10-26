import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/shell.dart';
import '../ui/theme.dart';
import 'providers.dart';

class PubulotronApp extends ConsumerWidget {
  const PubulotronApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(settingsProvider.select((s) => s.themeMode));
    return MaterialApp(
      title: 'Pubulotron',
      debugShowCheckedModeBanner: false,
      theme: PubTheme.light(),
      darkTheme: PubTheme.dark(),
      themeMode: themeMode,
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [Locale('fr', 'FR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const PubulotronShell(),
    );
  }
}
