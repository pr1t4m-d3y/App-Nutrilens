import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';

class LiquidGlassNavBar extends StatelessWidget {
  const LiquidGlassNavBar({super.key});

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/progress')) return 1;
    if (location.startsWith('/scan')) return 2;
    if (location.startsWith('/history')) return 3;
    if (location.startsWith('/profile')) return 4;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/progress');
        break;
      case 2:
        context.push('/scan');
        break;
      case 3:
        context.go('/history');
        break;
      case 4:
        context.go('/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final int currentIndex = _calculateSelectedIndex(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Dark mode: use dark card color; Light mode: frosted white
    final barColor = isDark 
        ? const Color(0xFF141414).withOpacity(0.85) 
        : AppColors.surfaceContainerLowest.withOpacity(0.7);
    final shadowColor = isDark
        ? Colors.black.withOpacity(0.3)
        : const Color(0xFF2D3335).withOpacity(0.06);

    return Container(
      margin: const EdgeInsets.only(left: 24, right: 24, bottom: 32),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9999),
        boxShadow: [
          BoxShadow(color: shadowColor, blurRadius: 32, offset: const Offset(0, 12)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 72,
            color: barColor,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double tabWidth = constraints.maxWidth / 5;
                
                return Stack(
                  children: [
                    // Liquid drop glow
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutBack,
                      top: 12,
                      left: (tabWidth * currentIndex) + (tabWidth / 2) - 24,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: currentIndex == 2 ? 0.0 : 1.0,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.12),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: theme.colorScheme.primary.withOpacity(0.2), blurRadius: 16),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    Row(
                      children: [
                        _buildTabItem(context, 0, Icons.home_rounded, currentIndex, tabWidth),
                        _buildTabItem(context, 1, Icons.bar_chart_rounded, currentIndex, tabWidth),
                        _buildCenterFab(context, 2, Icons.camera_alt_rounded, tabWidth),
                        _buildTabItem(context, 3, Icons.history_rounded, currentIndex, tabWidth),
                        _buildTabItem(context, 4, Icons.person_rounded, currentIndex, tabWidth),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem(BuildContext context, int index, IconData icon, int currentIndex, double width) {
    final theme = Theme.of(context);
    final bool isSelected = currentIndex == index;
    final Color iconColor = isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onItemTapped(index, context),
      child: SizedBox(
        width: width,
        height: 72,
        child: Center(child: Icon(icon, color: iconColor, size: 28)),
      ),
    );
  }

  Widget _buildCenterFab(BuildContext context, int index, IconData icon, double width) {
    final theme = Theme.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onItemTapped(index, context),
      child: SizedBox(
        width: width,
        height: 72,
        child: Center(
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [theme.colorScheme.primary, theme.colorScheme.primaryContainer],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }
}
