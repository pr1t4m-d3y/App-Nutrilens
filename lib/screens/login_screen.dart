import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/user_profile_provider.dart';
import '../providers/scan_history_provider.dart';
import '../theme/app_colors.dart';

/// Entry screen. There are no accounts: the health profile lives on this
/// phone in encrypted storage, and cloud requests use an anonymous identity
/// that the app creates itself.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _starting = false;

  Future<void> _start() async {
    if (_starting) return;
    setState(() => _starting = true);

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final profile = Provider.of<UserProfileProvider>(context, listen: false);
    final history = Provider.of<ScanHistoryProvider>(context, listen: false);

    auth.login('local');
    profile.clearAll();
    history.clearHistory();
    // Restore the saved profile (if one exists) and keep saving changes.
    await profile.attachStorage();

    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: AppColors.signatureGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryContainer.withOpacity(0.4),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: AppColors.onPrimary,
                  size: 40,
                ),
              ),
              const SizedBox(height: 32),

              Text('NutriLens', style: theme.textTheme.displayMedium),
              const SizedBox(height: 8),
              Text(
                'Food label and medicine scanner.',
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Text(
                        'Your health profile is stored on this phone, encrypted. '
                        'Allergen, avoid-list and medicine checks run on the phone.',
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _starting ? null : _start,
                          child: const Text('Get started'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
