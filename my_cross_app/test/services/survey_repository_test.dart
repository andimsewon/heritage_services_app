import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_cross_app/models/survey_models.dart';

void main() {
  group('SurveyRepository Tests', () {

    test('SurveyModel data structures work correctly', () {
      // Create a source survey with nested data
      final sourceSurvey = SurveyModel(
        year: '2024',
        section11: Section11Data(
          foundation: {
            'test': [{'text': 'foundation test'}]
          },
          wall: {
            'test': [{'text': 'wall test'}]
          },
          roof: {
            'test': [{'text': 'roof test'}]
          },
          paint: {
            'test': [{'text': 'paint test'}]
          },
          pest: {'hasPest': true, 'note': 'pest test'},
          etc: {
            'test': [{'text': 'etc test'}]
          },
          safetyNotes: {
            'test': [{'text': 'safety test'}]
          },
          investigatorOpinion: 'test opinion',
          grade: {'value': 'A', 'note': 'test grade'},
        ),
        section12: [
          Section12Row(
            group: 'test group',
            part: 'test part',
            content: 'test content',
            photoRef: 'test ref',
          ),
        ],
        section13: Section13Data(
          safety: {
            'manual': true,
            'extinguisher': {'exists': true, 'count': 5},
          },
          electric: {'regularCheck': true, 'notes': 'test notes'},
          gas: {'regularCheck': false, 'notes': ''},
          guard: {'exists': true, 'headcount': 3, 'shift': 'test shift', 'logbook': true},
          care: {'exists': true, 'org': 'test org'},
          guide: {
            'kiosk': true,
            'signBoard': {'exists': true, 'where': 'test where'},
            'museum': false,
            'interpreter': true,
          },
          surroundings: {
            'wall': 'test wall',
            'drainage': 'test drainage',
            'trees': 'test trees',
            'buildings': 'test buildings',
            'shelter': 'test shelter',
            'others': 'test others',
          },
          usage: {'note': 'test usage'},
        ),
        damageSummary: DamageSummary(
          byPart: {'test': {'grade': 'A'}},
          finalGrade: 'A',
          finalNote: 'test note',
        ),
      );

      // Test that the data structure is properly copied
      expect(sourceSurvey.section11.foundation['test']?[0]['text'], 'foundation test');
      expect(sourceSurvey.section12.first.group, 'test group');
      expect(sourceSurvey.section13.safety['manual'], true);
      expect(sourceSurvey.damageSummary?.finalGrade, 'A');
    });

    test('Audit log entries work correctly', () {
      final sourceSurvey = SurveyModel(
        year: '2024',
        section11: Section11Data.empty(),
        section12: [],
        section13: Section13Data.empty(),
        audit: [
          AuditLogEntry(
            timestamp: Timestamp.now(),
            uid: 'test_uid',
            action: 'test_action',
            path: '/test',
          ),
        ],
      );

      // Test audit log functionality
      expect(sourceSurvey.audit.isNotEmpty, true);
      expect(sourceSurvey.audit.first.uid, 'test_uid');
      expect(sourceSurvey.audit.first.action, 'test_action');
      expect(sourceSurvey.audit.first.path, '/test');
    });

    test('SurveyModel copyWith creates new instances', () {
      final original = SurveyModel(
        year: '2024',
        section11: Section11Data.empty(),
        section12: [],
        section13: Section13Data.empty(),
      );

      final updated = original.copyWith(
        section11: Section11Data(
          foundation: {'test': [{'text': 'new'}]},
          wall: {},
          roof: {},
          paint: {},
          pest: {'hasPest': false, 'note': ''},
          etc: {},
          safetyNotes: {},
          investigatorOpinion: '',
          grade: {'value': '', 'note': ''},
        ),
      );

      // Should be different instances
      expect(identical(original, updated), false);
      expect(updated.section11.foundation['test']?[0]['text'], 'new');
      expect(original.section11.foundation.isEmpty, true);
    });
  });
}
