import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:scdo_app/theme/glass_theme.dart';
import 'package:scdo_app/screens/dashboard_screen.dart';
import 'package:scdo_app/screens/alt_route_screen.dart';
import 'package:scdo_app/screens/supply_routes_screen.dart';
import 'package:scdo_app/screens/route_comparison_screen.dart';
import 'package:scdo_app/screens/history_screen.dart';
import 'package:scdo_app/screens/profile_screen.dart';
import 'package:scdo_app/screens/search_profiles_screen.dart';

class AppScaffold extends StatefulWidget {
  const AppScaffold({super.key});

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  int _selectedIndex = 0;

  final GlobalKey<RouteComparisonScreenState> _comparisonKey = GlobalKey();
  Map<String, dynamic>? _multiSupplierData;

  late final List<Widget> _screens;

  final List<String> _titles = [
    'Simulation Dashboard',
    'Alternate Routes',
    'Supply Routes',
    'Route Comparison',
    'Simulation History',
    'Community Profiles',
    'My Profile',
  ];

  @override
  void initState() {
    super.initState();
    _screens = [
      const DashboardScreen(),
      const AltRouteScreen(),
      SupplyRoutesScreen(
        onResultsReady: (data) {
          setState(() {
            _multiSupplierData = data;
          });
          _comparisonKey.currentState?.updateData(data);
          _onItemTapped(3);
        },
      ),
      RouteComparisonScreen(
        key: _comparisonKey,
        routeData: _multiSupplierData,
      ),
      const HistoryScreen(),
      const SearchProfilesScreen(),
      const ProfileScreen(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      appBar: isDesktop ? null : AppBar(
        title: Text(_titles[_selectedIndex]),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: GlassTheme.danger),
            onPressed: _signOut,
          ),
        ],
      ),
      body: isDesktop
          ? Row(
              children: [
                _buildSideNav(),
                Expanded(
                  child: Column(
                    children: [
                      _buildTopBar(),
                      Expanded(child: _screens[_selectedIndex]),
                    ],
                  ),
                ),
              ],
            )
          : _screens[_selectedIndex],
      bottomNavigationBar: isDesktop ? null : BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Simulate'),
          BottomNavigationBarItem(icon: Icon(Icons.alt_route), label: 'Routes'),
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
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: GlassTheme.backgroundDark,
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _titles[_selectedIndex],
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none),
                onPressed: () {},
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _signOut,
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Sign Out'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.1),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildSideNav() {
    return Container(
      width: 280,
      color: GlassTheme.backgroundCard,
      child: Column(
        children: [
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: GlassTheme.accentNeonGreen,
                ),
                child: const Icon(Icons.rocket_launch, color: GlassTheme.backgroundDark),
              ),
              const SizedBox(width: 12),
              Text(
                'SCDO',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: GlassTheme.accentNeonGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 48),
          _navItem(Icons.dashboard, 'Dashboard', 0),
          _navItem(Icons.alt_route, 'Alt Routes', 1),
          _navDivider("MULTI-SUPPLIER"),
          _navItem(Icons.hub, 'Supply Routes', 2),
          _navItem(Icons.compare_arrows, 'Comparison', 3),
          _navDivider("ANALYTICS"),
          _navItem(Icons.history, 'History', 4),
          _navItem(Icons.people, 'Community', 5),
          _navItem(Icons.person, 'My Profile', 6),
        ],
      ),
    );
  }

  Widget _navDivider(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.white.withOpacity(0.08))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.25),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ),
          Expanded(child: Divider(color: Colors.white.withOpacity(0.08))),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () => _onItemTapped(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? GlassTheme.accentNeonGreen.withOpacity(0.1) : Colors.transparent,
          border: isSelected ? const Border(
            right: BorderSide(color: GlassTheme.accentNeonGreen, width: 4),
          ) : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? GlassTheme.accentNeonGreen : GlassTheme.textSecondary,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: isSelected ? GlassTheme.accentNeonGreen : GlassTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
