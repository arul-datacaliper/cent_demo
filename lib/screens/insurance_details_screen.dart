import 'package:flutter/material.dart';

class InsuranceDetailsScreen extends StatefulWidget {
  const InsuranceDetailsScreen({super.key});

  @override
  State<InsuranceDetailsScreen> createState() => _InsuranceDetailsScreenState();
}

class _InsuranceDetailsScreenState extends State<InsuranceDetailsScreen> {
  final _payerController = TextEditingController();
  final _memberIdController = TextEditingController();
  final _dobController = TextEditingController();

  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _insuranceData;

  void _fetchInsuranceDetails() async {
    setState(() {
      _loading = true;
      _error = null;
      _insuranceData = null;
    });

    // TODO: Replace with actual API call
    await Future.delayed(const Duration(seconds: 2));
    setState(() {
      _loading = false;
      _insuranceData = {
        'plan': {
          'status': 'Active',
          'effectiveDate': '01/01/2025',
          'planName': 'CHOICE',
          'selfFunded': 'Yes',
          'policyType': 'Commercial',
          'groupNumber': '1484170',
          'gender': 'Male',
        },
        'otherPayer': {'misc': 'Other payer info here'},
        'coverageSummary': {'summary': 'Coverage summary here'},
        'benefitSummary': {
          'outNetwork': '• Out-Network',
          'inNetwork': 'In-Network',
          'specialistOffice': 'Specialist Office',
          'deductibleOOP': '\$75.000',
          'serviceCovered': 'YES',
          'coPay': '0%',
          'coIns': 'NO (May Depend on POS)',
          'authInfo': 'PROVIDER ROLE OTHER',
        },
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Insurance Details'),
        backgroundColor: Colors.blue[600],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _payerController,
                      decoration: const InputDecoration(
                        labelText: 'Payer Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _memberIdController,
                      decoration: const InputDecoration(
                        labelText: 'Member ID',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _dobController,
                      decoration: const InputDecoration(
                        labelText: 'Date of Birth (MM/DD/YYYY)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _fetchInsuranceDetails,
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Get Insurance Details'),
                      ),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(_error!, style: const TextStyle(color: Colors.red)),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_insuranceData != null) ...[
              _sectionTitle('Plan Coverage'),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _infoRow('Status:', _insuranceData!['plan']['status']),
                      _infoRow('Effective Date:', _insuranceData!['plan']['effectiveDate']),
                      _infoRow('Plan Name:', _insuranceData!['plan']['planName']),
                      _infoRow('Self Funded Plan:', _insuranceData!['plan']['selfFunded']),
                      _infoRow('Policy Type:', _insuranceData!['plan']['policyType']),
                      _infoRow('Group Number:', _insuranceData!['plan']['groupNumber']),
                      _infoRow('Patient Gender:', _insuranceData!['plan']['gender']),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _sectionTitle('Other Payer Info'),
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _infoRow('Miscellaneous Info:', _insuranceData!['otherPayer']['misc']),
                ),
              ),
              const SizedBox(height: 20),
              _sectionTitle('Coverage Summary'),
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _infoRow('Plan Benefit & Service Summary:', _insuranceData!['coverageSummary']['summary']),
                ),
              ),
              const SizedBox(height: 20),
              _sectionTitle('Benefit & Service Details'),
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _infoRow('Out-Network:', _insuranceData!['benefitSummary']['outNetwork']),
                      _infoRow('In-Network:', _insuranceData!['benefitSummary']['inNetwork']),
                      _infoRow('Specialist Office:', _insuranceData!['benefitSummary']['specialistOffice']),
                      _infoRow('Plan Deductible OOP:', _insuranceData!['benefitSummary']['deductibleOOP']),
                      _infoRow('Service Covered In Net:', _insuranceData!['benefitSummary']['serviceCovered']),
                      _infoRow('Co Pay In Net:', _insuranceData!['benefitSummary']['coPay']),
                      _infoRow('Co Ins In Net:', _insuranceData!['benefitSummary']['coIns']),
                      _infoRow('In Net Service Authorization Info:', _insuranceData!['benefitSummary']['authInfo']),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.black87))),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
      ),
    );
  }
}