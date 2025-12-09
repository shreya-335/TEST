import 'package:camera/camera.dart';
import 'package:go_router/go_router.dart';
import 'package:myapp/screens/splash_screen.dart';
import 'package:myapp/screens/onboarding/login_screen.dart';
import 'package:myapp/screens/home_screen.dart';
import 'package:myapp/screens/add_farm_screen.dart';
import 'package:myapp/screens/farm_details_screen.dart';
import 'package:myapp/screens/smart_camera_screen.dart';
import 'package:myapp/screens/onboarding/language_select_screen.dart';
import 'package:myapp/screens/onboarding/verify_otp_screen.dart';
import 'package:myapp/screens/onboarding/set_password_screen.dart';
import 'package:myapp/screens/smart_farming/community_hub_screen.dart';
import 'package:myapp/screens/smart_farming/finance_ledger_screen.dart';
import 'package:myapp/screens/advisory/advisory_chat_screen.dart';
import 'package:myapp/screens/profile_setup/profile_setup_screen.dart';
import 'package:myapp/screens/smart_farming/session_map_screen.dart';
import 'package:myapp/models/sampling_session.dart';
import 'package:myapp/screens/sampling/block_camera_screen.dart';

// --- NEW IMPORTS ---
import 'package:myapp/screens/cce/cce_task_list_screen.dart';
import 'package:myapp/screens/cce/cce_form_screen.dart';

final GoRouter router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/language-select',
      builder: (context, state) => const LanguageSelectScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/verify-otp',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return VerifyOTPScreen(
            sessionId: extra['sessionId'] ?? '',
            fullName: extra['fullName'] ?? '',
            email: extra['email'] ?? '',
            phone: extra['phone'] ?? ''
        );
      },
    ),
    GoRoute(
      path: '/set-password',
      builder: (context, state) {
         final extra = state.extra as Map<String, dynamic>? ?? {};
         return SetPasswordScreen(accessToken: extra['accessToken'] ?? '');
      },
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/add-farm',
      builder: (context, state) => const AddFarmScreen(accessToken: "valid"),
    ),
    GoRoute(
      path: '/farm/:id',
      builder: (context, state) {
        final farmId = state.pathParameters['id']!;
        return FarmDetailsScreen(farmId: farmId);
      },
    ),
    GoRoute(
      path: '/community',
      builder: (context, state) => const CommunityHubScreen(),
    ),
    GoRoute(
      path: '/finance',
      builder: (context, state) => const FinanceLedgerScreen(),
    ),
    GoRoute(
      path: '/advisory',
      builder: (context, state) => const AdvisoryChatScreen(),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileSetupScreen(), 
    ),
    GoRoute(
      path: '/smart-camera',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final farmId = extra?['farmId'] as String;
        return SmartCameraScreen(farmId: farmId);
      },
    ),
    GoRoute(
      path: '/session-map/:farmId',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        final sessionId = extra['sessionId'] as String? ?? '';
        final blocks = extra['blocks'] as List<dynamic>? ?? <dynamic>[];
        return SessionMapScreen(
          farmId: state.pathParameters['farmId']!,
          sessionId: sessionId,
          blocks: blocks.cast<SamplingBlock>(),
        );
      },
    ),
    GoRoute(
      path: '/block-camera',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        final block = extra['block'];
        final sessionId = extra['sessionId'] as String? ?? '';
        return BlockCameraScreen(block: block as SamplingBlock, sessionId: sessionId);
      },
    ),
    
    // --- NEW ROUTES FOR CCE ---
    GoRoute(
      path: '/cce-tasks',
      builder: (context, state) => const CceTaskListScreen(),
    ),
    GoRoute(
      path: '/cce-form',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return CceFormScreen(taskId: extra['taskId'] ?? 'Unknown');
      },
    ),
  ],
);