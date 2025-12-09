import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart'; // Required for GPS Verification
import '../../api/api_client.dart';
import '../../data/capture_data.dart';
import '../../models/sampling_session.dart';
import '../../services/ml_service.dart'; // From File 2 (Blur Detection)

class BlockCameraScreen extends StatefulWidget {
  final SamplingBlock block;
  final String sessionId;

  const BlockCameraScreen({
    super.key, 
    required this.block, 
    required this.sessionId
  });

  @override
  State<BlockCameraScreen> createState() => _BlockCameraScreenState();
}

enum CaptureStep { fieldView, cropView }

class _BlockCameraScreenState extends State<BlockCameraScreen> {
  CameraController? _controller;
  CaptureStep _currentStep = CaptureStep.fieldView;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    // Use high resolution for ML analysis
    _controller = CameraController(cameras.first, ResolutionPreset.high, enableAudio: false);
    await _controller!.initialize();
    if(mounted) setState(() {});
  }

  Future<void> _captureAndUpload() async {
    if (_controller == null || _isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      // 1. Capture Image
      final image = await _controller!.takePicture();

      // 2. Blur Check (Feature from File 2)
      // We check this locally before wasting bandwidth on upload
      bool isBlurry = await MLService().isBlurry(image.path);
      if (isBlurry) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("Image is too blurry. Please hold steady."),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
        setState(() => _isProcessing = false);
        return; // Stop execution
      }

      // 3. Get GPS Location (Feature from File 1)
      // Critical for backend verification (Geofencing)
      final LocationSettings settings = const LocationSettings(accuracy: LocationAccuracy.high);
      final position = await Geolocator.getCurrentPosition(locationSettings: settings);

      // 4. Prepare Data Object
      final capture = CaptureData(
        photoFile: image,
        captureLat: position.latitude,
        captureLon: position.longitude,
        exifLat: null, // API handles extraction if needed, or we rely on captureLat
        exifLon: null,
        exifTimestamp: null,
      );

      // 5. Pre-sign Upload (Backend Integration)
      // Links this specific photo to the Session and Block ID
      final presign = await ApiClient().presignUpload(
        capture,
        deviceMeta: {
          "sessionBlockId": widget.block.gridBlockId ?? widget.block.id, // Use DB ID
          "sessionId": widget.sessionId,
          "blockId": widget.block.id,
          "step": _currentStep.name, // Track if this is field or crop view
        }
      );

      capture.uploadId = presign['uploadId']?.toString();
      capture.signedUploadParams = presign['upload'] ?? presign['uploadParams'];

      // 6. Direct Upload to Cloudinary
      final cloudinaryRes = await ApiClient().uploadToCloudinary(capture.photoFile, capture.signedUploadParams!);
      
      // 7. Complete Transaction on Backend
      await ApiClient().completeUpload(capture, cloudinaryRes['public_id'], cloudinaryRes['secure_url']);

      // 8. Handle Success / Transition
      if (_currentStep == CaptureStep.fieldView) {
        setState(() {
          _currentStep = CaptureStep.cropView;
          _isProcessing = false;
        });
      } else {
        if(mounted) {
            context.pop(true); // Return 'true' to Map Screen to mark block as done
        }
      }

    } catch (e) {
      if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload Failed: $e")));
      }
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
        return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator()));
    }

    bool isFieldView = _currentStep == CaptureStep.fieldView;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Preview
          Center(child: CameraPreview(_controller!)),
          
          // Ghost Overlay (Hole Punch)
          CustomPaint(
            size: Size.infinite, 
            painter: HolePunchPainter(
                holeSize: isFieldView ? const Size(350, 200) : const Size(200, 200), 
                borderRadius: 12
            )
          ),
          
          // Instructions & Controls
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              color: Colors.black54,
              child: Column(
                children: [
                  Text(
                      isFieldView ? "STEP 1: FIELD VIEW" : "STEP 2: CROP VIEW", 
                      style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 18)
                  ),
                  const SizedBox(height: 8),
                  Text(
                      isFieldView 
                        ? "Hold horizontal. Fit the horizon in the box." 
                        : "Get closer. Center a single leaf/stem in the box.", 
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FloatingActionButton(
                    onPressed: _captureAndUpload,
                    backgroundColor: Colors.white,
                    child: _isProcessing 
                        ? const CircularProgressIndicator() 
                        : const Icon(Icons.camera, size: 32, color: Colors.black),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Visual helper to darken the screen except for the target area
class HolePunchPainter extends CustomPainter {
  final Size holeSize;
  final double borderRadius;
  HolePunchPainter({required this.holeSize, required this.borderRadius});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.6); // Darken opacity
    
    // Background (full screen)
    final backgroundPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    
    // Hole (center)
    final holeRect = Rect.fromCenter(center: Offset(size.width / 2, size.height / 2), width: holeSize.width, height: holeSize.height);
    final holePath = Path()..addRRect(RRect.fromRectAndRadius(holeRect, Radius.circular(borderRadius)));
    
    // Cutout
    final finalPath = Path.combine(PathOperation.difference, backgroundPath, holePath);
    canvas.drawPath(finalPath, paint);
    
    // White Border
    canvas.drawRRect(
        RRect.fromRectAndRadius(holeRect, Radius.circular(borderRadius)), 
        Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2
    );
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}