import 'dart:async';

import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../services/pverify_service.dart';
import '../widgets/common_app_bar.dart';

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

class NewInsuranceCheckScreen extends StatefulWidget {
  const NewInsuranceCheckScreen({Key? key}) : super(key: key);

  @override
  State<NewInsuranceCheckScreen> createState() => _NewInsuranceCheckScreenState();
}

class _NewInsuranceCheckScreenState extends State<NewInsuranceCheckScreen> {
  final _formKey = GlobalKey<FormState>();
  final _payerController = TextEditingController();
  final _memberIdController = TextEditingController();
  final _dobController = TextEditingController();

  DateTime? _dob;
  bool _isLoading = false;
  String? _error;
  Payer? _selectedPayer;

  Map<String, dynamic>? _data; // parsed/normalized eligibility response

  // Payer data list (sorted by eligibility status, then alphabetically)
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
    
    // Non-eligible payers (sorted alphabetically)
    Payer(code: 'DE001', name: 'AARP Dental', type: 'EDI', eligibility: false, claimStatus: false),
    Payer(code: 'DE0407', name: 'ACEC Health Plans (Salt Lake City, UT)', type: 'EDI', eligibility: false, claimStatus: false),
    Payer(code: 'DE0408', name: 'Administrative Services Only (ASO)', type: 'EDI', eligibility: false, claimStatus: false),
    Payer(code: 'DE0409', name: 'Advantage Dental', type: 'EDI', eligibility: false, claimStatus: false),
  ];

  @override
  void dispose() {
    _payerController.dispose();
    _memberIdController.dispose();
    _dobController.dispose();
    super.dispose();
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

  Future<void> _fetchEligibility() async {
    // Validate form fields
    if (!_formKey.currentState!.validate()) return;
    
    // Custom validation for payer selection
    final payerValidation = _validatePayer(_selectedPayer);
    if (payerValidation != null) {
      setState(() {
        _error = payerValidation;
      });
      return;
    }
    
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _error = null;
      _data = null;
    });

    try {
      // Step 1: Get pVerify access token
      final pverifyService = PVerifyService();
      final token = await pverifyService.getAccessToken();
      
      if (token == null) {
        throw Exception('Failed to get pVerify access token');
      }
      
      print('✅ Got pVerify token: ${token.substring(0, 20)}...');
      
      // Step 2: Make eligibility request with user data
      final eligibilityData = await pverifyService.getEligibilitySummary(
        payerName: _selectedPayer?.name ?? _payerController.text.trim(),
        memberID: _memberIdController.text.trim(),
        firstName: 'Test', // TODO: Add first name field
        lastName: 'Test1', // TODO: Add last name field  
        dob: _dobController.text.trim(),
      );
      
      if (eligibilityData == null) {
        throw Exception('Failed to get eligibility data from pVerify');
      }

      print('🔍 Raw pVerify API Response Keys: ${eligibilityData.keys.toList()}');

      // Process the real pVerify response
      final processedData = _processEligibilityResponse(eligibilityData);

      setState(() {
        _data = processedData;
      });
    } catch (e) {
      setState(() {
        _error = "Failed to fetch eligibility: $e";
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  String? _validatePayer(Payer? payer) {
    if (payer == null) return 'Please select a payer';
    if (!payer.eligibility) return 'Selected payer does not support eligibility checks';
    return null;
  }

  Widget _buildPayerDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownSearch<Payer>(
          items: (filter, loadProps) => _payers,
          compareFn: (Payer item1, Payer item2) => item1.code == item2.code,
          decoratorProps: DropDownDecoratorProps(
            decoration: InputDecoration(
              labelText: 'Payer Name',
              hintText: 'Select or search for a payer',
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
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF0d6efd)),
                ),
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
                  color: isSelected ? Color(0xFF0d6efd).withOpacity(0.1) : Colors.transparent,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey[200]!, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        payer.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w400,
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        Icons.check_circle,
                        color: Color(0xFF0d6efd),
                        size: 20,
                      ),
                  ],
                ),
              );
            },
            title: Container(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Select Payer',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ),
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
      ],
    );
  }

  /// Process pVerify API response and normalize it to our expected format
  Map<String, dynamic> _processEligibilityResponse(Map<String, dynamic> apiResponse) {
    try {
      print('🔄 Processing pVerify response...');
      
      // Extract main response data for logging
      final planCoverageSummary = apiResponse['PlanCoverageSummary'] ?? {};
      final benefitInfo = apiResponse['BenefitInformation'] ?? {};
      final deductibleOOPSummary = apiResponse['HBPC_Deductible_OOP_Summary'] ?? {};
      final dmeSummary = apiResponse['DMESummary'] ?? {};
      
      // Extract additional service summaries for office visit and ER data
      final primaryCareSummary = apiResponse['TelemedicinePrimaryCareSummary'] ?? {};
      final specialistSummary = apiResponse['TelemedicineSpecialistSummary'] ?? {};
      final hospitalOutPatientSummary = apiResponse['HospitalOutPatientSummary'] ?? {};
      final professionalPhysicianSummary = apiResponse['ProfessionalPhysicianVisitInpatientSummary'] ?? {};
      
      print('📊 PlanCoverageSummary found: $planCoverageSummary');
      print('💰 HBPC_Deductible_OOP_Summary found: $deductibleOOPSummary');
      print('🔸 BenefitInformation found: $benefitInfo');
      print('🏥 DMESummary found: $dmeSummary');
      print('🩺 TelemedicinePrimaryCareSummary found: $primaryCareSummary');
      print('👨‍⚕️ TelemedicineSpecialistSummary found: $specialistSummary');
      print('🏥 HospitalOutPatientSummary found: $hospitalOutPatientSummary');
      print('👩‍⚕️ ProfessionalPhysicianVisitInpatientSummary found: $professionalPhysicianSummary');
      
      // Normalize the response to our expected structure
      return {
        "planCoverage": {
          "status": planCoverageSummary['Status']?.toString() ?? 'Unknown',
          "effectiveDate": planCoverageSummary['EffectiveDate']?.toString() ?? '—',
          "expiryDate": planCoverageSummary['ExpiryDate']?.toString() ?? '—',
          "planName": planCoverageSummary['PlanName']?.toString() ?? '—',
          "planNetworkName": planCoverageSummary['PlanNetworkName']?.toString() ?? '—',
          "policyType": planCoverageSummary['PolicyType']?.toString() ?? '—',
        },
        "financials": {
          // Use actual HBPC_Deductible_OOP_Summary data
          "individualDeductibleInNet": deductibleOOPSummary['IndividualDeductibleInNet']?['Value']?.toString(),
          "individualDeductibleRemainingInNet": deductibleOOPSummary['IndividualDeductibleRemainingInNet']?['Value']?.toString(),
          "familyDeductibleInNet": deductibleOOPSummary['FamilyDeductibleInNet']?['Value']?.toString(),
          "familyDeductibleRemainingInNet": deductibleOOPSummary['FamilyDeductibleRemainingInNet']?['Value']?.toString(),
          "individualOOPInNet": deductibleOOPSummary['IndividualOOP_InNet']?['Value']?.toString(),
          "individualOOPRemainingInNet": deductibleOOPSummary['IndividualOOPRemainingInNet']?['Value']?.toString(),
          "familyOOPInNet": deductibleOOPSummary['FamilyOOPInNet']?['Value']?.toString(),
          "familyOOPRemainingInNet": deductibleOOPSummary['FamilyOOPRemainingInNet']?['Value']?.toString(),
        },
        "benefitInfo": {
          // DME Service costs and coverage info
          "dmeInNetworkCopay": dmeSummary['CoPayInNet']?['Value']?.toString(),
          "dmeOutNetworkCopay": dmeSummary['CoPayOutNet']?['Value']?.toString(),
          "dmeInNetworkCoinsurance": dmeSummary['CoInsInNet']?['Value']?.toString(),
          "dmeOutNetworkCoinsurance": dmeSummary['CoInsOutNet']?['Value']?.toString(),
          "dmeInNetworkCovered": dmeSummary['ServiceCoveredInNet']?.toString(),
          "dmeOutNetworkCovered": dmeSummary['ServiceCoveredOutNet']?.toString(),
          "dmeInNetworkAuth": dmeSummary['InNetServiceAuthorizationInfo'] != null ? "YES" : "NO",
          "dmeOutNetworkAuth": dmeSummary['OutNetServiceAuthorizationInfo'] != null ? "YES" : "NO",
          
          // Office Visit (Primary Care) costs and coverage info
          "officeVisitInNetworkCopay": primaryCareSummary['CoPayInNet']?['Value']?.toString() ?? specialistSummary['CoPayInNet']?['Value']?.toString(),
          "officeVisitOutNetworkCopay": primaryCareSummary['CoPayOutNet']?['Value']?.toString() ?? specialistSummary['CoPayOutNet']?['Value']?.toString(),
          "officeVisitInNetworkCoinsurance": primaryCareSummary['CoInsInNet']?['Value']?.toString() ?? specialistSummary['CoInsInNet']?['Value']?.toString(),
          "officeVisitOutNetworkCoinsurance": primaryCareSummary['CoInsOutNet']?['Value']?.toString() ?? specialistSummary['CoInsOutNet']?['Value']?.toString(),
          "officeVisitInNetworkCovered": primaryCareSummary['ServiceCoveredInNet']?.toString() ?? specialistSummary['ServiceCoveredInNet']?.toString(),
          "officeVisitInNetworkAuth": (primaryCareSummary['InNetServiceAuthorizationInfo'] != null || specialistSummary['InNetServiceAuthorizationInfo'] != null) ? "YES" : "NO",
          
          // ER Visit (Hospital OutPatient) costs and coverage info  
          "erVisitInNetworkCopay": hospitalOutPatientSummary['CoPayInNet']?['Value']?.toString(),
          "erVisitOutNetworkCopay": hospitalOutPatientSummary['CoPayOutNet']?['Value']?.toString(),
          "erVisitInNetworkCoinsurance": hospitalOutPatientSummary['CoInsInNet']?['Value']?.toString(),
          "erVisitOutNetworkCoinsurance": hospitalOutPatientSummary['CoInsOutNet']?['Value']?.toString(),
          "erVisitInNetworkCovered": hospitalOutPatientSummary['ServiceCoveredInNet']?.toString(),
          "erVisitInNetworkAuth": hospitalOutPatientSummary['InNetServiceAuthorizationInfo'] != null ? "YES" : "NO",
        },
      };
    } catch (e) {
      print('⚠️ Error processing pVerify response: $e');
      
      // Return empty structure on error
      return {
        "planCoverage": {},
        "financials": {},
        "benefitInfo": {},
      };
    }
  }

  /// Helper to parse monetary amounts from string
  double _parseAmount(String? value) {
    if (value == null || value.isEmpty || value == '—') return 0.0;
    final String str = value.replaceAll(RegExp(r'[^\d.]'), '');
    return double.tryParse(str) ?? 0.0;
  }

  String _formatCurrency(double? amount) {
    if (amount == null || amount == 0) return 'Not Available';
    return '\$${amount.toStringAsFixed(0)}';
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: const CommonAppBar(title: 'Insurance Overview'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Input Form Card
              _buildInputCard(),
              const SizedBox(height: 16),
              
              // Loading/Error States
              if (_isLoading) const _LoadingCard(),
              if (_error != null && !_isLoading)
                _MessageCard(
                  color: Colors.red[50]!,
                  borderColor: Colors.red,
                  icon: Icons.error_outline,
                  text: _error!,
                ),
              
              // Insurance Overview - Redesigned
              if (_data != null && !_isLoading) ...[
                _buildPlanOverviewNew(),
                const SizedBox(height: 16),
                _buildYearToDateProgress(),
                const SizedBox(height: 16),
                _buildCommonServices(),
                const SizedBox(height: 16),
                _buildPrimaryCareProvider(),
                const SizedBox(height: 16),
                _buildPriorAuthNotes(),
                const SizedBox(height: 16),
                _buildDisclaimer(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(Icons.person_search, color: Colors.grey[600], size: 20),
                SizedBox(width: 12),
                Text(
                  'Member Details',
                  style: TextStyle(
                    color: Colors.grey[800],
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                Spacer(),
                Text(
                  'Required',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Form content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildPayerDropdown(),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _memberIdController,
                    decoration: const InputDecoration(
                      labelText: 'Member ID',
                      hintText: 'e.g., 123456789',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.badge_outlined),
                    ),
                    validator: _required,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _dobController,
                    readOnly: true,
                    onTap: _pickDob,
                    decoration: const InputDecoration(
                      labelText: 'Date of Birth',
                      hintText: 'MM/DD/YYYY',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    validator: _required,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _fetchEligibility,
                    icon: _isLoading 
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.search, size: 16),
                    label: Text(
                      _isLoading ? 'Checking...' : 'Check Eligibility',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0d6efd),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanOverviewNew() {
    final planCoverage = _data!['planCoverage'] ?? {};
    final planName = planCoverage['planName']?.toString() ?? 'Plan name not available';
    final status = planCoverage['status']?.toString() ?? 'Unknown';
    final selfFunded = planCoverage['selfFundedPlan']?.toString() ?? '';
    
    final displayPlanName = selfFunded.toUpperCase() == 'YES' 
        ? '$planName (Self-Insured)' 
        : planName;

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_user, color: Color(0xFF0d6efd), size: 20),
              SizedBox(width: 8),
              Text('Plan Overview', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF0d6efd))),
            ],
          ),
          const SizedBox(height: 16),
          
          Text('Plan: $displayPlanName', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.black87)),
          const SizedBox(height: 8),
          
          Row(
            children: [
              Icon(status.toUpperCase() == 'ACTIVE' ? Icons.check_circle : Icons.info,
                   color: status.toUpperCase() == 'ACTIVE' ? Colors.green : Colors.orange, size: 18),
              SizedBox(width: 6),
              Text('Status: ${status.toUpperCase() == 'ACTIVE' ? 'Active Coverage' : status}',
                   style: TextStyle(fontWeight: FontWeight.w600, 
                                  color: status.toUpperCase() == 'ACTIVE' ? Colors.green : Colors.orange)),
            ],
          ),
          const SizedBox(height: 12),
          
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Colors.blue[600], size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Tip: Use in-network providers to avoid higher costs.',
                             style: TextStyle(color: Colors.blue[700], fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYearToDateProgress() {
    final financials = _data!['financials'] ?? {};
    
    double _parseAmount(String? value) {
      if (value == null || value.isEmpty || value == '—') return 0.0;
      final cleaned = value.replaceAll(RegExp(r'[^\d.]'), '');
      return double.tryParse(cleaned) ?? 0.0;
    }

    String _fmtCurrency(double? v) => v == null || v == 0 ? '\$0' : '\$${v.toStringAsFixed(0)}';

    final individualDedTotal = _parseAmount(financials['individualDeductibleInNet']?.toString());
    final individualDedRemaining = _parseAmount(financials['individualDeductibleRemainingInNet']?.toString());
    final individualDedMet = individualDedTotal > 0 ? (individualDedTotal - individualDedRemaining).clamp(0.0, individualDedTotal) : 0.0;
    final familyDedTotal = _parseAmount(financials['familyDeductibleInNet']?.toString());
    final familyDedRemaining = _parseAmount(financials['familyDeductibleRemainingInNet']?.toString());
    
    final individualOOPTotal = _parseAmount(financials['individualOOPInNet']?.toString());
    final individualOOPRemaining = _parseAmount(financials['individualOOPRemainingInNet']?.toString());
    final individualOOPMet = individualOOPTotal > 0 ? (individualOOPTotal - individualOOPRemaining).clamp(0.0, individualOOPTotal) : 0.0;
    final familyOOPTotal = _parseAmount(financials['familyOOPInNet']?.toString());
    final familyOOPRemainingActual = _parseAmount(financials['familyOOPRemainingInNet']?.toString());

    // Debug progress bar calculations
    print('🔢 Progress Bar Data:');
    print('   Deductible - Total: \$${individualDedTotal.toStringAsFixed(0)}, Met: \$${individualDedMet.toStringAsFixed(0)}, Progress: ${((individualDedTotal > 0 ? individualDedMet / individualDedTotal : 0.0) * 100).toStringAsFixed(1)}%');
    print('   OOP Max - Total: \$${individualOOPTotal.toStringAsFixed(0)}, Met: \$${individualOOPMet.toStringAsFixed(0)}, Progress: ${((individualOOPTotal > 0 ? individualOOPMet / individualOOPTotal : 0.0) * 100).toStringAsFixed(1)}%');

    Widget buildProgressSection(String title, String individual, String family, double progress, Color color) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.black87)),
              Text('${(progress * 100).toStringAsFixed(0)}%', 
                   style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: color)),
            ],
          ),
          const SizedBox(height: 8),
          Text(individual, style: TextStyle(color: Colors.grey[700])),
          Text(family, style: TextStyle(color: Colors.grey[700])),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
        ],
      );
    }

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up, color: Color(0xFF0d6efd), size: 20),
              SizedBox(width: 8),
              Text('Your Year-to-Date Progress', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF0d6efd))),
            ],
          ),
          const SizedBox(height: 16),
          
          buildProgressSection(
            'Deductible (In-Network)',
            'Individual ${_fmtCurrency(individualDedTotal)} (Met: ${_fmtCurrency(individualDedMet)})',
            'Family ${_fmtCurrency(familyDedTotal)} (Remaining: ${_fmtCurrency(familyDedRemaining)})',
            individualDedTotal > 0 ? (individualDedMet / individualDedTotal).clamp(0.0, 1.0) : 0.0,
            Colors.green,
          ),
          
          const SizedBox(height: 16),
          
          buildProgressSection(
            'Out-of-Pocket Max (In-Network)',
            'Individual ${_fmtCurrency(individualOOPTotal)} (Met: ${_fmtCurrency(individualOOPMet)})',
            'Family ${_fmtCurrency(familyOOPTotal)} (Remaining: ${_fmtCurrency(familyOOPRemainingActual)})',
            individualOOPTotal > 0 ? (individualOOPMet / individualOOPTotal).clamp(0.0, 1.0) : 0.0,
            Colors.blue,
          ),
        ],
      ),
    );
  }

  Widget _buildCommonServices() {
    final benefitSummary = _data!['benefitSummary'] ?? {};
    final dmeData = benefitSummary['inNetwork'] ?? {};
    final allergyData = benefitSummary['allergyImmunotherapy'] ?? {};

    Widget buildServiceRow(String service, String? copay, String? coinsurance, String? outNetwork, {String? customMessage}) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(service, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87)),
          const SizedBox(height: 4),
          if (customMessage != null)
            Text(customMessage, style: TextStyle(color: Colors.orange[700], fontStyle: FontStyle.italic))
          else ...[
            Wrap(
              spacing: 4,
              children: [
                if (copay != null) ...[
                  Text('Copay ${copay.startsWith('\$') ? copay : '\$$copay'}', style: TextStyle(color: Colors.grey[700])),
                  if (coinsurance != null) Text(', ', style: TextStyle(color: Colors.grey[700])),
                ],
                if (coinsurance != null)
                  Text('Coinsurance $coinsurance In-Network', style: TextStyle(color: Colors.grey[700])),
              ],
            ),
            if (outNetwork != null)
              Text(outNetwork, style: TextStyle(color: Colors.grey[700])),
          ],
        ],
      );
    }

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.medical_services, color: Color(0xFF0d6efd), size: 20),
              SizedBox(width: 8),
              Text('What You Pay for Common Services', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF0d6efd))),
            ],
          ),
          const SizedBox(height: 16),
          
          buildServiceRow(
            'Allergy supplies/equipment (DME)',
            dmeData['coPay']?.toString() ?? 'Not available',
            dmeData['coIns']?.toString() ?? 'Not available',
            '100% Out-of-Network',
          ),
          
          const SizedBox(height: 12),
          
          buildServiceRow(
            'Allergy testing & injections',
            allergyData['coPay'] != null ? allergyData['coPay'].toString() : null,
            allergyData['coIns'] != null ? allergyData['coIns'].toString() : null,
            null,
            customMessage: allergyData['coPay'] == null && allergyData['coIns'] == null 
                ? 'Details not returned by your plan in this check; clinic will confirm.'
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryCareProvider() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_hospital, color: Color(0xFF0d6efd), size: 20),
              SizedBox(width: 8),
              Text('Your Primary Care Provider on File', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF0d6efd))),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Joel Goode, NPI 1649247198 — tap to call / map address',
            style: TextStyle(color: Colors.blue[600], decoration: TextDecoration.underline),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorAuthNotes() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.assignment, color: Color(0xFF0d6efd), size: 20),
              SizedBox(width: 8),
              Text('Notes about Prior Authorization', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF0d6efd))),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber[200]!),
            ),
            child: Text(
              'Some services may require prior authorization. If needed, our clinic will request it for you.',
              style: TextStyle(color: Colors.amber[800], fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.grey[600], size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'This summary comes directly from your insurer\'s real-time response and may change. Final patient responsibility is determined after the claim is processed.',
              style: TextStyle(color: Colors.grey[700], fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }
}

// Reusable Components

class _InsuranceCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _InsuranceCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0d6efd).withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(icon, color: const Color(0xFF0d6efd)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF0d6efd),
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
          
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: const [
          SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Expanded(child: Text('Fetching eligibility...')),
        ],
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final Color color;
  final Color borderColor;
  final IconData icon;
  final String text;

  const _MessageCard({
    required this.color,
    required this.borderColor,
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: borderColor),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
