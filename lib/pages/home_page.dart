import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_rag/pages/space_page.dart';
import 'package:flutter_local_rag/types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_rag/providers/spaces_provider.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  static const routeName = '/home';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final spacesAsync = ref.watch(spacesProvider);

    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Doc Spaces'),
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
            Expanded(child: Container(color: Colors.red)),
          ],
        ),
      ),
      body: spacesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (spaces) => spaces.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_stories_outlined,
                      size: 72,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    const Text('No spaces yet. Create one!'),
                  ],
                ),
              )
            : ListView.builder(
                itemCount: spaces.length,
                itemBuilder: (_, i) {
                  final space = spaces[i];
                  return ListTile(
                    leading: const Icon(Icons.folder_outlined),
                    title: Text(space.name),
                    subtitle: Text(space.createdAt ?? ''),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => ref
                          .read(spacesProvider.notifier)
                          .deleteSpace(space.id),
                    ),
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        SpacePage.routeName,
                        arguments: SpacePageArguments(
                          spaceID: space.id,
                          spaceName: space.name,
                        ),
                      );
                    },
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSpaceDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showAddSpaceDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Space'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Space name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await ref.read(spacesProvider.notifier).addSpace(name);
    }
  }
}
