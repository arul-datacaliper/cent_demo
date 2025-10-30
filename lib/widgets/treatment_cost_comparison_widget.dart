import 'package:flutter/material.dart';
import '../models/immunotherapy_options.dart';

class TreatmentCostComparisonWidget extends StatelessWidget {
  const TreatmentCostComparisonWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final options = ImmunotherapyOptionsData.getAllOptions();
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Treatment Cost Comparison',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          _buildComparisonTable(options),
          const SizedBox(height: 24),
          _buildNextStepsSection(),
        ],
      ),
    );
  }

  Widget _buildComparisonTable(List<ImmunotherapyOption> options) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header Row
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Expanded(
                  flex: 2,
                  child: Text(
                    'Aspect',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    options[0].name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    options[1].name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Data Rows
          _buildTableRow('Initial cost', options[0].initialCost, options[1].initialCost),
          _buildDivider(),
          _buildTableRow('Annual cost', options[0].annualCost, options[1].annualCost),
          _buildDivider(),
          _buildTableRow('Insurance Coverage', options[0].insuranceCoverage, options[1].insuranceCoverage, isInsurance: true),
          _buildDivider(),
          _buildTableRow('Convenience', options[0].convenience, options[1].convenience, isConvenience: true),
        ],
      ),
    );
  }

  Widget _buildTableRow(String aspect, String value1, String value2, {bool isInsurance = false, bool isConvenience = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              aspect,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: _buildCellContent(value1, isInsurance, isConvenience),
          ),
          Expanded(
            flex: 2,
            child: _buildCellContent(value2, isInsurance, isConvenience),
          ),
        ],
      ),
    );
  }

  Widget _buildCellContent(String value, bool isInsurance, bool isConvenience) {
    if (isInsurance) {
      return Center(
        child: Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF4CAF50), // Green color for insurance
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    } else if (isConvenience) {
      return Center(
        child: Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF4CAF50), // Green color for convenience
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    } else {
      return Center(
        child: Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: Colors.grey[200],
    );
  }

  Widget _buildNextStepsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.checklist,
                color: Colors.blue,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Next Steps',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildNextStepItem('Consult with your allergist to determine the best option'),
          _buildNextStepItem('Review your insurance coverage for immunotherapy'),
          _buildNextStepItem('Consider your lifestyle and treatment preferences'),
          _buildNextStepItem('Compare total costs including initial setup and ongoing expenses'),
          const SizedBox(height: 16),
          const Text(
            'Would you like me to help you check your insurance coverage for these treatments?',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black87,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextStepItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
