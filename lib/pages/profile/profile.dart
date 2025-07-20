import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../Class Models/emergency contact.dart';
import '../../Class Models/user.dart';

class profile extends StatefulWidget {
  final uid;
  const profile({super.key, this.uid});

  @override
  State<profile> createState() => _profileState();
}

class _profileState extends State<profile> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  // Emergency contact controllers
  final TextEditingController _contactNameController = TextEditingController();
  final TextEditingController _contactPhoneController = TextEditingController();
  final TextEditingController _contactRelationshipController = TextEditingController();

  bool isEditing = false;
  final _formKey = GlobalKey<FormState>();
  List<EmergencyContact> emergencyContacts = [];

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    _contactRelationshipController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (_formKey.currentState!.validate()) {
      try {
        await FirebaseFirestore.instance
            .collection("Users")
            .doc(widget.uid)
            .update({
          'name': _nameController.text,
          'phoneNumber': _phoneController.text,
          'address': _addressController.text,
          'emergencyContacts': emergencyContacts.map((contact) => contact.toJson()).toList(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        setState(() => isEditing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e')),
        );
      }
    }
  }

  Future<void> _loadEmergencyContacts() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection("Users")
          .doc(widget.uid)
          .get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        if (data.containsKey('emergencyContacts')) {
          List<dynamic> contactsData = data['emergencyContacts'];
          setState(() {
            emergencyContacts = contactsData
                .map<EmergencyContact>((json) => EmergencyContact.fromJson(json))
                .toList();
          });
        }
      }
    } catch (error) {
      print('Error loading emergency contacts: $error');
    }
  }

  void _showAddContactDialog() {
    _contactNameController.clear();
    _contactPhoneController.clear();
    _contactRelationshipController.clear();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add Emergency Contact'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _contactNameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _contactPhoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _contactRelationshipController,
                  decoration: const InputDecoration(
                    labelText: 'Relationship',
                    border: OutlineInputBorder(),
                    hintText: 'e.g., Mother, Father, Spouse, Friend',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _addContact,
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _addContact() {
    if (_contactNameController.text.trim().isEmpty ||
        _contactPhoneController.text.trim().isEmpty ||
        _contactRelationshipController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    setState(() {
      emergencyContacts.add(
        EmergencyContact(
          name: _contactNameController.text.trim(),
          phoneNumber: _contactPhoneController.text.trim(),
          relationship: _contactRelationshipController.text.trim(),
        ),
      );
    });

    Navigator.of(context).pop();
  }

  void _editContact(int index) {
    final contact = emergencyContacts[index];
    _contactNameController.text = contact.name;
    _contactPhoneController.text = contact.phoneNumber;
    _contactRelationshipController.text = contact.relationship;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Emergency Contact'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _contactNameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _contactPhoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _contactRelationshipController,
                  decoration: const InputDecoration(
                    labelText: 'Relationship',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => _updateContact(index),
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  void _updateContact(int index) {
    if (_contactNameController.text.trim().isEmpty ||
        _contactPhoneController.text.trim().isEmpty ||
        _contactRelationshipController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    setState(() {
      emergencyContacts[index] = EmergencyContact(
        name: _contactNameController.text.trim(),
        phoneNumber: _contactPhoneController.text.trim(),
        relationship: _contactRelationshipController.text.trim(),
      );
    });

    Navigator.of(context).pop();
  }

  void _deleteContact(int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Contact'),
          content: Text('Are you sure you want to delete ${emergencyContacts[index].name}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  emergencyContacts.removeAt(index);
                });
                Navigator.of(context).pop();
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _callContact(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch phone dialer')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _loadEmergencyContacts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Profile",
          style: TextStyle(
            color: Color(0xFF212121),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF212121)),
        actions: [
          if (!isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => isEditing = true),
            )
          else
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => setState(() => isEditing = false),
            ),
        ],
      ),
      floatingActionButton: isEditing
          ? FloatingActionButton(
        backgroundColor: Colors.blue,
        child: const Icon(Icons.save),
        onPressed: _saveChanges,
      )
          : null,
      body: RefreshIndicator(
        color: const Color(0xFF000000),
        onRefresh: () async {
          await Future.delayed(const Duration(milliseconds: 200));
          setState(() {});
          _loadEmergencyContacts();
        },
        child: FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection("Users").doc(widget.uid).get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF000000),
                ),
              );
            }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(
                child: Text(
                  "No Data Available",
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF757575),
                  ),
                ),
              );
            }

            UserModel user = UserModel.fromJson(snapshot.data!.data() as Map<String, dynamic>);
            if (_nameController.text.isEmpty) {
              _nameController.text = user.name;
              _phoneController.text = user.phoneNumber;
              _addressController.text = user.address;
            }

            return Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                children: [
                  // Profile Card
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        // Profile Image
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xff000000).withOpacity(0.15),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 60,
                            backgroundColor: const Color(0xff000000).withOpacity(0.08),
                            backgroundImage: user.profileImageUrl != ""
                                ? NetworkImage(user.profileImageUrl)
                                : null,
                            child: user.profileImageUrl == ""
                                ? const Icon(Icons.person, size: 60, color: Color(0xFF000000))
                                : null,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // User Name
                        isEditing
                            ? TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Name',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your name';
                            }
                            return null;
                          },
                        )
                            : Text(
                          user.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF212121),
                          ),
                        ),
                        const SizedBox(height: 6),
                        // User Email
                        Text(
                          user.email,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Status Indicator
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xff000000).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text(
                            user.admin ? "Admin" : "Member",
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF000000),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Personal Information Card
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Section Title
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xff000000).withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.person_outline,
                                color: Color(0xFF000000),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              "Personal Information",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF212121),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Phone Number
                        isEditing
                            ? Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: TextFormField(
                            controller: _phoneController,
                            decoration: const InputDecoration(
                              labelText: 'Phone Number',
                              prefixIcon: Icon(Icons.phone),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        )
                            : buildInfoRow(Icons.phone_outlined, "Phone Number", user.phoneNumber),
                        const Divider(height: 32),
                        // Address
                        isEditing
                            ? Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: TextFormField(
                            controller: _addressController,
                            decoration: const InputDecoration(
                              labelText: 'Address',
                              prefixIcon: Icon(Icons.location_on),
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 2,
                          ),
                        )
                            : buildInfoRow(Icons.location_on_outlined, "Address", user.address),
                        const Divider(height: 32),
                        // User ID (non-editable)
                        buildInfoRow(Icons.fingerprint, "User ID", user.id),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  (user.admin==false)?
                  // Emergency Contacts Card - Professional Design
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Section Title
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xff000000).withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.contact_emergency_outlined,
                                    color: Color(0xFF000000),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  "Emergency Contacts",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF212121),
                                  ),
                                ),
                              ],
                            ),
                            // Add Contact Button - Only visible in editing mode
                            if (isEditing)
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.withOpacity(0.3)),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: TextButton.icon(
                                  onPressed: _showAddContactDialog,
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text("Add Contact"),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.grey[700],
                                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Emergency Contacts List
                        if (emergencyContacts.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.contacts_outlined,
                                  size: 40,
                                  color: Colors.grey.withOpacity(0.4),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  "No emergency contacts",
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (isEditing) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    "Add contacts for emergency situations",
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          )
                        else
                          Column(
                            children: emergencyContacts.asMap().entries.map((entry) {
                              int index = entry.key;
                              EmergencyContact contact = entry.value;
                              bool isLast = index == emergencyContacts.length - 1;

                              return Container(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                  border: isLast ? null : Border(
                                    bottom: BorderSide(
                                      color: Colors.grey.withOpacity(0.1),
                                      width: 1,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // Contact Avatar
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                      child: Center(
                                        child: Text(
                                          contact.name.isNotEmpty ? contact.name[0].toUpperCase() : 'C',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),

                                    // Contact Information
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            contact.name,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF212121),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            contact.relationship,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey[600],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.phone_outlined,
                                                size: 14,
                                                color: Colors.grey[500],
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: GestureDetector(
                                                  onTap: () => _callContact(contact.phoneNumber),
                                                  child: Text(
                                                    contact.phoneNumber,
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: Colors.grey[700],
                                                      decoration: TextDecoration.underline,
                                                      decorationColor: Colors.grey[400],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Action Buttons - Only visible in editing mode
                                    if (isEditing)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: IconButton(
                                              onPressed: () => _editContact(index),
                                              icon: const Icon(Icons.edit_outlined),
                                              iconSize: 18,
                                              color: Colors.grey[600],
                                              constraints: const BoxConstraints(
                                                minWidth: 36,
                                                minHeight: 36,
                                              ),
                                              padding: EdgeInsets.zero,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Container(
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: IconButton(
                                              onPressed: () => _deleteContact(index),
                                              icon: const Icon(Icons.delete_outline),
                                              iconSize: 18,
                                              color: Colors.grey[600],
                                              constraints: const BoxConstraints(
                                                minWidth: 36,
                                                minHeight: 36,
                                              ),
                                              padding: EdgeInsets.zero,
                                            ),
                                          ),
                                        ],
                                      )
                                    else
                                    // Call button when not editing
                                      Container(
                                        decoration: BoxDecoration(
                                          border: Border.all(color: Colors.grey.withOpacity(0.3)),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: IconButton(
                                          onPressed: () => _callContact(contact.phoneNumber),
                                          icon: const Icon(Icons.call_outlined),
                                          iconSize: 16,
                                          color: Colors.grey[700],
                                          constraints: const BoxConstraints(
                                            minWidth: 32,
                                            minHeight: 32,
                                          ),
                                          padding: EdgeInsets.zero,
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ):Container(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xff000000).withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF000000),
            size: 20,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF212121),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}