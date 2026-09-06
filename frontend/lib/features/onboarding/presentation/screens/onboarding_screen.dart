import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../settings/presentation/providers/settings_controller.dart';

/// Shown once on first launch (see `app_router.dart`'s redirect). Explains
/// the tradeoff up front rather than let the user discover it as
/// unexplained battery drain: this is a software approximation of AOD, not
/// real hardware AOD, and costs more battery.
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'AOD Clock',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'This shows a clock, date and mini music player instead of '
                'letting your screen turn off — an approximation of '
                'Samsung\'s Always-On Display.\n\n'
                'It is not the real thing: your phone\'s hardware AOD panel '
                'draws power through a dedicated low-power controller. This '
                'app keeps the full screen on at low brightness instead, so '
                'it uses noticeably more battery. Pure black backgrounds, '
                'once-a-minute redraws and pixel-shift help, but can\'t '
                'close that gap.\n\n'
                'It also needs a couple of permissions granted manually in '
                'system settings — the next screen walks through them.',
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () async {
                  await ref
                      .read(settingsDatasourceProvider)
                      .writeOnboardingComplete();
                  if (context.mounted) context.go('/');
                },
                child: const Text('Continue to setup'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
