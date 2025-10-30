class ImmunotherapyOption {
  final String name;
  final String description;
  final String duration;
  final String frequency;
  final String costRange;
  final String costRangeValue; // For sorting/comparison if needed
  final String initialCost;
  final String annualCost;
  final String insuranceCoverage;
  final String convenience;

  const ImmunotherapyOption({
    required this.name,
    required this.description,
    required this.duration,
    required this.frequency,
    required this.costRange,
    required this.costRangeValue,
    required this.initialCost,
    required this.annualCost,
    required this.insuranceCoverage,
    required this.convenience,
  });

  // Convert to JSON for future storage/API integration
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'duration': duration,
      'frequency': frequency,
      'costRange': costRange,
      'costRangeValue': costRangeValue,
      'initialCost': initialCost,
      'annualCost': annualCost,
      'insuranceCoverage': insuranceCoverage,
      'convenience': convenience,
    };
  }

  // Create from JSON for future storage/API integration
  factory ImmunotherapyOption.fromJson(Map<String, dynamic> json) {
    return ImmunotherapyOption(
      name: json['name'],
      description: json['description'],
      duration: json['duration'],
      frequency: json['frequency'],
      costRange: json['costRange'],
      costRangeValue: json['costRangeValue'],
      initialCost: json['initialCost'],
      annualCost: json['annualCost'],
      insuranceCoverage: json['insuranceCoverage'],
      convenience: json['convenience'],
    );
  }
}

class ImmunotherapyOptionsData {
  static const List<ImmunotherapyOption> options = [
    ImmunotherapyOption(
      name: 'Allergy Shots',
      description: 'Subcutaneous immunotherapy administered in clinical setting',
      duration: '3-5 years',
      frequency: 'weekly to monthly',
      costRange: '\$1200 - \$3,500/year',
      costRangeValue: '1200-3500',
      initialCost: '\$400-800',
      annualCost: '\$1,200-3,500',
      insuranceCoverage: 'Check Eligibility',
      convenience: 'Clinical Visits',
    ),
    ImmunotherapyOption(
      name: 'Allergy Drops',
      description: 'Sublingual immunotherapy self-administered at home',
      duration: '3-5 years',
      frequency: 'Daily',
      costRange: '\$800 - \$2,000/year',
      costRangeValue: '800-2000',
      initialCost: '\$300-600',
      annualCost: '\$800-2,000',
      insuranceCoverage: 'Check Eligibility',
      convenience: 'At Home',
    ),
  ];

  // Get all available options
  static List<ImmunotherapyOption> getAllOptions() {
    return options;
  }

  // Get option by name
  static ImmunotherapyOption? getOptionByName(String name) {
    try {
      return options.firstWhere(
        (option) => option.name.toLowerCase() == name.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }

  // Get formatted treatment information for display
  static String getFormattedTreatmentInfo() {
    StringBuffer buffer = StringBuffer();
    buffer.writeln('💉 Immunotherapy Treatment Options\n');
    
    for (int i = 0; i < options.length; i++) {
      final option = options[i];
      buffer.writeln(option.name);
      buffer.writeln('${option.description}\n');
      buffer.writeln('Duration: ${option.duration}');
      buffer.writeln('Frequency: ${option.frequency}');
      buffer.writeln('Estimated Cost Range: ${option.costRange}');
      
      if (i < options.length - 1) {
        buffer.writeln('\n────────────────────────────────\n');
      }
    }
    
    buffer.writeln('\n📋 Next Steps:');
    buffer.writeln('• Consult with your allergist to determine the best option');
    buffer.writeln('• Review your insurance coverage for immunotherapy');
    buffer.writeln('• Consider your lifestyle and treatment preferences');
    buffer.writeln('\nWould you like me to help you check your insurance coverage for these treatments?');
    
    return buffer.toString();
  }

  // Get compact treatment information for chat display
  static String getCompactTreatmentInfo() {
    return 'Here are your immunotherapy treatment options with detailed cost information. Please scroll down to see both options:';
  }
}
