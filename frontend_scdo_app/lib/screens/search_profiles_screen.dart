import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:scdo_app/theme/glass_theme.dart';
import 'package:scdo_app/widgets/glass_container.dart';

class SearchProfilesScreen extends StatefulWidget {
  const SearchProfilesScreen({super.key});

  @override
  State<SearchProfilesScreen> createState() => _SearchProfilesScreenState();
}

class _SearchProfilesScreenState extends State<SearchProfilesScreen> {
  final TextEditingController _searchController = TextEditingController();
  
  List<Map<String, dynamic>> _allProfiles = [];
  List<Map<String, dynamic>> _filteredProfiles = [];
  bool _isLoading = true;
  String _error = "";

  @override
  void initState() {
    super.initState();
    _fetchPublicProfiles();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchPublicProfiles() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('profiles')
          .where('is_public', isEqualTo: true)
          .get();

      final profiles = snapshot.docs.map((doc) => doc.data()).toList();
      
      if (mounted) {
        setState(() {
          _allProfiles = profiles;
          _filteredProfiles = profiles;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    
    if (query.isEmpty) {
      setState(() {
        _filteredProfiles = _allProfiles;
      });
      return;
    }

    setState(() {
      _filteredProfiles = _allProfiles.where((profile) {
        final location = (profile['location_data'] ?? '').toString().toLowerCase();
        final contact = (profile['contact'] ?? '').toString().toLowerCase();
        final email = (profile['email'] ?? '').toString().toLowerCase();
        
        // Products is a list of strings
        final products = profile['products_offered'];
        String productsStr = "";
        if (products is List) {
          productsStr = products.join(" ").toLowerCase();
        }

        return location.contains(query) || 
               contact.contains(query) || 
               email.contains(query) || 
               productsStr.contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Community Directory',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: "Search by location, product, or email...",
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                },
              ),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: GlassTheme.accentNeonGreen))
                : _error.isNotEmpty
                    ? Center(child: Text('Error: $_error', style: const TextStyle(color: GlassTheme.danger)))
                    : _filteredProfiles.isEmpty
                        ? const Center(child: Text('No profiles found matching your search.', style: TextStyle(color: GlassTheme.textSecondary)))
                        : GridView.builder(
                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 400,
                              childAspectRatio: 1.5,
                              crossAxisSpacing: 24,
                              mainAxisSpacing: 24,
                            ),
                            itemCount: _filteredProfiles.length,
                            itemBuilder: (context, index) {
                              final profile = _filteredProfiles[index];
                              return GlassContainer(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const CircleAvatar(
                                          backgroundColor: GlassTheme.backgroundDark,
                                          child: Icon(Icons.business, color: GlassTheme.accentNeonGreen),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Text(
                                            profile['email'] ?? 'Unknown User',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Spacer(),
                                    _buildInfoRow(Icons.location_on, profile['location_data'] ?? 'No location'),
                                    const SizedBox(height: 8),
                                    _buildInfoRow(Icons.production_quantity_limits, "Min Qty: ${profile['min_quantity'] ?? 0}"),
                                    const SizedBox(height: 8),
                                    _buildInfoRow(
                                      Icons.inventory, 
                                      (profile['products_offered'] is List && profile['products_offered'].isNotEmpty) 
                                        ? profile['products_offered'].join(', ') 
                                        : 'No products listed'
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: GlassTheme.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: GlassTheme.textSecondary, fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
