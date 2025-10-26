import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/survey_models.dart';

class SurveyRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _surveys(String assetId) =>
      _firestore.collection('heritage_assets').doc(assetId).collection('surveys');

  /// Load survey data for a specific year
  Future<SurveyModel?> loadSurvey(String assetId, String year) async {
    if (kDebugMode) {
      print('[SurveyRepository] Loading survey for asset: $assetId, year: $year');
    }

    try {
      final doc = await _surveys(assetId).doc(year).get();
      if (!doc.exists) {
        if (kDebugMode) {
          print('[SurveyRepository] No survey found for year: $year');
        }
        return null;
      }

      final data = doc.data()!;
      if (kDebugMode) {
        print('[SurveyRepository] Loaded survey data, keys: ${data.keys}');
      }

      return SurveyModel.fromMap(year: year, data: data);
    } catch (e) {
      if (kDebugMode) {
        print('[SurveyRepository] Error loading survey: $e');
      }
      rethrow;
    }
  }

  /// Save survey data for a specific year
  Future<void> saveSurvey(
    String assetId,
    String year,
    SurveyModel data, {
    required String editorUid,
    bool adminOverride = false,
  }) async {
    if (kDebugMode) {
      print('[SurveyRepository] Saving survey for asset: $assetId, year: $year');
      print('[SurveyRepository] Payload size: ${data.toMap().toString().length} chars');
    }

    try {
      final ref = _surveys(assetId).doc(year);
      final snapshot = await ref.get();
      final previous = snapshot.data();
      final auditPayload = data.toMap();
      final firestorePayload = {
        ...auditPayload,
        'editorUid': editorUid,
        'generatedAt': FieldValue.serverTimestamp(),
      };

      await ref.set(firestorePayload, SetOptions(merge: true));

      final auditEntries = _buildAuditEntries(
        previous: previous,
        next: auditPayload,
        editorUid: editorUid,
        adminOverride: adminOverride,
      );
      await _appendAudit(assetId, year, auditEntries);

      if (kDebugMode) {
        print('[SurveyRepository] Survey saved successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[SurveyRepository] Error saving survey: $e');
      }
      rethrow;
    }
  }

  /// Import survey data from one year to another
  Future<void> importFromYear(
    String assetId,
    String fromYear,
    String toYear, {
    required String editorUid,
  }) async {
    if (kDebugMode) {
      print('[SurveyRepository] Importing from $fromYear to $toYear');
    }

    try {
      final sourceSurvey = await loadSurvey(assetId, fromYear);
      if (sourceSurvey == null) {
        throw Exception('Source survey not found for year: $fromYear');
      }

      // Create a copy with the new year
      final importedSurvey = SurveyModel(
        year: toYear,
        section11: sourceSurvey.section11,
        section12: sourceSurvey.section12,
        section13: sourceSurvey.section13,
        damageSummary: null, // Don't copy damage summary
        generatedAt: null,
        editorUid: editorUid,
        audit: [],
      );

      await saveSurvey(assetId, toYear, importedSurvey, editorUid: editorUid);

      // Add import audit entry
      await _appendAudit(assetId, toYear, [
        AuditLogEntry(
          timestamp: Timestamp.now(),
          uid: editorUid,
          action: 'import',
          path: '/',
          before: null,
          after: 'fromYear→toYear',
        ),
      ]);

      if (kDebugMode) {
        print('[SurveyRepository] Import completed successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[SurveyRepository] Error importing survey: $e');
      }
      rethrow;
    }
  }

  /// Get list of available years for an asset
  Future<List<String>> getAvailableYears(String assetId) async {
    if (kDebugMode) {
      print('[SurveyRepository] Getting available years for asset: $assetId');
    }

    try {
      final snapshot = await _surveys(assetId).get();
      final years = snapshot.docs
          .map((doc) => doc.id)
          .toList()
        ..sort((a, b) => b.compareTo(a)); // Descending order

      if (kDebugMode) {
        print('[SurveyRepository] Found years: $years');
      }

      return years;
    } catch (e) {
      if (kDebugMode) {
        print('[SurveyRepository] Error getting years: $e');
      }
      rethrow;
    }
  }

  /// Build audit entries for changes
  List<AuditLogEntry> _buildAuditEntries({
    required Map<String, dynamic>? previous,
    required Map<String, dynamic> next,
    required String editorUid,
    required bool adminOverride,
  }) {
    if (previous == null) {
      return [
        AuditLogEntry(
          timestamp: Timestamp.now(),
          uid: editorUid,
          action: 'create',
          path: '/',
          before: null,
          after: next,
        ),
      ];
    }

    final entries = <AuditLogEntry>[];
    final changes = _findChanges(previous, next);

    for (final change in changes) {
      entries.add(
        AuditLogEntry(
          timestamp: Timestamp.now(),
          uid: editorUid,
          action: adminOverride ? 'admin_update' : 'update',
          path: change['path'],
          before: change['before'],
          after: change['after'],
        ),
      );
    }

    return entries;
  }

  /// Find changes between two data maps
  List<Map<String, dynamic>> _findChanges(
    Map<String, dynamic> before,
    Map<String, dynamic> after,
  ) {
    final changes = <Map<String, dynamic>>[];

    for (final key in after.keys) {
      if (!before.containsKey(key) || before[key] != after[key]) {
        changes.add({
          'path': '/$key',
          'before': before[key],
          'after': after[key],
        });
      }
    }

    return changes;
  }

  /// Append audit entries to a survey
  Future<void> _appendAudit(
    String assetId,
    String year,
    List<AuditLogEntry> entries,
  ) async {
    if (entries.isEmpty) return;

    try {
      await _surveys(assetId).doc(year).update({
        'audit': FieldValue.arrayUnion(
          entries.map((entry) => entry.toMap()).toList(),
        ),
      });
    } catch (e) {
      if (kDebugMode) {
        print('[SurveyRepository] Error appending audit: $e');
      }
      rethrow;
    }
  }
}