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
  final UserModel? currentUser; // Assuming you have a UserModel class

  const AppDrawer({Key? key,required this.currentUser}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      shape: BeveledRectangleBorder(),
      width: MediaQuery.of(context).size.width * 0.8,
      child: Column(
        children: [
          // Header with user info
          InkWell(
            onTap: (){
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => profile(uid: currentUser!.id,)),
              );
            },
            child: UserAccountsDrawerHeader(
              accountName: Text(
                currentUser?.name ?? 'Guest',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              accountEmail: Text(
                currentUser?.email ?? 'No email',
                style: const TextStyle(fontSize: 14),
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                backgroundImage: currentUser?.profileImageUrl != null
                    ? NetworkImage(currentUser!.profileImageUrl!)
                    : null,
                child: currentUser?.profileImageUrl == null
                    ? const Icon(Icons.person, size: 40, color: Colors.blue)
                    : null,
              ),
              decoration: BoxDecoration(
                color: Colors.blue,
                image: DecorationImage(
                  image: const NetworkImage('https://imgv3.fotor.com/images/share/Free-blue-gradient-pattern-background-from-Fotor.jpg'),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.blue.withOpacity(0.7),
                    BlendMode.dstATop,
                  ),
                ),
              ),
            ),
          ),

          // Main drawer items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(
                  icon: Icons.home,
                  title: 'Home',
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
                      MaterialPageRoute(builder: (context) => SocialScreen(currentUser:currentUser!)),
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
                ),_buildDrawerItem(
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
                  icon: Icons.emergency,
                  title: 'Emergency Contacts',
                  onTap: () {
                    Navigator.pop(context);
                    // Navigate to emergency contacts screen
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.local_police,
                  title: 'Nearby Police Stations',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => AddPoliceStations()),
                    );
                    // Navigate to police stations screen
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
                const Divider(height: 1, thickness: 1),
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
                const Divider(height: 1, thickness: 1),
                _buildDrawerItem(
                  icon: Icons.logout,
                  title: 'Sign Out',
                  onTap: () {
                    Navigator.pop(context);
                    Authentication().signout(context);
                  },
                ),
              ],
            ),
          ),

          // App version and footer
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const Text(
                  'ResQ Mobile',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Version 1.0.0',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
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
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue),
      title: Text(
        title,
        style: const TextStyle(fontSize: 16),
      ),
      onTap: onTap,
    );
  }
}