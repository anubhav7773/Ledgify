import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/theme/color_tokens.dart';
import '../../../../core/theme/typography_tokens.dart';
import '../../../masters/data/repositories/account_repository.dart';
import '../../../masters/domain/models/account_model.dart';
import '../../../vouchers/data/repositories/voucher_repository.dart';
import '../../../vouchers/domain/models/voucher_line_item_model.dart';
import '../../../vouchers/domain/models/voucher_model.dart';
import '../data/repositories/voice_intake_repository.dart';
import '../data/services/audio_recording_service.dart';
import '../widgets/audio_waveform_visualizer.dart';

/// Screen for recording code-switched Hindi/Hinglish Voice Vouchers and auto-generating double-entry postings.
/// Adheres strictly to docs/06_gemini_ai_multimodal_pipeline.md and docs/10_ui_ux_design_system_tokens.md.
class VoiceVoucherScreen extends StatefulWidget {
  final VoiceIntakeRepository? voiceRepository;
  final AudioRecordingService? recordingService;
  final VoucherRepository? voucherRepository;
  final AccountRepository? accountRepository;
  final String? businessId;

  const VoiceVoucherScreen({
    super.key,
    this.voiceRepository,
    this.recordingService,
    this.voucherRepository,
    this.accountRepository,
    this.businessId,
  });

  @override
  State<VoiceVoucherScreen> createState() => _VoiceVoucherScreenState();
}

class _VoiceVoucherScreenState extends State<VoiceVoucherScreen> {
  late final VoiceIntakeRepository _voiceRepository;
  late final AudioRecordingService _recordingService;
  late final VoucherRepository _voucherRepository;
  late final AccountRepository _accountRepository;

  bool _isRecording = false;
  bool _isProcessing = false;
  bool _isCommitting = false;
  int _recordDurationSeconds = 0;
  Timer? _timer;

  Map<String, dynamic>? _extractedVoiceVoucher;
  String? _selectedDebitAccountId;
  String? _selectedCreditAccountId;
  String? _selectedVoucherTypeId;

  List<AccountModel> _availableAccounts = [];

  @override
  void initState() {
    super.initState();
    _voiceRepository = widget.voiceRepository ?? VoiceIntakeRepository();
    _recordingService = widget.recordingService ?? AudioRecordingService();
    _voucherRepository = widget.voucherRepository ?? VoucherRepository();
    _accountRepository = widget.accountRepository ?? AccountRepository();
    _loadAccounts();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recordingService.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    try {
      final accounts = await _accountRepository.fetchAccounts();
      if (mounted) {
        setState(() => _availableAccounts = accounts);
      }
    } catch (_) {}
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      _stopAndProcess();
    } else {
      _startRecording();
    }
  }

  Future<void> _startRecording() async {
    try {
      await _recordingService.startRecording();
      setState(() {
        _isRecording = true;
        _extractedVoiceVoucher = null;
        _recordDurationSeconds = 0;
      });

      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() => _recordDurationSeconds++);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start recording: $e'), backgroundColor: LedgifyColors.creditRed),
      );
    }
  }

  Future<void> _stopAndProcess() async {
    _timer?.cancel();
    final filePath = await _recordingService.stopRecording();
    setState(() {
      _isRecording = false;
      _isProcessing = true;
    });

    if (filePath == null) {
      setState(() => _isProcessing = false);
      return;
    }

    try {
      final result = await _voiceRepository.processVoiceNote(
        filePath,
        businessId: widget.businessId ?? '00000000-0000-0000-0000-000000000000',
      );

      if (mounted) {
        setState(() {
          _extractedVoiceVoucher = result;
          _isProcessing = false;
          _autoMapLedgers(result);
        });
      }
    } on DpdpConsentRequiredFailure {
      setState(() => _isProcessing = false);
      if (mounted) {
        _showDpdpConsentDialog(filePath);
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Voice parsing error: $e'), backgroundColor: LedgifyColors.creditRed),
        );
      }
    }
  }

  void _autoMapLedgers(Map<String, dynamic> parsed) async {
    final vType = parsed['voucher_type'] as String? ?? 'Payment';
    final pMode = parsed['payment_mode'] as String? ?? 'Cash';
    final party = (parsed['party_name'] as String? ?? '').toLowerCase();

    // Map voucher type ID
    final types = await _voucherRepository.fetchVoucherTypes();
    final matchedType = types.firstWhere(
      (t) => t.category.toLowerCase() == vType.toLowerCase(),
      orElse: () => types.first,
    );
    _selectedVoucherTypeId = matchedType.id;

    // Map payment/settlement ledger (Cash vs Bank)
    AccountModel? cashAccount = _availableAccounts.firstWhere(
      (a) => a.name.toLowerCase().contains('cash'),
      orElse: () => _availableAccounts.first,
    );
    AccountModel? bankAccount = _availableAccounts.firstWhere(
      (a) => a.name.toLowerCase().contains('bank'),
      orElse: () => _availableAccounts.first,
    );

    // Best effort party match
    AccountModel? matchedParty = _availableAccounts.firstWhere(
      (a) => a.name.toLowerCase().contains(party) || (a.alias?.toLowerCase().contains(party) ?? false),
      orElse: () => _availableAccounts.first,
    );

    setState(() {
      if (vType == 'Payment') {
        _selectedDebitAccountId = matchedParty.id;
        _selectedCreditAccountId = (pMode.contains('Bank') || pMode.contains('UPI')) ? bankAccount.id : cashAccount.id;
      } else if (vType == 'Receipt') {
        _selectedDebitAccountId = (pMode.contains('Bank') || pMode.contains('UPI')) ? bankAccount.id : cashAccount.id;
        _selectedCreditAccountId = matchedParty.id;
      } else if (vType == 'Sales') {
        _selectedDebitAccountId = matchedParty.id;
        final salesAcc = _availableAccounts.firstWhere((a) => a.groupName == 'Sales Accounts', orElse: () => _availableAccounts.first);
        _selectedCreditAccountId = salesAcc.id;
      } else {
        _selectedDebitAccountId = matchedParty.id;
        _selectedCreditAccountId = cashAccount.id;
      }
    });
  }

  Future<void> _showDpdpConsentDialog(String filePath) async {
    final agreed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('DPDP Voice Consent / आवाज डेटा सहमति'),
        content: const Text(
          'Under the DPDP Act, Ledgify requires your explicit consent to process your spoken voice recordings using Google Gemini AI for automated accounting entries.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Decline')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: LedgifyColors.primaryBlue,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Agree & Process'),
          ),
        ],
      ),
    );

    if (agreed == true) {
      await _voiceRepository.recordVoiceConsent(
        businessId: widget.businessId ?? '00000000-0000-0000-0000-000000000000',
      );
      final result = await _voiceRepository.processVoiceNote(
        filePath,
        businessId: widget.businessId ?? '00000000-0000-0000-0000-000000000000',
      );
      if (mounted) {
        setState(() {
          _extractedVoiceVoucher = result;
          _autoMapLedgers(result);
        });
      }
    }
  }

  Future<void> _commitVoiceVoucher() async {
    if (_extractedVoiceVoucher == null || _selectedDebitAccountId == null || _selectedCreditAccountId == null) {
      return;
    }

    setState(() => _isCommitting = true);

    try {
      final double totalAmt = (_extractedVoiceVoucher!['total_amount'] as num).toDouble();
      final String partyName = _extractedVoiceVoucher!['party_name'] as String;
      final String narration = _extractedVoiceVoucher!['narration'] as String;

      final voucher = VoucherModel(
        id: '',
        businessId: widget.businessId ?? '00000000-0000-0000-0000-000000000000',
        voucherTypeId: _selectedVoucherTypeId ?? '',
        voucherNumber: 'VOICE-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        voucherDate: DateTime.now(),
        narration: narration,
        aiConfidenceScore: (_extractedVoiceVoucher!['confidence_score'] as num?)?.toDouble() ?? 0.95,
        lineItems: [
          VoucherLineItemModel(
            id: '',
            businessId: widget.businessId ?? '',
            voucherId: '',
            accountId: _selectedDebitAccountId!,
            entryType: 'Dr',
            amount: totalAmt,
            itemDescription: 'Voice Entry: $partyName',
          ),
          VoucherLineItemModel(
            id: '',
            businessId: widget.businessId ?? '',
            voucherId: '',
            accountId: _selectedCreditAccountId!,
            entryType: 'Cr',
            amount: totalAmt,
            itemDescription: 'Settlement for $partyName',
          ),
        ],
      );

      await _voucherRepository.createVoucher(voucher);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Voice Voucher posted successfully! / वाउचर दर्ज हो गया!'),
            backgroundColor: LedgifyColors.debitGreen,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post voucher: $e'), backgroundColor: LedgifyColors.creditRed),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCommitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Voucher / आवाज से वाउचर', style: LedgifyTypography.cardHeader),
        backgroundColor: LedgifyColors.surfaceLight,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(LedgifyColors.standardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Prompt Suggestions Header Banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: LedgifyColors.primaryContainer.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: LedgifyColors.primaryBlue.withOpacity(0.3)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Speak naturally in Hindi or English / बोलकर बताएं:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    SizedBox(height: 6),
                    Text('• "शर्मा जी को ₹2,500 नकद भुगतान किया"', style: TextStyle(fontSize: 13, color: LedgifyColors.secondarySlate)),
                    Text('• "Ramesh se 12,000 ka payment aaya phonepe pe"', style: TextStyle(fontSize: 13, color: LedgifyColors.secondarySlate)),
                    Text('• "Gupta Traders ko 10 peti tel becha"', style: TextStyle(fontSize: 13, color: LedgifyColors.secondarySlate)),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Audio Waveform Equalizer
              AudioWaveformVisualizer(
                amplitudeStream: _recordingService.amplitudeStream,
                isRecording: _isRecording,
              ),
              const SizedBox(height: 12),

              // Recording Status & Timer
              Center(
                child: Text(
                  _isRecording
                      ? 'Recording... 00:${_recordDurationSeconds.toString().padLeft(2, '0')} / रिकॉर्डिंग जारी...'
                      : _isProcessing
                          ? 'Analyzing voice with Gemini 2.5 Flash... / विश्लेषण जारी...'
                          : 'Tap microphone to speak / बोलने के लिए माइक दबाएं',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _isRecording ? LedgifyColors.creditRed : LedgifyColors.secondarySlate,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Central Microphone Button (72x72 dp)
              Center(
                child: InkWell(
                  onTap: _isProcessing ? null : _toggleRecording,
                  borderRadius: BorderRadius.circular(44),
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isRecording ? LedgifyColors.creditRed : LedgifyColors.primaryBlue,
                      boxShadow: [
                        BoxShadow(
                          color: (_isRecording ? LedgifyColors.creditRed : LedgifyColors.primaryBlue).withOpacity(0.35),
                          blurRadius: 16,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Icon(
                      _isRecording ? Icons.stop : Icons.mic,
                      color: Colors.white,
                      size: 38,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Extracted AI Confirmation Review Card
              if (_extractedVoiceVoucher != null) ...[
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(LedgifyColors.cardBorderRadius),
                    side: const BorderSide(color: LedgifyColors.primaryBlue, width: 1.2),
                  ),
                  color: LedgifyColors.surfaceCard,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: LedgifyColors.primaryContainer,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${_extractedVoiceVoucher!['voucher_type']} (${_extractedVoiceVoucher!['payment_mode']})',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: LedgifyColors.primaryBlue),
                              ),
                            ),
                            Text(
                              '₹${(_extractedVoiceVoucher!['total_amount'] as num).toStringAsFixed(2)}',
                              style: LedgifyTypography.financialAmount.copyWith(
                                color: LedgifyColors.debitGreen,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 20),

                        Text('Party / पक्ष: ${_extractedVoiceVoucher!['party_name']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        const SizedBox(height: 4),
                        Text('Narration: ${_extractedVoiceVoucher!['narration']}', style: const TextStyle(fontSize: 12, color: LedgifyColors.secondarySlate)),
                        const SizedBox(height: 16),

                        // Debit / Credit Ledger Mapping Selectors
                        DropdownButtonFormField<String>(
                          value: _selectedDebitAccountId,
                          decoration: const InputDecoration(
                            labelText: 'Debit Ledger (नाम खाता) *',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: _availableAccounts.map((a) {
                            return DropdownMenuItem(value: a.id, child: Text('${a.name} (${a.groupName})'));
                          }).toList(),
                          onChanged: (val) => setState(() => _selectedDebitAccountId = val),
                        ),
                        const SizedBox(height: 12),

                        DropdownButtonFormField<String>(
                          value: _selectedCreditAccountId,
                          decoration: const InputDecoration(
                            labelText: 'Credit Ledger (जमा खाता) *',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: _availableAccounts.map((a) {
                            return DropdownMenuItem(value: a.id, child: Text('${a.name} (${a.groupName})'));
                          }).toList(),
                          onChanged: (val) => setState(() => _selectedCreditAccountId = val),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Suggestion Repair Chips
                Wrap(
                  spacing: 8,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.currency_rupee, size: 14),
                      label: const Text('Edit Amount / राशि बदलें'),
                      onPressed: () {
                        // Quick amount adjustment helper
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.swap_horiz, size: 14),
                      label: const Text('Switch Dr/Cr / खाता बदलें'),
                      onPressed: () {
                        setState(() {
                          final temp = _selectedDebitAccountId;
                          _selectedDebitAccountId = _selectedCreditAccountId;
                          _selectedCreditAccountId = temp;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Post Button (48dp Touch Target)
                SizedBox(
                  height: LedgifyColors.minTouchTargetSize,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: LedgifyColors.primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: _isCommitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: Text(
                      _isCommitting ? 'Posting Transaction...' : 'Confirm & Post Voucher / वाउचर दर्ज करें',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    onPressed: _isCommitting ? null : _commitVoiceVoucher,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
