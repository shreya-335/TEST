import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import '../services/ml_service.dart';
import '../data/crop_standards.dart';
import '../api/api_client.dart';
import '../data/capture_data.dart';

class SmartCameraScreen extends StatefulWidget {
  final String farmId;
  const SmartCameraScreen({super.key, required this.farmId});

  @override
  State<SmartCameraScreen> createState() => _SmartCameraScreenState();
}

class _SmartCameraScreenState extends State<SmartCameraScreen> {
  CameraController? _controller;
  bool _isProcessing = false;
  bool _isLoading = true;

  // GPS State
  Position? _currentPosition;
  bool _isLocating = false;

  // Session State
  List<PhotoRequirement> _requirements = [];
  int _currentReqIndex = 0;
  int _photosTakenInCurrentReq = 0;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _startHighAccuracyLocation();
    _loadRequirements();
  }

  Future<void> _loadRequirements() async {
    // In a real app, you might fetch the Farm's current stage from the backend.
    // For now, we load standard vegetative requirements as per the requirements.
    try {
      if (mounted) {
        setState(() {
          // Using the data model from File 1/2
          _requirements = CropStandard.getRequirements(CropStage.vegetative);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _startHighAccuracyLocation() async {
    setState(() => _isLocating = true);
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _isLocating = false);
        return;
      }
    }

    try {
      // High accuracy for field reporting
      final LocationSettings locationSettings = const LocationSettings(accuracy: LocationAccuracy.bestForNavigation);
      _currentPosition = await Geolocator.getCurrentPosition(locationSettings: locationSettings);
    } catch (e) {
      debugPrint("GPS Error: $e");
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        _controller = CameraController(cameras.first, ResolutionPreset.high, enableAudio: false);
        await _controller!.initialize();
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint("Camera Error: $e");
    }
  }

  Future<void> _captureAndUpload() async {
    if (_controller == null || _isProcessing) return;

    // 1. Ensure GPS is ready
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Waiting for GPS...")));
      await _startHighAccuracyLocation();
      if (_currentPosition == null) return; 
    }

    setState(() => _isProcessing = true);

    try {
      final image = await _controller!.takePicture();
      final req = _requirements[_currentReqIndex];

      // 2. ML Check: Blur (From File 2)
      // Fast check to prevent bad uploads
      bool isBlurry = await MLService().isBlurry(image.path);
      if (isBlurry) {
        throw Exception("Image is too blurry. Hold steady.");
      }

      // 3. ML Check: Subject Validation (From File 1)
      // If asking for Macro, ensure we are close enough
      if (req.isMacro) {
        double confidence = await MLService().validateCropImage(image.path);
        if (confidence < 0.4) {
           throw Exception("Subject not clear. Get closer to the crop.");
        }
      }

      // 4. Prepare Data for Upload (Backend Integration from File 1)
      final capture = CaptureData(
        photoFile: image,
        captureLat: _currentPosition!.latitude,
        captureLon: _currentPosition!.longitude,
        exifLat: null, 
        exifLon: null, 
        exifTimestamp: null
      );

      // 5. Presign Upload
      final presign = await ApiClient().presignUpload(capture, deviceMeta: {
        "farmId": widget.farmId,
        "reportType": "WEEKLY",
        "stage": req.label,
        "requirementId": _currentReqIndex.toString()
      });

      capture.signedUploadParams = presign['upload'] ?? presign['uploadParams'];

      // 6. Upload to Cloudinary
      final cloudRes = await ApiClient().uploadToCloudinary(capture.photoFile, capture.signedUploadParams!);
      
      // 7. Complete Transaction
      await ApiClient().completeUpload(capture, cloudRes['public_id'], cloudRes['secure_url']);

      // 8. Update UI State (From File 2)
      _photosTakenInCurrentReq++;
      
      if (_photosTakenInCurrentReq >= req.count) {
        setState(() {
          _currentReqIndex++;
          _photosTakenInCurrentReq = 0;
        });
      }

      if (_currentReqIndex >= _requirements.length) {
        _finishSession();
      } else {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Uploaded! Next photo..."), duration: Duration(milliseconds: 800)));
      }

    } catch (e) {
      if (mounted) {
        showDialog(
          context: context, 
          builder: (c) => AlertDialog(
            title: const Text("Issue Detected"), 
            content: Text(e.toString().replaceAll("Exception:", "")), 
            actions: [TextButton(onPressed: ()=>Navigator.pop(c), child: const Text("Try Again"))]
          )
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _finishSession() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("Weekly Update Complete"),
        content: const Text("Great job! All samples have been collected and synced to the cloud."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.go('/home'); // Or back to farm details
            },
            child: const Text("Done"),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized || _isLoading) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.white)));
    }

    if (_currentReqIndex >= _requirements.length) return Container(color: Colors.black);

    final req = _requirements[_currentReqIndex];
    // Progress String from File 2
    final progress = "Step ${_currentReqIndex + 1}/${_requirements.length} • Photo ${_photosTakenInCurrentReq + 1}/${req.count}";

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Camera Preview
          Center(child: CameraPreview(_controller!)),

          // 2. Dynamic Overlay
          if (req.isMacro)
            Center(
              child: Container(
                width: 250, 
                height: 250, 
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.yellow, width: 2), 
                  borderRadius: BorderRadius.circular(12)
                )
              )
            )
          else
            Column(children: [
                  Expanded(child: Container(decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.3)))))), 
              Expanded(child: Container())
            ]),

          // 3. GPS Status Pill (From File 2)
          Positioned(
            top: 50, left: 0, right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_isLocating ? Icons.gps_not_fixed : Icons.gps_fixed, color: _isLocating ? Colors.red : Colors.green, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      _isLocating ? "Acquiring GPS..." : "GPS Locked (${_currentPosition?.accuracy.toStringAsFixed(1)}m)",
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 4. Bottom Controls & Instructions (From File 2)
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black87],
                  begin: Alignment.topCenter, end: Alignment.bottomCenter
                )
              ),
              child: Column(
                children: [
                  Text(req.label.toUpperCase(), style: const TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  Text(req.instruction, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(progress, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 24),
                  FloatingActionButton(
                    onPressed: _isProcessing ? null : _captureAndUpload,
                    backgroundColor: Colors.white,
                    child: _isProcessing 
                      ? const Padding(padding: EdgeInsets.all(12.0), child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(Icons.camera, color: Colors.green.shade800, size: 32),
                  )
                ],
              ),
            ),
          ),

          // 5. Close Button
          Positioned(
            top: 40, left: 20,
            child: GestureDetector(
              onTap: () => context.pop(),
              child: const CircleAvatar(
                backgroundColor: Colors.black45,
                child: Icon(Icons.close, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}