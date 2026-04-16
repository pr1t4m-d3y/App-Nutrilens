import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/home_screen.dart';
import '../screens/progress_screen.dart';
import '../screens/scan_screen.dart';
import '../screens/processing_screen.dart';
import '../screens/results_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/health_profile_screen.dart';
import '../screens/medicine_reminder_screen.dart';
import '../screens/login_screen.dart';
import '../screens/history_screen.dart';
import '../screens/avoid_list_screen.dart';
import '../screens/medicine_scan_screen.dart';
import '../screens/medicine_processing_screen.dart';
import '../screens/medicine_results_screen.dart';
import '../screens/chatbot_view_all_screen.dart';
import '../widgets/liquid_glass_nav_bar.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/scan',
      builder: (context, state) => const ScanScreen(),
    ),
    GoRoute(
      path: '/processing',
      builder: (context, state) => const ProcessingScreen(),
    ),
    GoRoute(
      path: '/results',
      builder: (context, state) => const ResultsScreen(),
    ),
    GoRoute(
      path: '/health-profile',
      builder: (context, state) => const HealthProfileScreen(),
    ),
    GoRoute(
      path: '/avoid-list',
      builder: (context, state) => const AvoidListScreen(),
    ),
    GoRoute(
      path: '/medicine-reminders',
      builder: (context, state) => const MedicineReminderScreen(),
    ),
    // Medicine scan flow
    GoRoute(
      path: '/medicine-scan',
      builder: (context, state) => const MedicineScanScreen(),
    ),
    GoRoute(
      path: '/chatbot-view-all',
      builder: (context, state) {
        final extras = state.extra as Map<String, dynamic>? ?? {};
        return ChatbotViewAllScreen(
          products: extras['products'] ?? [],
          intent: extras['intent'] ?? 'Search',
        );
      },
    ),
    GoRoute(
      path: '/medicine-processing',
      builder: (context, state) => const MedicineProcessingScreen(),
    ),
    GoRoute(
      path: '/medicine-results',
      builder: (context, state) => const MedicineResultsScreen(),
    ),
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) {
        return Scaffold(
          body: child,
          extendBody: true,
          bottomNavigationBar: const LiquidGlassNavBar(),
        );
      },
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/progress',
          builder: (context, state) => const ProgressScreen(),
        ),
        GoRoute(
          path: '/history',
          builder: (context, state) => const HistoryScreen(),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfileScreen(),
        ),
      ],
    ),
  ],
);
