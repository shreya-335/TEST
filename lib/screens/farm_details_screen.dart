import 'dart:ui'; // Required for ImageFilter
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../api/api_client.dart';
import '../models/farm_model.dart';
import '../models/sampling_session.dart'; // Ensure this model exists for SamplingBlock

class FarmDetailsScreen extends StatefulWidget {
  final String farmId;

  const FarmDetailsScreen({super.key, required this.farmId});

  @override
  State<FarmDetailsScreen> createState() => _FarmDetailsScreenState();
}

class _FarmDetailsScreenState extends State<FarmDetailsScreen> {
  late Future<Farm> _farmFuture;
  String _cropName = "Loading...";
  final String _wheatImage = 'assets/wheat1.jpg';
  
  // State to handle the "Starting Session" API latency
  bool _isActionLoading = false;

  @override
  void initState() {
    super.initState();
    _loadFarmDetails();
  }

  void _loadFarmDetails() {
    setState(() {
      _farmFuture = ApiClient().getFarmById(widget.farmId);
    });

    _farmFuture.then((farm) {
      if (farm.cropId != null) {
        _fetchCropName(farm.cropId!);
      } else {
        if (mounted) setState(() => _cropName = "Unknown Crop");
      }
    }).catchError((_) {
      // Error handling managed by FutureBuilder
    });
  }

  Future<void> _fetchCropName(String cropId) async {
    try {
      final crops = await ApiClient().getCrops();
      final crop = crops.firstWhere(
        (c) => c['id'].toString() == cropId,
        orElse: () => {'name': 'Unknown Crop'}
      );
      if (mounted) {
        setState(() => _cropName = crop['name']);
      }
    } catch (e) {
      if (mounted) setState(() => _cropName = "Crop ID: $cropId");
    }
  }

  // --- ACTIONS ---
  
  /// Handles the architecture requirement:
  /// 1. Call API to create a specific damage session (Phase 1).
  /// 2. Receive Session ID and selected Grid Blocks.
  /// 3. Navigate to Map with this "real data" (Phase 2).
  Future<void> _handleDamageReport() async {
    if (_isActionLoading) return;
    
    setState(() => _isActionLoading = true);

    try {
      // API call maps to: POST /api/farms/:farmId/damage-sessions/start
      final sessionData = await ApiClient().startDamageSession(widget.farmId);
      
      final String sessionId = sessionData['sessionId'];
      // Assuming sessionData['blocks'] matches your SamplingBlock model structure
      final List<SamplingBlock> blocks = sessionData['blocks']; 

      if (mounted) {
        context.push('/session-map/${widget.farmId}', extra: {
          'sessionId': sessionId,
          'blocks': blocks
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to start session: $e"))
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          child: _glassIconButton(Icons.arrow_back, () => context.pop()),
        ),
      ),
      body: Stack(
        children: [
          // --- 1. Top Background Image ---
          Positioned(
            top: 0, left: 0, right: 0, height: 350,
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
                      Colors.black.withValues(alpha: 0.4),
                      Colors.black.withValues(alpha: 0.1),
                      const Color(0xFFF2F2F2),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // --- 2. Main Content ---
          SafeArea(
            bottom: false,
            child: FutureBuilder<Farm>(
              future: _farmFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text("Error loading farm: ${snapshot.error}"),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadFarmDetails,
                          child: const Text("Retry"),
                        )
                      ],
                    ),
                  );
                }

                final farm = snapshot.data!;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 10),
                      
                      // Farm Header Info
                      Text(farm.name, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 4),
                      Text(farm.address, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                      
                      const SizedBox(height: 24),

                      // --- Glassmorphic Crop Details Card ---
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            color: Colors.white.withValues(alpha: 0.2),
                            child: Row(
                              children: [
                                Container(
                                  width: 60, height: 60,
                                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(16)),
                                  child: const Icon(Icons.grass, color: Colors.white, size: 30),
                                ),
                                const SizedBox(width: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("Current Crop", style: TextStyle(color: Colors.white70, fontSize: 12)),
                                    const SizedBox(height: 4),
                                    Text(_cropName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),

                      // --- Action Buttons Grid ---
                      Expanded(
                        child: _isActionLoading 
                          ? const Center(child: CircularProgressIndicator())
                          : GridView.count(
                              padding: const EdgeInsets.only(top: 10, bottom: 40),
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 1.1,
                              children: [
                                _buildActionTile(
                                  title: "Weekly Update",
                                  subtitle: "Click Photo",
                                  icon: Icons.camera_alt,
                                  themeColor: const Color(0xFF4C6646),
                                  onTap: () => context.push('/camera/${widget.farmId}'),
                                ),
                                _buildActionTile(
                                  title: "Damage Report",
                                  subtitle: "Report Issue",
                                  icon: Icons.warning_amber_rounded,
                                  themeColor: Colors.orange.shade700,
                                  // Calls the new API logic instead of direct nav
                                  onTap: _handleDamageReport, 
                                ),
                                _buildActionTile(
                                  title: "Past Reports",
                                  subtitle: "View History",
                                  icon: Icons.history,
                                  themeColor: const Color(0xFF4C6646),
                                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("History coming soon"))),
                                ),
                                _buildActionTile(
                                  title: "Analytics",
                                  subtitle: "Farm Insights",
                                  icon: Icons.analytics_outlined,
                                  themeColor: Colors.orange.shade700,
                                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Analytics coming soon"))),
                                ),
                              ],
                            ),
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

  // --- UI Components ---

  Widget _glassIconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(50),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            padding: const EdgeInsets.all(8),
                            color: Colors.white.withValues(alpha: 0.2),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color themeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: Colors.grey.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: themeColor.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, color: themeColor, size: 32),
            ),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}