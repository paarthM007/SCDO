import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:scdo_app/theme/glass_theme.dart';
import 'package:scdo_app/screens/dashboard_screen.dart';
import 'package:scdo_app/screens/supply_routes_screen.dart';
import 'package:scdo_app/screens/route_comparison_screen.dart';
import 'package:scdo_app/screens/history_screen.dart';
import 'package:scdo_app/screens/profile_screen.dart';
import 'package:scdo_app/screens/search_profiles_screen.dart';
import 'package:scdo_app/screens/alt_route_screen.dart';
import 'package:scdo_app/orchestrator_page.dart';

class AppScaffold extends StatefulWidget {
  const AppScaffold({super.key});
  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  int _selectedIndex = 0;

  final GlobalKey<RouteComparisonScreenState> _comparisonKey = GlobalKey();
  Map<String, dynamic>? _multiSupplierData;

  final List<String> _titles = [
    'Route Simulator',
    'Alt Route Discovery',
    'Multi-Supplier Routes',
    'Route Comparison',
    'Simulation History',
    'Community',
    'My Profile',
    'Live Orchestrator',
  ];

  List<Widget> get _screens => [
    const DashboardScreen(),
    const AltRouteScreen(),
    SupplyRoutesScreen(
      onResultsReady: (data) {
        setState(() {
          _multiSupplierData = data;
          _selectedIndex = 3;
        });
        _comparisonKey.currentState?.updateData(data);
      },
    ),
    RouteComparisonScreen(key: _comparisonKey, routeData: _multiSupplierData),
    const HistoryScreen(),
    const SearchProfilesScreen(),
    const ProfileScreen(),
    const OrchestratorPage(),
  ];

  @override
  void initState() { super.initState(); }

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  void _signOut() async => await FirebaseAuth.instance.signOut();

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;
    return Scaffold(
      appBar: isDesktop ? null : AppBar(title: Text(_titles[_selectedIndex]), actions: [
        IconButton(icon: const Icon(Icons.logout, color: GlassTheme.danger), onPressed: _signOut),
      ]),
      body: isDesktop
          ? Row(children: [_buildSideNav(), Expanded(child: Column(children: [_buildTopBar(), Expanded(child: _screens[_selectedIndex])]))])
          : _screens[_selectedIndex],
      bottomNavigationBar: isDesktop ? null : BottomNavigationBar(
        currentIndex: _selectedIndex, onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.route), label: 'Routes'),
          BottomNavigationBarItem(icon: Icon(Icons.alt_route), label: 'Alt'),
          BottomNavigationBarItem(icon: Icon(Icons.hub), label: 'Suppliers'),
          BottomNavigationBarItem(icon: Icon(Icons.compare_arrows), label: 'Compare'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Community'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    final user = FirebaseAuth.instance.currentUser;
    final firstName = user?.displayName?.split(' ').first ?? 'User';

    return Container(
      height: 80, padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(color: GlassTheme.backgroundDark, border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05)))),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(
          children: [
            Text(_titles[_selectedIndex], style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(width: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: GlassTheme.accentCyan.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: GlassTheme.accentCyan.withOpacity(0.2)),
              ),
              child: Text("Hi $firstName!", style: const TextStyle(color: GlassTheme.accentCyan, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ],
        ),
        Row(children: [
          const SizedBox(width: 16),
          ElevatedButton.icon(onPressed: _signOut, icon: const Icon(Icons.logout, size: 18), label: const Text('Sign Out'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.1), foregroundColor: Colors.white)),
        ]),
      ]),
    );
  }

  Widget _buildSideNav() {
    return Container(width: 260, color: GlassTheme.backgroundCard, child: SingleChildScrollView(
      child: Column(children: [
      const SizedBox(height: 32),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 40, height: 40, decoration: const BoxDecoration(shape: BoxShape.circle, color: GlassTheme.accentNeonGreen),
          child: const Icon(Icons.rocket_launch, color: GlassTheme.backgroundDark)),
        const SizedBox(width: 12),
        Text('SCDO', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: GlassTheme.accentNeonGreen)),
      ]),
      const SizedBox(height: 48),
      _navDivider("ROUTING"),
      _navItem(Icons.route, 'Route Simulator', 0, "Single origin → destination"),
      _navItem(Icons.alt_route, 'Alt Route', 1, "Constraint-aware discovery"),
      _navItem(Icons.hub, 'Multi-Supplier', 2, "Compare multiple suppliers"),
      _navItem(Icons.compare_arrows, 'Comparison', 3, "Side-by-side analysis"),
      _navDivider("ANALYTICS"),
      _navItem(Icons.history, 'History', 4, "Past simulation results"),
      _navItem(Icons.people, 'Community', 5, "User profiles & ratings"),
      _navItem(Icons.person, 'My Profile', 6, "Your account"),
      _navDivider("LIVE"),
      _navItem(Icons.radar, 'Live Orchestrator', 7, "Real-time shipment control"),
    ])));
  }

  Widget _navDivider(String label) {
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(children: [
        Expanded(child: Divider(color: Colors.white.withOpacity(0.08))),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(label, style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5))),
        Expanded(child: Divider(color: Colors.white.withOpacity(0.08))),
      ]));
  }

  Widget _navItem(IconData icon, String label, int index, String subtitle) {
    final isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () => _onItemTapped(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? GlassTheme.accentNeonGreen.withOpacity(0.1) : Colors.transparent,
          border: isSelected ? const Border(right: BorderSide(color: GlassTheme.accentNeonGreen, width: 4)) : null,
        ),
        child: Row(children: [
          Icon(icon, color: isSelected ? GlassTheme.accentNeonGreen : GlassTheme.textSecondary, size: 22),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(color: isSelected ? GlassTheme.accentNeonGreen : GlassTheme.textPrimary, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 14)),
            Text(subtitle, style: TextStyle(color: GlassTheme.textSecondary.withOpacity(0.6), fontSize: 10)),
          ])),
        ]),
      ),
    );
  }
}
