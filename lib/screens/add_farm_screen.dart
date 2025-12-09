import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../api/api_client.dart'; // Import ApiClient

class AddFarmScreen extends StatefulWidget {
  final String accessToken;
  const AddFarmScreen({super.key, required this.accessToken});

  @override
  State<AddFarmScreen> createState() => _AddFarmScreenState();
}

class _AddFarmScreenState extends State<AddFarmScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  
  String? _selectedCropId;
  final List<LatLng> _polygonPoints = [];
  final MapController _mapController = MapController();

  bool _isLoading = false;

  /// 🔥 IMPORTANT: Load only the crops list (not whole response)
  late Future<List<Map<String, dynamic>>> _cropsFuture;

  LatLng _initialCenter = const LatLng(20.5937, 78.9629);

  @override
  void initState() {
    super.initState();
    _cropsFuture = ApiClient().getCrops();     // <--- FIXED
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;
    
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    
    try {
      Position position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _initialCenter = LatLng(position.latitude, position.longitude);
          _mapController.move(_initialCenter, 16.0);
        });
      }
    } catch (e) {
      log("Error: $e");
    }
  }

  void _handleMapTap(TapPosition tapPosition, LatLng latLng) {
    if (_polygonPoints.length < 20) {
      setState(() => _polygonPoints.add(latLng));
    }
  }

  void _submitFarm() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedCropId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a crop")));
      return;
    }
    if (_polygonPoints.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mark at least 3 points for boundary")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ApiClient().createFarm(
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
        boundaryPoints: _polygonPoints,
        cropId: _selectedCropId!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Farm Added Successfully!")));
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${e.toString()}")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, 
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          child: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
          ),
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: 13.0,
              onTap: _handleMapTap,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.cropic',
              ),
              PolygonLayer(
                polygons: [
                  Polygon(
                    points: _polygonPoints,
                    color: Colors.green.withValues(alpha: 0.4),
                    borderColor: Colors.green,
                    borderStrokeWidth: 3,
                    isFilled: true,
                  ),
                ],
              ),
              MarkerLayer(
                markers: _polygonPoints.map((p) => Marker(
                  point: p,
                  width: 20, height: 20,
                  child: const Icon(Icons.circle, color: Colors.white, size: 14),
                )).toList(),
              ),
            ],
          ),

          Positioned(
            top: 100,
            right: 16,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: "undo",
                  backgroundColor: Colors.white,
                  onPressed: _polygonPoints.isEmpty ? null : () => setState(() => _polygonPoints.removeLast()),
                  child: const Icon(Icons.undo, color: Colors.black87),
                ),
                const SizedBox(height: 10),
                FloatingActionButton.small(
                  heroTag: "clear",
                  backgroundColor: Colors.white,
                  onPressed: _polygonPoints.isEmpty ? null : () => setState(() => _polygonPoints.clear()),
                  child: const Icon(Icons.delete_outline, color: Colors.red),
                ),
              ],
            ),
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, -5))],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("New Farm Details", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Farm Name',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        prefixIcon: const Icon(Icons.eco_outlined, color: Colors.green),
                      ),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _addressController,
                      decoration: InputDecoration(
                        labelText: 'Address',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        prefixIcon: const Icon(Icons.location_on_outlined, color: Colors.orange),
                      ),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),

                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: _cropsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const SizedBox(
                            height: 50,
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        if (snapshot.hasError) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              "Error loading crops: ${snapshot.error}",
                              style: const TextStyle(color: Colors.red),
                            ),
                          );
                        }

                        final crops = snapshot.data ?? [];
                        if (crops.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text("No crops available", style: TextStyle(color: Colors.orange)),
                          );
                        }

                        return DropdownButtonFormField<String>(
                          initialValue: _selectedCropId,
                          decoration: InputDecoration(
                            labelText: 'Select Crop',
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            prefixIcon: const Icon(Icons.grass, color: Colors.blue),
                          ),
                          items: crops.map((crop) {
                            return DropdownMenuItem<String>(
                              value: crop['id'],
                              child: Text(crop['name']),
                            );
                          }).toList(),
                          onChanged: (val) => setState(() => _selectedCropId = val),
                          validator: (v) => v == null ? 'Please select a crop' : null,
                        );
                      },
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitFarm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          elevation: 0,
                        ),
                        child: _isLoading 
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("SAVE FARM", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
