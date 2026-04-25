import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:scdo_app/theme/glass_theme.dart';
import 'package:scdo_app/widgets/glass_container.dart';
import 'package:scdo_app/widgets/delivery_zone_selector.dart';
// Inside your build method:

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _minQtyController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _productsController = TextEditingController();
  
  bool _isPublic = false;
  bool _isLoading = true;
  bool _isSaving = false;
  
  List<String> _selectedDeliveryZones = [];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('profiles').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _isPublic = data['is_public'] ?? false;
          _contactController.text = data['contact'] ?? '';
          _minQtyController.text = (data['min_quantity'] ?? '').toString();
          _locationController.text = data['location_data'] ?? '';
          
          final products = data['products_offered'];
          if (products is List) {
            _productsController.text = products.join(', ');
          } else if (products is String) {
            _productsController.text = products;
          }
          
          final dZones = data['delivery_zones'];
          if (dZones is List) {
            _selectedDeliveryZones = List<String>.from(dZones);
          }
        });
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final productsList = _productsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      
      await FirebaseFirestore.instance.collection('profiles').doc(user.uid).set({
        'user_id': user.uid,
        'email': user.email,
        'is_public': _isPublic,
        'contact': _contactController.text.trim(),
        'min_quantity': int.tryParse(_minQtyController.text.trim()) ?? 0,
        'location_data': _locationController.text.trim(),
        'products_offered': productsList,
        'delivery_zones': _selectedDeliveryZones,
        'updated_at': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved successfully'), backgroundColor: GlassTheme.accentNeonGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving profile: $e'), backgroundColor: GlassTheme.danger),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: GlassTheme.accentNeonGreen));
    }



    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'My Profile',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Manage your supply chain details. Make it public to connect with others.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              DeliveryZoneSelector(
                data: mockDeliveryData,
                initialSelection: _selectedDeliveryZones,
                onSelectionChanged: (List<String> selectedCityIds) {
                  _selectedDeliveryZones = selectedCityIds;
                },
              ),
              const SizedBox(height: 32),
              GlassContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Public Profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Switch(
                          value: _isPublic,
                          onChanged: (val) => setState(() => _isPublic = val),
                          activeColor: GlassTheme.accentNeonGreen,
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white24, height: 32),
                    TextField(
                      controller: _contactController,
                      decoration: const InputDecoration(
                        labelText: "Contact Email / Phone",
                        prefixIcon: Icon(Icons.contact_mail),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _minQtyController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Minimum Order Quantity",
                        prefixIcon: Icon(Icons.inventory_2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const SizedBox(height: 16),
                    Autocomplete<String>(
                      initialValue: TextEditingValue(text: _locationController.text),
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text == '') {
                          return const Iterable<String>.empty();
                        }
                        return getAllCityNames().where((String option) {
                          return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                        });
                      },
                      onSelected: (String selection) {
                        _locationController.text = selection;
                      },
                      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                        // Sync initial controller with internal autocomplete controller
                        return TextField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: const InputDecoration(
                            labelText: "Location Data (e.g., Warehouse City)",
                            prefixIcon: Icon(Icons.location_city),
                            hintText: "Search for a city...",
                          ),
                          onChanged: (val) {
                            _locationController.text = val;
                          },
                        );
                      },
                      optionsViewBuilder: (context, onSelected, options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4.0,
                            color: Colors.transparent,
                            child: GlassContainer(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxHeight: 200, maxWidth: 400),
                                child: ListView.builder(
                                  padding: EdgeInsets.zero,
                                  shrinkWrap: true,
                                  itemCount: options.length,
                                  itemBuilder: (BuildContext context, int index) {
                                    final String option = options.elementAt(index);
                                    return ListTile(
                                      title: Text(option, style: const TextStyle(color: Colors.white)),
                                      onTap: () => onSelected(option),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _productsController,
                      decoration: const InputDecoration(
                        labelText: "Products Offered (comma separated)",
                        prefixIcon: Icon(Icons.inventory),
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _saveProfile,
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: GlassTheme.backgroundDark),
                            )
                          : const Text("SAVE PROFILE"),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
