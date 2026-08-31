import 'dart:convert';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

/// Service managing device camera capture, document gallery picking, and image compression.
class ImageCaptureService {
  final ImagePicker _picker;

  ImageCaptureService({ImagePicker? picker})
      : _picker = picker ?? ImagePicker();

  /// Captures an invoice photo using device camera with high-resolution constraints
  Future<Uint8List?> captureFromCamera() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 80,
    );

    if (photo == null) return null;
    return await photo.readAsBytes();
  }

  /// Picks an invoice image or PDF from device storage / gallery
  Future<Uint8List?> pickFromGallery() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return null;
    return result.files.first.bytes;
  }

  /// Encodes raw image byte array into Base64 format for Gemini API transmission
  static String encodeToBase64(Uint8List bytes) {
    return base64Encode(bytes);
  }
}
