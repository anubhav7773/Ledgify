import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/theme/color_tokens.dart';
import '../../../../core/theme/typography_tokens.dart';
import 'package:ledgify/features/ai_intake/data/repositories/ai_intake_repository.dart';
import 'package:ledgify/features/ai_intake/data/services/image_capture_service.dart';
import 'ai_invoice_review_screen.dart';

/// Screen for capturing or picking bill photos for Gemini 2.5 Flash Multimodal OCR.
/// Includes DPDP statutory consent prompt modal and document framing guides.
class DocumentScannerScreen extends StatefulWidget {
  final AiIntakeRepository? repository;
  final ImageCaptureService? captureService;
  final String? businessId;

  const DocumentScannerScreen({
    super.key,
    this.repository,
    this.captureService,
    this.businessId,
  });

  @override
  State<DocumentScannerScreen> createState() => _DocumentScannerScreenState();
}

class _DocumentScannerScreenState extends State<DocumentScannerScreen> {
  late final AiIntakeRepository _repository;
  late final ImageCaptureService _captureService;

  bool _isAnalyzing = false;
  Uint8List? _capturedImageBytes;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? AiIntakeRepository();
    _captureService = widget.captureService ?? ImageCaptureService();
  }

  Future<void> _handleCapture() async {
    final imageBytes = await _captureService.captureFromCamera();
    if (imageBytes != null) {
      _processImage(imageBytes);
    }
  }

  Future<void> _handleGalleryPick() async {
    final imageBytes = await _captureService.pickFromGallery();
    if (imageBytes != null) {
      _processImage(imageBytes);
    }
  }

  Future<void> _processImage(Uint8List bytes) async {
    setState(() {
      _isAnalyzing = true;
      _capturedImageBytes = bytes;
    });

    try {
      final payload = await _repository.processBillImage(
        bytes,
        businessId: widget.businessId ?? '00000000-0000-0000-0000-000000000000',
      );

      if (mounted) {
        setState(() => _isAnalyzing = false);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AiInvoiceReviewScreen(
              extractedPayload: payload,
              imageBytes: bytes,
              businessId: widget.businessId,
            ),
          ),
        );
      }
    } on DpdpConsentRequiredFailure {
      setState(() => _isAnalyzing = false);
      if (mounted) {
        _showDpdpConsentDialog(bytes);
      }
    } catch (e) {
      setState(() => _isAnalyzing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('OCR analysis error: $e'),
            backgroundColor: LedgifyColors.creditRed,
          ),
        );
      }
    }
  }

  Future<void> _showDpdpConsentDialog(Uint8List pendingBytes) async {
    final agreed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('DPDP Act Consent / डेटा सहमति'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Under the Digital Personal Data Protection Act (DPDP), Ledgify requires your explicit consent to process financial documents using Google Gemini AI for automated ledger classification.',
              style: TextStyle(fontSize: 13),
            ),
            SizedBox(height: 12),
            Text(
              '• Data processed: Invoice details, GSTIN, amounts\n• Purpose: Double-entry accounting automation\n• Retention: Stored securely in your isolated company vault',
              style: TextStyle(fontSize: 12, color: LedgifyColors.secondarySlate),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Decline / अस्वीकार करें'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: LedgifyColors.primaryBlue,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Agree & Continue / सहमत हैं'),
          ),
        ],
      ),
    );

    if (agreed == true) {
      await _repository.recordDpdpConsent(
        businessId: widget.businessId ?? '00000000-0000-0000-0000-000000000000',
      );
      _processImage(pendingBytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan Bill / बिल स्कैन करें', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: _isAnalyzing
            ? _buildAnalyzingState()
            : Column(
                children: [
                  // Viewfinder Frame Overlay
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
                            ),
                          ),
                          // Corner brackets
                          Positioned(
                            top: 0,
                            left: 0,
                            child: _buildCorner(isTop: true, isLeft: true),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: _buildCorner(isTop: true, isLeft: false),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            child: _buildCorner(isTop: false, isLeft: true),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: _buildCorner(isTop: false, isLeft: false),
                          ),

                          const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.document_scanner, size: 64, color: Colors.white54),
                              SizedBox(height: 16),
                              Text(
                                'Align bill/invoice within the frame\nबिल को फ्रेम में सीधा रखें',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white70, fontSize: 14),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Controls Container
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    decoration: const BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        // Pick from Gallery
                        IconButton(
                          iconSize: 32,
                          icon: const Icon(Icons.photo_library_outlined, color: Colors.white),
                          tooltip: 'Gallery / गैलरी',
                          onPressed: _handleGalleryPick,
                        ),

                        // Shutter Button (Camera Capture)
                        InkWell(
                          onTap: _handleCapture,
                          borderRadius: BorderRadius.circular(40),
                          child: Container(
                            width: 72,
                            height: 72,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                            ),
                            child: Container(
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: LedgifyColors.primaryBlue,
                              ),
                              child: const Icon(Icons.camera_alt, color: Colors.white, size: 30),
                            ),
                          ),
                        ),

                        // Document Guide Toggle
                        IconButton(
                          iconSize: 32,
                          icon: const Icon(Icons.help_outline, color: Colors.white),
                          tooltip: 'Instructions',
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Ensure good lighting and avoid shadows on bill.')),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildAnalyzingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 64,
            height: 64,
            child: CircularProgressIndicator(strokeWidth: 3, color: LedgifyColors.primaryBlue),
          ),
          const SizedBox(height: 24),
          const Text(
            'Analyzing bill via Gemini AI...\nबिल का विश्लेषण किया जा रहा है...',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Extracting GSTIN, HSN, Tax splits & Ledgers',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildCorner({required bool isTop, required bool isLeft}) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        border: Border(
          top: isTop ? const BorderSide(color: LedgifyColors.primaryBlue, width: 4) : BorderSide.none,
          bottom: !isTop ? const BorderSide(color: LedgifyColors.primaryBlue, width: 4) : BorderSide.none,
          left: isLeft ? const BorderSide(color: LedgifyColors.primaryBlue, width: 4) : BorderSide.none,
          right: !isLeft ? const BorderSide(color: LedgifyColors.primaryBlue, width: 4) : BorderSide.none,
        ),
      ),
    );
  }
}
