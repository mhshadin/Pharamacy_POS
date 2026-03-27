import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

class DriveService {
  static const String _driveApiUrl = 'https://www.googleapis.com/drive/v3/files';
  static const String _driveUploadUrl = 'https://www.googleapis.com/upload/drive/v3/files';

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
    String? folderId,
  }) async {
    try {
      final File file = File(dbFilePath);
      if (!await file.exists()) {
        print("DEBUG ERROR: Local database file not found at $dbFilePath");
        throw Exception("Database file not found at $dbFilePath");
      }

      final String fileName = p.basename(dbFilePath);
      final List<int> bytes = await file.readAsBytes();

      if (fileId != null && fileId.isNotEmpty) {
        print("DEBUG: Attempting to update existing file $fileId. Folder ID: $folderId");
        
        final String patchUrl = '$_driveUploadUrl/$fileId?uploadType=media${folderId != null ? '&addParents=$folderId' : ''}';

        final patchResponse = await http.patch(
          Uri.parse(patchUrl),
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/octet-stream',
          },
          body: bytes,
        );

        if (patchResponse.statusCode == 200) {
          print("DEBUG: File content update successful for $fileId.");
          return fileId;
        } else if (patchResponse.statusCode == 404) {
          print("DEBUG: File $fileId not found on Drive (404). Falling back to fresh upload.");
          // Fall through to the multipart upload below
        } else {
          print("DEBUG ERROR: Patch failed for $fileId: ${patchResponse.statusCode} - ${patchResponse.body}");
          throw Exception('Failed to update database file $fileId: ${patchResponse.statusCode} - ${patchResponse.body}');
        }
      }

      print("DEBUG: Performing two-step upload (Create Metadata -> Patch Media)...");
      
      // Step 1: Create file entry with metadata
      final createResponse = await http.post(
        Uri.parse(_driveApiUrl),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'name': fileName,
          if (folderId != null) 'parents': [folderId],
        }),
      );

      if (createResponse.statusCode != 200 && createResponse.statusCode != 201) {
        print("DEBUG ERROR: Metadata creation failed: ${createResponse.statusCode} - ${createResponse.body}");
        throw Exception('Failed to create Drive file metadata: ${createResponse.body}');
      }

      final newFileId = jsonDecode(createResponse.body)['id'] as String;
      print("DEBUG: Metadata created. New file ID: $newFileId. Uploading content...");

      // Step 2: Patch content to the new file
      final uploadUrl = '$_driveUploadUrl/$newFileId?uploadType=media';
      final uploadResponse = await http.patch(
        Uri.parse(uploadUrl),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/octet-stream',
        },
        body: bytes,
      );

      if (uploadResponse.statusCode == 200) {
        print("DEBUG: Full upload successful for $newFileId.");
        return newFileId;
      } else {
        print("DEBUG ERROR: Media upload failed for $newFileId: ${uploadResponse.statusCode} - ${uploadResponse.body}");
        throw Exception('Failed to upload media content to Drive: ${uploadResponse.body}');
      }
    } catch (e, stack) {
      print("DEBUG ERROR: uploadDatabaseToDrive exception: $e");
      print(stack);
      rethrow;
    }
  }

  /// Finds or creates a folder with the given [folderName] and returns its ID.
  Future<String> getOrCreateFolder({
    required String accessToken,
    required String folderName,
  }) async {
    try {
      print("DEBUG: Searching for folder '$folderName'...");
      final searchUri = Uri.parse(
        '$_driveApiUrl?q=name=\'$folderName\' and mimeType=\'application/vnd.google-apps.folder\' and trashed=false&fields=files(id, name)',
      );

      final searchResponse = await http.get(
        searchUri,
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (searchResponse.statusCode == 200) {
        final data = jsonDecode(searchResponse.body);
        final List files = data['files'] ?? [];
        if (files.isNotEmpty) {
          final id = files.first['id'] as String;
          print("DEBUG: Found existing folder: $id");
          return id;
        }
      } else {
        print("DEBUG ERROR: Failed to search for folder: ${searchResponse.statusCode} - ${searchResponse.body}");
        throw Exception('Failed to search for folder: ${searchResponse.statusCode}');
      }

      print("DEBUG: Folder '$folderName' not found, creating new one...");
      final createUri = Uri.parse(_driveApiUrl);
      final createResponse = await http.post(
        createUri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode({
          'name': folderName,
          'mimeType': 'application/vnd.google-apps.folder',
        }),
      );

      if (createResponse.statusCode == 200 || createResponse.statusCode == 201) {
        final data = jsonDecode(createResponse.body);
        final id = data['id'] as String;
        print("DEBUG: Created folder: $id");
        return id;
      } else {
        print("DEBUG ERROR: Folder creation failed: ${createResponse.statusCode} - ${createResponse.body}");
        throw Exception('Failed to create backup folder: ${createResponse.statusCode} - ${createResponse.body}');
      }
    } catch (e, stack) {
      print("DEBUG ERROR: getOrCreateFolder exception: $e");
      print(stack);
      rethrow;
    }
  }
}
