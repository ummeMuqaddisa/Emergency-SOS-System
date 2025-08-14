import 'package:flutter/material.dart';
import 'package:resqmob/Class%20Models/social%20model.dart';
import 'package:resqmob/pages/homepage/safe%20road.dart';
import 'package:resqmob/pages/profile/profile.dart';

import '../../Class Models/user.dart';
import '../../backend/firebase config/Authentication.dart';
import '../../test.dart';
import '../admin/resources/police stations.dart';
import '../alert listing/my responded alert.dart';
import '../community/community.dart';
import 'homepage.dart';

class AppDrawer extends StatelessWidget {
  final UserModel? currentUser;

  const AppDrawer({Key? key, required this.currentUser}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      shape: const LinearBorder(),
      width: 350,
      backgroundColor: Colors.white,
      child: ListView(
        children: [

          // User Profile Header
          const SizedBox(height: 40),
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => profile(uid: currentUser!.id)),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: currentUser?.profileImageUrl != null
                        ? NetworkImage(currentUser!.profileImageUrl!)
                        : null,
                    child: currentUser?.profileImageUrl == null
                        ? const Icon(Icons.person, size: 30, color: Colors.blue)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentUser?.name ?? 'Guest',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currentUser?.email ?? 'No email',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),
          const Divider(height: 10),
          const SizedBox(height: 5),

          // Main Drawer Items
          _buildHighlightedItem(
            icon: Icons.home,
            title: 'Home',
            isSelected: true,
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const MyHomePage()),
              );
            },
          ),
          _buildDrawerItem(
            icon: Icons.language,
            title: 'Community',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => SocialScreen(currentUser: currentUser!)),
              );
            },
          ),
          _buildDrawerItem(
            icon: Icons.navigation_outlined,
            title: 'Navigation',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SafetyMap()),
              );
            },
          ),
          _buildDrawerItem(
            icon: Icons.history,
            title: 'Responded',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => RespondedAlertsScreen()),
              );
            },
          ),
          _buildDrawerItem(
            icon: Icons.local_police,
            title: 'Police Stations',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AddPoliceStations()),
              );
            },
          ),
          _buildDrawerItem(
            icon: Icons.local_hospital,
            title: 'Nearby Hospitals',
            onTap: () {
              Navigator.pop(context);
              // Navigate to hospitals screen
            },
          ),

          const Divider(height: 10, indent: 60),
          const Padding(
            padding: EdgeInsets.only(left: 21, top: 20, bottom: 20),
            child: Text(
              "SETTINGS",
              style: TextStyle(
                fontSize: 15,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          _buildDrawerItem(
            icon: Icons.settings,
            title: 'Settings',
            onTap: () {
              Navigator.pop(context);
              // Navigate to settings screen
            },
          ),
          _buildDrawerItem(
            icon: Icons.help,
            title: 'Help & Tutorial',
            onTap: () {
              Navigator.pop(context);
              // Navigate to help screen
            },
          ),
          _buildDrawerItem(
            icon: Icons.feedback,
            title: 'Send Feedback',
            onTap: () {
              Navigator.pop(context);
              // Navigate to feedback screen
            },
          ),

          const Divider(height: 10, indent: 60),
          _buildDrawerItem(
            icon: Icons.logout,
            title: 'Sign Out',
            onTap: () {
              Navigator.pop(context);
              Authentication().signout(context);
            },
          ),

          // App version footer
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(
                  'ResQmob',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Version 1.2.05',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    return Container(
      padding: const EdgeInsets.only(left: 5),
      margin: const EdgeInsets.only(right: 15),
      decoration: isSelected
          ? const BoxDecoration(
        color: Color(0XFFE8F0FE),
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      )
          : null,
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? const Color(0XFF3C88EC) : Colors.black.withOpacity(0.75),
          size: 23,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 15,
            color: isSelected ? const Color(0XFF3C88EC) : Colors.black.withOpacity(0.75),
            fontWeight: FontWeight.bold,
          ),
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildHighlightedItem({
    required IconData icon,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.only(left: 5),
      margin: const EdgeInsets.only(right: 15),
      decoration: const BoxDecoration(
        color: Color(0XFFE8F0FE),
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: const Color(0XFF3C88EC),
          size: 23,
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            color: Color(0XFF3C88EC),
            fontWeight: FontWeight.bold,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}