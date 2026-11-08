import 'package:brand_governance/features/guidelines/domain/brand_guidelines.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BrandGuidelines', () {
    test('round trips every field through JSON', () {
      const guidelines = BrandGuidelines(
        brandName: 'Northstar',
        description: 'A creative studio',
        tone: BrandTone.custom,
        customTone: 'Curious and clear',
        approvedTerms: ['members', 'community'],
        requiredTerms: ['Made for creators'],
        prohibitedTerms: ['guaranteed'],
        verifiedFacts: ['Founded in 2018'],
      );

      final restored = BrandGuidelines.fromJson(guidelines.toJson());

      expect(restored.brandName, guidelines.brandName);
      expect(restored.description, guidelines.description);
      expect(restored.tone, guidelines.tone);
      expect(restored.customTone, guidelines.customTone);
      expect(restored.approvedTerms, guidelines.approvedTerms);
      expect(restored.requiredTerms, guidelines.requiredTerms);
      expect(restored.prohibitedTerms, guidelines.prohibitedTerms);
      expect(restored.verifiedFacts, guidelines.verifiedFacts);
    });

    test('loads older saved guidelines without required terms', () {
      final restored = BrandGuidelines.fromJson({
        'brandName': 'Northstar',
        'approvedTerms': ['community'],
        'prohibitedTerms': ['guaranteed'],
        'verifiedFacts': <String>[],
      });

      expect(restored.requiredTerms, isEmpty);
      expect(restored.brandName, 'Northstar');
    });

    test('rejects malformed entries instead of silently discarding them', () {
      expect(
        () => BrandGuidelines.fromJson({
          'brandName': 'Northstar',
          'approvedTerms': ['members', 42],
        }),
        throwsFormatException,
      );
    });
  });
}
