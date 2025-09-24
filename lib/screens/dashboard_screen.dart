import 'package:cent/screens/chat_screen.dart';
import 'package:cent/screens/insurance_check_screen.dart';
import 'package:cent/screens/insurance_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:cent/screens/pollen_alerts_screen.dart';

class DashBoardPage extends StatefulWidget {
  const DashBoardPage({Key? key}) : super(key: key);

  @override
  State<DashBoardPage> createState() => _DashBoardPageState();
}

class _DashBoardPageState extends State<DashBoardPage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    // Slightly brighter, cooler background
    const scaffoldBg = Color(0xFFF4F8FF);

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 20),
                  _buildSearchBar(),
                  const SizedBox(height: 20),
                  _buildBanner(),
                  const SizedBox(height: 28),
                  _buildQuickAccess(context),
                  const SizedBox(height: 28),
                  _buildTodayAction(),
                  const SizedBox(height: 28),
                  _buildRecentAchievements(),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChatScreen()),
    );
        },
        backgroundColor: Colors.blue[600],
        child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
        tooltip: 'Chatbot',
      ),
    );
  }

  BottomNavigationBar _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) {
        setState(() => _currentIndex = index);
        // Optional: switch body content based on index
      },
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Colors.blue[600],
      unselectedItemColor: Colors.grey[500],
      backgroundColor: Colors.white,
      elevation: 8,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.schedule), label: 'Schedule'),
        BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Tracking'),
        BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'Learning'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
      ],
    );
  }

  // HEADER
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Andrew Donald!',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(
                Icons.notifications_outlined,
                size: 28,
                color: Colors.black54,
              ),
              onPressed: () {
                // Handle notification tap
              },
            ),
            Positioned(
              right: 10,
              top: 10,
              child: Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // SEARCH
  Widget _buildSearchBar() {
    return Container
    (
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search Doctors',
          hintStyle: TextStyle(color: Colors.grey[600]),
          prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  // BANNER
  Widget _buildBanner() {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF66CCFF), Color(0xFF33BBF3)], // slightly brighter
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              child: Image.asset(
                'assets/images/doctors.png',
                fit: BoxFit.cover,
                width: 180,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 180,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                    ),
                    child: const Icon(Icons.medical_services, size: 80, color: Colors.white70),
                  );
                },
              ),
            ),
          ),
          Positioned(
            left: 20,
            top: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _bannerLine('Expert Doctors,'),
                _bannerLine('Just a Click'),
                _bannerLine('Away'),
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFA726),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 0,
                  ),
                  child: const Text('Book Now', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bannerLine(String text) => Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          height: 1.15,
        ),
      );

  // QUICK ACCESS
  Widget _buildQuickAccess(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Access',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 15),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 15,
          mainAxisSpacing: 15,
          childAspectRatio: 1.0,
          children: [
            _buildQuickAccessCard(
              icon: Icons.access_time,
              title: 'Smart Reminder',
              onTap: () {},
            ),
            _buildQuickAccessCard(
              icon: Icons.track_changes,
              title: 'Adherence Tracker',
              onTap: () {},
            ),
            _buildQuickAccessCard(
              icon: Icons.account_balance_wallet,
              title: 'Insurance Check',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EligibilityScreen()),
                );
              },
            ),
            _buildQuickAccessCard(
              icon: Icons.accessible,
              title: 'Symptom Tracker',
              onTap: () {},
            ),
            _buildQuickAccessCard(
              icon: Icons.eco,
              title: 'Education Hub',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PollenAlertPage()),
                );
              },
            ),
            _buildQuickAccessCard(
              icon: Icons.card_giftcard,
              title: 'Rewards',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const InsuranceDetailsScreen()),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickAccessCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 24, color: Colors.blue[600]),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // TODAY ACTION
  Widget _buildTodayAction() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Today Action',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 15),
         _buildActionCard(
          title: 'Check Pollen Levels',
          subtitle: '',
          color: const Color.fromARGB(255, 237, 227, 212)!, // brighter, lighter
          iconColor: Colors.orange,
          icon: Icons.access_time,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PollenAlertPage()),
            );
          },
        ),
        const SizedBox(height: 10),
        _buildActionCard(
          title: 'Morning Dose Reminder',
          subtitle: 'Due in 30 mins',
          color: const Color.fromARGB(255, 202, 206, 238), // brighter, lighter
          iconColor: const Color.fromARGB(255, 15, 15, 231),
          icon: Icons.access_time,
        ),
        const SizedBox(height: 10),
        _buildActionCard(
          title: 'Symptom check complete',
          subtitle: 'Logged 2 hours ago',
          color: const Color.fromARGB(255, 233, 243, 234), // brighter, lighter
          iconColor: Colors.green,
          icon: Icons.check_circle,
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required Color color,
    required Color? iconColor,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: iconColor!.withOpacity(0.25), width: 1),
        ),
        child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
          Icon(icon, color: iconColor, size: 24),
        ],
      ),
      ),
    );
  }

  // RECENT ACHIEVEMENTS
  Widget _buildRecentAchievements() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Achievements',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 15),
        _buildAchievementItem(
          title: '7-Day Streak',
          subtitle: 'Consistent with daily doses',
          icon: Icons.check_circle,
        ),
        const SizedBox(height: 12),
        _buildAchievementItem(
          title: 'Early Adopter',
          subtitle: 'Completed first month successfully',
          icon: Icons.check_circle,
        ),
      ],
    );
  }

  Widget _buildAchievementItem({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.green[50], shape: BoxShape.circle),
          child: Icon(icon, color: Colors.green[600], size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
            ],
          ),
        ),
      ],
    );
  }
}
