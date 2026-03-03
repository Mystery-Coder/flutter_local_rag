import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_gemma/core/model_management/cancel_token.dart';
import 'package:flutter_local_rag/pages/home_page.dart';
import 'package:flutter_local_rag/services/model_download_service.dart';
import 'package:flutter_local_rag/services/vector_store_service.dart';

enum _DownloadState { idle, downloading, done, error }

class SetupPage extends StatefulWidget {
  const SetupPage({super.key});

  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  late final ModelDownloadService _llmService;
  late final VectorStoreService _embedderService;

  // ── check phase ────────────────────────────────────────────────────────────
  bool _checking = true;

  // ── LLM model ──────────────────────────────────────────────────────────────
  bool _llmInstalled = false;
  _DownloadState _llmState = _DownloadState.idle;
  double _llmProgress = 0;
  CancelToken? _llmCancelToken;

  // ── Embedding model ────────────────────────────────────────────────────────
  bool _embedderInstalled = false;
  _DownloadState _embedModelState = _DownloadState.idle;
  double _embedModelProgress = 0;
  _DownloadState _tokenizerState = _DownloadState.idle;
  double _tokenizerProgress = 0;

  String? _error;

  // ── Initialisation ─────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    final token = dotenv.maybeGet('HUGGINGFACE_TOKEN');
    _llmService = ModelDownloadService(token: token);
    _embedderService = VectorStoreService(token: token);
    _checkModels();
  }

  Future<void> _checkModels() async {
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final llm = await _llmService.isModelInstalled;
      final emb = await _embedderService.isEmbedderInstalled;
      if (!mounted) return;
      setState(() {
        _llmInstalled = llm;
        _llmState = llm ? _DownloadState.done : _DownloadState.idle;
        _embedderInstalled = emb;
        _embedModelState = emb ? _DownloadState.done : _DownloadState.idle;
        _tokenizerState = emb ? _DownloadState.done : _DownloadState.idle;
        _checking = false;
      });
      if (llm && emb) _proceed();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not check model status: $e';
        _checking = false;
      });
    }
  }

  // ── LLM download ───────────────────────────────────────────────────────────

  Future<void> _downloadLlm() async {
    _llmCancelToken = CancelToken();
    setState(() {
      _llmState = _DownloadState.downloading;
      _llmProgress = 0;
      _error = null;
    });
    try {
      await _llmService.downloadModel(
        onProgress: (p) {
          if (mounted) setState(() => _llmProgress = p);
        },
        cancelToken: _llmCancelToken,
      );
      if (!mounted) return;
      setState(() {
        _llmInstalled = true;
        _llmState = _DownloadState.done;
      });
      _checkBothDone();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _llmState = _DownloadState.error;
        _error = 'LLM download failed: $e';
      });
    }
  }

  // ── Embedder download ──────────────────────────────────────────────────────

  Future<void> _downloadEmbedder() async {
    setState(() {
      _embedModelState = _DownloadState.downloading;
      _tokenizerState = _DownloadState.downloading;
      _embedModelProgress = 0;
      _tokenizerProgress = 0;
      _error = null;
    });
    try {
      await _embedderService.installEmbedder(
        onModelProgress: (p) {
          if (mounted) setState(() => _embedModelProgress = p);
        },
        onTokenizerProgress: (p) {
          if (mounted) setState(() => _tokenizerProgress = p);
        },
      );
      if (!mounted) return;
      setState(() {
        _embedderInstalled = true;
        _embedModelState = _DownloadState.done;
        _tokenizerState = _DownloadState.done;
      });
      _checkBothDone();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _embedModelState = _DownloadState.error;
        _tokenizerState = _DownloadState.error;
        _error = 'Embedder download failed: $e';
      });
    }
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _checkBothDone() {
    if (_llmInstalled && _embedderInstalled) _proceed();
  }

  void _proceed() {
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Checking installed models…'),
            ],
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final bothBusy =
        _llmState == _DownloadState.downloading ||
        _embedModelState == _DownloadState.downloading;

    return Scaffold(
      appBar: AppBar(title: const Text('Setup')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          // ── Header ──────────────────────────────────────────────────────────
          Text(
            'Model Setup',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Install the on-device models before using Doc Spaces. '
            'Downloads happen once and are stored locally on the device.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
            ),
          ),

          const SizedBox(height: 28),

          // ── LLM model card ──────────────────────────────────────────────────
          _ModelCard(
            title: 'Inference Model',
            subtitle: 'Gemma 3 1B-IT · ~555 MB',
            icon: Icons.psychology_outlined,
            installed: _llmInstalled,
            downloadState: _llmState,
            progress: _llmProgress,
            onInstall: _downloadLlm,
          ),

          const SizedBox(height: 12),

          // ── Embedder card ──────────────────────────────────────────────────
          _EmbedderCard(
            installed: _embedderInstalled,
            modelState: _embedModelState,
            modelProgress: _embedModelProgress,
            tokenizerState: _tokenizerState,
            tokenizerProgress: _tokenizerProgress,
            onInstall: _downloadEmbedder,
          ),

          // ── Error banner ────────────────────────────────────────────────────
          if (_error != null) ...[
            const SizedBox(height: 16),
            Card(
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 32),

          // ── Continue button ─────────────────────────────────────────────────
          FilledButton.icon(
            onPressed: (!bothBusy && _llmInstalled && _embedderInstalled)
                ? _proceed
                : null,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Continue'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// LLM Model Card
// ────────────────────────────────────────────────────────────────────────────

class _ModelCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool installed;
  final _DownloadState downloadState;
  final double progress;
  final VoidCallback onInstall;

  const _ModelCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.installed,
    required this.downloadState,
    required this.progress,
    required this.onInstall,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDownloading = downloadState == _DownloadState.downloading;

    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Icon(icon, size: 28, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusBadge(state: downloadState, installed: installed),
              ],
            ),

            // Progress
            if (isDownloading) ...[
              const SizedBox(height: 14),
              LinearProgressIndicator(
                value: progress / 100,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 4),
              Text(
                '${progress.toStringAsFixed(1)} %',
                style: const TextStyle(fontSize: 12),
              ),
            ],

            // Install button
            if (!installed && !isDownloading) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onInstall,
                  icon: const Icon(Icons.download_outlined),
                  label: Text(
                    downloadState == _DownloadState.error ? 'Retry' : 'Install',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Embedder Card (model + tokenizer progress)
// ────────────────────────────────────────────────────────────────────────────

class _EmbedderCard extends StatelessWidget {
  final bool installed;
  final _DownloadState modelState;
  final double modelProgress;
  final _DownloadState tokenizerState;
  final double tokenizerProgress;
  final VoidCallback onInstall;

  const _EmbedderCard({
    required this.installed,
    required this.modelState,
    required this.modelProgress,
    required this.tokenizerState,
    required this.tokenizerProgress,
    required this.onInstall,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDownloading =
        modelState == _DownloadState.downloading ||
        tokenizerState == _DownloadState.downloading;
    final hasError =
        modelState == _DownloadState.error ||
        tokenizerState == _DownloadState.error;
    final badgeState = installed
        ? _DownloadState.done
        : isDownloading
        ? _DownloadState.downloading
        : hasError
        ? _DownloadState.error
        : _DownloadState.idle;

    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Icon(
                  Icons.data_array_outlined,
                  size: 28,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Embedding Model',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        'EmbeddingGemma 300M · ~300 MB',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusBadge(state: badgeState, installed: installed),
              ],
            ),

            // Dual progress bars
            if (isDownloading) ...[
              const SizedBox(height: 14),
              _ProgressRow(label: 'Model', progress: modelProgress),
              const SizedBox(height: 10),
              _ProgressRow(label: 'Tokenizer', progress: tokenizerProgress),
            ],

            // Install button
            if (!installed && !isDownloading) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onInstall,
                  icon: const Icon(Icons.download_outlined),
                  label: Text(hasError ? 'Retry' : 'Install'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  final String label;
  final double progress;

  const _ProgressRow({required this.label, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12)),
            Text(
              '${progress.toStringAsFixed(1)} %',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: progress / 100,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Status Badge
// ────────────────────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final _DownloadState state;
  final bool installed;

  const _StatusBadge({required this.state, required this.installed});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (installed || state == _DownloadState.done) {
      return _chip(
        icon: Icons.check_circle_outline,
        label: 'Installed',
        fg: cs.onPrimaryContainer,
        bg: cs.primaryContainer,
      );
    }
    if (state == _DownloadState.downloading) {
      return const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      );
    }
    if (state == _DownloadState.error) {
      return _chip(
        icon: Icons.error_outline,
        label: 'Error',
        fg: cs.onErrorContainer,
        bg: cs.errorContainer,
      );
    }
    return _chip(
      icon: Icons.downloading_outlined,
      label: 'Pending',
      fg: cs.onSurfaceVariant,
      bg: cs.surfaceContainerHighest,
    );
  }

  Widget _chip({
    required IconData icon,
    required String label,
    required Color fg,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: fg)),
        ],
      ),
    );
  }
}
