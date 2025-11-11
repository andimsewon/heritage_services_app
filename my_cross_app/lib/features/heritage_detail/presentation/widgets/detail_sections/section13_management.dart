import 'package:flutter/material.dart';
import 'package:my_cross_app/core/widgets/bool_count_row.dart';
import 'package:my_cross_app/core/widgets/kv_row.dart';
import 'package:my_cross_app/models/survey_models.dart';
import 'detail_sections_strings_ko.dart';

class Section13Management extends StatefulWidget {
  final Section13Data data;
  final ValueChanged<Section13Data> onChanged;
  final bool enabled;

  const Section13Management({
    super.key,
    required this.data,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  State<Section13Management> createState() => _Section13ManagementState();
}

class _Section13ManagementState extends State<Section13Management> {
  late Section13Data _data;

  @override
  void initState() {
    super.initState();
    _data = widget.data;
  }

  @override
  void didUpdateWidget(Section13Management oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data != oldWidget.data) {
      _data = widget.data;
    }
  }

  void _updateData(Section13Data newData) {
    setState(() {
      _data = newData;
    });
    widget.onChanged(newData);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              stringsKo['sec_13']!,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Safety section
            _buildSafetySection(),
            
            const SizedBox(height: 24),
            
            // Electric section
            _buildElectricSection(),
            
            const SizedBox(height: 24),
            
            // Gas section
            _buildGasSection(),
            
            const SizedBox(height: 24),
            
            // Guard section
            _buildGuardSection(),
            
            const SizedBox(height: 24),
            
            // Care section
            _buildCareSection(),
            
            const SizedBox(height: 24),
            
            // Guide section
            _buildGuideSection(),
            
            const SizedBox(height: 24),
            
            // Surroundings section
            _buildSurroundingsSection(),
            
            const SizedBox(height: 24),
            
            // Usage section
            _buildUsageSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildSafetySection() {
    final safety = _data.safety;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          stringsKo['safety']!,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        
        // Manual
        SwitchListTile(
          title: Text(stringsKo['manual']!),
          value: safety['manual'] == true,
          onChanged: widget.enabled
              ? (value) {
                  final newSafety = Map<String, dynamic>.from(safety);
                  newSafety['manual'] = value;
                  _updateData(_data.copyWith(safety: newSafety));
                }
              : null,
        ),
        
        // Fire truck access
        SwitchListTile(
          title: Text(stringsKo['fireTruckAccess']!),
          value: safety['fireTruckAccess'] == true,
          onChanged: widget.enabled
              ? (value) {
                  final newSafety = Map<String, dynamic>.from(safety);
                  newSafety['fireTruckAccess'] = value;
                  _updateData(_data.copyWith(safety: newSafety));
                }
              : null,
        ),
        
        // Fire line
        SwitchListTile(
          title: Text(stringsKo['fireLine']!),
          value: safety['fireLine'] == true,
          onChanged: widget.enabled
              ? (value) {
                  final newSafety = Map<String, dynamic>.from(safety);
                  newSafety['fireLine'] = value;
                  _updateData(_data.copyWith(safety: newSafety));
                }
              : null,
        ),
        
        // Evacuation targets
        SwitchListTile(
          title: Text(stringsKo['evacTargets']!),
          value: safety['evacTargets'] == true,
          onChanged: widget.enabled
              ? (value) {
                  final newSafety = Map<String, dynamic>.from(safety);
                  newSafety['evacTargets'] = value;
                  _updateData(_data.copyWith(safety: newSafety));
                }
              : null,
        ),
        
        // Training
        SwitchListTile(
          title: Text(stringsKo['training']!),
          value: safety['training'] == true,
          onChanged: widget.enabled
              ? (value) {
                  final newSafety = Map<String, dynamic>.from(safety);
                  newSafety['training'] = value;
                  _updateData(_data.copyWith(safety: newSafety));
                }
              : null,
        ),
        
        const SizedBox(height: 16),
        
        // Equipment counts
        _buildEquipmentSection(),
        
        const SizedBox(height: 16),
        
        // Safety notes
        KeyValueRow(
          title: '특기사항',
          enabled: widget.enabled,
          value: TextFormField(
            initialValue: safety['notes'] ?? '',
            enabled: widget.enabled,
            maxLines: 3,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: '소방 및 안전관리 특기사항을 입력하세요',
            ),
            onChanged: (value) {
              final newSafety = Map<String, dynamic>.from(safety);
              newSafety['notes'] = value;
              _updateData(_data.copyWith(safety: newSafety));
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEquipmentSection() {
    final safety = _data.safety;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '소방시설 현황',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        
        // Extinguisher
        BoolCountRow(
          label: stringsKo['extinguisher']!,
          value: safety['extinguisher']?['exists'] == true,
          count: safety['extinguisher']?['count'] ?? 0,
          enabled: widget.enabled,
          onChanged: (value) {
            final newSafety = Map<String, dynamic>.from(safety);
            newSafety['extinguisher'] = {
              'exists': value,
              'count': value ? (newSafety['extinguisher']?['count'] ?? 0) : 0,
            };
            _updateData(_data.copyWith(safety: newSafety));
          },
          onCountChanged: (count) {
            final newSafety = Map<String, dynamic>.from(safety);
            newSafety['extinguisher'] = {
              'exists': true,
              'count': count,
            };
            _updateData(_data.copyWith(safety: newSafety));
          },
        ),
        
        // Hydrant
        BoolCountRow(
          label: stringsKo['hydrant']!,
          value: safety['hydrant']?['exists'] == true,
          count: safety['hydrant']?['count'] ?? 0,
          enabled: widget.enabled,
          onChanged: (value) {
            final newSafety = Map<String, dynamic>.from(safety);
            newSafety['hydrant'] = {
              'exists': value,
              'count': value ? (newSafety['hydrant']?['count'] ?? 0) : 0,
            };
            _updateData(_data.copyWith(safety: newSafety));
          },
          onCountChanged: (count) {
            final newSafety = Map<String, dynamic>.from(safety);
            newSafety['hydrant'] = {
              'exists': true,
              'count': count,
            };
            _updateData(_data.copyWith(safety: newSafety));
          },
        ),
        
        // Auto alarm
        BoolCountRow(
          label: stringsKo['autoAlarm']!,
          value: safety['autoAlarm']?['exists'] == true,
          count: safety['autoAlarm']?['count'] ?? 0,
          enabled: widget.enabled,
          onChanged: (value) {
            final newSafety = Map<String, dynamic>.from(safety);
            newSafety['autoAlarm'] = {
              'exists': value,
              'count': value ? (newSafety['autoAlarm']?['count'] ?? 0) : 0,
            };
            _updateData(_data.copyWith(safety: newSafety));
          },
          onCountChanged: (count) {
            final newSafety = Map<String, dynamic>.from(safety);
            newSafety['autoAlarm'] = {
              'exists': true,
              'count': count,
            };
            _updateData(_data.copyWith(safety: newSafety));
          },
        ),
        
        // CCTV
        BoolCountRow(
          label: stringsKo['cctv']!,
          value: safety['cctv']?['exists'] == true,
          count: safety['cctv']?['count'] ?? 0,
          enabled: widget.enabled,
          onChanged: (value) {
            final newSafety = Map<String, dynamic>.from(safety);
            newSafety['cctv'] = {
              'exists': value,
              'count': value ? (newSafety['cctv']?['count'] ?? 0) : 0,
            };
            _updateData(_data.copyWith(safety: newSafety));
          },
          onCountChanged: (count) {
            final newSafety = Map<String, dynamic>.from(safety);
            newSafety['cctv'] = {
              'exists': true,
              'count': count,
            };
            _updateData(_data.copyWith(safety: newSafety));
          },
        ),
        
        // Anti-theft camera
        BoolCountRow(
          label: stringsKo['antiTheftCam']!,
          value: safety['antiTheftCam']?['exists'] == true,
          count: safety['antiTheftCam']?['count'] ?? 0,
          enabled: widget.enabled,
          onChanged: (value) {
            final newSafety = Map<String, dynamic>.from(safety);
            newSafety['antiTheftCam'] = {
              'exists': value,
              'count': value ? (newSafety['antiTheftCam']?['count'] ?? 0) : 0,
            };
            _updateData(_data.copyWith(safety: newSafety));
          },
          onCountChanged: (count) {
            final newSafety = Map<String, dynamic>.from(safety);
            newSafety['antiTheftCam'] = {
              'exists': true,
              'count': count,
            };
            _updateData(_data.copyWith(safety: newSafety));
          },
        ),
        
        // Fire detector
        BoolCountRow(
          label: stringsKo['fireDetector']!,
          value: safety['fireDetector']?['exists'] == true,
          count: safety['fireDetector']?['count'] ?? 0,
          enabled: widget.enabled,
          onChanged: (value) {
            final newSafety = Map<String, dynamic>.from(safety);
            newSafety['fireDetector'] = {
              'exists': value,
              'count': value ? (newSafety['fireDetector']?['count'] ?? 0) : 0,
            };
            _updateData(_data.copyWith(safety: newSafety));
          },
          onCountChanged: (count) {
            final newSafety = Map<String, dynamic>.from(safety);
            newSafety['fireDetector'] = {
              'exists': true,
              'count': count,
            };
            _updateData(_data.copyWith(safety: newSafety));
          },
        ),
      ],
    );
  }

  Widget _buildElectricSection() {
    final electric = _data.electric;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          stringsKo['electric']!,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          title: const Text('정기 점검 실시'),
          value: electric['regularCheck'] == true,
          onChanged: widget.enabled
              ? (value) {
                  final newElectric = Map<String, dynamic>.from(electric);
                  newElectric['regularCheck'] = value;
                  _updateData(_data.copyWith(electric: newElectric));
                }
              : null,
        ),
        KeyValueRow(
          title: '비고',
          enabled: widget.enabled,
          value: TextFormField(
            initialValue: electric['notes'] ?? '',
            enabled: widget.enabled,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: '전기시설 관련 비고사항을 입력하세요',
            ),
            onChanged: (value) {
              final newElectric = Map<String, dynamic>.from(electric);
              newElectric['notes'] = value;
              _updateData(_data.copyWith(electric: newElectric));
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGasSection() {
    final gas = _data.gas;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          stringsKo['gas']!,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          title: const Text('정기 점검 실시'),
          value: gas['regularCheck'] == true,
          onChanged: widget.enabled
              ? (value) {
                  final newGas = Map<String, dynamic>.from(gas);
                  newGas['regularCheck'] = value;
                  _updateData(_data.copyWith(gas: newGas));
                }
              : null,
        ),
        KeyValueRow(
          title: '비고',
          enabled: widget.enabled,
          value: TextFormField(
            initialValue: gas['notes'] ?? '',
            enabled: widget.enabled,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: '가스시설 관련 비고사항을 입력하세요',
            ),
            onChanged: (value) {
              final newGas = Map<String, dynamic>.from(gas);
              newGas['notes'] = value;
              _updateData(_data.copyWith(gas: newGas));
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGuardSection() {
    final guard = _data.guard;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          stringsKo['guard']!,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          title: const Text('안전경비인력 배치'),
          value: guard['exists'] == true,
          onChanged: widget.enabled
              ? (value) {
                  final newGuard = Map<String, dynamic>.from(guard);
                  newGuard['exists'] = value;
                  _updateData(_data.copyWith(guard: newGuard));
                }
              : null,
        ),
        if (guard['exists'] == true) ...[
          KeyValueRow(
            title: '인원수',
            enabled: widget.enabled,
            value: TextFormField(
              initialValue: guard['headcount']?.toString() ?? '0',
              enabled: widget.enabled,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                final newGuard = Map<String, dynamic>.from(guard);
                newGuard['headcount'] = int.tryParse(value) ?? 0;
                _updateData(_data.copyWith(guard: newGuard));
              },
            ),
          ),
          KeyValueRow(
            title: '근무체계',
            enabled: widget.enabled,
            value: TextFormField(
              initialValue: guard['shift'] ?? '',
              enabled: widget.enabled,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '예: 8시간 3교대',
              ),
              onChanged: (value) {
                final newGuard = Map<String, dynamic>.from(guard);
                newGuard['shift'] = value;
                _updateData(_data.copyWith(guard: newGuard));
              },
            ),
          ),
          SwitchListTile(
            title: const Text('근무일지 작성'),
            value: guard['logbook'] == true,
            onChanged: widget.enabled
                ? (value) {
                    final newGuard = Map<String, dynamic>.from(guard);
                    newGuard['logbook'] = value;
                    _updateData(_data.copyWith(guard: newGuard));
                  }
                : null,
          ),
        ],
      ],
    );
  }

  Widget _buildCareSection() {
    final care = _data.care;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          stringsKo['care_business']!,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          title: const Text('돌봄사업 운영'),
          value: care['exists'] == true,
          onChanged: widget.enabled
              ? (value) {
                  final newCare = Map<String, dynamic>.from(care);
                  newCare['exists'] = value;
                  _updateData(_data.copyWith(care: newCare));
                }
              : null,
        ),
        if (care['exists'] == true)
          KeyValueRow(
            title: '운영기관',
            enabled: widget.enabled,
            value: TextFormField(
              initialValue: care['org'] ?? '',
              enabled: widget.enabled,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '돌봄사업 운영기관명을 입력하세요',
              ),
              onChanged: (value) {
                final newCare = Map<String, dynamic>.from(care);
                newCare['org'] = value;
                _updateData(_data.copyWith(care: newCare));
              },
            ),
          ),
      ],
    );
  }

  Widget _buildGuideSection() {
    final guide = _data.guide;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          stringsKo['guide']!,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          title: const Text('안내 키오스크'),
          value: guide['kiosk'] == true,
          onChanged: widget.enabled
              ? (value) {
                  final newGuide = Map<String, dynamic>.from(guide);
                  newGuide['kiosk'] = value;
                  _updateData(_data.copyWith(guide: newGuide));
                }
              : null,
        ),
        SwitchListTile(
          title: const Text('안내판'),
          value: guide['signBoard']?['exists'] == true,
          onChanged: widget.enabled
              ? (value) {
                  final newGuide = Map<String, dynamic>.from(guide);
                  newGuide['signBoard'] = {
                    'exists': value,
                    'where': value ? (newGuide['signBoard']?['where'] ?? '') : '',
                  };
                  _updateData(_data.copyWith(guide: newGuide));
                }
              : null,
        ),
        if (guide['signBoard']?['exists'] == true)
          KeyValueRow(
            title: '설치위치',
            enabled: widget.enabled,
            value: TextFormField(
              initialValue: guide['signBoard']?['where'] ?? '',
              enabled: widget.enabled,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '예: 정면, 1개소',
              ),
              onChanged: (value) {
                final newGuide = Map<String, dynamic>.from(guide);
                newGuide['signBoard'] = {
                  'exists': true,
                  'where': value,
                };
                _updateData(_data.copyWith(guide: newGuide));
              },
            ),
          ),
        SwitchListTile(
          title: const Text('박물관'),
          value: guide['museum'] == true,
          onChanged: widget.enabled
              ? (value) {
                  final newGuide = Map<String, dynamic>.from(guide);
                  newGuide['museum'] = value;
                  _updateData(_data.copyWith(guide: newGuide));
                }
              : null,
        ),
        SwitchListTile(
          title: const Text('해설사'),
          value: guide['interpreter'] == true,
          onChanged: widget.enabled
              ? (value) {
                  final newGuide = Map<String, dynamic>.from(guide);
                  newGuide['interpreter'] = value;
                  _updateData(_data.copyWith(guide: newGuide));
                }
              : null,
        ),
      ],
    );
  }

  Widget _buildSurroundingsSection() {
    final surroundings = _data.surroundings;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          stringsKo['surroundings']!,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        KeyValueRow(
          title: '담장',
          enabled: widget.enabled,
          value: TextFormField(
            initialValue: surroundings['wall'] ?? '',
            enabled: widget.enabled,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              final newSurroundings = Map<String, dynamic>.from(surroundings);
              newSurroundings['wall'] = value;
              _updateData(_data.copyWith(surroundings: newSurroundings));
            },
          ),
        ),
        KeyValueRow(
          title: '배수',
          enabled: widget.enabled,
          value: TextFormField(
            initialValue: surroundings['drainage'] ?? '',
            enabled: widget.enabled,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              final newSurroundings = Map<String, dynamic>.from(surroundings);
              newSurroundings['drainage'] = value;
              _updateData(_data.copyWith(surroundings: newSurroundings));
            },
          ),
        ),
        KeyValueRow(
          title: '수목',
          enabled: widget.enabled,
          value: TextFormField(
            initialValue: surroundings['trees'] ?? '',
            enabled: widget.enabled,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              final newSurroundings = Map<String, dynamic>.from(surroundings);
              newSurroundings['trees'] = value;
              _updateData(_data.copyWith(surroundings: newSurroundings));
            },
          ),
        ),
        KeyValueRow(
          title: '건물',
          enabled: widget.enabled,
          value: TextFormField(
            initialValue: surroundings['buildings'] ?? '',
            enabled: widget.enabled,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              final newSurroundings = Map<String, dynamic>.from(surroundings);
              newSurroundings['buildings'] = value;
              _updateData(_data.copyWith(surroundings: newSurroundings));
            },
          ),
        ),
        KeyValueRow(
          title: '대피소',
          enabled: widget.enabled,
          value: TextFormField(
            initialValue: surroundings['shelter'] ?? '',
            enabled: widget.enabled,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              final newSurroundings = Map<String, dynamic>.from(surroundings);
              newSurroundings['shelter'] = value;
              _updateData(_data.copyWith(surroundings: newSurroundings));
            },
          ),
        ),
        KeyValueRow(
          title: '기타',
          enabled: widget.enabled,
          value: TextFormField(
            initialValue: surroundings['others'] ?? '',
            enabled: widget.enabled,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              final newSurroundings = Map<String, dynamic>.from(surroundings);
              newSurroundings['others'] = value;
              _updateData(_data.copyWith(surroundings: newSurroundings));
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUsageSection() {
    final usage = _data.usage;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          stringsKo['usage']!,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        KeyValueRow(
          title: '사용현황',
          enabled: widget.enabled,
          value: TextFormField(
            initialValue: usage['note'] ?? '',
            enabled: widget.enabled,
            maxLines: 3,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: '원래기능/활용상태/사용빈도를 입력하세요',
            ),
            onChanged: (value) {
              final newUsage = Map<String, dynamic>.from(usage);
              newUsage['note'] = value;
              _updateData(_data.copyWith(usage: newUsage));
            },
          ),
        ),
      ],
    );
  }
}