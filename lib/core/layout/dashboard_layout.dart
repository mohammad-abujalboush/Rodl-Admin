import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:roadside_service/core/api/secure_storage_helper.dart';
import 'package:roadside_service/core/di/injection_container.dart';
import 'package:roadside_service/core/theme/app_theme.dart';

class DashboardLayout extends StatelessWidget {
  final Widget child;

  const DashboardLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, sizingInformation) {
        bool isMobileOrTablet =
            sizingInformation.isMobile || sizingInformation.isTablet;

        return Scaffold(
          appBar: isMobileOrTablet
              ? AppBar(title: const Text('Rodl Admin'))
              : null,
          drawer: isMobileOrTablet ? const _DashboardSidebar() : null,
          body: Row(
            children: [
              if (!isMobileOrTablet)
                const SizedBox(width: 260, child: _DashboardSidebar()),
              Expanded(
                child: Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: child,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// --- THE SIDEBAR WIDGET ---
class _DashboardSidebar extends StatelessWidget {
  const _DashboardSidebar();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Drawer(
      elevation: 0,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.only(
              top: 48,
              bottom: 24,
              left: 24,
              right: 24,
            ),
            decoration: BoxDecoration(
              color: theme.primaryColor.withOpacity(0.05),
              border: Border(
                bottom: BorderSide(color: theme.dividerColor.withOpacity(0.05)),
              ),
            ),
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // --- UPGRADED SIDEBAR LOGO ---
                Image.asset('assets/images/app-icon.jpeg', height: 40),
                const SizedBox(height: 12),
                Text(
                  'Rodl Admin',
                  style: TextStyle(
                    color: theme.primaryColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Menu Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                const _SidebarSectionTitle(title: 'OPERATIONS'),
                _SidebarItem(
                  icon: Icons.dashboard,
                  title: 'Home',
                  onTap: () => context.go('/'),
                ),
                _SidebarItem(
                  icon: Icons.radar,
                  title: 'Live Map',
                  onTap: () => context.go('/live-radar'),
                ),
                _SidebarItem(
                  icon: Icons.local_shipping,
                  title: 'Active Jobs',
                  onTap: () => context.go('/active-jobs'),
                ),

                const SizedBox(height: 16),
                const _SidebarSectionTitle(title: 'FINANCE'),

                _SidebarItem(
                  icon: Icons.money,
                  title: 'Financial Overview',
                  onTap: () => context.go('/financial-overview'),
                ),
                _SidebarItem(
                  icon: Icons.payments,
                  title: 'Payroll',
                  onTap: () => context.go('/payroll'),
                ),

                _SidebarItem(
                  icon: Icons.receipt_long,
                  title: 'Invoices',
                  onTap: () => context.go('/invoices'),
                ),
                const SizedBox(height: 16),

                const _SidebarSectionTitle(title: 'TEAM'),
                _SidebarItem(
                  icon: Icons.people,
                  title: 'Drivers',
                  onTap: () => context.go('/driver-approvals'),
                ),
                _SidebarItem(
                  icon: Icons.business,
                  title: 'Employees',
                  onTap: () => context.go('/staff-management'),
                ),
                const SizedBox(height: 16),
                const _SidebarSectionTitle(title: 'Customer Management'),
                _SidebarItem(
                  icon: Icons.contacts,
                  title: 'Customers',
                  onTap: () => context.go('/crm'),
                ),

                const SizedBox(height: 16),
                const _SidebarSectionTitle(title: 'HISTORY & SUPPORT'),

                _SidebarItem(
                  icon: Icons.support_agent,
                  title: 'Support',
                  onTap: () => context.go('/helpdesk'),
                ),
                _SidebarItem(
                  icon: Icons.history,
                  title: 'Job History',
                  onTap: () => context.go('/incidents'),
                ),

                const SizedBox(height: 16),
                const _SidebarSectionTitle(title: 'Marketing'),

                _SidebarItem(
                  icon: Icons.campaign,
                  title: 'Social Campigns',
                  onTap: () => context.go('/marketing'),
                ),
                _SidebarItem(
                  icon: Icons.featured_play_list_outlined,
                  title: 'Promotions',
                  onTap: () => context.go('/marketing'),
                ),

                const _SidebarSectionTitle(title: 'SYSTEM'),
                _SidebarItem(
                  icon: Icons.settings,
                  title: 'Settings',
                  onTap: () => context.go('/settings'),
                ),
                _SidebarItem(
                  icon: Icons.price_change,
                  title: 'Price Engine',
                  onTap: () => context.go('/pricing'),
                ),
                _SidebarItem(
                  icon: Icons.question_answer,
                  title: 'Smart Questions',
                  onTap: () => context.go('/dispatch-builder'),
                ),
                _SidebarItem(
                  icon: Icons.call,
                  title: 'Call Management',
                  onTap: () => context.go('/call-management'),
                ),
              ],
            ),
          ),

          // Bottom Actions
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Column(
              children: [
                // --- THEME TOGGLE BUTTON DIRECTLY LINKED TO APP_THEME ---
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: AppTheme.themeNotifier,
                  builder: (context, currentTheme, _) {
                    final isDark = currentTheme == ThemeMode.dark;
                    return _SidebarItem(
                      icon: isDark ? Icons.light_mode : Icons.dark_mode,
                      title: isDark ? 'Light Mode' : 'Dark Mode',
                      onTap: () => AppTheme.toggleTheme(),
                    );
                  },
                ),

                // --- SECURE LOGOUT ---
                _SidebarItem(
                  icon: Icons.logout,
                  title: 'Log Out',
                  isDestructive: true,
                  onTap: () {
                    sl<SecureStorageHelper>().deleteToken().then((_) {
                      context.go('/login');
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarSectionTitle extends StatelessWidget {
  final String title;
  const _SidebarSectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, bottom: 8, top: 8),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).disabledColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isDestructive;

  const _SidebarItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isDestructive
        ? theme.colorScheme.error
        : theme.colorScheme.onSurface.withOpacity(0.7);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        leading: Icon(icon, color: color, size: 22),
        title: Text(
          title,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        hoverColor: theme.primaryColor.withOpacity(0.05),
        onTap: onTap,
      ),
    );
  }
}
