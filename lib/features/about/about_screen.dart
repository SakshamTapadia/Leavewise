import 'package:flutter/material.dart';
import 'package:leavewise/core/constants/regions.dart';
import 'package:leavewise/core/theme/app_colors.dart';
import 'package:leavewise/core/theme/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.all(Gap.l),
        children: [
          Text(
            'LeaveWise',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.accent,
                ),
          ),
          const SizedBox(height: Gap.xs),
          const Text('Work smarter. Take better breaks.'),
          const SizedBox(height: Gap.m),
          const Text('Version $appVersion'),
          const SizedBox(height: Gap.m),
          const Text(
            'LeaveWise finds long weekends and shows how few leave days you need '
            'to turn holidays into longer breaks. It runs entirely on your device.',
          ),
          const SizedBox(height: Gap.l),
          OutlinedButton(
            onPressed: () => showLicensePage(
              context: context,
              applicationName: 'LeaveWise',
              applicationVersion: appVersion,
            ),
            child: const Text('Open source licenses'),
          ),
        ],
      ),
    );
  }
}
