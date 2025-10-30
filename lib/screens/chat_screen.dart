import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:dropdown_search/dropdown_search.dart';
import '../services/pverify_service.dart';
import '../models/immunotherapy_options.dart';
import '../widgets/immunotherapy_options_widget.dart';

// Payer model class
class Payer {
  final String code;
  final String name;
  final String type;
  final bool eligibility;
  final bool claimStatus;

  const Payer({
    required this.code,
    required this.name,
    required this.type,
    required this.eligibility,
    required this.claimStatus,
  });

  @override
  String toString() => name;
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatMessage {
  String text;
  final bool isBot;
  List<Map<String, dynamic>>? citations;
  List<String>? followUps;
  bool streaming;
  Widget? customWidget; // Add support for custom widgets
  Map<String, double>? costBreakdown; // For treatment cost analysis
  _ChatMessage({
    required this.text,
    required this.isBot,
    this.citations,
    this.followUps,
    this.streaming = false,
    this.customWidget,
    this.costBreakdown,
  });
}

class _ChatScreenState extends State<ChatScreen> {
  static const String _baseUrl = 'https://stage-fortifyguardian-api-bbf0cxa5bjc6bjay.eastus-01.azurewebsites.net';

  final List<_ChatMessage> _messages = [
    _ChatMessage(
      text: "Hi Sarah! I'm here to make things easier for you.",
      isBot: true,
    ),
    _ChatMessage(
      text: "To get started with which expert do you like to talk today?",
      isBot: true,
    ),
  ];
  
  bool _showInput = false;
  bool _showInsuranceForm = false;
  String? _selectedExpert;
  final _controller = TextEditingController();
  final _scrollCtrl = ScrollController();

  // Insurance form controllers
  final _formKey = GlobalKey<FormState>();
  final _payerController = TextEditingController();
  final _memberIdController = TextEditingController();
  final _dobController = TextEditingController();
  DateTime? _dob;
  Payer? _selectedPayer;
  bool _isLoadingInsurance = false;

  // Store insurance data after eligibility check
  Map<String, dynamic>? _insuranceData;

  StreamSubscription<String>? _streamSub;
  final _client = http.Client();

  // Payer data list (same as in new_insurance_check_screen.dart)
  static const List<Payer> _payers = [
    // Eligible payers first (sorted alphabetically)
    Payer(code: '00283', name: 'AARP (A United HealthCare Insurance Company)', type: 'EDI', eligibility: true, claimStatus: true),
    Payer(code: '00344', name: 'Absolute Total Care', type: 'EDI', eligibility: true, claimStatus: true),
    Payer(code: 'BO10061', name: 'ACCESS IPA BO', type: 'Non-EDI', eligibility: true, claimStatus: false),
    Payer(code: '01410', name: 'Acclaim Inc', type: 'EDI', eligibility: true, claimStatus: false),
    Payer(code: '00736', name: 'ACE Property and Casualty Medicare Supplement', type: 'EDI', eligibility: true, claimStatus: false),
    Payer(code: '000947', name: 'ACS Benefit Services', type: 'EDI', eligibility: true, claimStatus: true),
    Payer(code: 'BO00013', name: 'Adavanced Primary Care Network BO', type: 'Non-EDI', eligibility: true, claimStatus: false),
    Payer(code: 'BO10002', name: 'ADOC aka ADVANCED DOCTORS OF ORANGE COUNTY BO', type: 'Non-EDI', eligibility: true, claimStatus: false),
    Payer(code: 'BO10049', name: 'ADVANCED MEDICAL DOCTORS OF CA BO', type: 'Non-EDI', eligibility: true, claimStatus: false),
    Payer(code: '06024', name: 'Administrative Concepts', type: 'EDI', eligibility: true, claimStatus: false),
    Payer(code: '00468', name: 'Administrative Services Inc', type: 'EDI', eligibility: true, claimStatus: false),
    Payer(code: '00345', name: 'Advantage by Bridgeway Health Solutions', type: 'EDI', eligibility: true, claimStatus: true),
    Payer(code: '00346', name: 'Advantage by Buckeye Community Health Plan', type: 'EDI', eligibility: true, claimStatus: true),
    Payer(code: '00347', name: 'Advantage by Managed Health Services', type: 'EDI', eligibility: true, claimStatus: true),
    Payer(code: '00348', name: 'Advantage by Superior HealthPlan', type: 'EDI', eligibility: true, claimStatus: true),
    Payer(code: 'BO10014', name: 'ADVANTAGE CARE IPA BO', type: 'Non-EDI', eligibility: true, claimStatus: false),
    Payer(code: '00738', name: 'Advantage Health Solutions', type: 'EDI', eligibility: true, claimStatus: false),
    Payer(code: '00292', name: 'ADVANTRA (TEXAS, NEW MEXICO, ARIZONA ONLY)', type: 'EDI', eligibility: true, claimStatus: false),
    Payer(code: 'BO00123', name: 'Advantica BO', type: 'Non-EDI', eligibility: true, claimStatus: false),
    Payer(code: '00192', name: 'United Healthcare', type: 'EDI', eligibility: true, claimStatus: true),
    
    // Non-eligible payers (sorted alphabetically)
    Payer(code: 'DE001', name: 'AARP Dental', type: 'EDI', eligibility: false, claimStatus: false),
    Payer(code: 'DE0407', name: 'ACEC Health Plans (Salt Lake City, UT)', type: 'EDI', eligibility: false, claimStatus: false),
    Payer(code: 'DE0408', name: 'Administrative Services Only (ASO)', type: 'EDI', eligibility: false, claimStatus: false),
    Payer(code: 'DE0409', name: 'Advantage Dental', type: 'EDI', eligibility: false, claimStatus: false),
  ];

  @override
  void dispose() {
    _streamSub?.cancel();
    _client.close();
    _scrollCtrl.dispose();
    _controller.dispose();
    _payerController.dispose();
    _memberIdController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  void _handleExpertSelection(String expertType) {
    setState(() {
      _selectedExpert = expertType;
      
      if (expertType == "Finance Expert") {
        _messages.add(_ChatMessage(
          text: "Hi Sarah! I'm here to help you with all your financial questions about your allergy immunotherapy treatment. How can I assist you today?",
          isBot: true,
        ));
        _messages.add(_ChatMessage(
          text: "Here are some quick action you can take:",
          isBot: true,
          followUps: ["Check Insurance Coverage", "Calculate Treatment Cost", "Financial Assessment"],
        ));
      } else {
        _messages.add(_ChatMessage(
          text: "Great! You've selected $expertType. How can I help you today?",
          isBot: true,
        ));
      }
      
      _showInput = true;
    });
    _autoScroll();
  }

  void _handleFollowUpAction(String action) {
    setState(() {
      _messages.add(_ChatMessage(text: action, isBot: false));
    });
    
    if (action == "Check Insurance Coverage") {
      setState(() {
        _messages.add(_ChatMessage(
          text: "I'll help you check your insurance coverage. Please provide the following information:",
          isBot: true,
        ));
        _showInsuranceForm = true;
        _showInput = false;
      });
    } else if (action == "Calculate Treatment Cost") {
      setState(() {
        _messages.add(_ChatMessage(
          text: "Here's a comprehensive overview of your immunotherapy treatment options:",
          isBot: true,
        ));
        _messages.add(_ChatMessage(
          text: "",
          isBot: true,
          customWidget: ImmunotherapyOptionsWidget(
            onCheckInsurance: () => _handleFollowUpAction("Check Insurance Coverage"),
          ),
        ));
      });
    } else if (action == "Financial Assessment") {
      setState(() {
        _messages.add(_ChatMessage(
          text: "I'll provide you with a comprehensive financial assessment for your allergy immunotherapy treatment. This will include cost breakdown, payment options, potential savings, and financial planning recommendations.",
          isBot: true,
        ));
      });
    } else if (action == "Analyze Treatment Cost Coverage") {
      setState(() {
        _messages.add(_ChatMessage(
          text: "Let me analyze how your insurance coverage applies to different treatment costs. Please select a treatment option to analyze:",
          isBot: true,
          followUps: [
            "Allergy Shots - \$2,500 total cost",
            "Allergy Drops - \$1,800 total cost", 
            "Custom treatment cost"
          ],
        ));
      });
    } else if (action.startsWith("Allergy Shots - ") || action.startsWith("Allergy Drops - ")) {
      // Extract treatment cost and analyze
      final costString = action.split(" - ")[1].replaceAll("\$", "").replaceAll(" total cost", "").replaceAll(",", "");
      final treatmentCost = double.tryParse(costString) ?? 2500.0;
      
      // Extract remaining deductible and out-of-pocket from stored insurance data
      final financials = _insuranceData?['financials'] ?? {};
      final remainingDeductible = double.tryParse(
        financials['individualDeductibleRemainingInNet']?.toString().replaceAll(RegExp(r'[^\d.]'), '') ?? '0'
      ) ?? 250.0; // Default if not available
      
      final remainingOutOfPocket = double.tryParse(
        financials['individualOOPRemainingInNet']?.toString().replaceAll(RegExp(r'[^\d.]'), '') ?? '0'
      ) ?? 500.0; // Default if not available
      
      _analyzeInsuranceCost(
        treatmentCost: treatmentCost,
        remainingDeductible: remainingDeductible,
        remainingOutOfPocket: remainingOutOfPocket,
      );
    } else {
      // For other actions, use the regular streaming response
      _startStreamingAnswer(action);
    }
    
    _autoScroll();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(_ChatMessage(text: text, isBot: false));
      _controller.clear();
    });
    _autoScroll();

    // Start streaming bot answer
    await _startStreamingAnswer(text);
  }

  Future<void> _startStreamingAnswer(String prompt) async {
    await _streamSub?.cancel();

    setState(() {
      _messages.add(_ChatMessage(text: "", isBot: true, streaming: true));
    });
    final int botIndex = _messages.length - 1;
    _autoScroll();

    final req = http.Request('POST', Uri.parse('$_baseUrl/chat/ask'))
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode({
        "message": prompt,
        "topK": 5,
        "stream": true,
      });

    final streamed = await _client.send(req);

    _streamSub = streamed.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      if (!line.startsWith('data:')) return;
      final data = line.substring(5).trim();
      if (data.isEmpty || data == '[DONE]') return;

      Map<String, dynamic> payload;
      try {
        payload = jsonDecode(data) as Map<String, dynamic>;
      } catch (_) {
        return;
      }

      final type = payload['type'];
      if (type == 'token') {
        final token = (payload['text'] ?? '') as String;
        if (token.isEmpty) return;
        setState(() {
          _messages[botIndex].text += token;
        });
        _autoScroll();
      } else if (type == 'final') {
        setState(() {
          _messages[botIndex].streaming = false;
          _messages[botIndex].citations =
              (payload['citations'] as List?)?.cast<Map<String, dynamic>>();
          _messages[botIndex].followUps =
              (payload['followUps'] as List?)?.cast<String>();
        });
        _autoScroll();
      } else if (type == 'error') {
        setState(() {
          _messages[botIndex].streaming = false;
          _messages[botIndex].text =
              _messages[botIndex].text.isEmpty ? 'Something went wrong.' : _messages[botIndex].text;
        });
      }
    }, onError: (_) {
      if (!mounted) return;
      setState(() {
        _messages[botIndex].streaming = false;
        if (_messages[botIndex].text.isEmpty) {
          _messages[botIndex].text = 'Network error. Please try again.';
        }
      });
    }, onDone: () {
      if (!mounted) return;
      setState(() {
        _messages[botIndex].streaming = false;
      });
    });
  }

  void _autoScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final initial = _dob ?? DateTime(now.year - 25, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        _dob = picked;
        _dobController.text =
            "${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}/${picked.year}";
      });
    }
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  String? _validatePayer(Payer? payer) {
    if (payer == null) return 'Please select a payer';
    if (!payer.eligibility) return 'Selected payer does not support eligibility checks';
    return null;
  }

  Future<void> _checkInsuranceEligibility() async {
    if (!_formKey.currentState!.validate()) return;
    
    final payerValidation = _validatePayer(_selectedPayer);
    if (payerValidation != null) {
      setState(() {
        _messages.add(_ChatMessage(
          text: payerValidation,
          isBot: true,
        ));
      });
      return;
    }

    setState(() {
      _isLoadingInsurance = true;
      _messages.add(_ChatMessage(
        text: "Checking your insurance eligibility...",
        isBot: true,
        streaming: true,
      ));
    });
    _autoScroll();

    try {
      final pverifyService = PVerifyService();
      final token = await pverifyService.getAccessToken();
      
      if (token == null) {
        throw Exception('Failed to get pVerify access token');
      }
      
      print('🔍 Checking eligibility with pVerify...');
      print('📋 Form Data:');
      print('  - Selected Payer: ${_selectedPayer?.name ?? "N/A"}');
      print('  - Payer Code: ${_selectedPayer?.code ?? "N/A"}');
      print('  - Member ID: ${_memberIdController.text.trim()}');
      print('  - DOB: ${_dobController.text.trim()}');
      
      final eligibilityData = await pverifyService.getEligibilitySummary(
        payerCode: _selectedPayer?.code,
        payerName: _selectedPayer?.name ?? _payerController.text.trim(),
        memberID: _memberIdController.text.trim(),
        dob: _dobController.text.trim(),
      );
      
      if (eligibilityData == null) {
        throw Exception('Failed to get eligibility data from pVerify');
      }

      // Check for error messages in the response
      final errorMessage = eligibilityData['APIResponseMessage'] as String?;
      final ediErrorMessage = eligibilityData['EDIErrorMessage'] as String?;
      
      if (errorMessage != null && errorMessage.contains('Error')) {
        print('❌ API Error Response:');
        print('  - Message: $errorMessage');
        print('  - EDI Message: $ediErrorMessage');
        print('  - Follow-up Action: ${eligibilityData['FollowUpAction']}');
        print('  - Possible Resolution: ${eligibilityData['PossibleResolution']}');
        
        setState(() {
          _isLoadingInsurance = false;
          _messages.removeLast(); // Remove loading message
          
          // Create user-friendly error message
          String userError = "❌ Unable to verify insurance coverage\n\n";
          
          if (errorMessage.contains('Invalid/Missing Subscriber/Insured ID')) {
            userError += "⚠️ Member ID Issue:\n";
            userError += "The Member ID you entered doesn't match the insurance payer's records.\n\n";
            userError += "📋 Please check:\n";
            userError += "• Member ID format (including any letters/prefixes)\n";
            userError += "• Correct insurance payer selected\n";
            userError += "• Member ID matches your insurance card exactly\n\n";
            userError += "💡 Tip: Member IDs are case-sensitive and may include letters.";
          } else {
            userError += "Error: $errorMessage\n\n";
            userError += "Follow-up Action: ${eligibilityData['FollowUpAction'] ?? 'Please verify your information'}\n";
          }
          
          _messages.add(_ChatMessage(
            text: userError,
            isBot: true,
            followUps: [
              "Try again with different Member ID",
              "Contact support"
            ],
          ));
        });
        return;
      }

      final processedData = _processEligibilityResponse(eligibilityData);
      
      setState(() {
        _isLoadingInsurance = false;
        _messages.removeLast(); // Remove loading message
        _showInsuranceForm = false;
        _showInput = true;
        
        // Store insurance data for later use
        _insuranceData = processedData;
        
        // Add success message with insurance details
        final planCoverage = processedData['planCoverage'] ?? {};
        final financials = processedData['financials'] ?? {};
        
        String statusMessage = "✅ Insurance Coverage Status:\n\n";
        statusMessage += "Plan: ${planCoverage['planName'] ?? 'Not available'}\n";
        statusMessage += "Status: ${planCoverage['status'] ?? 'Unknown'}\n\n";
        
        if (financials['individualDeductibleInNet'] != null) {
          statusMessage += "💰 Deductible (In-Network):\n";
          statusMessage += "Individual: ${financials['individualDeductibleInNet']}\n";
          statusMessage += "Remaining: ${financials['individualDeductibleRemainingInNet'] ?? '0'}\n\n";
        }
        
        if (financials['individualOOPInNet'] != null) {
          statusMessage += "🎯 Out-of-Pocket Maximum:\n";
          statusMessage += "Individual: ${financials['individualOOPInNet']}\n";
          statusMessage += "Remaining: ${financials['individualOOPRemainingInNet'] ?? '0'}\n\n";
        }
        
        statusMessage += "Is there anything specific about your coverage you'd like to know more about?";
        
        _messages.add(_ChatMessage(
          text: statusMessage,
          isBot: true,
          followUps: [
            "Analyze Treatment Cost Coverage",
            "What treatments are covered?",
            "How to maximize my benefits?"
          ],
        ));
      });
      
    } catch (e) {
      print('❌ Exception during eligibility check: $e');
      setState(() {
        _isLoadingInsurance = false;
        _messages.removeLast(); // Remove loading message
        _messages.add(_ChatMessage(
          text: "Sorry, I couldn't retrieve your insurance information at the moment. Error: ${e.toString()}",
          isBot: true,
        ));
      });
    }
    
    _autoScroll();
  }

  Map<String, dynamic> _processEligibilityResponse(Map<String, dynamic> apiResponse) {
    try {
      final planCoverageSummary = apiResponse['PlanCoverageSummary'] ?? {};
      final deductibleOOPSummary = apiResponse['HBPC_Deductible_OOP_Summary'] ?? {};
      
      return {
        "planCoverage": {
          "status": planCoverageSummary['Status']?.toString() ?? 'Unknown',
          "planName": planCoverageSummary['PlanName']?.toString() ?? 'Plan name not available',
        },
        "financials": {
          "individualDeductibleInNet": deductibleOOPSummary['IndividualDeductibleInNet']?['Value']?.toString(),
          "individualDeductibleRemainingInNet": deductibleOOPSummary['IndividualDeductibleRemainingInNet']?['Value']?.toString(),
          "individualOOPInNet": deductibleOOPSummary['IndividualOOP_InNet']?['Value']?.toString(),
          "individualOOPRemainingInNet": deductibleOOPSummary['IndividualOOPRemainingInNet']?['Value']?.toString(),
        },
      };
    } catch (e) {
      return {
        "planCoverage": {},
        "financials": {},
      };
    }
  }

  Future<void> _analyzeInsuranceCost({
    required double treatmentCost,
    required double remainingDeductible,
    required double remainingOutOfPocket,
  }) async {
    setState(() {
      _messages.add(_ChatMessage(
        text: "Analyzing your insurance coverage for this treatment cost...",
        isBot: true,
        streaming: true,
      ));
    });
    _autoScroll();

    try {
      final req = http.Request('POST', Uri.parse('$_baseUrl/chat/insurance-analysis'))
        ..headers['Content-Type'] = 'application/json'
        ..body = jsonEncode({
          "treatmentCost": treatmentCost,
          "remainingDeductible": remainingDeductible,
          "remainingOutOfPocket": remainingOutOfPocket,
          "stream": true,
        });

      final streamed = await _client.send(req);
      final int botIndex = _messages.length - 1;

      await _streamSub?.cancel();

      String fullResponse = "";

      _streamSub = streamed.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        if (!line.startsWith('data:')) return;
        final data = line.substring(5).trim();
        if (data.isEmpty || data == '[DONE]') return;

        Map<String, dynamic> payload;
        try {
          payload = jsonDecode(data) as Map<String, dynamic>;
        } catch (_) {
          return;
        }

        final type = payload['type'];
        if (type == 'token') {
          final token = (payload['text'] ?? '') as String;
          if (token.isEmpty) return;
          fullResponse += token;
          setState(() {
            if (_messages[botIndex].text == "Analyzing your insurance coverage for this treatment cost...") {
              _messages[botIndex].text = token;
            } else {
              _messages[botIndex].text += token;
            }
          });
          _autoScroll();
        } else if (type == 'final') {
          // Extract cost breakdown from the response
          final costBreakdown = _extractCostBreakdownFromResponse(fullResponse, treatmentCost, remainingDeductible, remainingOutOfPocket);
          
          setState(() {
            _messages[botIndex].streaming = false;
            _messages[botIndex].costBreakdown = costBreakdown;
            _messages[botIndex].followUps =
                (payload['followUps'] as List?)?.cast<String>();
            // Replace text message with custom widget
            _messages[botIndex].customWidget = _buildTreatmentAnalysisWidget(
              fullResponse,
              costBreakdown,
              remainingDeductible,
              remainingOutOfPocket,
            );
            _messages[botIndex].text = ""; // Clear text since we're using widget
          });
          _autoScroll();
        }
      }, onError: (_) {
        if (!mounted) return;
        setState(() {
          _messages[botIndex].streaming = false;
          if (_messages[botIndex].text.contains("Analyzing your insurance coverage")) {
            _messages[botIndex].text = 'Unable to analyze insurance coverage at the moment. Please try again.';
          }
        });
      }, onDone: () {
        if (!mounted) return;
        setState(() {
          _messages[botIndex].streaming = false;
        });
      });

    } catch (e) {
      setState(() {
        _messages.removeLast(); // Remove loading message
        _messages.add(_ChatMessage(
          text: "Sorry, I couldn't analyze your insurance coverage at the moment. Please try again later.",
          isBot: true,
        ));
      });
    }
  }

  Map<String, double> _extractCostBreakdownFromResponse(String response, double treatmentCost, double remainingDeductible, double remainingOutOfPocket) {
    // Calculate cost breakdown using the same logic as new_insurance_check_screen.dart
    final patientPaysDeductible = treatmentCost <= remainingDeductible ? treatmentCost : remainingDeductible;
    final remainingAfterDeductible = treatmentCost - patientPaysDeductible;
    final patientPaysOOP = remainingAfterDeductible <= remainingOutOfPocket ? remainingAfterDeductible : remainingOutOfPocket;
    final insuranceCovers = treatmentCost - patientPaysDeductible - patientPaysOOP;

    return {
      'Patient Pays (Deductible)': patientPaysDeductible,
      'Patient Pays (Out-of-Pocket)': patientPaysOOP,
      'Insurance Covers': insuranceCovers,
    };
  }

  Widget _buildTreatmentAnalysisWidget(String analysisText, Map<String, double> costBreakdown, double remainingDeductible, double remainingOutOfPocket) {
    return Container(
      constraints: BoxConstraints(maxWidth: 500),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green[200]!, width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.check_circle, color: Colors.green[600], size: 24),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Analysis Complete',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        'Here\'s your personalized cost breakdown',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Insurance Status Card
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[100]!, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.account_balance_wallet, color: Colors.blue[700], size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Your Current Insurance Status',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                _buildInsuranceStatusRow(
                  'Remaining Deductible',
                  '\$${remainingDeductible.toStringAsFixed(0)}',
                  Colors.orange,
                  Icons.trending_down,
                ),
                const SizedBox(height: 8),
                
                _buildInsuranceStatusRow(
                  'Remaining Out-of-Pocket',
                  '\$${remainingOutOfPocket.toStringAsFixed(0)}',
                  Colors.purple,
                  Icons.payments_outlined,
                ),
              ],
            ),
          ),
          
          // Cost Breakdown Visual Card
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.pie_chart, color: Colors.blue[700], size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Treatment Cost Split',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildCostBreakdownChart(costBreakdown),
              ],
            ),
          ),
          
          // Summary Insight Card
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.insights, color: Colors.green[700], size: 22),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bottom Line',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.green[900],
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        _buildSimplifiedSummary(costBreakdown),
                        style: TextStyle(
                          color: Colors.green[900],
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCostBreakdownChart(Map<String, double> costBreakdown) {
    final total = costBreakdown.values.reduce((a, b) => a + b);
    if (total == 0) return SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cost Breakdown',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),
          
          if ((costBreakdown['Patient Pays (Deductible)'] ?? 0) > 0)
            _buildCostBar(
              'Patient Pays (Deductible)', 
              costBreakdown['Patient Pays (Deductible)']!, 
              total, 
              Colors.red[400]!
            ),
          
          if ((costBreakdown['Patient Pays (Out-of-Pocket)'] ?? 0) > 0)
            _buildCostBar(
              'Patient Pays (Out-of-Pocket)', 
              costBreakdown['Patient Pays (Out-of-Pocket)']!, 
              total, 
              Colors.orange[400]!
            ),
          
          if ((costBreakdown['Insurance Covers'] ?? 0) > 0)
            _buildCostBar(
              'Insurance Covers', 
              costBreakdown['Insurance Covers']!, 
              total, 
              Colors.green[400]!
            ),
          
          const SizedBox(height: 8),
          Divider(color: Colors.grey[300]),
          const SizedBox(height: 8),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Treatment Cost',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
              Text(
                '\$${total.toStringAsFixed(0)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCostBar(String label, double amount, double total, Color color) {
    final percentage = (amount / total * 100);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
              ),
              Text(
                '\$${amount.toStringAsFixed(0)} (${percentage.toStringAsFixed(0)}%)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percentage / 100,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _buildSimplifiedSummary(Map<String, double> costBreakdown) {
    final patientDeductible = costBreakdown['Patient Pays (Deductible)'] ?? 0;
    final patientOOP = costBreakdown['Patient Pays (Out-of-Pocket)'] ?? 0;
    final insuranceCovers = costBreakdown['Insurance Covers'] ?? 0;
    final totalPatientPays = patientDeductible + patientOOP;
    
    if (totalPatientPays == 0) {
      return 'Great news! Your insurance covers the full treatment cost.';
    } else if (insuranceCovers == 0) {
      return 'You will pay the full treatment cost of \$${totalPatientPays.toStringAsFixed(0)} towards your deductible.';
    } else {
      return 'You will pay \$${totalPatientPays.toStringAsFixed(0)} and your insurance covers \$${insuranceCovers.toStringAsFixed(0)}.';
    }
  }

  Widget _buildInsuranceStatusRow(String label, String amount, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF4A90E2),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.green[400],
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.smart_toy,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Your Health Assistant',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'AI-powered support',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (_, i) => _chatBubble(_messages[i]),
            ),
          ),
          if (!_showInput && !_showInsuranceForm && _selectedExpert == null)
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _expertButton("Finance Expert"),
                  const SizedBox(height: 12),
                  _expertButton("Health Expert"),
                  const SizedBox(height: 12),
                  _expertButton("General"),
                ],
              ),
            ),
          if (_showInsuranceForm)
            _buildInsuranceForm(),
          if (_showInput)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                    ),
                    child: ClipOval(
                      child: Image.network(
                        'https://via.placeholder.com/40x40/FF6B6B/FFFFFF?text=U',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.orange[300],
                            child: const Icon(Icons.person, color: Colors.white),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: "Search or ask a question...",
                        border: InputBorder.none,
                        hintStyle: TextStyle(color: Colors.grey),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.blue),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        height: 80,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey[200]!)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _bottomNavItem(Icons.home, "Home", true),
            _bottomNavItem(Icons.schedule, "Schedule", false),
            _bottomNavItem(Icons.bar_chart, "Tracking", false),
            _bottomNavItem(Icons.build, "Tools", false),
            _bottomNavItem(Icons.person, "Profile", false),
          ],
        ),
      ),
    );
  }

  Widget _bottomNavItem(IconData icon, String label, bool isActive) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          color: isActive ? Colors.blue : Colors.grey,
          size: 24,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.blue : Colors.grey,
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _chatBubble(_ChatMessage msg) {
    return Align(
      alignment: msg.isBot ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (msg.isBot) ...[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.green[400],
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.smart_toy,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Container(
                padding: msg.customWidget != null 
                  ? EdgeInsets.zero 
                  : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: msg.customWidget != null 
                    ? Colors.transparent 
                    : (msg.isBot ? Colors.grey[100] : Colors.blue[50]),
                  borderRadius: msg.customWidget != null 
                    ? null 
                    : BorderRadius.circular(12),
                ),
                child: msg.customWidget ?? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (msg.isBot)
                      Text(
                        "Just Now",
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 11,
                        ),
                      ),
                    if (msg.text.isNotEmpty)
                      Text(
                        msg.text,
                        style: const TextStyle(fontSize: 14),
                      ),
                    if (msg.streaming) ...[
                      const SizedBox(height: 8),
                      const _TypingDots(),
                    ],
                    if ((msg.citations?.isNotEmpty ?? false)) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: msg.citations!
                            .map((c) => Chip(
                                  label: Text(c['title'] ?? c['id'] ?? 'Source'),
                                  backgroundColor: Colors.white,
                                  side: const BorderSide(color: Color(0xFF0d6efd)),
                                ))
                            .toList(),
                      )
                    ],
                    if ((msg.followUps?.isNotEmpty ?? false)) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: msg.followUps!
                            .map((q) => Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: OutlinedButton.icon(
                                    onPressed: () => _handleFollowUpAction(q),
                                    icon: Icon(
                                      q.contains("Insurance") 
                                        ? Icons.security 
                                        : q.contains("Financial Assessment")
                                          ? Icons.attach_money
                                          : Icons.calculate,
                                      size: 18,
                                    ),
                                    label: Text(q),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                      side: BorderSide(color: Colors.grey[400]!),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ))
                            .toList(),
                      )
                    ]
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _expertButton(String expertType) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => _handleExpertSelection(expertType),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey[100],
          foregroundColor: Colors.black87,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.grey[300]!),
          ),
        ),
        child: Text(
          expertType,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildInsuranceForm() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Insurance Information",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 16),
            
            // Payer Dropdown
            DropdownSearch<Payer>(
              items: (filter, loadProps) => _payers,
              compareFn: (Payer item1, Payer item2) => item1.code == item2.code,
              decoratorProps: DropDownDecoratorProps(
                decoration: InputDecoration(
                  labelText: 'Insurance Payer',
                  labelStyle: TextStyle(fontSize: 12),
                  hintText: 'Select your insurance provider',
                  hintStyle: TextStyle(fontSize: 12),
                  border: const OutlineInputBorder(),
                  suffixIcon: const Icon(Icons.search),
                ),
              ),
              itemAsString: (Payer payer) => payer.name,
              popupProps: PopupProps.modalBottomSheet(
                showSearchBox: true,
                searchFieldProps: TextFieldProps(
                  decoration: InputDecoration(
                    hintText: 'Search payers...',
                    prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                    border: const OutlineInputBorder(),
                  ),
                ),
                modalBottomSheetProps: ModalBottomSheetProps(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                ),
                itemBuilder: (context, payer, isSelected, isFocused) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.transparent,
                      border: Border(
                        bottom: BorderSide(color: Colors.grey[200]!, width: 1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: Text(payer.name, style: const TextStyle(fontSize: 10))),
                        if (isSelected)
                          Icon(Icons.check_circle, color: Colors.blue, size: 20),
                      ],
                    ),
                  );
                },
              ),
              filterFn: (payer, filter) {
                return payer.name.toLowerCase().contains(filter.toLowerCase()) ||
                       payer.code.toLowerCase().contains(filter.toLowerCase());
              },
              selectedItem: _selectedPayer,
              onChanged: (Payer? payer) {
                setState(() {
                  _selectedPayer = payer;
                  _payerController.text = payer?.name ?? '';
                });
              },
              validator: (payer) => _validatePayer(payer),
            ),
            
            const SizedBox(height: 16),
            
            // Member ID
            TextFormField(
              controller: _memberIdController,
              style: TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                labelText: 'Member ID',
                labelStyle: TextStyle(fontSize: 12),
                hintText: 'Enter your member ID',
                hintStyle: TextStyle(fontSize: 12),
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              validator: _required,
            ),
            
            const SizedBox(height: 16),
            
            // Date of Birth
            TextFormField(
              controller: _dobController,
              readOnly: true,
              onTap: _pickDob,
              style: TextStyle(fontSize: 12),
              decoration: const InputDecoration(
                labelText: 'Date of Birth',
                labelStyle: TextStyle(fontSize: 12),
                hintText: 'MM/DD/YYYY',
                hintStyle: TextStyle(fontSize: 12),
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.calendar_today),
              ),
              validator: _required,
            ),
            
            const SizedBox(height: 20),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _showInsuranceForm = false;
                        _showInput = true;
                      });
                    },
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoadingInsurance ? null : _checkInsuranceEligibility,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoadingInsurance
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Check Coverage'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = (_c.value * 3).floor();
        final dots = '.' * (t + 1);
        return Text('typing$dots', style: TextStyle(color: Colors.blue[600]));
      },
    );
  }
}
