import 'package:flutter/material.dart';
import '../../features/gst_compliance/presentation/screens/gst_compliance_dashboard_screen.dart';
import '../../features/monetization/domain/services/entitlement_manager.dart';
import '../../features/monetization/presentation/screens/subscription_paywall_screen.dart';
import '../../features/reports/presentation/screens/day_book_screen.dart';
import '../../features/reports/presentation/screens/executive_dashboard_screen.dart';
import '../../features/reports/presentation/screens/reports_hub_screen.dart';
import '../../features/search/domain/models/search_result_item.dart';
import '../../features/search/presentation/screens/global_search_delegate.dart';
import '../shortcuts/tally_shortcuts_handler.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/multimodal_fab_dial.dart';

/// Root Application Shell featuring M3 NavigationBar, Top App Bar with Business Switcher,
/// Multimodal FAB Speed Dial, and Tally-style Shortcuts.
class AppShell extends StatefulWidget {
  final int initialIndex;

  const AppShell({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _currentIndex;
  final EntitlementManager _entitlementManager = EntitlementManager();
  final FocusNode _focusNode = FocusNode();

  String _currentBusinessName = 'Ledgify Enterprise';

  final List<Widget> _destinations = [
    const ExecutiveDashboardScreen(),
    const DayBookScreen(),
    const SizedBox.shrink(), // Center slot reserved for FAB
    const ReportsHubScreen(),
    const GstComplianceDashboardScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _entitlementManager.addListener(_onEntitlementChanged);
  }

  @override
  void dispose() {
    _entitlementManager.removeListener(_onEntitlementChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onEntitlementChanged() {
    if (mounted) setState(() {});
  }

  void _onSearchPressed() async {
    final SearchResultItem? result = await showSearch<SearchResultItem?>(
      context: context,
      delegate: GlobalSearchDelegate(),
    );

    if (result != null && mounted) {
      if (result.category == SearchCategory.report) {
        setState(() => _currentIndex = 3); // Switch to Reports tab
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sub = _entitlementManager.currentSubscription;

    return RawKeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKey: (event) => TallyShortcutsHandler.handleKeyEvent(context, event),
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          backgroundColor: AppColors.surfaceCard,
          title: Row(
            children: [
              // Business Switcher Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.business, size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      _currentBusinessName,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary),
                    ),
                    const Icon(Icons.arrow_drop_down, size: 18, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            // Spotlight Search Action (Min 48dp Touch Target)
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Global Search (G)',
              onPressed: _onSearchPressed,
            ),

            // Tally Gateway Shortcuts Quick Jump
            IconButton(
              icon: const Icon(Icons.keyboard_outlined),
              tooltip: 'Tally Shortcuts',
              onPressed: () => TallyShortcutsHandler.showQuickJumpSheet(context),
            ),

            // Subscription Tier Badge (Tap to open Paywall)
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SubscriptionPaywallScreen()),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: sub.isProOrEnterprise ? const Color(0xFFFEF3C7) : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: sub.isProOrEnterprise ? const Color(0xFFF59E0B) : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        sub.isProOrEnterprise ? Icons.workspace_premium : Icons.stars_outlined,
                        size: 14,
                        color: sub.isProOrEnterprise ? const Color(0xFFB45309) : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        sub.tier,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: sub.isProOrEnterprise ? const Color(0xFFB45309) : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        body: IndexedStack(
          index: _currentIndex,
          children: _destinations,
        ),
        floatingActionButton: const MultimodalFabDial(),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex == 2 ? 0 : _currentIndex,
          onDestinationSelected: (int index) {
            if (index == 2) {
              TallyShortcutsHandler.showQuickJumpSheet(context);
              return;
            }
            setState(() => _currentIndex = index);
          },
          backgroundColor: AppColors.surfaceCard,
          indicatorColor: AppColors.primaryLight,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard, color: AppColors.primary),
              label: 'Home / मुख्य',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long, color: AppColors.primary),
              label: 'Vouchers / बही',
            ),
            NavigationDestination(
              icon: Icon(Icons.bolt_outlined),
              label: 'Shortcuts / मेन्यू',
            ),
            NavigationDestination(
              icon: Icon(Icons.analytics_outlined),
              selectedIcon: Icon(Icons.analytics, color: AppColors.primary),
              label: 'Reports / रिपोर्ट',
            ),
            NavigationDestination(
              icon: Icon(Icons.verified_outlined),
              selectedIcon: Icon(Icons.verified, color: AppColors.primary),
              label: 'GST / नियम',
            ),
          ],
        ),
      ),
    );
  }
}
