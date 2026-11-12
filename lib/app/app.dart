import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:leavewise/app/providers.dart';
import 'package:leavewise/app/router.dart';
import 'package:leavewise/core/theme/app_theme.dart';
import 'package:leavewise/features/settings/domain/app_settings.dart';

class LeaveWiseApp extends ConsumerWidget {
  const LeaveWiseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final choice = ref.watch(settingsProvider.select((s) => s.theme));
    return MaterialApp.router(
      title: 'LeaveWise',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: switch (choice) {
        ThemeChoice.light => ThemeMode.light,
        ThemeChoice.dark => ThemeMode.dark,
        ThemeChoice.system => ThemeMode.system,
      },
      routerConfig: ref.watch(routerProvider),
    );
  }
}
