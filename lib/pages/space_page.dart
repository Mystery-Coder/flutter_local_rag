import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_rag/types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SpacePage extends ConsumerWidget {
  final SpacePageArguments arguments;

  const SpacePage({super.key, required this.arguments});

  static const routeName = "/space";

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(arguments.spaceName),
        centerTitle: false,
        // Make the AppBar itself transparent — flexibleSpace paints the colors
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarIconBrightness: Brightness.light,
        ),
        flexibleSpace: Column(
          children: [
            Container(color: Colors.black, height: statusBarHeight),
            Expanded(child: Container(color: Colors.blue)),
          ],
        ),
      ),
    );
  }
}
