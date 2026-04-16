import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/user_profile_provider.dart';
import '../providers/scan_history_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userIdController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showLoginFields = false;
  String? _errorText;

  /// Valid credentials
  static const _validUsers = {
    'User123': 'User123',
    'Admin123': 'Admin123',
  };

  void _handleCredentialLogin() {
    final uid = _userIdController.text.trim();
    final pwd = _passwordController.text.trim();
    
    if (uid.isEmpty || pwd.isEmpty) {
      setState(() => _errorText = 'Please enter both User ID and Password');
      return;
    }

    if (_validUsers[uid] == pwd) {
      setState(() => _errorText = null);
      _loginAs(uid);
    } else {
      setState(() => _errorText = 'Invalid credentials');
    }
  }

  void _loginAs(String userId) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final profile = Provider.of<UserProfileProvider>(context, listen: false);
    final history = Provider.of<ScanHistoryProvider>(context, listen: false);

    auth.login(userId);

    if (userId == 'User123') {
      // Demo user — load pre-built data
      profile.loadDemoData();
      history.loadDemoHistory();
    } else {
      // New / admin user — completely fresh
      profile.clearAll();
      history.clearHistory();
    }

    context.go('/home');
  }

  void _showComingSoon(String method) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$method login coming soon! Use User ID login for now.'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _userIdController.dispose();
    _passwordController.dispose();
    super.dispose();
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
              
              // Welcome Text
              Text('NutriLens', style: theme.textTheme.displayMedium),
              const SizedBox(height: 8),
              Text(
                'Your AI food label scanner.',
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Login Card
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      // Google Login
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _showComingSoon('Google'),
                          icon: const Icon(Icons.g_mobiledata_rounded, size: 32),
                          label: const Text('Continue with Google'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.colorScheme.onSurface,
                            side: BorderSide(color: theme.colorScheme.outlineVariant, width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
                            textStyle: theme.textTheme.titleSmall,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Phone Login
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _showComingSoon('Phone'),
                          icon: const Icon(Icons.phone_iphone_rounded, size: 24),
                          label: const Text('Continue with Phone'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.colorScheme.onSurface,
                            side: BorderSide(color: theme.colorScheme.outlineVariant, width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
                            textStyle: theme.textTheme.titleSmall,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      Divider(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
                      const SizedBox(height: 16),

                      // Toggle credential fields
                      if (!_showLoginFields) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => setState(() => _showLoginFields = true),
                            child: const Text('Login with User ID'),
                          ),
                        ),
                      ] else ...[
                        // User ID field
                        TextField(
                          controller: _userIdController,
                          decoration: InputDecoration(
                            labelText: 'User ID',
                            hintText: 'Enter User ID',
                            prefixIcon: const Icon(Icons.person_outline_rounded),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Password field
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            hintText: 'Enter Password',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onSubmitted: (_) => _handleCredentialLogin(),
                        ),
                        if (_errorText != null) ...[
                          const SizedBox(height: 8),
                          Text(_errorText!, style: TextStyle(color: theme.colorScheme.error, fontSize: 13)),
                        ],
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _handleCredentialLogin,
                            child: const Text('Login'),
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),
                      // Hint text
                      Text(
                        'Demo: User123 / User123  •  New: Admin123 / Admin123',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        textAlign: TextAlign.center,
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
