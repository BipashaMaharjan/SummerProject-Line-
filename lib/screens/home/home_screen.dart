import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/token_provider.dart';
import '../../models/user_profile.dart';
import '../../config/supabase_config.dart';
import '../auth/login_screen.dart';
import '../booking/service_selection_screen.dart';
import '../tokens/user_tokens_screen.dart';
import '../staff/staff_dashboard_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  late final List<Widget> _screens = [
    const DashboardTab(),
    const ServicesTab(),
    const TokensTab(),
    const ProfileTab(),
  ];

  late final List<Widget> _staffScreens = [
    const StaffDashboardScreen(),
    const ServicesTab(),
    const TokensTab(),
    const ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isStaff = authProvider.user?.userMetadata?['role'] == 'staff';
    final screens = isStaff ? _staffScreens : _screens;

    return Scaffold(
      appBar: AppBar(
        title: Text(isStaff ? 'Staff Dashboard' : 'Digital Queue'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        actions: [
          if (!isStaff) ...[
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () {
                // TODO: Implement notifications
              },
            ),
          ],
        ],
      ),
      body: screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        selectedItemColor: Colors.blue.shade600,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.room_service_outlined),
            activeIcon: Icon(Icons.room_service),
            label: 'Services',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.confirmation_number_outlined),
            activeIcon: Icon(Icons.confirmation_number),
            label: 'My Tokens',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outlined),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade600, Colors.blue.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome Back!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Book your service token quickly and easily',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Quick Actions
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _buildQuickActionCard(
                  icon: Icons.add_circle_outline,
                  title: 'New Token',
                  subtitle: 'Book a service',
                  color: Colors.green,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const ServiceSelectionScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionCard(
                  icon: Icons.history,
                  title: 'History',
                  subtitle: 'View past tokens',
                  color: Colors.orange,
                  onTap: () {
                    // TODO: Navigate to history screen
                  },
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Current Status
          const Text(
            'Current Status',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 16),
          
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 48,
                  color: Colors.grey,
                ),
                SizedBox(height: 12),
                Text(
                  'No Active Tokens',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Book a service to get started',
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class ServicesTab extends StatelessWidget {
  const ServicesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TokenProvider>(
      builder: (context, tokenProvider, child) {
        if (tokenProvider.errorMessage != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red.shade400,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Unable to Load Services',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tokenProvider.errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => tokenProvider.reloadServices(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (tokenProvider.services.isEmpty && tokenProvider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (tokenProvider.services.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No Services Available',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Check back later for available services',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => tokenProvider.reloadServices(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Available Services',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: tokenProvider.services.length,
                  itemBuilder: (context, index) {
                    final service = tokenProvider.services[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.room_service,
                            color: Colors.blue.shade600,
                            size: 24,
                          ),
                        ),
                        title: Text(
                          service.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              service.description ?? 'No description available',                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 16,
                                  color: Colors.grey.shade500,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '~${service.estimatedTimeMinutes} min',
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: ElevatedButton(
                          onPressed: () {
                            // Navigate to service selection with this service pre-selected
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ServiceSelectionScreen(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                          child: const Text('Book Token'),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class TokensTab extends StatelessWidget {
  const TokensTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const UserTokensScreen();
  }
}

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  UserProfile? userProfile;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() => isLoading = true);
    
    try {
      final user = SupabaseConfig.client.auth.currentUser;
      if (user != null) {
        print('🔍 DEBUG: Current user ID: ${user.id}');
        print('🔍 DEBUG: Current user email: ${user.email}');
        
        // Try to get user data from database
        final response = await SupabaseConfig.client
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();
            
        print('🔍 DEBUG: Database response: $response');
            
        if (response != null) {
          print('🔍 DEBUG: Found profile data - Name: ${response['full_name']}, Phone: ${response['phone']}');
          setState(() {
            userProfile = UserProfile(
              id: response['id'],
              fullName: response['full_name'],
              phone: response['phone'],
              role: UserRole.values.firstWhere(
                (e) => e.name == (response['role'] ?? 'customer'),
                orElse: () => UserRole.customer,
              ),
              isActive: response['is_active'] ?? true,
              createdAt: DateTime.parse(response['created_at']),
              updatedAt: DateTime.parse(response['updated_at'] ?? response['created_at']),
            );
          });
        } else {
          print('🔍 DEBUG: No profile data found in database, using auth metadata');
          // Fallback to auth metadata if no database record
          setState(() {
            userProfile = UserProfile(
              id: user.id,
              fullName: user.userMetadata?['name'],
              phone: user.phone,
              role: UserRole.customer,
              isActive: true,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
          });
        }
      } else {
        print('🔍 DEBUG: No current user found');
      }
    } catch (e) {
      print('❌ Error loading user profile: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Profile Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.blue.shade100,
                  child: Icon(
                    Icons.person,
                    size: 40,
                    color: Colors.blue.shade600,
                  ),
                ),
                const SizedBox(height: 16),
                if (isLoading)
                  const CircularProgressIndicator()
                else
                  Text(
                    userProfile?.fullName ?? 'Not provided',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Profile Options
          _buildProfileOption(
            icon: Icons.edit_outlined,
            title: 'Edit Profile',
            onTap: () {
              // TODO: Navigate to edit profile
            },
          ),
          
          _buildProfileOption(
            icon: Icons.history,
            title: 'Token History',
            onTap: () {
              // TODO: Navigate to history
            },
          ),
          
          _buildProfileOption(
            icon: Icons.settings_outlined,
            title: 'Settings',
            onTap: () {
              // TODO: Navigate to settings
            },
          ),
          
          _buildProfileOption(
            icon: Icons.help_outline,
            title: 'Help & Support',
            onTap: () {
              // TODO: Navigate to help
            },
          ),
          
          const Spacer(),
          
          // Logout Button
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 20),
            child: ElevatedButton(
              onPressed: () async {
                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                await authProvider.signOut();
                
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Logout',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: Colors.grey.shade700,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: Colors.grey,
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        tileColor: Colors.white,
      ),
    );
  }
}
