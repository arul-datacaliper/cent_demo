import 'dart:async';

import 'package:flutter/material.dart';

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

  Map<String, dynamic>? _data; // parsed/normalized eligibility response

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
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _error = null;
      _data = null;
    });

    try {
      // TODO: Replace this mock with your real pVerify API call.
      await Future<void>.delayed(const Duration(milliseconds: 800));

      // Example normalized structure (adjust to your real response mapping).
      final mock = {
        "planCoverage": {
          "status": "Active",
          "effectiveDate": "01/01/2025",
          "planName": "CHOICE",
          "selfFundedPlan": "Yes",
          "policyType": "Commercial",
          "groupNumber": "1484170",
          "patientGender": "Male",
        },
        "otherPayerInfo": {
          "name": "Other Payer ABC",
          "id": "OP-8832",
          "notes": "—",
        },
        "coverageSummary": {
          "summary": "Member has active benefits under CHOICE plan.",
        },
        "miscInfo": {"message": "Eligibility verified successfully."},
        "benefitSummary": {
          "inNetwork": {
            "service": "Specialist Office",
            "serviceCovered": "YES",
            "coPay": "\$75.00",
            "coIns": "0%",
            "authRequired": "NO (May Depend on POS)",
          },
          "outNetwork": {
            "service": "Specialist Office",
            "serviceCovered": "YES",
            "coPay": "Varies",
            "coIns": "40%",
            "authRequired": "Likely",
          },
          "planDeductibleOOP": {"deductible": "\$1,500", "oopMax": "\$5,000"},
          "roleNotes": {"providerRole": "PROVIDER ROLE OTHER"},
        },
        "financials": {
          "deductibleTotal": 2500.00,
          "deductibleMet": 555.00, // example
          "oopMaxTotal": 5500.00,
          "oopMet": 820.00, // example
          "coinsurancePercent": 20, // 20% after deductible
          "specialistCopay": 75.00, // $75 per visit
        },
      };

      setState(() {
        _data = mock;
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

  String _fmtCurrency(num? v) => v == null ? '—' : '\$${v.toStringAsFixed(0)}';
  double _safeDiv(num a, num b) => (b == 0) ? 0.0 : (a / b);

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
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
        title: const Text('Eligibility Check'),
      ),
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
                    SectionAccordion(
                      title: 'Plan Coverage',
                      icon: Icons.verified_user,
                      initiallyExpanded: true,
                      child: _PlanCoverageCard(
                        data: _data!["planCoverage"] ?? {},
                      ),
                    ),
                    const SizedBox(height: 12),
                        SectionAccordion(
                      title: 'Plan Benefit & Service Summary',
                      icon: Icons.health_and_safety,
                      initiallyExpanded: true,
                      child: _BenefitSummaryCard(
                        data: _data!["benefitSummary"] ?? {},
                      ),
                    ),
                    const SizedBox(height: 12),

                    SectionAccordion(
                      title: 'Costs at a Glance',
                      icon: Icons.payments_outlined,
                      initiallyExpanded: true,
                      child: FinancialOverviewCard(
                        data: _data!['financials'] ?? {},
                      ),
                    ),
                    const SizedBox(height: 12),

                    SectionAccordion(
                      title: 'What this means',
                      icon: Icons.insights,
                      initiallyExpanded: true,
                      child: _SimpleNoteCard(
                        title: 'Summary',
                        text: _buildFinancialNarrative(
                          _data!['financials'] ?? {},
                        ),
                        icon: Icons.summarize,
                      ),
                    ),
const SizedBox(height: 12),
                    SectionAccordion(
                      title: 'Other Payer Info',
                      icon: Icons.account_balance,
                      initiallyExpanded: false,
                      child: _OtherPayerCard(
                        data: _data!["otherPayerInfo"] ?? {},
                      ),
                    ),
                    const SizedBox(height: 12),

                    SectionAccordion(
                      title: 'Coverage Summary',
                      icon: Icons.assignment,
                      initiallyExpanded: false,
                      child: _SimpleNoteCard(
                        title: 'Summary',
                        text: _data!["coverageSummary"]?["summary"] ?? '—',
                        icon: Icons.assignment,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // SectionAccordion(
                    //   title: 'Miscellaneous Info',
                    //   icon: Icons.notes,
                    //   initiallyExpanded: false,
                    //   child: _SimpleNoteCard(
                    //     title: 'Info',
                    //     text: _data!["miscInfo"]?["message"] ?? '—',
                    //     icon: Icons.notes,
                    //   ),
                    // ),
                    // const SizedBox(height: 12),

                    // 🔓 This one starts OPEN
                
                  ],

                  // if (_data != null && !_isLoading) ...[
                  //   // _SectionHeader(title: 'Plan Coverage'),
                  //   // _PlanCoverageCard(data: _data!["planCoverage"] ?? {}),
                  //   const SizedBox(height: 16),

                  //   _SectionHeader(title: 'Other Payer Info'),
                  //   _OtherPayerCard(data: _data!["otherPayerInfo"] ?? {}),
                  //   const SizedBox(height: 16),

                  //   _SectionHeader(title: 'Coverage Summary'),
                  //   _SimpleNoteCard(
                  //     title: 'Summary',
                  //     text: _data!["coverageSummary"]?["summary"] ?? '—',
                  //     icon: Icons.assignment,
                  //   ),
                  //   const SizedBox(height: 16),

                  //   _SectionHeader(title: 'Miscellaneous Info'),
                  //   _SimpleNoteCard(
                  //     title: 'Info',
                  //     text: _data!["miscInfo"]?["message"] ?? '—',
                  //     icon: Icons.notes,
                  //   ),
                  //   const SizedBox(height: 16),

                  //   _SectionHeader(title: 'Plan Benefit & Service Summary'),
                  //   _BenefitSummaryCard(data: _data!["benefitSummary"] ?? {}),
                  //   const SizedBox(height: 16),
                  //   _SectionHeader(title: 'Costs at a Glance'),
                  //   FinancialOverviewCard(data: _data!['financials'] ?? {}),
                  //   const SizedBox(height: 16),
                  //   _SimpleNoteCard(
                  //     title: 'What this means',
                  //     text: _buildFinancialNarrative(
                  //       _data!['financials'] ?? {},
                  //     ),
                  //     icon: Icons.insights,
                  //   ),
                  // ],
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
                  TextFormField(
                    controller: _payerController,
                    decoration: const InputDecoration(
                      labelText: 'Payer Name',
                      hintText: 'e.g., UnitedHealthcare',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.account_balance),
                    ),
                    validator: _required,
                    textInputAction: TextInputAction.next,
                  ),
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

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: Colors.black87,
      ),
    );
  }
}

class _TitleRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;

  const _TitleRow({required this.title, this.subtitle, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          decoration: const BoxDecoration(
            color: Color(0xFFE8F0FE),
            shape: BoxShape.circle,
          ),
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: const Color(0xFF0d6efd)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
            ],
          ),
        ),
      ],
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
        children: [
          _row(
            'Status',
            status,
            valueStyle: TextStyle(
              fontWeight: FontWeight.w700,
              color: _statusColor(status),
            ),
            icon: Icons.verified_user,
          ),
          _row(
            'Effective Date',
            data["effectiveDate"] ?? '—',
            icon: Icons.event,
          ),
          _row(
            'Plan Name',
            data["planName"] ?? '—',
            icon: Icons.medical_services,
          ),
          _row(
            'Self Funded Plan',
            data["selfFundedPlan"] ?? '—',
            icon: Icons.account_balance,
          ),
          _row(
            'Policy Type',
            data["policyType"] ?? '—',
            icon: Icons.description,
          ),
          _row('Group Number', data["groupNumber"] ?? '—', icon: Icons.tag),
          _row(
            'Patient Gender',
            data["patientGender"] ?? '—',
            icon: Icons.person,
          ),
        ],
      ),
    );
  }

  Widget _row(String k, String v, {IconData? icon, TextStyle? valueStyle}) {
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
          Text(v, style: valueStyle),
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
          _row('Name', data["name"] ?? '—', Icons.account_balance),
          _row('ID', data["id"] ?? '—', Icons.confirmation_number),
          _row('Notes', data["notes"] ?? '—', Icons.sticky_note_2_outlined),
        ],
      ),
    );
  }

  Widget _row(String k, String v, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Text(v),
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
    final covered = (m["serviceCovered"] ?? '—').toString().toUpperCase();
    final coveredColor = covered == 'YES' ? Colors.green : Colors.redAccent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _chip(m["service"] ?? 'Service', color: Colors.indigo),
            _chip(
              'Covered: ${m["serviceCovered"] ?? "—"}',
              color: coveredColor,
            ),
            _chip('CoPay: ${m["coPay"] ?? "—"}', color: Colors.orange),
            _chip('CoIns: ${m["coIns"] ?? "—"}', color: Colors.teal),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.verified_user, size: 18, color: Colors.grey),
            const SizedBox(width: 6),
            Expanded(child: Text('Auth: ${m["authRequired"] ?? "—"}')),
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
  String _fmtCurrency(num? v) => v == null ? '—' : '\$${v.toStringAsFixed(0)}';

  @override
  Widget build(BuildContext context) {
    final deductibleTotal = (data['deductibleTotal'] ?? 0).toDouble();
    final deductibleMet = (data['deductibleMet'] ?? 0).toDouble();
    final deductibleLeft = (deductibleTotal - deductibleMet).clamp(
      0,
      deductibleTotal,
    );
    final deductiblePct = _safeDiv(
      deductibleMet,
      deductibleTotal,
    ).clamp(0.0, 1.0);

    final oopMaxTotal = (data['oopMaxTotal'] ?? 0).toDouble();
    final oopMet = (data['oopMet'] ?? 0).toDouble();
    final oopPct = _safeDiv(oopMet, oopMaxTotal).clamp(0.0, 1.0);

    final copay = (data['specialistCopay'] ?? 0).toDouble();
    final coins = (data['coinsurancePercent'] ?? 0).toInt();

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
