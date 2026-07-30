import 'package:flutter/material.dart' hide Text;

import '../../core/app_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/localized_text.dart';
import '../../models/binary_installation.dart';
import '../../widgets/page_header.dart';

class EnvironmentScreen extends StatefulWidget {
  const EnvironmentScreen({super.key, required this.controller});
  final AppController controller;

  @override
  State<EnvironmentScreen> createState() => _EnvironmentScreenState();
}

class _EnvironmentScreenState extends State<EnvironmentScreen> {
  late final TextEditingController _ffmpegPath;
  late final TextEditingController _ffprobePath;

  @override
  void initState() {
    super.initState();
    _ffmpegPath = TextEditingController();
    _ffprobePath = TextEditingController();
    widget.controller.addListener(_syncPaths);
    _syncPaths();
  }

  void _syncPaths() {
    final ffmpeg = widget.controller.ffmpeg;
    final ffprobe = widget.controller.ffprobe;
    if (_ffmpegPath.text.isEmpty && ffmpeg != null) {
      _ffmpegPath.text = ffmpeg.path;
    }
    if (_ffprobePath.text.isEmpty && ffprobe != null) {
      _ffprobePath.text = ffprobe.path;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncPaths);
    _ffmpegPath.dispose();
    _ffprobePath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Column(
      children: [
        PageHeader(
          title: 'Środowisko',
          subtitle: 'Wykryte narzędzia i możliwości tej instalacji FFmpeg.',
          actions: [
            FilledButton.icon(
              onPressed: controller.scanning
                  ? null
                  : controller.scanCapabilities,
              icon: const Icon(Icons.radar),
              label: const Text('Skanuj możliwości'),
            ),
          ],
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            children: [
              if (controller.initializationError != null)
                _ErrorCard(message: controller.initializationError!),
              for (final installation in controller.installations)
                _BinaryCard(installation: installation),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ręczne ścieżki',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _ffmpegPath,
                        decoration: InputDecoration(
                          labelText: context.tr('Ścieżka do ffmpeg'),
                          prefixIcon: Icon(Icons.movie_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _ffprobePath,
                        decoration: InputDecoration(
                          labelText: context.tr('Ścieżka do ffprobe'),
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => controller.detectBinaries(
                          ffmpegPath: _ffmpegPath.text,
                          ffprobePath: _ffprobePath.text,
                        ),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Sprawdź ścieżki'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _CatalogStatus(controller: controller),
            ],
          ),
        ),
      ],
    );
  }
}

class _BinaryCard extends StatelessWidget {
  const _BinaryCard({required this.installation});
  final BinaryInstallation installation;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              installation.available ? Icons.check_circle : Icons.error,
              color: installation.available ? colors.primary : colors.error,
              size: 30,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    installation.executableName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  SelectableText(installation.path),
                  if (installation.version.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(installation.version),
                  ],
                  if (installation.configuration.isNotEmpty)
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('Konfiguracja kompilacji'),
                      children: [SelectableText(installation.configuration)],
                    ),
                  if (installation.error != null)
                    Text(
                      installation.error!,
                      style: TextStyle(color: colors.error),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogStatus extends StatelessWidget {
  const _CatalogStatus({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final progress = controller.scanProgress;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Baza możliwości',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (controller.snapshot != null)
              Text(
                'Gotowy dla: ${controller.snapshot!.version}\n'
                'Utworzony: ${controller.snapshot!.createdAt.toLocal()}',
              )
            else
              const Text('Możliwości nie zostały jeszcze przeskanowane.'),
            if (progress != null) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(value: progress.fraction),
              const SizedBox(height: 6),
              Text(progress.label),
            ],
            if (controller.scanError != null)
              Text(
                controller.scanError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(padding: const EdgeInsets.all(16), child: Text(message)),
    );
  }
}
