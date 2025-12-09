import 'dart:ui'; // Required for ImageFilter (Blur)
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../api/api_client.dart';
import '../models/farm_model.dart';
import '../I10n/app_localizations.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Farm>> _farmsFuture;
  Map<String, dynamic>? _userProfile;

  // Asset path constant
  final String _wheatImage = 'assets/wheat1.jpg';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _farmsFuture = ApiClient().getFarms();
    ApiClient().getMe().then((data) {
      if (mounted) setState(() => _userProfile = data['data']);
    }).catchError((_) {});
  }

  Future<void> _refreshFarms(BuildContext context) async {
    try {
      setState(() {
        _farmsFuture = ApiClient().getFarms();
      });
      await _farmsFuture;
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Farms refreshed')));
      }
    } catch (e) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Refresh failed: ${e.toString()}')));
      }
    }
  }

  // --- Navigation Helpers ---
  void _onBottomNavTapped(int index) {
    // 0: Home, 1: Advisory, 2: Community, 3: Claims, 4: Finance, 5: CCE (New)
    switch (index) {
      case 0:
        break; // Home
      case 1:
        context.push('/advisory');
        break;
      case 2:
        context.push('/community');
        break;
      case 3:
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Claims feature coming soon")));
        break;
      case 4:
        context.push('/finance');
        break;
      case 5:
        context.push('/cce-tasks'); // Navigate to CCE Task List
        break;
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    await ApiClient().logout();
    if (context.mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFFF2F2F2), 
      body: Stack(
        children: [
          // --- 1. Top Background Image ---
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 350,
            child: Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(_wheatImage),
                  fit: BoxFit.cover,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.3),
                      Colors.black.withOpacity(0.1),
                      const Color(0xFFF2F2F2),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // --- 2. Main Scrollable Content ---
          SafeArea(
            child: RefreshIndicator(
              onRefresh: () async => await _refreshFarms(context),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    
                    // --- Header ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                             CircleAvatar(
                              radius: 22,
                              backgroundImage: AssetImage(_wheatImage),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.translate('welcome_back'), 
                                  style: const TextStyle(color: Colors.white, fontSize: 14)
                                ),
                                Text(
                                  _userProfile?['name'] ?? "Farmer",
                                  style: const TextStyle(
                                    color: Colors.white, 
                                    fontWeight: FontWeight.bold, 
                                    fontSize: 18
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        // Top Right Controls
                        Row(
                          children: [
                             _glassIconButton(Icons.refresh, () => _refreshFarms(context)),
                             const SizedBox(width: 8),
                             _glassIconButton(Icons.notifications_none, () {}),
                             const SizedBox(width: 8),
                             _glassIconButton(Icons.logout, () => _handleLogout(context), color: Colors.redAccent),
                          ],
                        )
                      ],
                    ),

                    const SizedBox(height: 24),
                    _buildGlassWeatherCard(l10n),
                    const SizedBox(height: 20),
                    _buildProactiveAlerts(l10n),
                    const SizedBox(height: 24),

                    // --- "Our agriculture field" Header ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Our agriculture field",
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            if (!mounted || !context.mounted) return;
                            final res = await context.push('/add-farm');
                            if (mounted && res == true && context.mounted) {
                              await _refreshFarms(context);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4C6646),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            elevation: 0,
                          ),
                          child: Text(
                            l10n.translate('add_new'),
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // --- Farm List ---
                    FutureBuilder<List<Farm>>(
                      future: _farmsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
                        }
                        if (snapshot.hasError) {
                          return Center(child: Text("Error: ${snapshot.error}"));
                        }

                        final farms = snapshot.data ?? [];
                        if (farms.isEmpty) {
                          return _buildEmptyState(l10n);
                        }

                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: farms.length,
                          padding: const EdgeInsets.only(bottom: 100), 
                          itemBuilder: (ctx, index) => _buildFarmCard(context, farms[index], l10n),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // --- Custom Bottom Navigation Bar ---
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildCustomBottomNav(context),
          ),
        ],
      ),
    );
  }

  // --- UI Components ---

  Widget _glassIconButton(IconData icon, VoidCallback onTap, {Color color = Colors.white}) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(50),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            padding: const EdgeInsets.all(8),
            color: Colors.white.withOpacity(0.2),
            child: Icon(icon, color: color, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassWeatherCard(AppLocalizations l10n) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          color: Colors.white.withOpacity(0.15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Text(
                        l10n.translate('todays_weather'), 
                        style: const TextStyle(color: Colors.white70, fontSize: 14)
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "16°C", 
                        style: TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w500)
                      ),
                    ],
                  ),
                   const Column(
                    children: [
                      Icon(Icons.cloud_outlined, color: Colors.white, size: 28),
                      SizedBox(height: 4),
                      Text("Partly Cloudy", style: TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  )
                ],
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.air, color: Colors.white70, size: 16),
                  SizedBox(width: 4),
                  Text("2.4 km/h", style: TextStyle(color: Colors.white70, fontSize: 12)),
                  SizedBox(width: 16),
                  Icon(Icons.water_drop_outlined, color: Colors.white70, size: 16),
                  SizedBox(width: 4),
                  Text("72.5%", style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProactiveAlerts(AppLocalizations l10n) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Colors.white.withOpacity(0.4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                   const Text(
                    "Proactive Alert System",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                   ),
                   Icon(Icons.arrow_forward_ios, size: 14, color: Colors.black54),
                 ],
               ),
               const SizedBox(height: 12),
               SingleChildScrollView(
                 scrollDirection: Axis.horizontal,
                 child: Row(
                   children: [
                     _buildAlertCard("Weather Alert", "Heavy Rain imminent", "Action Required", Colors.grey.shade300),
                     const SizedBox(width: 12),
                     _buildAlertCard("Pest Outbreak", "Aphids detected in Field B", "View Details", Colors.green.shade100),
                   ],
                 ),
               )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlertCard(String title, String subtitle, String action, Color btnColor) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Text.rich(
             TextSpan(
               text: "$title: ",
               style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
               children: [
                 TextSpan(text: subtitle, style: const TextStyle(fontWeight: FontWeight.normal))
               ]
             )
           ),
           const SizedBox(height: 12),
           Container(
             padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
             decoration: BoxDecoration(
               color: btnColor,
               borderRadius: BorderRadius.circular(12),
             ),
             child: Text(action, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
           )
        ],
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Center(child: Text(l10n.translate('no_farms'))),
    );
  }

  Widget _buildFarmCard(BuildContext context, Farm farm, AppLocalizations l10n) {
    return GestureDetector(
      onTap: () => context.push('/farm/${farm.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F4F2),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                _wheatImage,
                width: 70, 
                height: 70, 
                fit: BoxFit.cover
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    farm.name, 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)
                  ),
                  const SizedBox(height: 4),
                  const Text("Area: 6.2 ha", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Text("Status: ", style: TextStyle(color: Colors.grey, fontSize: 12)),
                      Text(l10n.translate('active'), style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.more_vert, size: 20, color: Colors.grey.shade600),
          ],
        ),
      ),
    );
  }

  // --- Custom Bottom Navigation Bar ---
  Widget _buildCustomBottomNav(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))
        ]
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), // Adjusted padding
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround, // Space evenly
          children: [
            _buildNavIcon(Icons.home_filled, "Home", 0, isActive: true),
            _buildNavIcon(Icons.spa_outlined, "Advisory", 1),
            // Central Camera Button (Community/Scan)
            GestureDetector(
               onTap: () => _onBottomNavTapped(2), 
               child: Container(
                 width: 45, height: 45, // Slightly smaller
                 decoration: BoxDecoration(
                   color: const Color(0xFF4C6646), 
                   shape: BoxShape.circle,
                   boxShadow: [
                     BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))
                   ]
                 ),
                 child: const Icon(Icons.groups_outlined, color: Colors.white),
               ),
            ),
            _buildNavIcon(Icons.description_outlined, "Claims", 3),
            _buildNavIcon(Icons.account_balance_wallet_outlined, "Finance", 4),
            
            // --- CCE MODE BUTTON ---
            _buildNavIcon(Icons.assignment, "CCE Mode", 5, isActive: false, color: Colors.blueAccent),
          ],
        ),
      ),
    );
  }

  Widget _buildNavIcon(IconData icon, String label, int index, {bool isActive = false, Color? color}) {
    final finalColor = color ?? (isActive ? const Color(0xFF4C6646) : Colors.grey);
    return GestureDetector(
      onTap: () => _onBottomNavTapped(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: finalColor, size: 24),
          const SizedBox(height: 4),
          Text(
            label, 
            style: TextStyle(
              color: finalColor, 
              fontSize: 9, // Slightly smaller font to fit 6 items
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal
            )
          )
        ],
      ),
    );
  }
}