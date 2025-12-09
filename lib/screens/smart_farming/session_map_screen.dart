import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../models/sampling_session.dart';
import '../../api/api_client.dart';

class SessionMapScreen extends StatefulWidget {
  final String farmId;
  final String sessionId;
  final List<SamplingBlock> blocks;

  const SessionMapScreen({
    super.key,
    required this.farmId,
    required this.sessionId,
    required this.blocks,
  });

  @override
  State<SessionMapScreen> createState() => _SessionMapScreenState();
}

class _SessionMapScreenState extends State<SessionMapScreen> {
  final MapController _mapController = MapController();
  Position? _currentPosition;
  bool _isDevMode = false;
  bool _isSubmitting = false; // To handle API loading state
  
  SamplingBlock? _selectedBlock;
  bool _isInRange = false;
  StreamSubscription<Position>? _positionStream;

  @override
  void initState() {
    super.initState();
    _startLocationUpdates();
  }

  Future<void> _startLocationUpdates() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    // High accuracy settings for field work
    const settings = LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 2);
    
    _positionStream = Geolocator.getPositionStream(locationSettings: settings).listen((Position position) {
      // Filter out poor GPS signals (jumping)
      if (position.accuracy > 25.0) {
        log("GPS Signal Weak: ${position.accuracy}m - Ignoring update");
        return; 
      }

      if (mounted) {
        setState(() {
          _currentPosition = position;
          _checkProximity();
        });
      }
    });
  }

  void _checkProximity() {
    if (_selectedBlock == null || _currentPosition == null) {
      _isInRange = false;
      return;
    }

    double distance = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      _selectedBlock!.center.latitude,
      _selectedBlock!.center.longitude,
    );

    // UNLOCK DISTANCE: 30 meters
    setState(() => _isInRange = distance < 30);
  }

  // --- ACTIONS ---

  void _onBlockTapped(SamplingBlock block) {
    setState(() {
      _selectedBlock = block;
      _checkProximity();
    });
  }

  Future<void> _submitSession() async {
    if (_isSubmitting) return;
    
    // Quick validation: warn if not all blocks are done (optional)
    bool allDone = widget.blocks.every((b) => b.status == BlockStatus.completed);
    if (!allDone) {
      final proceed = await showDialog<bool>(
        context: context, 
        builder: (c) => AlertDialog(
          title: const Text("Incomplete Session"),
          content: const Text("Not all blocks are sampled. Submit anyway?"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Cancel")),
            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("Submit")),
          ],
        )
      );
      if (proceed != true) return;
    }

    setState(() => _isSubmitting = true);
    
    try {
      await ApiClient().submitDamageSession(widget.farmId, widget.sessionId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Report Submitted Successfully!")));
        context.go('/home'); // Or back to farm details
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Determine center: First block or default
    final center = widget.blocks.isNotEmpty ? widget.blocks.first.center : const LatLng(20.5937, 78.9629);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Damage Session"),
        actions: [
          // Submit Button from File 1
          IconButton(
             icon: _isSubmitting 
               ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
               : const Icon(Icons.check),
             tooltip: "Submit Report",
             onPressed: _isSubmitting ? null : _submitSession,
          )
        ]
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 18.0,
            ),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
              
              // 1. Draw Polygons (Boundaries) - From File 1
              PolygonLayer(
                polygons: widget.blocks.map((b) => Polygon(
                  points: b.boundary.isNotEmpty ? b.boundary : [b.center], 
                  color: b.status == BlockStatus.completed ? Colors.green.withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.3),
                  borderColor: b.status == BlockStatus.completed ? Colors.green : Colors.red,
                  borderStrokeWidth: 2,
                  isFilled: true,
                )).toList(),
              ),

              // 2. Draw Interactive Markers - From File 2 (Better UX)
              MarkerLayer(
                markers: widget.blocks.map((block) {
                  bool isSelected = _selectedBlock == block;
                  bool isCompleted = block.status == BlockStatus.completed;

                  return Marker(
                    point: block.center,
                    width: 60, height: 60,
                    child: GestureDetector(
                      onTap: () => _onBlockTapped(block),
                      child: Center(
                        child: Container(
                          width: isSelected ? 50 : 30, // Animate size
                          height: isSelected ? 50 : 30,
                          decoration: BoxDecoration(
                             color: isCompleted 
                               ? Colors.green.withValues(alpha: 0.5) 
                               : (isSelected ? Colors.blue.withValues(alpha: 0.5) : Colors.red.withValues(alpha: 0.5)),
                             shape: BoxShape.circle,
                             border: Border.all(
                               color: isCompleted ? Colors.green : (isSelected ? Colors.blue : Colors.red), 
                               width: 2
                             ),
                          ),
                          child: isCompleted ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              // 3. User Location Marker
              if (_currentPosition != null)
                MarkerLayer(markers: [
                  Marker(
                    point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude), 
                    child: const Icon(Icons.navigation, color: Colors.blue, size: 30)
                  )
                ]),
            ],
          ),

          // --- DEV TOOLS (From File 2) ---
          
          // "Locate Me" / Teleport Target Button
          Positioned(
            top: 20,
            right: 20,
            child: FloatingActionButton.small(
              heroTag: "locate_btn",
              backgroundColor: Colors.orange,
              child: const Icon(Icons.my_location, color: Colors.white),
              onPressed: () {
                 if (_currentPosition != null && _selectedBlock != null && _isDevMode) {
                   // Dev Feature: simulate being in range without mutating final model
                   setState(() {
                    // Move map to current position and mark as in-range for testing
                    _mapController.move(LatLng(_currentPosition!.latitude, _currentPosition!.longitude), 18);
                    _isInRange = true;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("DEBUG: Simulated target in-range")));
                   });
                 } else if (_currentPosition != null) {
                   // Standard feature: Center map on me
                   _mapController.move(LatLng(_currentPosition!.latitude, _currentPosition!.longitude), 18);
                 }
              },
            ),
          ),

          // Dev Mode Switch
          Positioned(
            top: 20,
            left: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Dev Mode", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  Switch(
                    value: _isDevMode,
                    activeThumbColor: Colors.orange,
                    onChanged: (val) => setState(() => _isDevMode = val),
                  ),
                ],
              ),
            ),
          ),

          // --- BOTTOM CONTROLLER (The "Pokemon Go" Style Card) ---
          Positioned(
            bottom: 30, left: 20, right: 20,
            child: _buildBottomCard(),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomCard() {
    if (_selectedBlock == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)]),
        child: const Text("Tap a red circle to start navigation.", textAlign: TextAlign.center),
      );
    }

    if (_selectedBlock!.status == BlockStatus.completed) {
       return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)]),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text("Block Completed!", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
          ],
        ),
      );
    }

    bool canStart = _isInRange || _isDevMode;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("Target #${_selectedBlock!.id}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 10),
          
          canStart
              ? Text(
                  _isDevMode ? "Dev Mode: GPS Bypassed" : "You are in the zone!",
                  style: TextStyle(color: _isDevMode ? Colors.orange : Colors.green, fontWeight: FontWeight.bold),
                )
              : const Text("Walk closer to the circle...", style: TextStyle(color: Colors.grey)),
          
          const SizedBox(height: 16),
          
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: canStart ? () async {
                  // Navigate to Camera, passing REAL IDs
                  final result = await context.push('/block-camera', extra: {
                      'block': _selectedBlock,
                      'sessionId': widget.sessionId,
                  });
                  
                  // If camera returns true (uploaded successfully)
                  if (result == true) {
                    setState(() {
                      _selectedBlock!.status = BlockStatus.completed;
                      _selectedBlock = null; 
                    });
                  }
              } : null, 
              style: ElevatedButton.styleFrom(backgroundColor: canStart ? Colors.green : Colors.grey),
              icon: const Icon(Icons.camera_alt, color: Colors.white),
              label: Text(
                canStart ? (_isDevMode ? "START SAMPLING (DEV)" : "START SAMPLING") : "TOO FAR", 
                style: const TextStyle(color: Colors.white)
              ),
            ),
          ),
        ],
      ),
    );
  }
}