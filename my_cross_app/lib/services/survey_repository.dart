import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();
const _deepEq = DeepCollectionEquality();

class SurveyRepository {
  SurveyRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _surveys(String assetId) =>
      _firestore.collection('heritage_assets').doc(assetId).collection('surveys');

  Future<SurveyModel?> loadSurvey(String assetId, String year) async {
    final ref = _surveys(assetId).doc(year);
    final snap = await ref.get();
    if (!snap.exists) {
      if (kDebugMode) {
        print('[SurveyRepository] loadSurvey → empty for $assetId/$year');
      }
      return null;
    }
    final sanitized = await _ensureSchema(
      assetId: assetId,
      year: year,
      ref: ref,
      data: snap.data() ?? <String, dynamic>{},
    );
    final model = SurveyModel.fromMap(year: year, data: sanitized);
    if (kDebugMode) {
      print('[SurveyRepository] loadSurvey → sections: '
          '${model.section12.length} rows, audit=${model.audit.length}');
    }
    return model;
  }

  Future<List<SurveyYearEntry>> fetchAvailableYears(String assetId) async {
    final query = await _surveys(assetId)
        .orderBy(FieldPath.documentId, descending: true)
        .get();
    final items = query.docs.map((doc) {
      final data = doc.data();
      final ts = data['generatedAt'];
      return SurveyYearEntry(
        year: doc.id,
        hasData: true,
        updatedAt: ts is Timestamp ? ts.toDate() : null,
      );
    }).toList();
    if (kDebugMode) {
      print('[SurveyRepository] fetchAvailableYears($assetId) → ${items.length}');
    }
    return items;
  }

  Future<void> saveSurvey(
    String assetId,
    String year,
    SurveyModel model, {
    required String editorUid,
    bool adminOverride = false,
  }) async {
    final ref = _surveys(assetId).doc(year);
    final snapshot = await ref.get();
    final previous = snapshot.data();
    final auditPayload = model.toAuditPayload();
    final firestorePayload = {
      ...model.toFirestorePayload(),
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
      print('[SurveyRepository] saveSurvey($assetId/$year) '
          'payloadKeys=${firestorePayload.keys}');
    }
  }

  Future<void> importFromYear(
    String assetId,
    String fromYear,
    String toYear, {
    required String editorUid,
  }) async {
    final collection = _surveys(assetId);
    final fromRef = collection.doc(fromYear);
    final toRef = collection.doc(toYear);

    final source = await fromRef.get();
    if (!source.exists) {
      throw Exception('출처 연도($fromYear)의 데이터가 없습니다.');
    }
    final raw = source.data() ?? <String, dynamic>{};
    final payload = {
      'section_11': raw['section_11'] ?? Section11Data.empty().toMap(),
      'section_12': List<Map<String, dynamic>>.from(
        (raw['section_12'] as List?)?.whereType<Map<String, dynamic>>() ?? const [],
      ),
      'section_13': raw['section_13'] ?? Section13Data.empty().toMap(),
      'editorUid': editorUid,
      'generatedAt': FieldValue.serverTimestamp(),
    };

    await toRef.set(payload, SetOptions(merge: true));

    final entry = AuditLogEntry(
      ts: DateTime.now(),
      uid: editorUid,
      action: 'import',
      path: '/',
      before: null,
      after: '$fromYear→$toYear',
    );
    await _appendAudit(assetId, toYear, [entry]);

    if (kDebugMode) {
      print('[SurveyRepository] importFromYear $fromYear→$toYear '
          'copied section_11..13');
    }
  }

  Future<Map<String, dynamic>> _ensureSchema({
    required String assetId,
    required String year,
    required DocumentReference<Map<String, dynamic>> ref,
    required Map<String, dynamic> data,
  }) async {
    final sanitized = Map<String, dynamic>.from(data);
    final updates = <String, dynamic>{};

    void ensure(String key, dynamic defaultValue) {
      if (!sanitized.containsKey(key)) {
        sanitized[key] = defaultValue;
        updates[key] = defaultValue;
      }
    }

    ensure('section_11', Section11Data.empty().toMap());
    ensure('section_12', <Map<String, dynamic>>[]);
    ensure('section_13', Section13Data.empty().toMap());

    if (updates.isNotEmpty) {
      await ref.set(updates, SetOptions(merge: true));
      if (kDebugMode) {
        print('[SurveyRepository] schema backfilled for $assetId/$year '
            'keys=${updates.keys}');
      }
    }
    return sanitized;
  }

  Future<void> _appendAudit(
    String assetId,
    String year,
    List<AuditLogEntry> entries,
  ) async {
    if (entries.isEmpty) return;
    final ref = _surveys(assetId).doc(year);
    final auditMaps = entries.map((e) => e.toMap()).toList();
    await ref.set({'audit': FieldValue.arrayUnion(auditMaps)}, SetOptions(merge: true));
  }

  List<AuditLogEntry> _buildAuditEntries({
    required Map<String, dynamic>? previous,
    required Map<String, dynamic> next,
    required String editorUid,
    required bool adminOverride,
  }) {
    final ts = DateTime.now();
    if (!adminOverride) {
      return [
        AuditLogEntry(
          ts: ts,
          uid: editorUid,
          action: 'update',
          path: '/',
          before: previous,
          after: next,
        ),
      ];
    }

    final keys = ['section_11', 'section_12', 'section_13'];
    final List<AuditLogEntry> entries = [];
    for (final key in keys) {
      if (!_deepEq.equals(previous?[key], next[key])) {
        entries.add(
          AuditLogEntry(
            ts: ts,
            uid: editorUid,
            action: 'update',
            path: '/$key',
            before: previous?[key],
            after: next[key],
          ),
        );
      }
    }

    if (entries.isEmpty) {
      entries.add(
        AuditLogEntry(
          ts: ts,
          uid: editorUid,
          action: 'update',
          path: '/',
          before: previous,
          after: next,
        ),
      );
    }
    return entries;
  }
}

class SurveyModel {
  SurveyModel({
    required this.year,
    required this.section11,
    required this.section12,
    required this.section13,
    this.damageSummary,
    this.generatedAt,
    this.editorUid,
    this.audit = const [],
  });

  final String year;
  final Section11Data section11;
  final List<Section12Row> section12;
  final Section13Data section13;
  final Map<String, dynamic>? damageSummary;
  final DateTime? generatedAt;
  final String? editorUid;
  final List<AuditLogEntry> audit;

  SurveyModel copyWith({
    Section11Data? section11,
    List<Section12Row>? section12,
    Section13Data? section13,
    Map<String, dynamic>? damageSummary,
  }) {
    return SurveyModel(
      year: year,
      section11: section11 ?? this.section11,
      section12: section12 ?? this.section12,
      section13: section13 ?? this.section13,
      damageSummary: damageSummary ?? this.damageSummary,
      generatedAt: generatedAt,
      editorUid: editorUid,
      audit: audit,
    );
  }

  Map<String, dynamic> toFirestorePayload() => {
        'section_11': section11.toMap(),
        'section_12': section12.map((row) => row.toMap()).toList(),
        'section_13': section13.toMap(),
        if (damageSummary != null) 'damage_summary': damageSummary,
      };

  Map<String, dynamic> toAuditPayload() => {
        'section_11': section11.toMap(),
        'section_12': section12.map((row) => row.toMap()).toList(),
        'section_13': section13.toMap(),
        if (damageSummary != null) 'damage_summary': damageSummary,
      };

  factory SurveyModel.fromMap({
    required String year,
    required Map<String, dynamic> data,
  }) {
    final rows = (data['section_12'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(Section12Row.fromMap)
            .toList() ??
        const <Section12Row>[];
    final auditEntries = (data['audit'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(AuditLogEntry.fromMap)
            .toList() ??
        const <AuditLogEntry>[];
    return SurveyModel(
      year: year,
      section11: Section11Data.fromMap(data['section_11'] as Map<String, dynamic>?),
      section12: rows,
      section13: Section13Data.fromMap(data['section_13'] as Map<String, dynamic>?),
      damageSummary: data['damage_summary'] as Map<String, dynamic>?,
      generatedAt: (data['generatedAt'] as Timestamp?)?.toDate(),
      editorUid: data['editorUid'] as String?,
      audit: auditEntries,
    );
  }

  factory SurveyModel.empty(String year) => SurveyModel(
        year: year,
        section11: Section11Data.empty(),
        section12: const [],
        section13: Section13Data.empty(),
      );
}

class Section11Data {
  const Section11Data({
    required this.foundation,
    required this.wall,
    required this.roof,
    required this.paint,
    required this.pest,
    required this.etc,
    required this.safetyNotes,
    required this.investigatorOpinion,
    required this.grade,
  });

  final List<String> foundation;
  final List<String> wall;
  final List<String> roof;
  final List<String> paint;
  final PestInfo pest;
  final List<String> etc;
  final List<String> safetyNotes;
  final String investigatorOpinion;
  final GradeInfo grade;

  Section11Data copyWith({
    List<String>? foundation,
    List<String>? wall,
    List<String>? roof,
    List<String>? paint,
    PestInfo? pest,
    List<String>? etc,
    List<String>? safetyNotes,
    String? investigatorOpinion,
    GradeInfo? grade,
  }) {
    return Section11Data(
      foundation: foundation ?? this.foundation,
      wall: wall ?? this.wall,
      roof: roof ?? this.roof,
      paint: paint ?? this.paint,
      pest: pest ?? this.pest,
      etc: etc ?? this.etc,
      safetyNotes: safetyNotes ?? this.safetyNotes,
      investigatorOpinion: investigatorOpinion ?? this.investigatorOpinion,
      grade: grade ?? this.grade,
    );
  }

  Map<String, dynamic> toMap() => {
        'foundation': _textListToMap(foundation),
        'wall': _textListToMap(wall),
        'roof': _textListToMap(roof),
        'paint': _textListToMap(paint),
        'pest': pest.toMap(),
        'etc': _textListToMap(etc),
        'safetyNotes': _textListToMap(safetyNotes),
        'investigatorOpinion': investigatorOpinion,
        'grade': grade.toMap(),
      };

  factory Section11Data.fromMap(Map<String, dynamic>? map) {
    map ??= const {};
    return Section11Data(
      foundation: _textListFrom(map['foundation']),
      wall: _textListFrom(map['wall']),
      roof: _textListFrom(map['roof']),
      paint: _textListFrom(map['paint']),
      pest: PestInfo.fromMap(map['pest'] as Map<String, dynamic>?),
      etc: _textListFrom(map['etc']),
      safetyNotes: _textListFrom(map['safetyNotes']),
      investigatorOpinion: map['investigatorOpinion'] as String? ?? '',
      grade: GradeInfo.fromMap(map['grade'] as Map<String, dynamic>?),
    );
  }

  factory Section11Data.empty() => Section11Data(
        foundation: const [],
        wall: const [],
        roof: const [],
        paint: const [],
        pest: PestInfo.empty(),
        etc: const [],
        safetyNotes: const [],
        investigatorOpinion: '',
        grade: GradeInfo.empty(),
      );
}

class PestInfo {
  const PestInfo({required this.hasPest, required this.note});

  final bool hasPest;
  final String note;

  PestInfo copyWith({bool? hasPest, String? note}) => PestInfo(
        hasPest: hasPest ?? this.hasPest,
        note: note ?? this.note,
      );

  Map<String, dynamic> toMap() => {
        'hasPest': hasPest,
        'note': note,
      };

  factory PestInfo.fromMap(Map<String, dynamic>? map) {
    map ??= const {};
    return PestInfo(
      hasPest: map['hasPest'] as bool? ?? false,
      note: map['note'] as String? ?? '',
    );
  }

  factory PestInfo.empty() => const PestInfo(hasPest: false, note: '');
}

class GradeInfo {
  const GradeInfo({required this.value, required this.note});

  final String value;
  final String note;

  GradeInfo copyWith({String? value, String? note}) => GradeInfo(
        value: value ?? this.value,
        note: note ?? this.note,
      );

  Map<String, dynamic> toMap() => {
        'value': value,
        'note': note,
      };

  factory GradeInfo.fromMap(Map<String, dynamic>? map) {
    map ??= const {};
    return GradeInfo(
      value: map['value'] as String? ?? '',
      note: map['note'] as String? ?? '',
    );
  }

  factory GradeInfo.empty() => const GradeInfo(value: '', note: '');
}

class Section12Row {
  Section12Row({
    required this.id,
    required this.group,
    required this.part,
    required this.content,
    required this.ref,
  });

  final String id;
  final String group;
  final String part;
  final String content;
  final String ref;

  Section12Row copyWith({
    String? group,
    String? part,
    String? content,
    String? ref,
  }) {
    return Section12Row(
      id: id,
      group: group ?? this.group,
      part: part ?? this.part,
      content: content ?? this.content,
      ref: ref ?? this.ref,
    );
  }

  Map<String, dynamic> toMap() => {
        'group': group,
        'part': part,
        'content': content,
        'ref': ref,
      };

  factory Section12Row.fromMap(Map<String, dynamic> map) {
    return Section12Row(
      id: map['id'] as String? ?? _uuid.v4(),
      group: map['group'] as String? ?? '',
      part: map['part'] as String? ?? '',
      content: map['content'] as String? ?? '',
      ref: map['ref'] as String? ?? '',
    );
  }

  factory Section12Row.empty() => Section12Row(
        id: _uuid.v4(),
        group: '',
        part: '',
        content: '',
        ref: '',
      );
}

class Section13Data {
  const Section13Data({
    required this.safety,
    required this.electric,
    required this.gas,
    required this.guard,
    required this.care,
    required this.guide,
    required this.surroundings,
    required this.usage,
  });

  final SafetyManagement safety;
  final ElectricInfo electric;
  final GasInfo gas;
  final GuardInfo guard;
  final CareInfo care;
  final GuideInfo guide;
  final SurroundingsInfo surroundings;
  final UsageInfo usage;

  Section13Data copyWith({
    SafetyManagement? safety,
    ElectricInfo? electric,
    GasInfo? gas,
    GuardInfo? guard,
    CareInfo? care,
    GuideInfo? guide,
    SurroundingsInfo? surroundings,
    UsageInfo? usage,
  }) {
    return Section13Data(
      safety: safety ?? this.safety,
      electric: electric ?? this.electric,
      gas: gas ?? this.gas,
      guard: guard ?? this.guard,
      care: care ?? this.care,
      guide: guide ?? this.guide,
      surroundings: surroundings ?? this.surroundings,
      usage: usage ?? this.usage,
    );
  }

  Map<String, dynamic> toMap() => {
        'safety': safety.toMap(),
        'electric': electric.toMap(),
        'gas': gas.toMap(),
        'guard': guard.toMap(),
        'care': care.toMap(),
        'guide': guide.toMap(),
        'surroundings': surroundings.toMap(),
        'usage': usage.toMap(),
      };

  factory Section13Data.fromMap(Map<String, dynamic>? map) {
    map ??= const {};
    return Section13Data(
      safety: SafetyManagement.fromMap(map['safety'] as Map<String, dynamic>?),
      electric: ElectricInfo.fromMap(map['electric'] as Map<String, dynamic>?),
      gas: GasInfo.fromMap(map['gas'] as Map<String, dynamic>?),
      guard: GuardInfo.fromMap(map['guard'] as Map<String, dynamic>?),
      care: CareInfo.fromMap(map['care'] as Map<String, dynamic>?),
      guide: GuideInfo.fromMap(map['guide'] as Map<String, dynamic>?),
      surroundings: SurroundingsInfo.fromMap(map['surroundings'] as Map<String, dynamic>?),
      usage: UsageInfo.fromMap(map['usage'] as Map<String, dynamic>?),
    );
  }

  factory Section13Data.empty() => Section13Data(
        safety: SafetyManagement.empty(),
        electric: ElectricInfo.empty(),
        gas: GasInfo.empty(),
        guard: GuardInfo.empty(),
        care: CareInfo.empty(),
        guide: GuideInfo.empty(),
        surroundings: SurroundingsInfo.empty(),
        usage: UsageInfo.empty(),
      );
}

class SafetyManagement {
  const SafetyManagement({
    required this.manual,
    required this.fireTruckAccess,
    required this.fireLine,
    required this.evacTargets,
    required this.training,
    required this.extinguisher,
    required this.hydrant,
    required this.autoAlarm,
    required this.cctv,
    required this.antiTheftCam,
    required this.fireDetector,
    required this.notes,
  });

  final bool manual;
  final bool fireTruckAccess;
  final bool fireLine;
  final bool evacTargets;
  final bool training;
  final EquipmentEntry extinguisher;
  final EquipmentEntry hydrant;
  final EquipmentEntry autoAlarm;
  final EquipmentEntry cctv;
  final EquipmentEntry antiTheftCam;
  final EquipmentEntry fireDetector;
  final String notes;

  SafetyManagement copyWith({
    bool? manual,
    bool? fireTruckAccess,
    bool? fireLine,
    bool? evacTargets,
    bool? training,
    EquipmentEntry? extinguisher,
    EquipmentEntry? hydrant,
    EquipmentEntry? autoAlarm,
    EquipmentEntry? cctv,
    EquipmentEntry? antiTheftCam,
    EquipmentEntry? fireDetector,
    String? notes,
  }) {
    return SafetyManagement(
      manual: manual ?? this.manual,
      fireTruckAccess: fireTruckAccess ?? this.fireTruckAccess,
      fireLine: fireLine ?? this.fireLine,
      evacTargets: evacTargets ?? this.evacTargets,
      training: training ?? this.training,
      extinguisher: extinguisher ?? this.extinguisher,
      hydrant: hydrant ?? this.hydrant,
      autoAlarm: autoAlarm ?? this.autoAlarm,
      cctv: cctv ?? this.cctv,
      antiTheftCam: antiTheftCam ?? this.antiTheftCam,
      fireDetector: fireDetector ?? this.fireDetector,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() => {
        'manual': manual,
        'fireTruckAccess': fireTruckAccess,
        'fireLine': fireLine,
        'evacTargets': evacTargets,
        'training': training,
        'extinguisher': extinguisher.toMap(),
        'hydrant': hydrant.toMap(),
        'autoAlarm': autoAlarm.toMap(),
        'cctv': cctv.toMap(),
        'antiTheftCam': antiTheftCam.toMap(),
        'fireDetector': fireDetector.toMap(),
        'notes': notes,
      };

  factory SafetyManagement.fromMap(Map<String, dynamic>? map) {
    map ??= const {};
    return SafetyManagement(
      manual: map['manual'] as bool? ?? false,
      fireTruckAccess: map['fireTruckAccess'] as bool? ?? false,
      fireLine: map['fireLine'] as bool? ?? false,
      evacTargets: map['evacTargets'] as bool? ?? false,
      training: map['training'] as bool? ?? false,
      extinguisher: EquipmentEntry.fromMap(map['extinguisher'] as Map<String, dynamic>?),
      hydrant: EquipmentEntry.fromMap(map['hydrant'] as Map<String, dynamic>?),
      autoAlarm: EquipmentEntry.fromMap(map['autoAlarm'] as Map<String, dynamic>?),
      cctv: EquipmentEntry.fromMap(map['cctv'] as Map<String, dynamic>?),
      antiTheftCam: EquipmentEntry.fromMap(map['antiTheftCam'] as Map<String, dynamic>?),
      fireDetector: EquipmentEntry.fromMap(map['fireDetector'] as Map<String, dynamic>?),
      notes: map['notes'] as String? ?? '',
    );
  }

  factory SafetyManagement.empty() => SafetyManagement(
        manual: false,
        fireTruckAccess: false,
        fireLine: false,
        evacTargets: false,
        training: false,
        extinguisher: EquipmentEntry.empty(),
        hydrant: EquipmentEntry.empty(),
        autoAlarm: EquipmentEntry.empty(),
        cctv: EquipmentEntry.empty(),
        antiTheftCam: EquipmentEntry.empty(),
        fireDetector: EquipmentEntry.empty(),
        notes: '',
      );
}

class EquipmentEntry {
  const EquipmentEntry({required this.exists, required this.count});

  final bool exists;
  final int count;

  EquipmentEntry copyWith({bool? exists, int? count}) => EquipmentEntry(
        exists: exists ?? this.exists,
        count: count ?? this.count,
      );

  Map<String, dynamic> toMap() => {
        'exists': exists,
        'count': count,
      };

  factory EquipmentEntry.fromMap(Map<String, dynamic>? map) {
    map ??= const {};
    return EquipmentEntry(
      exists: map['exists'] as bool? ?? false,
      count: (map['count'] as num?)?.toInt() ?? 0,
    );
  }

  factory EquipmentEntry.empty() => const EquipmentEntry(exists: false, count: 0);
}

class ElectricInfo {
  const ElectricInfo({required this.regularCheck, required this.notes});

  final bool regularCheck;
  final String notes;

  ElectricInfo copyWith({bool? regularCheck, String? notes}) => ElectricInfo(
        regularCheck: regularCheck ?? this.regularCheck,
        notes: notes ?? this.notes,
      );

  Map<String, dynamic> toMap() => {
        'regularCheck': regularCheck,
        'notes': notes,
      };

  factory ElectricInfo.fromMap(Map<String, dynamic>? map) {
    map ??= const {};
    return ElectricInfo(
      regularCheck: map['regularCheck'] as bool? ?? false,
      notes: map['notes'] as String? ?? '',
    );
  }

  factory ElectricInfo.empty() => const ElectricInfo(regularCheck: false, notes: '');
}

class GasInfo {
  const GasInfo({required this.regularCheck, required this.notes});

  final bool regularCheck;
  final String notes;

  GasInfo copyWith({bool? regularCheck, String? notes}) => GasInfo(
        regularCheck: regularCheck ?? this.regularCheck,
        notes: notes ?? this.notes,
      );

  Map<String, dynamic> toMap() => {
        'regularCheck': regularCheck,
        'notes': notes,
      };

  factory GasInfo.fromMap(Map<String, dynamic>? map) {
    map ??= const {};
    return GasInfo(
      regularCheck: map['regularCheck'] as bool? ?? false,
      notes: map['notes'] as String? ?? '',
    );
  }

  factory GasInfo.empty() => const GasInfo(regularCheck: false, notes: '');
}

class GuardInfo {
  const GuardInfo({
    required this.exists,
    required this.headcount,
    required this.shift,
    required this.logbook,
  });

  final bool exists;
  final int headcount;
  final String shift;
  final bool logbook;

  GuardInfo copyWith({
    bool? exists,
    int? headcount,
    String? shift,
    bool? logbook,
  }) => GuardInfo(
        exists: exists ?? this.exists,
        headcount: headcount ?? this.headcount,
        shift: shift ?? this.shift,
        logbook: logbook ?? this.logbook,
      );

  Map<String, dynamic> toMap() => {
        'exists': exists,
        'headcount': headcount,
        'shift': shift,
        'logbook': logbook,
      };

  factory GuardInfo.fromMap(Map<String, dynamic>? map) {
    map ??= const {};
    return GuardInfo(
      exists: map['exists'] as bool? ?? false,
      headcount: (map['headcount'] as num?)?.toInt() ?? 0,
      shift: map['shift'] as String? ?? '',
      logbook: map['logbook'] as bool? ?? false,
    );
  }

  factory GuardInfo.empty() => const GuardInfo(
        exists: false,
        headcount: 0,
        shift: '',
        logbook: false,
      );
}

class CareInfo {
  const CareInfo({required this.exists, required this.org});

  final bool exists;
  final String org;

  CareInfo copyWith({bool? exists, String? org}) => CareInfo(
        exists: exists ?? this.exists,
        org: org ?? this.org,
      );

  Map<String, dynamic> toMap() => {
        'exists': exists,
        'org': org,
      };

  factory CareInfo.fromMap(Map<String, dynamic>? map) {
    map ??= const {};
    return CareInfo(
      exists: map['exists'] as bool? ?? false,
      org: map['org'] as String? ?? '',
    );
  }

  factory CareInfo.empty() => const CareInfo(exists: false, org: '');
}

class GuideInfo {
  const GuideInfo({
    required this.kiosk,
    required this.signBoardExists,
    required this.signBoardWhere,
    required this.museum,
    required this.interpreter,
  });

  final bool kiosk;
  final bool signBoardExists;
  final String signBoardWhere;
  final bool museum;
  final bool interpreter;

  GuideInfo copyWith({
    bool? kiosk,
    bool? signBoardExists,
    String? signBoardWhere,
    bool? museum,
    bool? interpreter,
  }) => GuideInfo(
        kiosk: kiosk ?? this.kiosk,
        signBoardExists: signBoardExists ?? this.signBoardExists,
        signBoardWhere: signBoardWhere ?? this.signBoardWhere,
        museum: museum ?? this.museum,
        interpreter: interpreter ?? this.interpreter,
      );

  Map<String, dynamic> toMap() => {
        'kiosk': kiosk,
        'signBoard': {
          'exists': signBoardExists,
          'where': signBoardWhere,
        },
        'museum': museum,
        'interpreter': interpreter,
      };

  factory GuideInfo.fromMap(Map<String, dynamic>? map) {
    map ??= const {};
    final signBoard = map['signBoard'] as Map<String, dynamic>?;
    return GuideInfo(
      kiosk: map['kiosk'] as bool? ?? false,
      signBoardExists: signBoard?['exists'] as bool? ?? false,
      signBoardWhere: signBoard?['where'] as String? ?? '',
      museum: map['museum'] as bool? ?? false,
      interpreter: map['interpreter'] as bool? ?? false,
    );
  }

  factory GuideInfo.empty() => const GuideInfo(
        kiosk: false,
        signBoardExists: false,
        signBoardWhere: '',
        museum: false,
        interpreter: false,
      );
}

class SurroundingsInfo {
  const SurroundingsInfo({
    required this.wall,
    required this.drainage,
    required this.trees,
    required this.buildings,
    required this.shelter,
    required this.others,
  });

  final String wall;
  final String drainage;
  final String trees;
  final String buildings;
  final String shelter;
  final String others;

  SurroundingsInfo copyWith({
    String? wall,
    String? drainage,
    String? trees,
    String? buildings,
    String? shelter,
    String? others,
  }) => SurroundingsInfo(
        wall: wall ?? this.wall,
        drainage: drainage ?? this.drainage,
        trees: trees ?? this.trees,
        buildings: buildings ?? this.buildings,
        shelter: shelter ?? this.shelter,
        others: others ?? this.others,
      );

  Map<String, dynamic> toMap() => {
        'wall': wall,
        'drainage': drainage,
        'trees': trees,
        'buildings': buildings,
        'shelter': shelter,
        'others': others,
      };

  factory SurroundingsInfo.fromMap(Map<String, dynamic>? map) {
    map ??= const {};
    return SurroundingsInfo(
      wall: map['wall'] as String? ?? '',
      drainage: map['drainage'] as String? ?? '',
      trees: map['trees'] as String? ?? '',
      buildings: map['buildings'] as String? ?? '',
      shelter: map['shelter'] as String? ?? '',
      others: map['others'] as String? ?? '',
    );
  }

  factory SurroundingsInfo.empty() => const SurroundingsInfo(
        wall: '',
        drainage: '',
        trees: '',
        buildings: '',
        shelter: '',
        others: '',
      );
}

class UsageInfo {
  const UsageInfo({required this.note});

  final String note;

  UsageInfo copyWith({String? note}) => UsageInfo(note: note ?? this.note);

  Map<String, dynamic> toMap() => {'note': note};

  factory UsageInfo.fromMap(Map<String, dynamic>? map) {
    map ??= const {};
    return UsageInfo(note: map['note'] as String? ?? '');
  }

  factory UsageInfo.empty() => const UsageInfo(note: '');
}

class AuditLogEntry {
  const AuditLogEntry({
    required this.ts,
    required this.uid,
    required this.action,
    required this.path,
    this.before,
    this.after,
  });

  final DateTime ts;
  final String uid;
  final String action;
  final String path;
  final dynamic before;
  final dynamic after;

  Map<String, dynamic> toMap() => {
        'ts': Timestamp.fromDate(ts),
        'uid': uid,
        'action': action,
        'path': path,
        if (before != null) 'before': before,
        if (after != null) 'after': after,
      };

  factory AuditLogEntry.fromMap(Map<String, dynamic> map) {
    final ts = map['ts'];
    return AuditLogEntry(
      ts: ts is Timestamp ? ts.toDate() : DateTime.now(),
      uid: map['uid'] as String? ?? 'unknown',
      action: map['action'] as String? ?? 'unknown',
      path: map['path'] as String? ?? '/',
      before: map['before'],
      after: map['after'],
    );
  }
}

class SurveyYearEntry {
  const SurveyYearEntry({
    required this.year,
    required this.hasData,
    this.updatedAt,
  });

  final String year;
  final bool hasData;
  final DateTime? updatedAt;
}

List<Map<String, dynamic>> _textListToMap(List<String> values) =>
    values
        .where((text) => text.trim().isNotEmpty)
        .map((text) => {'text': text.trim()})
        .toList();

List<String> _textListFrom(dynamic raw) {
  if (raw is List) {
    return raw
        .map((entry) {
          if (entry is Map<String, dynamic>) {
            return entry['text'] as String? ?? '';
          }
          return entry?.toString() ?? '';
        })
        .where((text) => text.trim().isNotEmpty)
        .map((text) => text.trim())
        .toList();
  }
  return const [];
}
