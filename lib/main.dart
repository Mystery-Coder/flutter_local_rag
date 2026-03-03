import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_rag/pages/setup_page.dart';
import 'package:flutter_local_rag/services/db_service.dart';
import 'package:flutter_local_rag/services/model_download_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from the bundled .env asset.
  await dotenv.load(fileName: '.env');
  final hfToken = dotenv.maybeGet('HUGGINGFACE_TOKEN');
  debugPrint("Token $hfToken");
  // One-time initialisation – registers the HuggingFace token with flutter_gemma.
  ModelDownloadService.ensureInitialized(huggingFaceToken: hfToken);

  // Warm-up the database: creates all tables on first launch.
  await DatabaseHelper.singleInstance.database;

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
      home: const SetupPage(),
    ),
  );
}
