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

class EligibilityScreen extends StatefulWidget {
  const EligibilityScreen({Key? key}) : super(key: key);

  @override
  State<EligibilityScreen> createState() => _EligibilityScreenState();
}

class _EligibilityScreenState extends State<EligibilityScreen> {
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
    Payer(code: '00192', name: 'United Healthcare', type: 'EDI', eligibility: true, claimStatus: true),
    
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
      
      // Check for PlanCoverageSummary specifically
      if (eligibilityData.containsKey('PlanCoverageSummary')) {
        print('✅ Found PlanCoverageSummary: ${eligibilityData['PlanCoverageSummary']}');
      } else {
        print('⚠️ PlanCoverageSummary not found in response');
        print('📋 Available top-level keys: ${eligibilityData.keys.toList()}');
      }

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



  Future<void> _testToken() async {
    try {
      final pverifyService = PVerifyService();
      
      // Clear any existing token to force a fresh one
      await pverifyService.clearToken();
      
      final token = await pverifyService.getAccessToken();
      
      if (token != null) {
        final tokenInfo = pverifyService.getTokenInfo();
        
        // Show success dialog
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Text('Token Generated'),
                ],
              ),
              content: Text(tokenInfo),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      } else {
        // Show error dialog
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.error, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Token Failed'),
                ],
              ),
              content: const Text('Failed to generate pVerify access token. Check your credentials and network connection.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      print('Error testing token: $e');
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error, color: Colors.red),
                SizedBox(width: 8),
                Text('Error'),
              ],
            ),
            content: Text('Error testing token: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  String _fmtCurrency(num? v) => v == null ? '—' : '\$${v.toStringAsFixed(0)}';

  /// Helper function to extract field values with multiple possible paths
  String _extractField(Map<String, dynamic> apiResponse, List<String> possiblePaths, String defaultValue) {
    for (String path in possiblePaths) {
      final keys = path.split('.');
      dynamic current = apiResponse;
      
      bool foundValue = true;
      for (String key in keys) {
        if (current is Map<String, dynamic> && current.containsKey(key)) {
          current = current[key];
        } else {
          foundValue = false;
          break;
        }
      }
      
      if (foundValue && current != null && current.toString().trim().isNotEmpty) {
        print('✅ Found ${possiblePaths.first} at path: $path = $current');
        return current.toString();
      }
    }
    
    print('⚠️ Could not find ${possiblePaths.first} in any of these paths: $possiblePaths');
    return defaultValue;
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
      
      // Extract additional service summaries for office visit, ER, and allergy immunotherapy data
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
          // Direct access to PlanCoverageSummary fields
          "status": planCoverageSummary['Status']?.toString() ?? 'Unknown',
          "effectiveDate": planCoverageSummary['EffectiveDate']?.toString() ?? '—',
          "expiryDate": planCoverageSummary['ExpiryDate']?.toString() ?? '—',
          "planName": planCoverageSummary['PlanName']?.toString() ?? '—',
          "selfFundedPlan": planCoverageSummary['SelfFundedPlan']?.toString() ?? '—',
          "policyType": planCoverageSummary['PolicyType']?.toString() ?? '—',
          "groupNumber": planCoverageSummary['GroupNumber']?.toString() ?? '—',
          "groupName": planCoverageSummary['GroupName']?.toString() ?? '—',
          "planNetworkID": planCoverageSummary['PlanNetworkID']?.toString() ?? '—',
          "planNetworkName": planCoverageSummary['PlanNetworkName']?.toString() ?? '—',
          "subscriberRelationship": planCoverageSummary['SubscriberRelationship']?.toString() ?? '—',
          "planNumber": planCoverageSummary['PlanNumber']?.toString() ?? '—',
          "hraHsaLimitations": planCoverageSummary['HRAorHSALimitationsRemaining']?.toString() ?? '—',
          "lastUpdatedEDI": planCoverageSummary['LastUpdatedDateOfEDI']?.toString() ?? '—',
          
          // Keep patient gender from other sources since it's not in PlanCoverageSummary
          "patientGender": _extractField(apiResponse, [
            'EligibilityStatus.PatientGender',
            'PatientGender',
            'Gender'
          ], '—'),
        },
        "otherPayerInfo": {
          "name": apiResponse['OtherPayerName'] ?? '—',
          "id": apiResponse['OtherPayerId'] ?? '—',
          "notes": apiResponse['OtherPayerNotes'] ?? '—',
        },
        "coverageSummary": {
          "summary": _extractField(apiResponse, [
            'EligibilityStatus.Summary',
            'PlanCoverageSummary.Summary',
            'Summary'
          ], 'Eligibility verified via pVerify API.'),
        },
        "miscInfo": {
          "message": "Real-time eligibility verified via pVerify API.",
        },
        "benefitSummary": {
          "inNetwork": {
            "service": "DME (Durable Medical Equipment)",
            "serviceCovered": dmeSummary['ServiceCoveredInNet'],
            "coPay": dmeSummary['CoPayInNet']?['Value'],
            "coIns": dmeSummary['CoInsInNet']?['Value'],
            "authRequired": dmeSummary['InNetServiceAuthorizationInfo'] != null ? "YES" : "NO",
          },
          "outNetwork": {
            "service": "DME (Durable Medical Equipment)",
            "serviceCovered": dmeSummary['ServiceCoveredOutNet'],
            "coPay": dmeSummary['CoPayOutNet']?['Value'],
            "coIns": dmeSummary['CoInsOutNet']?['Value'],
            "authRequired": dmeSummary['OutNetServiceAuthorizationInfo'] != null ? "YES" : "NO",
          },
          // Add allergy immunotherapy service details
          "allergyImmunotherapy": {
            "service": "Allergy Immunotherapy (Allergy Shots)",
            "serviceCovered": specialistSummary['ServiceCoveredInNet'] ?? primaryCareSummary['ServiceCoveredInNet'],
            "coPay": specialistSummary['CoPayInNet']?['Value'] ?? primaryCareSummary['CoPayInNet']?['Value'],
            "coIns": specialistSummary['CoInsInNet']?['Value'] ?? primaryCareSummary['CoInsInNet']?['Value'],
            "authRequired": (specialistSummary['InNetServiceAuthorizationInfo'] != null || primaryCareSummary['InNetServiceAuthorizationInfo'] != null) ? "YES" : "NO",
            "frequency": "Multiple visits required over 6-12 months",
            "phases": {
              "buildUp": "Weekly visits for 3-6 months with increasing doses",
              "maintenance": "Monthly visits for 3-5 years with consistent doses"
            },
          },
          "planDeductibleOOP": {
            // Use HBPC_Deductible_OOP_Summary data
            "individualDeductibleInNet": deductibleOOPSummary['IndividualDeductibleInNet']?['Value']?.toString() ?? '—',
            "individualDeductibleOutNet": deductibleOOPSummary['IndividualDeductibleOutNet']?['Value']?.toString() ?? '—',
            "individualDeductibleRemainingInNet": deductibleOOPSummary['IndividualDeductibleRemainingInNet']?['Value']?.toString() ?? '—',
            "individualDeductibleRemainingOutNet": deductibleOOPSummary['IndividualDeductibleRemainingOutNet']?['Value']?.toString() ?? '—',
            "familyDeductibleInNet": deductibleOOPSummary['FamilyDeductibleInNet']?['Value']?.toString() ?? '—',
            "familyDeductibleOutNet": deductibleOOPSummary['FamilyDeductibleOutNet']?['Value']?.toString() ?? '—',
            "familyDeductibleRemainingInNet": deductibleOOPSummary['FamilyDeductibleRemainingInNet']?['Value']?.toString() ?? '—',
            "familyDeductibleRemainingOutNet": deductibleOOPSummary['FamilyDeductibleRemainingOutNet']?['Value']?.toString() ?? '—',
            "individualOOPInNet": deductibleOOPSummary['IndividualOOP_InNet']?['Value']?.toString() ?? '—',
            "individualOOPOutNet": deductibleOOPSummary['IndividualOOP_OutNet']?['Value']?.toString() ?? '—',
            "individualOOPRemainingInNet": deductibleOOPSummary['IndividualOOPRemainingInNet']?['Value']?.toString() ?? '—',
            "individualOOPRemainingOutNet": deductibleOOPSummary['IndividualOOPRemainingOutNet']?['Value']?.toString() ?? '—',
            "familyOOPInNet": deductibleOOPSummary['FamilyOOPInNet']?['Value']?.toString() ?? '—',
            "familyOOPOutNet": deductibleOOPSummary['FamilyOOPOutNet']?['Value']?.toString() ?? '—',
            "familyOOPRemainingInNet": deductibleOOPSummary['FamilyOOPRemainingInNet']?['Value']?.toString() ?? '—',
            "familyOOPRemainingOutNet": deductibleOOPSummary['FamilyOOPRemainingOutNet']?['Value']?.toString() ?? '—',
          },
          "roleNotes": {
            "providerRole": apiResponse['ProviderRole'] ?? 'PROVIDER ROLE'
          },
        },
        "financials": {
          // Use actual HBPC_Deductible_OOP_Summary data ONLY - no fallback values
          "deductibleTotal": _parseAmount(deductibleOOPSummary['IndividualDeductibleInNet']?['Value']),
          "deductibleMet": _parseAmount(deductibleOOPSummary['IndividualDeductibleInNet']?['Value']) != null && 
                          _parseAmount(deductibleOOPSummary['IndividualDeductibleRemainingInNet']?['Value']) != null 
                          ? (_parseAmount(deductibleOOPSummary['IndividualDeductibleInNet']?['Value'])! - 
                             _parseAmount(deductibleOOPSummary['IndividualDeductibleRemainingInNet']?['Value'])!)
                          : null,
          "oopMaxTotal": _parseAmount(deductibleOOPSummary['IndividualOOP_InNet']?['Value']),
          "oopMet": _parseAmount(deductibleOOPSummary['IndividualOOP_InNet']?['Value']) != null && 
                   _parseAmount(deductibleOOPSummary['IndividualOOPRemainingInNet']?['Value']) != null 
                   ? (_parseAmount(deductibleOOPSummary['IndividualOOP_InNet']?['Value'])! - 
                      _parseAmount(deductibleOOPSummary['IndividualOOPRemainingInNet']?['Value'])!)
                   : null,
          "coinsurancePercent": _parsePercent(dmeSummary['CoInsInNet']?['Value']),
          "specialistCopay": _parseAmount(dmeSummary['CoPayInNet']?['Value']),
          "dmeCoinsuranceInNet": dmeSummary['CoInsInNet']?['Value'],
          "dmeCoinsuranceOutNet": dmeSummary['CoInsOutNet']?['Value'],
          "dmeCopayInNet": dmeSummary['CoPayInNet']?['Value'],
          "dmeCopayOutNet": dmeSummary['CoPayOutNet']?['Value'],
          
          // Store raw HBPC values for comprehensive display - API values only
          "individualDeductibleInNet": deductibleOOPSummary['IndividualDeductibleInNet']?['Value']?.toString(),
          "individualDeductibleOutNet": deductibleOOPSummary['IndividualDeductibleOutNet']?['Value']?.toString(),
          "individualDeductibleMetInNet": _parseAmount(deductibleOOPSummary['IndividualDeductibleInNet']?['Value']) != null && 
                                         _parseAmount(deductibleOOPSummary['IndividualDeductibleRemainingInNet']?['Value']) != null 
                                         ? (_parseAmount(deductibleOOPSummary['IndividualDeductibleInNet']?['Value'])! - 
                                            _parseAmount(deductibleOOPSummary['IndividualDeductibleRemainingInNet']?['Value'])!).toString()
                                         : null,
          "familyDeductibleInNet": deductibleOOPSummary['FamilyDeductibleInNet']?['Value']?.toString(),
          "familyDeductibleOutNet": deductibleOOPSummary['FamilyDeductibleOutNet']?['Value']?.toString(),
          "individualOOPInNet": deductibleOOPSummary['IndividualOOP_InNet']?['Value']?.toString(),
          "individualOOPOutNet": deductibleOOPSummary['IndividualOOP_OutNet']?['Value']?.toString(),
          "individualOOPMetInNet": _parseAmount(deductibleOOPSummary['IndividualOOP_InNet']?['Value']) != null && 
                                  _parseAmount(deductibleOOPSummary['IndividualOOPRemainingInNet']?['Value']) != null 
                                  ? (_parseAmount(deductibleOOPSummary['IndividualOOP_InNet']?['Value'])! - 
                                     _parseAmount(deductibleOOPSummary['IndividualOOPRemainingInNet']?['Value'])!).toString()
                                  : null,
          "familyOOPInNet": deductibleOOPSummary['FamilyOOPInNet']?['Value']?.toString(),
          "familyOOPOutNet": deductibleOOPSummary['FamilyOOPOutNet']?['Value']?.toString(),
          
          // Additional detailed information from HBPC - API values only
          "familyDeductibleTotal": _parseAmount(deductibleOOPSummary['FamilyDeductibleInNet']?['Value']),
          "familyDeductibleRemaining": _parseAmount(deductibleOOPSummary['FamilyDeductibleRemainingInNet']?['Value']),
          "familyOOPTotal": _parseAmount(deductibleOOPSummary['FamilyOOPInNet']?['Value']),
          "familyOOPRemaining": _parseAmount(deductibleOOPSummary['FamilyOOPRemainingInNet']?['Value']),
        },
      };
    } catch (e) {
      print('⚠️ Error processing pVerify response: $e');
      
      // Return empty structure on error - no mock data
      return {
        "planCoverage": {
          "status": "Error processing API response",
          "effectiveDate": null,
          "planName": null,
          "selfFundedPlan": null,
          "policyType": null,
          "groupNumber": null,
          "patientGender": null,
        },
        "otherPayerInfo": {
          "name": null,
          "id": null,
          "notes": "Error processing pVerify API response: $e",
        },
        "coverageSummary": {
          "summary": "Error processing eligibility response from pVerify API.",
        },
        "miscInfo": {
          "message": "Error occurred during API response processing.",
        },
        "benefitSummary": {
          "inNetwork": {
            "service": null,
            "serviceCovered": null,
            "coPay": null,
            "coIns": null,
            "authRequired": null,
          },
          "outNetwork": {
            "service": null,
            "serviceCovered": null,
            "coPay": null,
            "coIns": null,
            "authRequired": null,
          },
          "planDeductibleOOP": {},
          "roleNotes": {"providerRole": null},
        },
        "financials": {
          "deductibleTotal": null,
          "deductibleMet": null,
          "oopMaxTotal": null,
          "oopMet": null,
          "coinsurancePercent": null,
          "specialistCopay": null,
        },
      };
    }
  }

  /// Helper to parse monetary amounts from string
  double? _parseAmount(dynamic value) {
    if (value == null) return null;
    final String str = value.toString().replaceAll(RegExp(r'[^\d.]'), '');
    return double.tryParse(str);
  }

  /// Helper to parse percentage from string
  int? _parsePercent(dynamic value) {
    if (value == null) return null;
    final String str = value.toString().replaceAll(RegExp(r'[^\d]'), '');
    return int.tryParse(str);
  }

  String _buildFinancialNarrative(Map<String, dynamic> f) {
    final dedTotal = (f['deductibleTotal'] ?? 0).toDouble();
    final dedMet = (f['deductibleMet'] ?? 0).toDouble();
    final dedLeft = (dedTotal - dedMet).clamp(0, dedTotal);
    final coins = (f['coinsurancePercent'] ?? 0).toInt();
    final oopMax = (f['oopMaxTotal'] ?? 0).toDouble();

    return 'Your annual deductible is ${_fmtCurrency(dedTotal)}, and you have '
        '${_fmtCurrency(dedLeft)} left to meet it. Until you meet that amount, '
        'you’ll pay the full allowed cost for immunotherapy visits. Once your '
        'deductible is met, you’ll pay $coins% of the allowed cost for these services '
        'until your total out-of-pocket spending reaches ${_fmtCurrency(oopMax)}, '
        'at which point insurance will pay 100% for the rest of the year.';
  }

  @override
  Widget build(BuildContext context) {
    const scaffoldBg =
        Colors.white; // Color(0xFFF4F8FF); // bright, soft background
    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: const CommonAppBar(title: 'Eligibility Check'),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildInputCard(),
                  const SizedBox(height: 16),
                  if (_isLoading) const _LoadingCard(),
                  if (_error != null && !_isLoading)
                    _MessageCard(
                      color: Colors.amber[50]!,
                      borderColor: Colors.amber,
                      icon: Icons.info_outline,
                      text: _error!,
                    ),
                  if (_data != null && !_isLoading) ...[
                    // Plan Overview Section
                    _PlanOverviewCard(
                      data: _data!["planCoverage"] ?? {},
                    ),
                    const SizedBox(height: 16),

                    // Year-to-Date Progress Section
                    _YearToDateProgressCard(
                      data: _data!['financials'] ?? {},
                    ),
                    const SizedBox(height: 16),

                    // What You Pay for Common Services Section
                    _CommonServicesCard(
                      data: _data!["benefitSummary"] ?? {},
                    ),
                    const SizedBox(height: 16),

                    // Primary Care Provider Section (placeholder)
                    _PrimaryCareProviderCard(),
                    const SizedBox(height: 16),

                    // Prior Authorization Notes Section
                    _PriorAuthorizationCard(),
                    const SizedBox(height: 16),

                    // Footer Disclaimer
                    _DisclaimerFooter(),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
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
          // 🔵 Colored header
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: Color(0xFF0d6efd), // bright blue accent
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: const [
                Icon(Icons.person_search, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Member Details',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),

          // 📝 Form content
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
                  // Debug: Test Token Generation
                  SizedBox(
                    height: 36,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.key, size: 16),
                      label: const Text(
                        'Test pVerify Token',
                        style: TextStyle(fontSize: 12),
                      ),
                      onPressed: _isLoading ? null : _testToken,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text(
                        'Fetch Eligibility',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0d6efd),
                      ),
                      onPressed: _isLoading ? null : _fetchEligibility,
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
}

/// ---------- Reusable UI pieces ----------

class _CardContainer extends StatelessWidget {
  final Widget child;
  const _CardContainer({required this.child});

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
      child: child,
    );
  }
}



class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return _CardContainer(
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

/// ---------- Cards for sections ----------

class _PlanCoverageCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _PlanCoverageCard({required this.data});

  Color _statusColor(String s) {
    switch (s.toUpperCase()) {
      case 'ACTIVE':
        return Colors.green;
      case 'INACTIVE':
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = (data["status"] ?? '—').toString();
    return _CardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Primary Information Section
          const Text(
            'Plan Information',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: Color(0xFF0d6efd),
            ),
          ),
          const SizedBox(height: 12),
          _row(
            'Status',
            data["status"],
            valueStyle: TextStyle(
              fontWeight: FontWeight.w700,
              color: _statusColor(status),
            ),
            icon: Icons.verified_user,
          ),
          _row(
            'Plan Name',
            data["planName"],
            icon: Icons.medical_services,
          ),
          _row(
            'Policy Type',
            data["policyType"],
            icon: Icons.description,
          ),
          _row(
            'Plan Number',
            data["planNumber"],
            icon: Icons.confirmation_number,
          ),
          
          const Divider(height: 24),
          
          // Coverage Dates Section
          const Text(
            'Coverage Period',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: Color(0xFF0d6efd),
            ),
          ),
          const SizedBox(height: 12),
          _row(
            'Effective Date',
            data["effectiveDate"],
            icon: Icons.event,
          ),
          _row(
            'Expiry Date',
            data["expiryDate"],
            icon: Icons.event_available,
          ),
          
          const Divider(height: 24),
          
          // Group Information Section
          const Text(
            'Group Details',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: Color(0xFF0d6efd),
            ),
          ),
          const SizedBox(height: 12),
          _row('Group Number', data["groupNumber"], icon: Icons.tag),
          _row(
            'Group Name',
            data["groupName"],
            icon: Icons.group,
          ),
          _row(
            'Subscriber Relationship',
            data["subscriberRelationship"],
            icon: Icons.family_restroom,
          ),
          
          const Divider(height: 24),
          
          // Network Information Section
          const Text(
            'Network Information',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: Color(0xFF0d6efd),
            ),
          ),
          const SizedBox(height: 12),
          _row(
            'Plan Network ID',
            data["planNetworkID"],
            icon: Icons.network_check,
          ),
          _row(
            'Plan Network Name',
            data["planNetworkName"],
            icon: Icons.wifi,
          ),
          
          const Divider(height: 24),
          
          // Additional Information Section
          const Text(
            'Additional Details',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: Color(0xFF0d6efd),
            ),
          ),
          const SizedBox(height: 12),
          _row(
            'Self Funded Plan',
            data["selfFundedPlan"],
            icon: Icons.account_balance,
          ),
          _row(
            'Patient Gender',
            data["patientGender"],
            icon: Icons.person,
          ),
          _row(
            'HRA/HSA Limitations',
            data["hraHsaLimitations"],
            icon: Icons.savings,
          ),
          _row(
            'Last EDI Update',
            data["lastUpdatedEDI"],
            icon: Icons.update,
          ),
        ],
      ),
    );
  }

  Widget _row(String k, String? v, {IconData? icon, TextStyle? valueStyle}) {
    final displayValue = v?.toString() ?? 'No Data';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: Colors.grey[700]),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Text(displayValue, style: valueStyle),
        ],
      ),
    );
  }
}

class _OtherPayerCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _OtherPayerCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return _CardContainer(
      child: Column(
        children: [
          _row('Name', data["name"], Icons.account_balance),
          _row('ID', data["id"], Icons.confirmation_number),
          _row('Notes', data["notes"], Icons.sticky_note_2_outlined),
        ],
      ),
    );
  }

  Widget _row(String k, String? v, IconData icon) {
    final displayValue = v?.toString() ?? 'No Data';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Text(displayValue),
        ],
      ),
    );
  }
}

class _SimpleNoteCard extends StatelessWidget {
  final String title;
  final String text;
  final IconData icon;

  const _SimpleNoteCard({
    required this.title,
    required this.text,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return _CardContainer(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.blue[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(text),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitSummaryCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _BenefitSummaryCard({required this.data});

  Widget _chip(String label, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (color ?? Colors.blue).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color ?? Colors.blue,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inNet = data["inNetwork"] ?? {};
    final outNet = data["outNetwork"] ?? {};
    final dedOop = data["planDeductibleOOP"] ?? {};
    final role = data["roleNotes"] ?? {};

    return _CardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SubHeader('In-Network'),
          _benefitRow(inNet),
          const SizedBox(height: 12),
          const _SubHeader('Out-Network'),
          _benefitRow(outNet),
          const Divider(height: 24),
          const _SubHeader('Plan Deductible & OOP'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(
                'Deductible: ${dedOop["deductible"] ?? "—"}',
                color: Colors.deepPurple,
              ),
              _chip(
                'OOP Max: ${dedOop["oopMax"] ?? "—"}',
                color: Colors.deepPurple,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if ((role["providerRole"] ?? '') != '')
            Row(
              children: [
                const Icon(
                  Icons.person_pin_circle,
                  size: 18,
                  color: Colors.grey,
                ),
                const SizedBox(width: 6),
                Text(
                  role["providerRole"],
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _benefitRow(Map<String, dynamic> m) {
    final service = m["service"]?.toString() ?? 'No Data';
    final serviceCovered = m["serviceCovered"]?.toString() ?? 'No Data';
    final coPay = m["coPay"]?.toString() ?? 'No Data';
    final coIns = m["coIns"]?.toString() ?? 'No Data';
    final authRequired = m["authRequired"]?.toString() ?? 'No Data';
    
    final covered = serviceCovered.toUpperCase();
    final coveredColor = covered == 'YES' ? Colors.green : 
                        covered == 'NO DATA' ? Colors.grey : Colors.redAccent;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _chip(service, color: Colors.indigo),
            _chip(
              'Covered: $serviceCovered',
              color: coveredColor,
            ),
            _chip('CoPay: $coPay', color: Colors.orange),
            _chip('CoIns: $coIns', color: Colors.teal),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.verified_user, size: 18, color: Colors.grey),
            const SizedBox(width: 6),
            Expanded(child: Text('Auth: $authRequired')),
          ],
        ),
      ],
    );
  }
}

class FinancialOverviewCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const FinancialOverviewCard({required this.data});

  double _safeDiv(num a, num b) => (b == 0) ? 0.0 : (a / b);
  String _fmtCurrency(num? v) => v == null || v == 0 ? 'No Data' : '\$${v.toStringAsFixed(0)}';
  double _parseAmount(String? value) {
    if (value == null || value.isEmpty || value == '—') return 0.0;
    final cleaned = value.replaceAll(RegExp(r'[^\d.]'), '');
    return double.tryParse(cleaned) ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    // Debug: Show what data is available
    print('💳 FinancialOverviewCard received data keys: ${data.keys.toList()}');
    print('💳 Raw data values:');
    data.forEach((key, value) => print('  $key: $value'));
    
    // Use HBPC deductible data (individual in-network as primary)
    final individualDeductibleInNet = _parseAmount(data['individualDeductibleInNet']?.toString());
    final individualDeductibleMetInNet = _parseAmount(data['individualDeductibleMetInNet']?.toString());
    final familyDeductibleInNet = _parseAmount(data['familyDeductibleInNet']?.toString());
    
    final individualOOPInNet = _parseAmount(data['individualOOPInNet']?.toString());
    final individualOOPMetInNet = _parseAmount(data['individualOOPMetInNet']?.toString());
    final familyOOPInNet = _parseAmount(data['familyOOPInNet']?.toString());
    
    // Debug: Show parsed values
    print('💳 Parsed values:');
    print('  individualDeductibleInNet: $individualDeductibleInNet');
    print('  individualDeductibleMetInNet: $individualDeductibleMetInNet');
    print('  individualOOPInNet: $individualOOPInNet');
    print('  individualOOPMetInNet: $individualOOPMetInNet');

    // Primary calculations for display (individual in-network) - handle nulls
    final deductibleTotal = individualDeductibleInNet;
    final deductibleMet = individualDeductibleMetInNet;
    final deductibleLeft = (deductibleTotal > 0 && deductibleMet >= 0) 
        ? (deductibleTotal - deductibleMet).clamp(0.0, deductibleTotal) 
        : 0.0;
    final deductiblePct = (deductibleTotal > 0) 
        ? _safeDiv(deductibleMet, deductibleTotal).clamp(0.0, 1.0) 
        : 0.0;

    final oopMaxTotal = individualOOPInNet;
    final oopMet = individualOOPMetInNet;
    final oopPct = (oopMaxTotal > 0) 
        ? _safeDiv(oopMet, oopMaxTotal).clamp(0.0, 1.0) 
        : 0.0;

    final copay = data['specialistCopay'] != null ? (data['specialistCopay'] as num).toDouble() : 0.0;
    final coins = data['coinsurancePercent'] != null ? (data['coinsurancePercent'] as num).toInt() : 0;

    return _CardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: const [
              _IconDot(icon: Icons.payments_outlined),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Financial Summary',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Deductible donut + Quick facts responsive layout
          LayoutBuilder(
            builder: (context, c) {
              final narrow = c.maxWidth < 520;
              final donut = _deductibleDonut(
                deductiblePct,
                deductibleMet,
                deductibleLeft,
                deductibleTotal,
              );
              final facts = _quickFacts(copay, coins);
              return narrow
                  ? Column(children: [donut, const SizedBox(height: 16), facts])
                  : Row(
                      children: [
                        Expanded(flex: 2, child: donut),
                        const SizedBox(width: 16),
                        Expanded(flex: 3, child: facts),
                      ],
                    );
            },
          ),

          const SizedBox(height: 20),
          const Divider(),

          // OOP progress bar
          const SizedBox(height: 8),
          const Text(
            'Out-of-Pocket Progress',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: oopPct,
              minHeight: 14,
              backgroundColor: Colors.grey[200],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Met: ${_fmtCurrency(oopMet)}'),
              Text('Max: ${_fmtCurrency(oopMaxTotal)}'),
            ],
          ),

          // Comprehensive deductible and OOP breakdown
          if (familyDeductibleInNet > 0 || familyOOPInNet > 0) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              'Coverage Details',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            _coverageBreakdown(data),
          ],
        ],
      ),
    );
  }

  // --- Pieces ---

  Widget _deductibleDonut(double pct, double met, double left, double total) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            height: 88,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 88,
                  height: 88,
                  child: CircularProgressIndicator(
                    value: pct,
                    strokeWidth: 10,
                    backgroundColor: Colors.grey[200],
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${(pct * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const Text(
                      'Met',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Deductible',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _pill('Total: ${_fmtCurrency(total)}', Colors.indigo),
                    _pill('Met: ${_fmtCurrency(met)}', Colors.green),
                    _pill('Left: ${_fmtCurrency(left)}', Colors.orange),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickFacts(double copay, int coins) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Facts',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _pill(
              'Specialist Copay: ${_fmtCurrency(copay)}',
              Colors.deepPurple,
            ),
            _pill('Coinsurance: $coins%', Colors.teal),
          ],
        ),
      ],
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _coverageBreakdown(Map<String, dynamic> data) {
    final individualDeductibleInNet = _parseAmount(data['individualDeductibleInNet']?.toString());
    final individualDeductibleOutNet = _parseAmount(data['individualDeductibleOutNet']?.toString());
    final familyDeductibleInNet = _parseAmount(data['familyDeductibleInNet']?.toString());
    final familyDeductibleOutNet = _parseAmount(data['familyDeductibleOutNet']?.toString());
    
    final individualOOPInNet = _parseAmount(data['individualOOPInNet']?.toString());
    final individualOOPOutNet = _parseAmount(data['individualOOPOutNet']?.toString());
    final familyOOPInNet = _parseAmount(data['familyOOPInNet']?.toString());
    final familyOOPOutNet = _parseAmount(data['familyOOPOutNet']?.toString());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Deductible section
        _coverageSection(
          'Deductible',
          Colors.indigo,
          [
            _coverageRow('Individual In-Network', _fmtCurrency(individualDeductibleInNet)),
            _coverageRow('Individual Out-Network', _fmtCurrency(individualDeductibleOutNet)),
            _coverageRow('Family In-Network', _fmtCurrency(familyDeductibleInNet)),
            _coverageRow('Family Out-Network', _fmtCurrency(familyDeductibleOutNet)),
          ],
        ),
        const SizedBox(height: 16),
        // Out-of-Pocket section
        _coverageSection(
          'Out-of-Pocket Maximum',
          Colors.green,
          [
            _coverageRow('Individual In-Network', _fmtCurrency(individualOOPInNet)),
            _coverageRow('Individual Out-Network', _fmtCurrency(individualOOPOutNet)),
            _coverageRow('Family In-Network', _fmtCurrency(familyOOPInNet)),
            _coverageRow('Family Out-Network', _fmtCurrency(familyOOPOutNet)),
          ],
        ),
      ],
    );
  }

  Widget _coverageSection(String title, Color color, List<Widget> rows) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: color,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          ...rows,
        ],
      ),
    );
  }

  Widget _coverageRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _DebugHBPCCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _DebugHBPCCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return _CardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'API Field Mapping Analysis',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'UI "No Data" Fields Analysis:',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 12),
          
          // Section 1: In-Network/Out-Network Service Data
          _buildFieldMappingSection('In-Network Service Data', [
            _FieldMapping('UI Display', 'API Field Expected', 'Current Value', 'Notes'),
            _FieldMapping('Service Type', 'BenefitInformation.InNetworkService', data['inNetwork']?['service']?.toString() ?? 'null', 'Service category'),
            _FieldMapping('Covered Status', 'BenefitInformation.InNetworkCovered', data['inNetwork']?['serviceCovered']?.toString() ?? 'null', 'YES/NO expected'),
            _FieldMapping('CoPay Amount', 'BenefitInformation.InNetworkCopay', data['inNetwork']?['coPay']?.toString() ?? 'null', 'Dollar amount'),
            _FieldMapping('CoInsurance', 'BenefitInformation.InNetworkCoinsurance', data['inNetwork']?['coIns']?.toString() ?? 'null', 'Percentage'),
            _FieldMapping('Auth Required', 'BenefitInformation.InNetworkAuth', data['inNetwork']?['authRequired']?.toString() ?? 'null', 'YES/NO expected'),
          ]),
          
          const SizedBox(height: 16),
          
          // Section 2: Out-Network Service Data
          _buildFieldMappingSection('Out-Network Service Data', [
            _FieldMapping('UI Display', 'API Field Expected', 'Current Value', 'Notes'),
            _FieldMapping('Service Type', 'BenefitInformation.OutNetworkService', data['outNetwork']?['service']?.toString() ?? 'null', 'Service category'),
            _FieldMapping('Covered Status', 'BenefitInformation.OutNetworkCovered', data['outNetwork']?['serviceCovered']?.toString() ?? 'null', 'YES/NO expected'),
            _FieldMapping('CoPay Amount', 'BenefitInformation.OutNetworkCopay', data['outNetwork']?['coPay']?.toString() ?? 'null', 'Dollar amount'),
            _FieldMapping('CoInsurance', 'BenefitInformation.OutNetworkCoinsurance', data['outNetwork']?['coIns']?.toString() ?? 'null', 'Percentage'),
            _FieldMapping('Auth Required', 'BenefitInformation.OutNetworkAuth', data['outNetwork']?['authRequired']?.toString() ?? 'null', 'YES/NO expected'),
          ]),
          
          const SizedBox(height: 16),
          
          // Section 3: Deductible & OOP Data
          _buildFieldMappingSection('Plan Deductible & OOP Data', [
            _FieldMapping('UI Display', 'API Field Expected', 'Current Value', 'Notes'),
            _FieldMapping('Individual Deductible', 'HBPC_Deductible_OOP_Summary.IndividualDeductibleInNet.Value', data['planDeductibleOOP']?['individualDeductibleInNet']?.toString() ?? 'null', 'Dollar amount'),
            _FieldMapping('Individual OOP Max', 'HBPC_Deductible_OOP_Summary.IndividualOOP_InNet.Value', data['planDeductibleOOP']?['individualOOPInNet']?.toString() ?? 'null', 'Dollar amount'),
            _FieldMapping('Family Deductible', 'HBPC_Deductible_OOP_Summary.FamilyDeductibleInNet.Value', data['planDeductibleOOP']?['familyDeductibleInNet']?.toString() ?? 'null', 'Dollar amount'),
            _FieldMapping('Family OOP Max', 'HBPC_Deductible_OOP_Summary.FamilyOOPInNet.Value', data['planDeductibleOOP']?['familyOOPInNet']?.toString() ?? 'null', 'Dollar amount'),
          ]),
          
          const SizedBox(height: 16),
          
          // Section 4: Troubleshooting Help
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.yellow.shade50,
              border: Border.all(color: Colors.orange.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.help_outline, color: Colors.orange.shade700, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Troubleshooting: Why "No Data"?',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '1. API may not return BenefitInformation section\n'
                  '2. Field names may be different in actual API response\n'
                  '3. Data may be nested differently than expected\n'
                  '4. Payer may not provide this specific benefit data\n'
                  '5. Check console logs for actual API field names',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFieldMappingSection(String title, List<_FieldMapping> mappings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            children: mappings.asMap().entries.map((entry) {
              final index = entry.key;
              final mapping = entry.value;
              final isHeader = index == 0;
              
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: isHeader ? Colors.grey.shade100 : null,
                  border: index > 0 ? Border(top: BorderSide(color: Colors.grey.shade300)) : null,
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        mapping.uiDisplay,
                        style: TextStyle(
                          fontWeight: isHeader ? FontWeight.w600 : FontWeight.normal,
                          fontSize: isHeader ? 12 : 11,
                          color: isHeader ? Colors.black87 : Colors.blue.shade700,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        mapping.apiField,
                        style: TextStyle(
                          fontWeight: isHeader ? FontWeight.w600 : FontWeight.normal,
                          fontSize: isHeader ? 12 : 10,
                          fontFamily: isHeader ? null : 'monospace',
                          color: isHeader ? Colors.black87 : Colors.green.shade700,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        mapping.currentValue,
                        style: TextStyle(
                          fontWeight: isHeader ? FontWeight.w600 : FontWeight.normal,
                          fontSize: isHeader ? 12 : 10,
                          color: isHeader ? Colors.black87 : (mapping.currentValue == 'null' ? Colors.red : Colors.black87),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        mapping.notes,
                        style: TextStyle(
                          fontWeight: isHeader ? FontWeight.w600 : FontWeight.normal,
                          fontSize: isHeader ? 12 : 10,
                          color: isHeader ? Colors.black87 : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _FieldMapping {
  final String uiDisplay;
  final String apiField;
  final String currentValue;
  final String notes;
  
  _FieldMapping(this.uiDisplay, this.apiField, this.currentValue, this.notes);
}

// Small round icon used in card headers
class _IconDot extends StatelessWidget {
  final IconData icon;
  const _IconDot({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFE8F0FE),
        shape: BoxShape.circle,
      ),
      padding: const EdgeInsets.all(10),
      child: Icon(icon, color: const Color(0xFF0d6efd)),
    );
  }
}

class _SubHeader extends StatelessWidget {
  final String text;
  const _SubHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 14,
        color: Colors.black87,
      ),
    );
  }
}

class SectionAccordion extends StatelessWidget {
  final String title;
  final Widget child;
  final bool initiallyExpanded;
  final IconData? icon;

  const SectionAccordion({
    Key? key,
    required this.title,
    required this.child,
    this.initiallyExpanded = false,
    this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return _CardContainer(
      child: Theme(
        // remove the ExpansionTile divider line
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          maintainState: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 8),
          childrenPadding: const EdgeInsets.only(left: 8, right: 8, bottom: 12),
          leading: icon != null
              ? Icon(icon, color: const Color(0xFF0d6efd))
              : const Icon(Icons.folder_open, color: Color(0xFF0d6efd)),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          children: [child],
        ),
      ),
    );
  }
}

class _AllergyImmunotherapyCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _AllergyImmunotherapyCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final service = data["service"]?.toString() ?? 'Allergy Immunotherapy (Allergy Shots)';
    final serviceCovered = data["serviceCovered"]?.toString() ?? 'Unknown';
    final coPay = data["coPay"]?.toString() ?? 'Check with provider';
    final coIns = data["coIns"]?.toString() ?? 'Check with provider';
    final authRequired = data["authRequired"]?.toString() ?? 'Unknown';
    final frequency = data["frequency"]?.toString() ?? 'Multiple visits required';
    final phases = data["phases"] as Map<String, dynamic>? ?? {};
    
    final covered = serviceCovered.toUpperCase();
    final coveredColor = covered == 'YES' ? Colors.green : 
                        covered == 'UNKNOWN' ? Colors.grey : Colors.redAccent;

    return _CardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Service Title
          Row(
            children: [
              Icon(Icons.vaccines, color: Colors.blue[600], size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  service,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Color(0xFF0d6efd),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Coverage Status
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: coveredColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: coveredColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  covered == 'YES' ? Icons.check_circle : Icons.help_outline,
                  color: coveredColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Coverage Status: $serviceCovered',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: coveredColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Cost Information
          const Text(
            'Cost Information',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          _costRow('Copay per Visit', coPay, Icons.attach_money),
          _costRow('Coinsurance', coIns, Icons.percent),
          _costRow('Prior Authorization', authRequired, Icons.verified_user),
          
          const SizedBox(height: 16),

          // Treatment Information
          const Text(
            'Treatment Schedule',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  frequency,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                if (phases.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _phaseRow('Build-up Phase', phases['buildUp']?.toString() ?? '', Icons.trending_up),
                  const SizedBox(height: 4),
                  _phaseRow('Maintenance Phase', phases['maintenance']?.toString() ?? '', Icons.refresh),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Important Note
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber[200]!),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: Colors.amber[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Allergy immunotherapy is a long-term treatment that requires regular visits. Costs may vary based on allergen testing, serum preparation, and injection frequency. Consult with your allergist for specific treatment plans.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.amber[800],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _costRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _phaseRow(String phase, String description, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: Colors.blue[600]),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                phase,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              if (description.isNotEmpty)
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[700],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Plan Overview Card - Shows plan name, status, and tip
class _PlanOverviewCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _PlanOverviewCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final planName = data['planName']?.toString() ?? 'Plan name not available';
    final status = data['status']?.toString() ?? 'Unknown';
    final selfFunded = data['selfFundedPlan']?.toString() ?? '';
    
    final displayPlanName = selfFunded.toUpperCase() == 'YES' 
        ? '$planName (Self-Insured)' 
        : planName;
    
    return _CardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_user, color: Color(0xFF0d6efd), size: 20),
              SizedBox(width: 8),
              Text(
                'Plan Overview',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF0d6efd)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Text(
            'Plan: $displayPlanName',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          
          Row(
            children: [
              Icon(status.toUpperCase() == 'ACTIVE' ? Icons.check_circle : Icons.info,
                   color: status.toUpperCase() == 'ACTIVE' ? Colors.green : Colors.orange, size: 18),
              SizedBox(width: 6),
              Text(
                'Status: ${status.toUpperCase() == 'ACTIVE' ? 'Active Coverage' : status}',
                style: TextStyle(fontWeight: FontWeight.w600, 
                               color: status.toUpperCase() == 'ACTIVE' ? Colors.green : Colors.orange),
              ),
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
}

/// Year-to-Date Progress Card with visual progress bars
class _YearToDateProgressCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _YearToDateProgressCard({required this.data});

  double _parseAmount(String? value) {
    if (value == null || value.isEmpty || value == '—') return 0.0;
    final cleaned = value.replaceAll(RegExp(r'[^\d.]'), '');
    return double.tryParse(cleaned) ?? 0.0;
  }

  String _fmtCurrency(double? v) => v == null || v == 0 ? '\$0' : '\$${v.toStringAsFixed(0)}';

  @override
  Widget build(BuildContext context) {
    final individualDedTotal = _parseAmount(data['individualDeductibleInNet']?.toString());
    final individualDedMet = _parseAmount(data['individualDeductibleMetInNet']?.toString());
    final familyDedTotal = _parseAmount(data['familyDeductibleInNet']?.toString());
    final familyDedRemaining = familyDedTotal > 0 ? (familyDedTotal - individualDedMet).clamp(0.0, familyDedTotal) : 0.0;
    
    final individualOOPTotal = _parseAmount(data['individualOOPInNet']?.toString());
    final individualOOPMet = _parseAmount(data['individualOOPMetInNet']?.toString());
    final individualOOPRemaining = individualOOPTotal > 0 ? (individualOOPTotal - individualOOPMet).clamp(0.0, individualOOPTotal) : 0.0;
    final familyOOPTotal = _parseAmount(data['familyOOPInNet']?.toString());
    final familyOOPRemaining = familyOOPTotal > 0 ? (familyOOPTotal - individualOOPMet).clamp(0.0, familyOOPTotal) : 0.0;

    return _CardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up, color: Color(0xFF0d6efd), size: 20),
              SizedBox(width: 8),
              Text('Your Year-to-Date Progress',
                   style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF0d6efd))),
            ],
          ),
          const SizedBox(height: 16),
          
          _buildProgressSection(
            'Deductible (In-Network)',
            'Individual ${_fmtCurrency(individualDedTotal)} (Met)',
            'Family ${_fmtCurrency(familyDedTotal)} (Remaining ${_fmtCurrency(familyDedRemaining)})',
            individualDedTotal > 0 ? (individualDedMet / individualDedTotal).clamp(0.0, 1.0) : 0.0,
            Colors.green,
          ),
          
          const SizedBox(height: 16),
          
          _buildProgressSection(
            'Out-of-Pocket Max (In-Network)',
            'Individual ${_fmtCurrency(individualOOPTotal)} (Remaining ${_fmtCurrency(individualOOPRemaining)})',
            'Family ${_fmtCurrency(familyOOPTotal)} (Remaining ${_fmtCurrency(familyOOPRemaining)})',
            individualOOPTotal > 0 ? (individualOOPMet / individualOOPTotal).clamp(0.0, 1.0) : 0.0,
            Colors.blue,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection(String title, String individual, String family, double progress, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.black87)),
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
}

/// Common Services Card - Shows costs for allergy services
class _CommonServicesCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _CommonServicesCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final dmeData = data['inNetwork'] ?? {};
    final allergyData = data['allergyImmunotherapy'] ?? {};
    
    return _CardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.medical_services, color: Color(0xFF0d6efd), size: 20),
              SizedBox(width: 8),
              Text('What You Pay for Common Services',
                   style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF0d6efd))),
            ],
          ),
          const SizedBox(height: 16),
          
          _buildServiceRow(
            'Allergy supplies/equipment (DME)',
            dmeData['coPay']?.toString() ?? 'Not available',
            dmeData['coIns']?.toString() ?? 'Not available',
            '100% Out-of-Network',
          ),
          
          const SizedBox(height: 12),
          
          _buildServiceRow(
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

  Widget _buildServiceRow(String service, String? copay, String? coinsurance, String? outNetwork, {String? customMessage}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(service, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87)),
        const SizedBox(height: 4),
        if (customMessage != null)
          Text(customMessage, style: TextStyle(color: Colors.orange[700], fontStyle: FontStyle.italic))
        else ...[
          Row(
            children: [
              if (copay != null) ...[
                Text('Copay ${copay.startsWith('\$') ? copay : '\$$copay'}', 
                     style: TextStyle(color: Colors.grey[700])),
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
}

/// Primary Care Provider Card (placeholder)
class _PrimaryCareProviderCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _CardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_hospital, color: Color(0xFF0d6efd), size: 20),
              SizedBox(width: 8),
              Text('Your Primary Care Provider on File',
                   style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF0d6efd))),
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
}

/// Prior Authorization Notes Card
class _PriorAuthorizationCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _CardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.assignment, color: Color(0xFF0d6efd), size: 20),
              SizedBox(width: 8),
              Text('Notes about Prior Authorization',
                   style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF0d6efd))),
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
}

/// Disclaimer Footer
class _DisclaimerFooter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
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
