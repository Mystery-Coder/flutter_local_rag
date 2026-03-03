import 'package:flutter/material.dart';
import 'package:flutter_local_rag/services/model_download_service.dart';

/// Supply your HuggingFace token at build time:
///   flutter run --dart-define-from-file=config.json
/// where config.json contains: { "HUGGINGFACE_TOKEN": "hf_..." }
///
/// This keeps the token out of bundled assets (unlike .env).
const _hfToken = String.fromEnvironment('HUGGINGFACE_TOKEN');

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // One-time initialisation – registers the token with flutter_gemma.
  ModelDownloadService.ensureInitialized(
    huggingFaceToken: _hfToken.isNotEmpty ? _hfToken : null,
  );

  runApp(
    MaterialApp(
      title: 'Doc Spaces',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const DocSpacesApp(),
    ),
  );
}

class DocSpacesApp extends StatefulWidget {
  const DocSpacesApp({super.key});

  @override
  State<DocSpacesApp> createState() => _DocSpacesAppState();
}

class _DocSpacesAppState extends State<DocSpacesApp> {
  final _downloadService = ModelDownloadService(
    token: _hfToken.isNotEmpty ? _hfToken : null,
  );

  bool? _modelInstalled;

  @override
  void initState() {
    super.initState();
    _checkModel();
  }

  Future<void> _checkModel() async {
    final installed = await _downloadService.isModelInstalled;
    if (mounted) setState(() => _modelInstalled = installed);
  }

  @override
  Widget build(BuildContext context) {
    final status = _modelInstalled == null
        ? 'Checking…'
        : 'Model downloaded → $_modelInstalled';

    return Scaffold(body: Center(child: Text(status)));
  }
}
