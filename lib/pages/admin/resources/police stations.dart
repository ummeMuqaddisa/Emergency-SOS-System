import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AddPoliceStations extends StatefulWidget {
  const AddPoliceStations({super.key});

  @override
  State<AddPoliceStations> createState() => _AddPoliceStationsState();
}

class _AddPoliceStationsState extends State<AddPoliceStations> {
  final List<Map<String, dynamic>> _allStations = [];
  bool _isLoading = true;

  // Controllers for the add station form
  final TextEditingController _stationNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>(); // Form key for validation

  @override
  void initState() {
    super.initState();
    _fetchPoliceStations();
  }

  @override
  void dispose() {
    _stationNameController.dispose();
    _addressController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _fetchPoliceStations() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('Resources/PoliceStations/Stations')
          .orderBy('stationName') // Order for better display
          .get();
      setState(() {
        _allStations.clear();
        for (final doc in querySnapshot.docs) {
          _allStations.add(doc.data());
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading police stations: $e'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addPoliceStation() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true; // Show loading while adding
    });

    try {
      final newStationRef = FirebaseFirestore.instance.collection('Resources/PoliceStations/Stations').doc();
      final newStationData = {
        'stationId': newStationRef.id, // Use Firestore generated ID
        'stationName': _stationNameController.text.trim(),
        'address': _addressController.text.trim(),
        'location': {
          'latitude': double.parse(_latitudeController.text.trim()),
          'longitude': double.parse(_longitudeController.text.trim()),
        },
        'phone': _phoneController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(), // Add a timestamp
      };

      await newStationRef.set(newStationData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Police station added successfully!'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
      Navigator.pop(context); // Close the modal
      _fetchPoliceStations(); // Refresh the list
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding police station: $e'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showAddStationModal() {
    // Clear controllers before showing the dialog
    _stationNameController.clear();
    _addressController.clear();
    _latitudeController.clear();
    _longitudeController.clear();
    _phoneController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  children: [
                    const Icon(Icons.local_police_outlined, color: Color(0xFF3B82F6), size: 28),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Add New Police Station',
                        style: TextStyle(
                          color: Color(0xFF1F2937),
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF6B7280)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Form Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTextField(
                          controller: _stationNameController,
                          label: 'Station Name',
                          hint: 'Enter police station name',
                          icon: Icons.local_police_outlined,
                          validator: (value) => value!.isEmpty ? 'Station name cannot be empty' : null,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _addressController,
                          label: 'Address',
                          hint: 'Enter full address',
                          icon: Icons.location_on_outlined,
                          validator: (value) => value!.isEmpty ? 'Address cannot be empty' : null,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _latitudeController,
                                label: 'Latitude',
                                hint: 'e.g., 23.769',
                                icon: Icons.map_outlined,
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value!.isEmpty) return 'Latitude cannot be empty';
                                  if (double.tryParse(value) == null) return 'Invalid number';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildTextField(
                                controller: _longitudeController,
                                label: 'Longitude',
                                hint: 'e.g., 90.425',
                                icon: Icons.map_outlined,
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value!.isEmpty) return 'Longitude cannot be empty';
                                  if (double.tryParse(value) == null) return 'Invalid number';
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _phoneController,
                          label: 'Phone Number (Optional)',
                          hint: 'Enter phone number',
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: _isLoading
                                ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                                : const Icon(Icons.save_outlined, size: 20),
                            label: Text(_isLoading ? 'Saving...' : 'Save Police Station'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3B82F6),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            onPressed: _isLoading ? null : _addPoliceStation,
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF1F2937),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
            prefixIcon: Icon(icon, color: const Color(0xFF6B7280), size: 20),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          ),
          style: const TextStyle(
            color: Color(0xFF1F2937),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          _buildContentSection(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddStationModal,
        backgroundColor: const Color(0xFF3B82F6),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add_rounded, size: 32),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1F2937), size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF6B7280), size: 20),
            onPressed: _fetchPoliceStations,
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        title: const Text(
          'Police Stations',
          style: TextStyle(
            color: Color(0xFF1F2937),
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white,
                Color(0xFFF8FAFC),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContentSection() {
    if (_isLoading) {
      return const SliverFillRemaining(
        child: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF3B82F6),
            strokeWidth: 3,
          ),
        ),
      );
    }

    if (_allStations.isEmpty) {
      return SliverFillRemaining(
        child: _buildEmptyState(),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
              (context, index) {
            final station = _allStations[index];
            return _buildStationCard(station, index);
          },
          childCount: _allStations.length,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(60),
            ),
            child: const Icon(
              Icons.local_police_outlined,
              size: 60,
              color: Color(0xFF9CA3AF),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'No police stations added',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add your first police station now!',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStationCard(Map<String, dynamic> station, int index) {
    final latitude = station['location']?['latitude'];
    final longitude = station['location']?['longitude'];
    final phone = station['phone'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1F2937).withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.local_police_outlined, color: Color(0xFF3B82F6), size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    station['stationName'] ?? 'Unknown Station',
                    style: const TextStyle(
                      color: Color(0xFF1F2937),
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.location_on_outlined, station['address'] ?? 'Address not available'),
            if (latitude != null && longitude != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                Icons.map_outlined,
                'Lat: ${latitude.toStringAsFixed(4)}, Lng: ${longitude.toStringAsFixed(4)}',
              ),
            ],
            if (phone.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildInfoRow(Icons.phone_outlined, phone),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: const Color(0xFF6B7280),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF374151),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
