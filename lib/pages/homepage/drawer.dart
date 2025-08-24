import 'package:flutter/material.dart';
import 'package:resqmob/Class%20Models/social%20model.dart';
import 'package:resqmob/pages/homepage/safe%20road.dart';
import 'package:resqmob/pages/profile/profile.dart';

import '../../Class Models/user.dart';
import '../../backend/firebase config/Authentication.dart';
import '../../test.dart';
import '../admin/resources/feedback.dart';
import 'help page.dart';
import 'hospitals.dart';
import 'police stations.dart';
import '../alert listing/my responded alert.dart';
import '../alert listing/view my alerts.dart';
import '../community/community.dart';
import 'homepage.dart';

class AppDrawer extends StatelessWidget {
  final UserModel? currentUser;
  final int activePage;

  const AppDrawer({Key? key, required this.currentUser, required this.activePage}) : super(key: key);

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
                    backgroundImage: currentUser?.profileImageUrl != ""
                        ? NetworkImage(currentUser!.profileImageUrl!)
                        : null,
                    child: currentUser?.profileImageUrl == ""
                        ? const Icon(Icons.person, size: 30, color: Color(0xFF6B7280))
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
          _buildDrawerItem(
            icon: Icons.home,
            title: 'Home',
            isSelected: activePage==1?true:false,
            onTap: () {
              Navigator.pop(context);
              Navigator.popUntil(context, (route) => route.isFirst);
              // Navigator.pushReplacement(
              //   context,
              //   MaterialPageRoute(builder: (context) => const MyHomePage()),
              // );
            },
          ),
          _buildDrawerItem(
            icon: Icons.language,
            title: 'Community',
            isSelected: activePage==2?true:false,
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
            icon: Icons.history_rounded,
            title: 'My Alers',
            isSelected: activePage==3?true:false,
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AlertHistoryScreen(currentUser: currentUser!)),
              );
            },
          ),
          _buildDrawerItem(
            icon: Icons.handshake_rounded,
            title: 'My Responses',
            isSelected: activePage==4?true:false,
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => RespondedAlertsScreen(currentUser: currentUser!)),
              );
            },
          ),
          _buildDrawerItem(
            icon: Icons.local_police,
            title: 'Police Stations',
            isSelected: activePage==5?true:false,
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AddPoliceStations(currentUser: currentUser,)),
              );
            },
          ),
          _buildDrawerItem(
            icon: Icons.local_hospital,
            title: 'Nearby Hospitals',
            isSelected: activePage==6?true:false,
            onTap: () {

              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => HospitalsPage(currentUser: currentUser,)),
              );

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
            isSelected: activePage==8?true:false,
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => GeminiChatPage(init_text: 'hello',isSupport: true,currentUser: currentUser!,)),
              );

              // Navigate to help screen
            },
          ),
          _buildDrawerItem(
            isSelected: activePage==9?true:false,
            icon: Icons.feedback,
            title: 'Send Feedback',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => FeedbackPage(currentUser: currentUser!)),
              );


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
                  'Version 1.2.16',
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