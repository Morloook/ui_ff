import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_config.dart';
import '../../core/app_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/localized_text.dart';
import '../../widgets/page_header.dart';
import '../widgets/scripts_directory_editor.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});
  final AppController controller;

  Future<void> _restoreDefaults(BuildContext context) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Przywrócić ustawienia domyślne?'),
            content: const Text(
              'Wszystkie ustawienia zapisane przez użytkownika zostaną '
              'usunięte z options.json. Program ponownie zastosuje wartości '
              'z app_config.dart i odświeży interfejs.\n\n'
              'Katalog możliwości, zadania i pliki użytkownika nie zostaną '
              'usunięte.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Anuluj'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Przywróć domyślne'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await controller.restoreDefaultOptions();
      if (messenger.mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Przywrócono ustawienia domyślne.')),
        );
      }
    } on Object catch (error) {
      if (messenger.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Nie można przywrócić ustawień: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = controller.options!;
    return Column(
      children: [
        const PageHeader(
          title: 'Ustawienia i informacje',
          subtitle:
              'Zmiany są zapisywane jako JSON użytkownika i łączone z SSOT.',
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Konfiguracja aplikacji',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Wartości domyślne pochodzą wyłącznie z '
                        'lib/core/app_config.dart. Plik użytkownika '
                        'zawiera tylko zmienione wartości.',
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: options.themeMode,
                        decoration: InputDecoration(
                          labelText: context.tr('Motyw'),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'system',
                            child: Text('Zgodny z systemem'),
                          ),
                          DropdownMenuItem(
                            value: 'light',
                            child: Text('Jasny'),
                          ),
                          DropdownMenuItem(
                            value: 'dark',
                            child: Text('Ciemny'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          unawaited(
                            controller.updateOption(['ui', 'themeMode'], value),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        key: ValueKey('locale-${options.locale}'),
                        initialValue: options.locale,
                        decoration: InputDecoration(
                          labelText: context.tr('Język interfejsu'),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'pl', child: Text('Polski')),
                          DropdownMenuItem(
                            value: 'en',
                            child: Text('Angielski'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null || value == options.locale) return;
                          unawaited(
                            controller.updateOption(['ui', 'locale'], value),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: options.autoScanOnStart,
                        title: const Text(
                          'Automatycznie skanuj po pierwszym uruchomieniu',
                        ),
                        subtitle: const Text(
                          'Aktualny cache nadal jest wczytywany automatycznie.',
                        ),
                        onChanged: (value) {
                          unawaited(
                            controller.updateOption([
                              'catalog',
                              'autoScanOnStart',
                            ], value),
                          );
                        },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: options.warnBeforeOverwrite,
                        title: const Text(
                          'Ostrzegaj przed możliwym nadpisaniem',
                        ),
                        onChanged: (value) {
                          unawaited(
                            controller.updateOption([
                              'terminal',
                              'warnBeforeOverwrite',
                            ], value),
                          );
                        },
                      ),
                      const Divider(),
                      const Text('Plik ustawień użytkownika:'),
                      Row(
                        children: [
                          Expanded(
                            child: SelectableText(
                              controller.settingsService.userFilePath,
                              style: const TextStyle(fontFamily: 'monospace'),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Clipboard.setData(
                              ClipboardData(
                                text: controller.settingsService.userFilePath,
                              ),
                            ),
                            tooltip: 'Kopiuj ścieżkę',
                            icon: const Icon(Icons.copy),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () => _restoreDefaults(context),
                        icon: const Icon(Icons.restore),
                        label: const Text('Przywróć ustawienia domyślne'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ScriptsDirectoryEditor(controller: controller),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.storage),
                      title: const Text('Baza możliwości'),
                      subtitle: Text(
                        controller.snapshot == null
                            ? 'Brak przeskanowanych możliwości'
                            : 'SQLite · '
                                  '${controller.snapshot!.fingerprint.substring(0, 12)}…',
                      ),
                    ),
                    const ListTile(
                      leading: Icon(Icons.security),
                      title: Text('Uruchamianie procesów'),
                      subtitle: Text(
                        'Bez powłoki systemowej. Terminal uruchamia wyłącznie '
                        'ffmpeg/ffprobe.',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'O aplikacji',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '${AppConfig.applicationName} '
                        'v${AppConfig.applicationVersion}\n'
                        'Aplikacja nie zawiera binariów FFmpeg. Korzysta z '
                        'narzędzi zainstalowanych lokalnie przez użytkownika.\n\n'
                        'Autor: ${AppConfig.applicationAuthor}\n'
                        'Kontakt: ${AppConfig.applicationContactEmail}',
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => launchUrl(
                          Uri.parse(AppConfig.applicationGithubUrl),
                          mode: LaunchMode.externalApplication,
                        ),
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('GitHub'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () => showLicensePage(
                          context: context,
                          applicationName: AppConfig.applicationName,
                          applicationVersion: AppConfig.applicationVersion,
                        ),
                        child: const Text('Licencje zależności Flutter'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Text(
                    'Windows: zainstaluj FFmpeg i dodaj katalog bin do PATH '
                    'albo wskaż pliki ffmpeg.exe i ffprobe.exe ręcznie.\n\n'
                    'Linux: dostępność NVENC, VAAPI, Vulkan i innych metod '
                    'zależy od kompilacji FFmpeg oraz sterowników.',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
