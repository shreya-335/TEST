import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:camera/camera.dart';
import 'package:latlong2/latlong.dart';
import '../data/capture_data.dart';
import '../models/farm_model.dart';
import '../models/sampling_session.dart';

// Ensure this matches your backend IP (LAN IP for physical device testing)
const String _baseUrl = 'http://172.20.10.2:4000/api';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  String? _accessToken;

  bool get isAuthenticated => _accessToken != null;
  String? get accessToken => _accessToken;

  void setAuthToken(String? token) {
    _accessToken = token;
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
  };

  // ---------------------------------------------------------------------------
  // AUTHENTICATION
  // ---------------------------------------------------------------------------
  Future<String> requestOtp(String phone) async {
    final url = Uri.parse('$_baseUrl/auth/request-otp');
    try {
      final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode({"phone": phone, "purpose": "login"}));
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['data']['sessionId'];
      } else {
        throw Exception('Failed to send OTP: ${response.body}');
      }
    } catch (e) { rethrow; }
  }

  Future<Map<String, dynamic>> verifyOtp(String sessionId, String otp) async {
    final url = Uri.parse('$_baseUrl/auth/verify-otp');
    final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode({"sessionId": sessionId, "otp": otp}));
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      _accessToken = body['data']['tokens']['accessToken'];
      return body['data']['user'];
    } else throw Exception('Invalid OTP');
  }
  
  Future<void> logout() async { _accessToken = null; }

  Future<Map<String, dynamic>> getMe() async {
    final response = await http.get(Uri.parse('$_baseUrl/auth/me'), headers: _headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['data'] ?? jsonDecode(response.body);
    }
    throw Exception('Failed to fetch user');
  }

  // ---------------------------------------------------------------------------
  // FARM MANAGEMENT
  // ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> getCrops() async {
    final response = await http.get(Uri.parse('$_baseUrl/crops'), headers: _headers);
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(body is List ? body : body['data'] ?? []);
    } else throw Exception('Failed to fetch crops');
  }

  Future<List<Farm>> getFarms() async {
    final response = await http.get(Uri.parse('$_baseUrl/farms?page=1&perPage=50'), headers: _headers);
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      List<dynamic> list = (body is List) ? body : (body['data'] is List ? body['data'] : []);
      return list.map<Farm>((e) => Farm.fromJson(e)).toList();
    } else throw Exception('Failed to fetch farms');
  }

  Future<Farm> getFarmById(String id) async {
    final response = await http.get(Uri.parse('$_baseUrl/farms/$id'), headers: _headers);
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return Farm.fromJson(body['data'] ?? body);
    } else throw Exception('Failed to load farm');
  }

  Future<Farm> createFarm({required String name, required String address, required List<LatLng> boundaryPoints, required String cropId}) async {
    final boundary = FarmBoundary.fromLatLng(boundaryPoints);
    final response = await http.post(Uri.parse('$_baseUrl/farms'), headers: _headers, body: jsonEncode({"name": name, "address": address, "boundary": boundary.toJson(), "cropId": cropId}));
    if (response.statusCode == 201 || response.statusCode == 200) {
       return await getFarms().then((farms) => farms.firstWhere((f) => f.name == name));
    } else throw Exception('Failed to create farm');
  }

  // ---------------------------------------------------------------------------
  // NEW: DAMAGE & SAMPLING SESSIONS
  // ---------------------------------------------------------------------------

  /// Start a Damage Reporting Session
  Future<Map<String, dynamic>> startDamageSession(String farmId) async {
    final url = Uri.parse('$_baseUrl/farms/$farmId/damage-sessions/start');
    final response = await http.post(url, headers: _headers);

    if (response.statusCode == 201 || response.statusCode == 200) {
      final body = jsonDecode(response.body);
      final data = body['data'] ?? body;
      
      List<SamplingBlock> blocks = [];
      if (data['blocks'] != null) {
        blocks = (data['blocks'] as List).map((b) => SamplingBlock.fromJson(b)).toList();
      }

      return {
        'sessionId': data['sessionId'] ?? data['id'], 
        'blocks': blocks
      };
    } else {
      throw Exception('Failed to start damage session: ${response.body}');
    }
  }

  /// Submit a completed Damage Session
  Future<void> submitDamageSession(String farmId, String sessionId) async {
    final url = Uri.parse('$_baseUrl/farms/$farmId/damage-sessions/$sessionId/submit');
    final response = await http.post(url, headers: _headers);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to submit session: ${response.body}');
    }
  }

  // ---------------------------------------------------------------------------
  // UPLOAD MANAGEMENT
  // ---------------------------------------------------------------------------

  /// Step 1: Presign Upload (Updated with deviceMeta)
  Future<Map<String, dynamic>> presignUpload(CaptureData data, {Map<String, dynamic>? deviceMeta}) async {
    final file = File(data.photoFile.path);
    
    final body = {
      "localUploadId": data.localUploadId,
      "filename": data.photoFile.name,
      "filesize": await file.length(),
      "captureTimestamp": data.captureTimestamp.toIso8601String(),
      "hasCaptureCoords": data.isExifDataPresent,
      if (deviceMeta != null) "deviceMeta": deviceMeta,
    };

    final response = await http.post(
      Uri.parse('$_baseUrl/uploads/presign'),
      headers: _headers,
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get presigned URL: ${response.body}');
    }
  }

  /// Step 2: Upload to Cloudinary
  Future<Map<String, dynamic>> uploadToCloudinary(XFile file, Map<String, dynamic> signedParams) async {
    final uploadUrl = signedParams['uploadUrl'] as String;
    final Map<String, dynamic> uploadFields = signedParams['uploadParams'];

    final request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
    uploadFields.forEach((key, value) => request.fields[key] = value.toString());
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Cloudinary upload failed: ${response.body}');
    }
  }

  /// Step 3: Complete Upload
  Future<Map<String, dynamic>> completeUpload(CaptureData data, String publicId, String storageUrl) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/uploads/complete'),
      headers: _headers,
      body: jsonEncode({
        "uploadId": data.uploadId,
        "publicId": publicId,
        "localUploadId": data.localUploadId,
        "captureLat": data.captureLat,
        "captureLon": data.captureLon,
        "captureTimestamp": data.captureTimestamp.toIso8601String(),
        "uploadTimestamp": DateTime.now().toUtc().toIso8601String(),
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to complete upload');
    }
  }
}