import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

class DriveService {
  /// Uploads or updates the database file to Google Drive.
  /// 
  /// If [fileId] is provided, it attempts to overwrite (PATCH) the existing file.
  /// Otherwise, it creates a new file (POST).
  /// 
  /// Returns the Google Drive file ID of the uploaded/updated file.
  Future<String> uploadDatabaseToDrive({
    required String accessToken,
    required String dbFilePath,
    String? fileId,
  }) async {
    final file = File(dbFilePath);
    if (!await file.exists()) {
      throw Exception('Database file not found at $dbFilePath');
    }

    final String fileName = p.basename(dbFilePath);
    // 1. Prepare Multipart Request
    final isUpdate = fileId != null && fileId.isNotEmpty;
    final Uri uri = isUpdate
        ? Uri.parse('https://www.googleapis.com/upload/drive/v3/files/$fileId?uploadType=multipart')
        : Uri.parse('https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart');

    final request = http.MultipartRequest(isUpdate ? 'PATCH' : 'POST', uri);
    request.headers.addAll({
      'Authorization': 'Bearer $accessToken',
    });

    // 2. Add Metadata Part
    // The metadata part MUST come first in the multipart request for Google Drive API.
    final metadata = {
      'name': fileName,
      // If it's a new file, we can optionally set the parent folder here.
      // 'parents': ['appDataFolder'] // or a specific folder ID
    };

    request.fields['metadata'] = jsonEncode(metadata);
    
    // We need to manually construct the multipart request to ensure correct content types
    // Since http.MultipartRequest doesn't easily let us send JSON as one part and file as another
    // with different Content-Types out of the box without some dancing.
    // Let's use the direct REST API with a multipart body manually.

    final String boundary = 'foo_bar_baz_${DateTime.now().millisecondsSinceEpoch}';
    
    final http.Request rawRequest = http.Request(isUpdate ? 'PATCH' : 'POST', uri);
    rawRequest.headers.addAll({
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'multipart/related; boundary=$boundary',
    });

    final List<int> bodyBytes = [];

    // Part 1: Metadata
    bodyBytes.addAll(utf8.encode('--$boundary\r\n'));
    bodyBytes.addAll(utf8.encode('Content-Type: application/json; charset=UTF-8\r\n\r\n'));
    bodyBytes.addAll(utf8.encode(jsonEncode(metadata)));
    bodyBytes.addAll(utf8.encode('\r\n'));

    // Part 2: File Content
    bodyBytes.addAll(utf8.encode('--$boundary\r\n'));
    bodyBytes.addAll(utf8.encode('Content-Type: application/octet-stream\r\n\r\n'));
    bodyBytes.addAll(await file.readAsBytes());
    bodyBytes.addAll(utf8.encode('\r\n'));

    // End boundary
    bodyBytes.addAll(utf8.encode('--$boundary--\r\n'));

    rawRequest.bodyBytes = bodyBytes;

    // 3. Send Request
    final response = await http.Client().send(rawRequest);
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode == 200 || response.statusCode == 201) {
      final jsonResponse = jsonDecode(responseBody);
      return jsonResponse['id'] as String;
    } else {
      throw Exception('Failed to upload to Google Drive: ${response.statusCode} - $responseBody');
    }
  }
}
