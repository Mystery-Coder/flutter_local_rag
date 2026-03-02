import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_rag/services/model_download_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
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
      home: DocSpacesApp(),
    ),
  );
}

class DocSpacesApp extends StatefulWidget {
  const DocSpacesApp({super.key});

  @override
  State<DocSpacesApp> createState() => _DocSpacesAppState();
}

class _DocSpacesAppState extends State<DocSpacesApp> {
  var service = ModelDownloadService();
  late var b = service.isModelInstalled;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text("Model downloaded -> $b")));
  }
}
