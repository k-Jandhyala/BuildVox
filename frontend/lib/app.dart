import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'router.dart';
import 'theme.dart';

class BuildVoxApp extends ConsumerWidget {
  const BuildVoxApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'BuildVox',
      theme: buildVoxTheme(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
