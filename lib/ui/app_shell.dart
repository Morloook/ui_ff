import 'package:flutter/material.dart' hide Text;

import '../core/app_config.dart';
import '../core/app_controller.dart';
import '../l10n/localized_text.dart';
import 'screens/builder_screen.dart';
import 'screens/catalog_screen.dart';
import 'screens/environment_screen.dart';
import 'screens/inspector_screen.dart';
import 'screens/jobs_screen.dart';
import 'screens/scripts_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/terminal_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.controller});
  final AppController controller;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  void _openTerminal() => setState(() => _selectedIndex = 3);

  @override
  void initState() {
    super.initState();
    final notice = widget.controller.startupNotice;
    if (notice != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(notice),
            duration: const Duration(seconds: 12),
            showCloseIcon: true,
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      EnvironmentScreen(controller: widget.controller),
      CatalogScreen(controller: widget.controller),
      InspectorScreen(controller: widget.controller),
      TerminalScreen(controller: widget.controller),
      BuilderScreen(
        controller: widget.controller,
        onOpenTerminal: _openTerminal,
      ),
      ScriptsScreen(controller: widget.controller),
      JobsScreen(controller: widget.controller),
      SettingsScreen(controller: widget.controller),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final extended = constraints.maxWidth >= 1180;
        return Scaffold(
          body: Row(
            children: [
              SafeArea(
                child: NavigationRail(
                  extended: extended,
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (value) {
                    setState(() => _selectedIndex = value);
                  },
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.movie_filter_rounded, size: 30),
                        if (extended) ...[
                          const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppConfig.applicationName,
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'v${AppConfig.applicationVersion}',
                                style: TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.monitor_heart_outlined),
                      selectedIcon: Icon(Icons.monitor_heart),
                      label: Text('Środowisko'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.view_list_outlined),
                      selectedIcon: Icon(Icons.view_list),
                      label: Text('Możliwości'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.manage_search_outlined),
                      selectedIcon: Icon(Icons.manage_search),
                      label: Text('Inspektor'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.terminal_outlined),
                      selectedIcon: Icon(Icons.terminal),
                      label: Text('Terminal'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.build_outlined),
                      selectedIcon: Icon(Icons.build),
                      label: Text('Kreator'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.code_outlined),
                      selectedIcon: Icon(Icons.code),
                      label: Text('Skrypty'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.queue_play_next_outlined),
                      selectedIcon: Icon(Icons.queue_play_next),
                      label: Text('Zadania'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.settings_outlined),
                      selectedIcon: Icon(Icons.settings),
                      label: Text('Ustawienia'),
                    ),
                  ],
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: SafeArea(
                  left: false,
                  child: IndexedStack(index: _selectedIndex, children: pages),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
