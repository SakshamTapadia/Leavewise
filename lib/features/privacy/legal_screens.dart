import 'package:flutter/material.dart';
import 'package:leavewise/core/theme/app_colors.dart';
import 'package:leavewise/core/theme/app_theme.dart';

class _DocScreen extends StatelessWidget {
  const _DocScreen({required this.title, required this.sections});

  final String title;
  final List<(String, String)> sections;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(Gap.l),
        children: [
          Text(
            'Draft for review. Not legal advice.',
            style: TextStyle(color: mutedColor(context), fontStyle: FontStyle.italic),
          ),
          for (final s in sections) ...[
            const SizedBox(height: Gap.l),
            Semantics(
              header: true,
              child: Text(s.$1, style: Theme.of(context).textTheme.titleMedium),
            ),
            const SizedBox(height: Gap.xs),
            Text(s.$2),
          ],
        ],
      ),
    );
  }
}

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _DocScreen(
      title: 'Privacy policy',
      sections: [
        (
          'What LeaveWise stores',
          'Your country, region, work schedule, holiday preferences, leave '
              'entitlement, leave entries, saved plans and any holidays you add. '
              'It is stored only on your device.',
        ),
        (
          'What LeaveWise does not do',
          'There is no account, no server, no analytics and no advertising. '
              'LeaveWise does not collect your location, contacts or device '
              'calendar, and sends no data anywhere.',
        ),
        (
          'Sharing',
          'Data leaves your device only when you choose Share or Export. What '
              'happens to it after that depends on the app you share it with.',
        ),
        (
          'Retention and deletion',
          'Data stays until you delete it. Settings, Delete all my data, removes '
              'everything LeaveWise stored. Uninstalling the app also removes it.',
        ),
        (
          'Children',
          'LeaveWise is intended for working adults and does not knowingly '
              'collect data from children.',
        ),
        (
          'Changes',
          'If a future version adds accounts, sync or analytics, this policy '
              'will be updated first and new data collection will be optional.',
        ),
      ],
    );
  }
}

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _DocScreen(
      title: 'Terms of service',
      sections: [
        (
          'Using LeaveWise',
          'LeaveWise is a planning aid. It calculates days off from the holiday '
              'dates and work schedule you provide.',
        ),
        (
          'Holiday dates',
          'Holiday dates come from published government notifications or are '
              'estimated. Dates marked tentative depend on moon sighting or '
              'announcements and can change. Always confirm with your employer.',
        ),
        (
          'Leave approval',
          'LeaveWise does not apply for leave and cannot guarantee approval. '
              'Suggestions are not a promise that leave will be granted.',
        ),
        (
          'No warranty',
          'The app is provided as is. You are responsible for your leave '
              'decisions and for checking your employer policy.',
        ),
        (
          'Paid features',
          'The app is free. If paid features are added later, pricing, '
              'renewal and cancellation terms will be shown before purchase, and '
              'refunds follow Google Play and Apple App Store rules.',
        ),
      ],
    );
  }
}
