import 'package:cloud_firestore/cloud_firestore.dart';

/// Section 1.1 - Investigation Results
class Section11Data {
  final Map<String, List<Map<String, String>>> foundation;
  final Map<String, List<Map<String, String>>> wall;
  final Map<String, List<Map<String, String>>> roof;
  final Map<String, List<Map<String, String>>> paint;
  final Map<String, dynamic> pest;
  final Map<String, List<Map<String, String>>> etc;
  final Map<String, List<Map<String, String>>> safetyNotes;
  final String investigatorOpinion;
  final Map<String, dynamic> grade;

  Section11Data({
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

  factory Section11Data.empty() => Section11Data(
        foundation: {},
        wall: {},
        roof: {},
        paint: {},
        pest: {'hasPest': false, 'note': ''},
        etc: {},
        safetyNotes: {},
        investigatorOpinion: '',
        grade: {'value': '', 'note': ''},
      );

  Map<String, dynamic> toMap() => {
        'foundation': foundation,
        'wall': wall,
        'roof': roof,
        'paint': paint,
        'pest': pest,
        'etc': etc,
        'safetyNotes': safetyNotes,
        'investigatorOpinion': investigatorOpinion,
        'grade': grade,
      };

  factory Section11Data.fromMap(Map<String, dynamic> map) => Section11Data(
        foundation: Map<String, List<Map<String, String>>>.from(
          map['foundation'] ?? {},
        ),
        wall: Map<String, List<Map<String, String>>>.from(
          map['wall'] ?? {},
        ),
        roof: Map<String, List<Map<String, String>>>.from(
          map['roof'] ?? {},
        ),
        paint: Map<String, List<Map<String, String>>>.from(
          map['paint'] ?? {},
        ),
        pest: Map<String, dynamic>.from(map['pest'] ?? {}),
        etc: Map<String, List<Map<String, String>>>.from(
          map['etc'] ?? {},
        ),
        safetyNotes: Map<String, List<Map<String, String>>>.from(
          map['safetyNotes'] ?? {},
        ),
        investigatorOpinion: map['investigatorOpinion'] ?? '',
        grade: Map<String, dynamic>.from(map['grade'] ?? {}),
      );

  Section11Data copyWith({
    Map<String, List<Map<String, String>>>? foundation,
    Map<String, List<Map<String, String>>>? wall,
    Map<String, List<Map<String, String>>>? roof,
    Map<String, List<Map<String, String>>>? paint,
    Map<String, dynamic>? pest,
    Map<String, List<Map<String, String>>>? etc,
    Map<String, List<Map<String, String>>>? safetyNotes,
    String? investigatorOpinion,
    Map<String, dynamic>? grade,
  }) =>
      Section11Data(
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

/// Section 1.2 - Conservation Items (Wooden Structure)
class Section12Row {
  final String group;
  final String part;
  final String content;
  final String photoRef;

  Section12Row({
    required this.group,
    required this.part,
    required this.content,
    required this.photoRef,
  });

  Map<String, dynamic> toMap() => {
        'group': group,
        'part': part,
        'content': content,
        'photoRef': photoRef,
      };

  factory Section12Row.fromMap(Map<String, dynamic> map) => Section12Row(
        group: map['group'] ?? '',
        part: map['part'] ?? '',
        content: map['content'] ?? '',
        photoRef: map['photoRef'] ?? '',
      );
}

/// Section 1.3 - Management Items
class Section13Data {
  final Map<String, dynamic> safety;
  final Map<String, dynamic> electric;
  final Map<String, dynamic> gas;
  final Map<String, dynamic> guard;
  final Map<String, dynamic> care;
  final Map<String, dynamic> guide;
  final Map<String, dynamic> surroundings;
  final Map<String, dynamic> usage;

  Section13Data({
    required this.safety,
    required this.electric,
    required this.gas,
    required this.guard,
    required this.care,
    required this.guide,
    required this.surroundings,
    required this.usage,
  });

  factory Section13Data.empty() => Section13Data(
        safety: {
          'manual': false,
          'fireTruckAccess': false,
          'fireLine': false,
          'evacTargets': false,
          'training': false,
          'extinguisher': {'exists': false, 'count': 0},
          'hydrant': {'exists': false, 'count': 0},
          'autoAlarm': {'exists': false, 'count': 0},
          'cctv': {'exists': false, 'count': 0},
          'antiTheftCam': {'exists': false, 'count': 0},
          'fireDetector': {'exists': false, 'count': 0},
          'notes': '',
        },
        electric: {'regularCheck': false, 'notes': ''},
        gas: {'regularCheck': false, 'notes': ''},
        guard: {'exists': false, 'headcount': 0, 'shift': '', 'logbook': false},
        care: {'exists': false, 'org': ''},
        guide: {
          'kiosk': false,
          'signBoard': {'exists': false, 'where': ''},
          'museum': false,
          'interpreter': false,
        },
        surroundings: {
          'wall': '',
          'drainage': '',
          'trees': '',
          'buildings': '',
          'shelter': '',
          'others': '',
        },
        usage: {'note': ''},
      );

  Map<String, dynamic> toMap() => {
        'safety': safety,
        'electric': electric,
        'gas': gas,
        'guard': guard,
        'care': care,
        'guide': guide,
        'surroundings': surroundings,
        'usage': usage,
      };

  factory Section13Data.fromMap(Map<String, dynamic> map) => Section13Data(
        safety: Map<String, dynamic>.from(map['safety'] ?? {}),
        electric: Map<String, dynamic>.from(map['electric'] ?? {}),
        gas: Map<String, dynamic>.from(map['gas'] ?? {}),
        guard: Map<String, dynamic>.from(map['guard'] ?? {}),
        care: Map<String, dynamic>.from(map['care'] ?? {}),
        guide: Map<String, dynamic>.from(map['guide'] ?? {}),
        surroundings: Map<String, dynamic>.from(map['surroundings'] ?? {}),
        usage: Map<String, dynamic>.from(map['usage'] ?? {}),
      );

  Section13Data copyWith({
    Map<String, dynamic>? safety,
    Map<String, dynamic>? electric,
    Map<String, dynamic>? gas,
    Map<String, dynamic>? guard,
    Map<String, dynamic>? care,
    Map<String, dynamic>? guide,
    Map<String, dynamic>? surroundings,
    Map<String, dynamic>? usage,
  }) =>
      Section13Data(
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

/// Damage Summary
class DamageSummary {
  final Map<String, dynamic> byPart;
  final String finalGrade;
  final String finalNote;

  DamageSummary({
    required this.byPart,
    required this.finalGrade,
    required this.finalNote,
  });

  factory DamageSummary.empty() => DamageSummary(
        byPart: {},
        finalGrade: '',
        finalNote: '',
      );

  Map<String, dynamic> toMap() => {
        'byPart': byPart,
        'finalGrade': finalGrade,
        'finalNote': finalNote,
      };

  factory DamageSummary.fromMap(Map<String, dynamic> map) => DamageSummary(
        byPart: Map<String, dynamic>.from(map['byPart'] ?? {}),
        finalGrade: map['finalGrade'] ?? '',
        finalNote: map['finalNote'] ?? '',
      );
}

/// Audit Log Entry
class AuditLogEntry {
  final Timestamp timestamp;
  final String uid;
  final String action;
  final String path;
  final dynamic before;
  final dynamic after;

  AuditLogEntry({
    required this.timestamp,
    required this.uid,
    required this.action,
    required this.path,
    this.before,
    this.after,
  });

  Map<String, dynamic> toMap() => {
        'timestamp': timestamp,
        'uid': uid,
        'action': action,
        'path': path,
        if (before != null) 'before': before,
        if (after != null) 'after': after,
      };

  factory AuditLogEntry.fromMap(Map<String, dynamic> map) => AuditLogEntry(
        timestamp: map['timestamp'] as Timestamp,
        uid: map['uid'] ?? '',
        action: map['action'] ?? '',
        path: map['path'] ?? '',
        before: map['before'],
        after: map['after'],
      );
}

/// Complete Survey Model
class SurveyModel {
  final String year;
  final Section11Data section11;
  final List<Section12Row> section12;
  final Section13Data section13;
  final DamageSummary? damageSummary;
  final Timestamp? generatedAt;
  final String? editorUid;
  final List<AuditLogEntry> audit;

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

  Map<String, dynamic> toMap() => {
        'section_11': section11.toMap(),
        'section_12': section12.map((row) => row.toMap()).toList(),
        'section_13': section13.toMap(),
        if (damageSummary != null) 'damage_summary': damageSummary!.toMap(),
        if (generatedAt != null) 'generatedAt': generatedAt,
        if (editorUid != null) 'editorUid': editorUid,
        'audit': audit.map((entry) => entry.toMap()).toList(),
      };

  factory SurveyModel.fromMap({
    required String year,
    required Map<String, dynamic> data,
  }) =>
      SurveyModel(
        year: year,
        section11: Section11Data.fromMap(data['section_11'] ?? {}),
        section12: (data['section_12'] as List<dynamic>? ?? [])
            .map((item) => Section12Row.fromMap(item as Map<String, dynamic>))
            .toList(),
        section13: Section13Data.fromMap(data['section_13'] ?? {}),
        damageSummary: data['damage_summary'] != null
            ? DamageSummary.fromMap(data['damage_summary'])
            : null,
        generatedAt: data['generatedAt'] as Timestamp?,
        editorUid: data['editorUid'],
        audit: (data['audit'] as List<dynamic>? ?? [])
            .map((item) => AuditLogEntry.fromMap(item as Map<String, dynamic>))
            .toList(),
      );

  SurveyModel copyWith({
    Section11Data? section11,
    List<Section12Row>? section12,
    Section13Data? section13,
    DamageSummary? damageSummary,
  }) =>
      SurveyModel(
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
