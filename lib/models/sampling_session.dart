import 'package:latlong2/latlong.dart';

enum BlockStatus { pending, completed }

class SamplingBlock {
  final String id;
  final String? gridBlockId; // ID from database
  final LatLng center; // The target location
  final List<LatLng> boundary; // The polygon (visual only)
  BlockStatus status;
  
  SamplingBlock({
    required this.id,
    this.gridBlockId,
    required this.center,
    required this.boundary,
    this.status = BlockStatus.pending,
  });

  factory SamplingBlock.fromJson(Map<String, dynamic> json) {
    // Parse Center
    LatLng centerPoint = const LatLng(0, 0);
    if (json['center'] != null) {
       // GeoJSON Point: { type: "Point", coordinates: [lon, lat] } 
       // OR simple object { lat: x, lon: y }
       if (json['center']['coordinates'] != null) {
         final coords = json['center']['coordinates'];
         centerPoint = LatLng(coords[1], coords[0]);
       } else if (json['center']['lat'] != null) {
         centerPoint = LatLng(json['center']['lat'], json['center']['lon'] ?? json['center']['lng']);
       }
    } else if (json['centroid'] != null) {
       // Handling "centroid" key if API returns that
       if (json['centroid']['coordinates'] != null) {
         final coords = json['centroid']['coordinates'];
         centerPoint = LatLng(coords[1], coords[0]);
       }
    }

    // Parse Boundary (GeoJSON Polygon)
    List<LatLng> boundaryPoints = [];
    if (json['geom'] != null && json['geom']['coordinates'] != null) {
      final rings = json['geom']['coordinates'] as List;
      if (rings.isNotEmpty) {
        final outerRing = rings[0] as List;
        boundaryPoints = outerRing.map((c) => LatLng(c[1], c[0])).toList();
      }
    }

    // Status mapping (API might return string status)
    BlockStatus initialStatus = BlockStatus.pending;
    if (json['status'] == 'COMPLETED') {
      initialStatus = BlockStatus.completed;
    }

    return SamplingBlock(
      id: json['id']?.toString() ?? 'unknown',
      gridBlockId: json['gridBlockId']?.toString(),
      center: centerPoint,
      boundary: boundaryPoints,
      status: initialStatus,
    );
  }
}