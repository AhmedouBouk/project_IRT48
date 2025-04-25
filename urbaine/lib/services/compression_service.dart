// compression_service.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';

class CompressionService {
  static const int highQuality = 85; // High quality compression
  static const int mediumQuality = 70; // Medium quality compression
  static const int lowQuality = 50; // Low quality compression for low bandwidth

  /// Compresses an image file and returns the path to the compressed file
  /// Quality is determined by the connection type
  static Future<String> compressImage(String imagePath, {int? quality}) async {
    if (imagePath.isEmpty || !await File(imagePath).exists()) {
      throw Exception('Image file not found: $imagePath');
    }

    try {
      final File imageFile = File(imagePath);
      final Directory tempDir = await getTemporaryDirectory();
      final String targetPath = path.join(
        tempDir.path, 
        'compressed_${const Uuid().v4()}${path.extension(imagePath)}'
      );

      // Default to medium quality if not specified
      final int compressionQuality = quality ?? mediumQuality;
      
      // Get original file size for logging
      final int originalSize = await imageFile.length();
      
      // Compress the image
      final Uint8List? compressedData = await FlutterImageCompress.compressWithFile(
        imagePath,
        quality: compressionQuality,
        minWidth: 1024, // Reasonable max width for mobile uploads
        minHeight: 1024, // Preserve aspect ratio
      );
      
      if (compressedData == null) {
        throw Exception('Failed to compress image');
      }
      
      // Write compressed data to file
      final File result = File(targetPath);
      await result.writeAsBytes(compressedData);
      
      // Get compressed file size for logging
      final int compressedSize = await result.length();
      final double compressionRatio = originalSize / compressedSize;
      
      print('Image compressed: $originalSize bytes → $compressedSize bytes (${compressionRatio.toStringAsFixed(2)}x reduction)');
      
      return result.path;
    } catch (e) {
      print('Error compressing image: $e');
      // Return original file path if compression fails
      return imagePath;
    }
  }

  /// Determines the optimal compression quality based on connection type
  static Future<int> getOptimalQuality(String connectionType) async {
    switch (connectionType.toLowerCase()) {
      case 'wifi':
        return highQuality;
      case 'mobile':
      case 'cellular':
        return mediumQuality;
      case 'slow':
      case '2g':
      case '3g':
        return lowQuality;
      default:
        return mediumQuality;
    }
  }
}
