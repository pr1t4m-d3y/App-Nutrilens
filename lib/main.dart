import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'navigation/app_router.dart';
import 'providers/auth_provider.dart';
import 'providers/user_profile_provider.dart';
import 'providers/scan_provider.dart';
import 'providers/scan_history_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/chat_provider.dart';
import 'services/cloud_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase (anonymous sign-in for the cloud API) is initialised only when the
  // build was given its configuration. Without it the app runs fully on-device.
  if (CloudConfig.firebaseConfigured) {
    try {
      await Firebase.initializeApp(options: CloudConfig.firebaseOptions);
    } catch (e) {
      debugPrint('Firebase init failed: ${e.runtimeType}');
    }
  }

  runApp(const NutriLensApp());
}

class NutriLensApp extends StatelessWidget {
  const NutriLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => UserProfileProvider()),
        ChangeNotifierProvider(create: (_) => ScanProvider()),
        ChangeNotifierProvider(create: (_) => ScanHistoryProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp.router(
            title: 'NutriLens',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            routerConfig: appRouter,
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
