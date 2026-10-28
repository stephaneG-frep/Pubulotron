import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import 'screens/creation_screens.dart';
import 'screens/help_screen.dart';
import 'screens/home_screen.dart';
import 'screens/identity_screen.dart';
import 'screens/library_screens.dart';
import 'screens/pack_screen.dart';
import 'screens/print_screen.dart';
import 'screens/qr_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/studio_screen.dart';
import 'screens/surprise_screen.dart';
import 'screens/variants_screen.dart';
import 'sections.dart';
import 'theme.dart';
import 'widgets/robopub.dart';

/// Structure principale : barre latérale (ordinateur) ou tiroir (téléphone).
class PubulotronShell extends ConsumerWidget {
  const PubulotronShell({super.key});

  Widget _screen(AppSection section) => switch (section) {
    AppSection.home => const HomeScreen(),
    AppSection.newCreation => const NewCreationScreen(),
    AppSection.aiCreation => const AiCreationScreen(),
    AppSection.studio => const StudioScreen(),
    AppSection.templates => const TemplatesScreen(),
    AppSection.projects => const ProjectsScreen(),
    AppSection.pack => const PackScreen(),
    AppSection.print => const PrintScreen(),
    AppSection.identity => const IdentityScreen(),
    AppSection.aiSettings => const AiSettingsScreen(),
    AppSection.help => const HelpScreen(),
    AppSection.qr => const QrScreen(),
    AppSection.variants => const VariantsScreen(),
    AppSection.surprise => const SurpriseScreen(),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(navigationProvider);
    final body = AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.02),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: KeyedSubtree(key: ValueKey(current), child: _screen(current)),
    );
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            _SideBar(current: current),
            Expanded(child: SafeArea(left: false, child: body)),
          ],
        ),
      );
    }
    final info = infoFor(current);
    return Scaffold(
      appBar: AppBar(
        title: Text(current == AppSection.home ? 'Pubulotron' : info.label),
        actions: [
          if (current != AppSection.home)
            IconButton(
              tooltip: 'Tableau de bord',
              icon: const Icon(Icons.home_outlined),
              onPressed: () =>
                  ref.read(navigationProvider.notifier).go(AppSection.home),
            ),
        ],
      ),
      drawer: Drawer(child: _NavList(current: current, closeOnTap: true)),
      body: body,
    );
  }
}

class _SideBar extends StatelessWidget {
  const _SideBar({required this.current});

  final AppSection current;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 262,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: dark
              ? const [Color(0xFF0C1324), Color(0xFF17213B)]
              : const [PubColors.night, Color(0xFF241B55)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Theme(
        data: ThemeData(
          brightness: Brightness.dark,
          fontFamily: PubTheme.fontFamily,
          colorSchemeSeed: PubColors.violet,
          useMaterial3: true,
        ),
        child: SafeArea(child: _NavList(current: current, closeOnTap: false)),
      ),
    );
  }
}

class _NavList extends ConsumerWidget {
  const _NavList({required this.current, required this.closeOnTap});

  final AppSection current;
  final bool closeOnTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
          child: Row(
            children: [
              const RoboPub(size: 52),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShaderMask(
                      shaderCallback: (r) =>
                          PubColors.brandGradient.createShader(r),
                      child: const Text(
                        'Pubulotron',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Text(
                      'Studio publicitaire',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        for (final s in sections)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: ListTile(
              dense: true,
              selected: s.section == current,
              selectedTileColor: s.color.withValues(alpha: 0.22),
              selectedColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              leading: Icon(
                s.icon,
                color: s.section == current ? PubColors.orange : null,
              ),
              title: Text(
                s.label,
                style: TextStyle(
                  fontWeight: s.section == current
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
              trailing: s.offline
                  ? null
                  : const Tooltip(
                      message: 'Nécessite Internet',
                      child: Icon(Icons.cloud_outlined, size: 16),
                    ),
              onTap: () {
                ref.read(navigationProvider.notifier).go(s.section);
                if (closeOnTap) Navigator.of(context).maybePop();
              },
            ),
          ),
      ],
    );
  }
}
