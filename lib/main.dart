import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_rag/pages/home_page.dart';
import 'package:flutter_local_rag/pages/setup_page.dart';
import 'package:flutter_local_rag/pages/space_page.dart';
import 'package:flutter_local_rag/services/db_service.dart';
import 'package:flutter_local_rag/services/model_download_service.dart';
import 'package:flutter_local_rag/types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');
  final hfToken = dotenv.maybeGet('HUGGINGFACE_TOKEN');

  ModelDownloadService.ensureInitialized(huggingFaceToken: hfToken);

  await DatabaseHelper.singleInstance.database;

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
      initialRoute: SetupPage.routeName,
      onGenerateRoute: (settings) {
        final args = settings.arguments;

        switch (settings.name) {
          case SetupPage.routeName:
            {
              return MaterialPageRoute(builder: (context) => const SetupPage());
            }
          case HomePage.routeName:
            {
              return MaterialPageRoute(builder: (context) => const HomePage());
            }
          case SpacePage.routeName:
            {
              if (args is SpacePageArguments) {
                return MaterialPageRoute(
                  builder: (_) => SpacePage(arguments: args),
                );
              }

              return _errorRoute(message: "Arguments for Space Page Missing");
            }
          default:
            {
              return _errorRoute();
            }
        }
      },

      home: const SetupPage(),
    );
  }
}

Route<dynamic> _errorRoute({
  String message = 'Something went wrong with the navigation!',
}) {
  return MaterialPageRoute(
    builder: (_) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text(message)),
      );
    },
  );
}
