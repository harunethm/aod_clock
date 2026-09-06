import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/aod_display/presentation/screens/aod_display_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../persistence/secure_storage_provider.dart';
import '../persistence/storage_keys.dart';

/// `AodOverlayActivity` (native) launches the same Dart entrypoint as the
/// normal app, but overrides `getInitialRoute()` to `/aod` — that's how one
/// Flutter engine serves both the settings UI and the AOD overlay. This is
/// the standard multi-entry-Activity pattern for a single Flutter module.
final appRouterProvider = Provider<GoRouter>((ref) {
  final initialRoute = PlatformDispatcher.instance.defaultRouteName;

  return GoRouter(
    initialLocation: initialRoute == '/' ? '/' : initialRoute,
    redirect: (context, state) async {
      // Never redirect the native-launched AOD route — it must render
      // immediately with no app-shell detour.
      if (state.matchedLocation == '/aod') return null;

      final storage = ref.read(secureStorageProvider);
      final onboardingDone =
          (await storage.read(kOnboardingCompleteKey)) == 'true';
      if (!onboardingDone && state.matchedLocation != '/onboarding') {
        return '/onboarding';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SettingsScreen()),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/aod',
        // `extra: true` marks a Preview-button push (see settings_screen.dart)
        // — the native-launched initial route never carries `extra`.
        builder: (context, state) =>
            AodDisplayScreen(isPreview: state.extra == true),
      ),
    ],
  );
});
