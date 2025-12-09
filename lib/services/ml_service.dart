import 'dart:io';
import 'package:image/image.dart' as img;

class MLService {
  static final MLService _instance = MLService._internal();
  factory MLService() => _instance;
  MLService._internal();

  /// Calculates the Laplacian Variance of an image.
  /// A lower variance indicates less edge detail (blurrier).
  /// A threshold of ~100-300 is common, but depends on resolution/lighting.
  Future<bool> isBlurry(String imagePath, {double threshold = 150.0}) async {
    try {
      // 1. Read Image
      final bytes = await File(imagePath).readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) return true; // Fail safe

      // 2. Resize to speed up calculation (processing full res is slow)
      final resized = img.copyResize(image, width: 500);

      // 3. Convert to Grayscale
      final grayscale = img.grayscale(resized);

      // 4. Apply Laplacian Kernel
      // [ 0, -1,  0]
      // [-1,  4, -1]
      // [ 0, -1,  0]
      final laplacian = img.convolution(grayscale, filter: [0, -1, 0, -1, 4, -1, 0, -1, 0]);

      // 5. Calculate Variance
      double sum = 0.0;
      double sumSq = 0.0;
      int count = 0;

      // Iterate through pixels to calculate statistical variance
      for (var pixel in laplacian) {
        // Since it's grayscale, r, g, and b are the same. We use r (red channel).
        final val = pixel.r.toDouble(); 
        sum += val;
        sumSq += val * val;
        count++;
      }

      final mean = sum / count;
      final variance = (sumSq / count) - (mean * mean);

      // If variance is less than threshold, it is blurry
      return variance < threshold;

    } catch (e) {
      // If something goes wrong, assume it's bad to force retake
      return true;
    }
  }

  /// Very small heuristic to validate whether the captured image contains
  /// crop-like content. This is not a full ML model — it computes the
  /// proportion of "green" pixels in the center region and returns a
  /// confidence between 0.0 and 1.0. It's sufficient as a lightweight
  /// fallback while a proper model is integrated.
  Future<double> validateCropImage(String imagePath) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) return 0.0;

      // Focus on center region to avoid sky/soil influence
      final int w = image.width;
      final int h = image.height;
      final int cx = (w * 0.25).round();
      final int cy = (h * 0.25).round();
      final int cw = (w * 0.5).round();
      final int ch = (h * 0.5).round();

      int greenCount = 0;
      int total = 0;

      for (int y = cy; y < cy + ch; y++) {
        for (int x = cx; x < cx + cw; x++) {
          final p = image.getPixel(x, y);
          // Pixel is a Pixel object from the image package; access channels directly
          final r = p.r as int;
          final g = p.g as int;
          final b = p.b as int;

          total++;
          // Simple green detection: green channel significantly higher
          if (g > 100 && g > r + 20 && g > b + 20) greenCount++;
        }
      }

      if (total == 0) return 0.0;
      final ratio = greenCount / total;
      // Map ratio to a 0..1 confidence (clamp)
      final confidence = ratio.clamp(0.0, 1.0);
      return confidence;
    } catch (e) {
      return 0.0;
    }
  }
}