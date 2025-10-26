import 'package:flutter/material.dart';

import '../../services/survey_repository.dart';
import '../../widgets/bool_count_row.dart';
import '../../widgets/kv_row.dart';
import 'detail_sections_strings_ko.dart';

class Section13Management extends StatelessWidget {
  const Section13Management({
    super.key,
    required this.data,
    required this.onChanged,
    this.enabled = true,
  });

  final Section13Data data;
  final ValueChanged<Section13Data> onChanged;
  final bool enabled;

  void _emit(Section13Data value) => onChanged(value);

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.7,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                stringsKo['sec_13']!,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              _buildSafetyBlock(),
              const Divider(height: 32),
              _buildElectricGas(),
              const Divider(height: 32),
              _buildGuardCare(),
              const Divider(height: 32),
              _buildGuideBlock(),
              const Divider(height: 32),
              _buildSurroundings(),
              const SizedBox(height: 16),
              _buildUsage(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSafetyBlock() {
    final safety = data.safety;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(stringsKo['safety']!, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        _toggleTile(
          label: stringsKo['manual']!,
          value: safety.manual,
          onChanged: (value) => _emit(
            data.copyWith(safety: safety.copyWith(manual: value)),
          ),
        ),
        _toggleTile(
          label: stringsKo['fireTruckAccess']!,
          value: safety.fireTruckAccess,
          onChanged: (value) => _emit(
            data.copyWith(safety: safety.copyWith(fireTruckAccess: value)),
          ),
        ),
        _toggleTile(
          label: stringsKo['fireLine']!,
          value: safety.fireLine,
          onChanged: (value) => _emit(
            data.copyWith(safety: safety.copyWith(fireLine: value)),
          ),
        ),
        _toggleTile(
          label: stringsKo['evacTargets']!,
          value: safety.evacTargets,
          onChanged: (value) => _emit(
            data.copyWith(safety: safety.copyWith(evacTargets: value)),
          ),
        ),
        _toggleTile(
          label: stringsKo['training']!,
          value: safety.training,
          onChanged: (value) => _emit(
            data.copyWith(safety: safety.copyWith(training: value)),
          ),
        ),
        const SizedBox(height: 12),
        BoolCountRow(
          label: stringsKo['extinguisher']!,
          value: safety.extinguisher.exists,
          count: safety.extinguisher.count,
          enabled: enabled,
          onChanged: (value) => _emit(
            data.copyWith(safety: safety.copyWith(
              extinguisher: safety.extinguisher.copyWith(exists: value),
            )),
          ),
          onCountChanged: (count) => _emit(
            data.copyWith(safety: safety.copyWith(
              extinguisher: safety.extinguisher.copyWith(count: count),
            )),
          ),
        ),
        BoolCountRow(
          label: stringsKo['hydrant']!,
          value: safety.hydrant.exists,
          count: safety.hydrant.count,
          enabled: enabled,
          onChanged: (value) => _emit(
            data.copyWith(safety: safety.copyWith(
              hydrant: safety.hydrant.copyWith(exists: value),
            )),
          ),
          onCountChanged: (count) => _emit(
            data.copyWith(safety: safety.copyWith(
              hydrant: safety.hydrant.copyWith(count: count),
            )),
          ),
        ),
        BoolCountRow(
          label: stringsKo['autoAlarm']!,
          value: safety.autoAlarm.exists,
          count: safety.autoAlarm.count,
          enabled: enabled,
          onChanged: (value) => _emit(
            data.copyWith(safety: safety.copyWith(
              autoAlarm: safety.autoAlarm.copyWith(exists: value),
            )),
          ),
          onCountChanged: (count) => _emit(
            data.copyWith(safety: safety.copyWith(
              autoAlarm: safety.autoAlarm.copyWith(count: count),
            )),
          ),
        ),
        BoolCountRow(
          label: stringsKo['cctv']!,
          value: safety.cctv.exists,
          count: safety.cctv.count,
          enabled: enabled,
          onChanged: (value) => _emit(
            data.copyWith(safety: safety.copyWith(
              cctv: safety.cctv.copyWith(exists: value),
            )),
          ),
          onCountChanged: (count) => _emit(
            data.copyWith(safety: safety.copyWith(
              cctv: safety.cctv.copyWith(count: count),
            )),
          ),
        ),
        BoolCountRow(
          label: stringsKo['antiTheftCam']!,
          value: safety.antiTheftCam.exists,
          count: safety.antiTheftCam.count,
          enabled: enabled,
          onChanged: (value) => _emit(
            data.copyWith(safety: safety.copyWith(
              antiTheftCam: safety.antiTheftCam.copyWith(exists: value),
            )),
          ),
          onCountChanged: (count) => _emit(
            data.copyWith(safety: safety.copyWith(
              antiTheftCam: safety.antiTheftCam.copyWith(count: count),
            )),
          ),
        ),
        BoolCountRow(
          label: stringsKo['fireDetector']!,
          value: safety.fireDetector.exists,
          count: safety.fireDetector.count,
          enabled: enabled,
          onChanged: (value) => _emit(
            data.copyWith(safety: safety.copyWith(
              fireDetector: safety.fireDetector.copyWith(exists: value),
            )),
          ),
          onCountChanged: (count) => _emit(
            data.copyWith(safety: safety.copyWith(
              fireDetector: safety.fireDetector.copyWith(count: count),
            )),
          ),
        ),
        TextFormField(
          enabled: enabled,
          initialValue: safety.notes,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: '비고',
          ),
          onChanged: enabled
              ? (value) => _emit(
                    data.copyWith(
                      safety: safety.copyWith(notes: value),
                    ),
                  )
              : null,
        ),
      ],
    );
  }

  Widget _buildElectricGas() {
    final electric = data.electric;
    final gas = data.gas;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _toggleTile(
          label: stringsKo['electric']!,
          value: electric.regularCheck,
          onChanged: (value) => _emit(
            data.copyWith(electric: electric.copyWith(regularCheck: value)),
          ),
        ),
        TextFormField(
          enabled: enabled,
          initialValue: electric.notes,
          decoration: const InputDecoration(labelText: '전기시설 비고'),
          onChanged: enabled
              ? (value) => _emit(
                    data.copyWith(electric: electric.copyWith(notes: value)),
                  )
              : null,
        ),
        const SizedBox(height: 12),
        _toggleTile(
          label: stringsKo['gas']!,
          value: gas.regularCheck,
          onChanged: (value) => _emit(
            data.copyWith(gas: gas.copyWith(regularCheck: value)),
          ),
        ),
        TextFormField(
          enabled: enabled,
          initialValue: gas.notes,
          decoration: const InputDecoration(labelText: '가스시설 비고'),
          onChanged: enabled
              ? (value) => _emit(data.copyWith(gas: gas.copyWith(notes: value)))
              : null,
        ),
      ],
    );
  }

  Widget _buildGuardCare() {
    final guard = data.guard;
    final care = data.care;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _toggleTile(
          label: stringsKo['guard']!,
          value: guard.exists,
          onChanged: (value) => _emit(
            data.copyWith(guard: guard.copyWith(exists: value)),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                enabled: enabled,
                initialValue: guard.headcount.toString(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '인원 수'),
                onChanged: enabled
                    ? (value) => _emit(
                          data.copyWith(
                            guard: guard.copyWith(
                              headcount: int.tryParse(value) ?? guard.headcount,
                            ),
                          ),
                        )
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                enabled: enabled,
                initialValue: guard.shift,
                decoration: const InputDecoration(labelText: '근무 형태'),
                onChanged: enabled
                    ? (value) => _emit(
                          data.copyWith(guard: guard.copyWith(shift: value)),
                        )
                    : null,
              ),
            ),
          ],
        ),
        _toggleTile(
          label: '근무 일지 작성 여부',
          value: guard.logbook,
          onChanged: (value) => _emit(
            data.copyWith(guard: guard.copyWith(logbook: value)),
          ),
        ),
        const SizedBox(height: 12),
        _toggleTile(
          label: stringsKo['care_business']!,
          value: care.exists,
          onChanged: (value) => _emit(
            data.copyWith(care: care.copyWith(exists: value)),
          ),
        ),
        TextFormField(
          enabled: enabled,
          initialValue: care.org,
          decoration: const InputDecoration(labelText: '수행 기관'),
          onChanged: enabled
              ? (value) => _emit(
                    data.copyWith(care: care.copyWith(org: value)),
                  )
              : null,
        ),
      ],
    );
  }

  Widget _buildGuideBlock() {
    final guide = data.guide;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(stringsKo['guide']!, style: const TextStyle(fontWeight: FontWeight.w700)),
        _toggleTile(
          label: '키오스크',
          value: guide.kiosk,
          onChanged: (value) => _emit(
            data.copyWith(guide: guide.copyWith(kiosk: value)),
          ),
        ),
        _toggleTile(
          label: '전시/박물관',
          value: guide.museum,
          onChanged: (value) => _emit(
            data.copyWith(guide: guide.copyWith(museum: value)),
          ),
        ),
        _toggleTile(
          label: '해설 인력',
          value: guide.interpreter,
          onChanged: (value) => _emit(
            data.copyWith(guide: guide.copyWith(interpreter: value)),
          ),
        ),
        _toggleTile(
          label: '안내판 설치 여부',
          value: guide.signBoardExists,
          onChanged: (value) => _emit(
            data.copyWith(guide: guide.copyWith(signBoardExists: value)),
          ),
        ),
        TextFormField(
          enabled: enabled,
          initialValue: guide.signBoardWhere,
          decoration: const InputDecoration(labelText: '안내판 위치/수량'),
          onChanged: enabled
              ? (value) => _emit(
                    data.copyWith(guide: guide.copyWith(signBoardWhere: value)),
                  )
              : null,
        ),
      ],
    );
  }

  Widget _buildSurroundings() {
    final s = data.surroundings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(stringsKo['surroundings']!, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        KeyValueRow(
          title: '성곽/담장',
          enabled: enabled,
          value: TextFormField(
            enabled: enabled,
            initialValue: s.wall,
            onChanged: enabled
                ? (value) => _emit(
                      data.copyWith(
                        surroundings: s.copyWith(wall: value),
                      ),
                    )
                : null,
          ),
        ),
        KeyValueRow(
          title: '배수',
          enabled: enabled,
          value: TextFormField(
            enabled: enabled,
            initialValue: s.drainage,
            onChanged: enabled
                ? (value) => _emit(data.copyWith(
                      surroundings: s.copyWith(drainage: value),
                    ))
                : null,
          ),
        ),
        KeyValueRow(
          title: '수목',
          enabled: enabled,
          value: TextFormField(
            enabled: enabled,
            initialValue: s.trees,
            onChanged: enabled
                ? (value) => _emit(data.copyWith(
                      surroundings: s.copyWith(trees: value),
                    ))
                : null,
          ),
        ),
        KeyValueRow(
          title: '건축물',
          enabled: enabled,
          value: TextFormField(
            enabled: enabled,
            initialValue: s.buildings,
            onChanged: enabled
                ? (value) => _emit(data.copyWith(
                      surroundings: s.copyWith(buildings: value),
                    ))
                : null,
          ),
        ),
        KeyValueRow(
          title: '대피/휴게',
          enabled: enabled,
          value: TextFormField(
            enabled: enabled,
            initialValue: s.shelter,
            onChanged: enabled
                ? (value) => _emit(data.copyWith(
                      surroundings: s.copyWith(shelter: value),
                    ))
                : null,
          ),
        ),
        KeyValueRow(
          title: '기타',
          enabled: enabled,
          value: TextFormField(
            enabled: enabled,
            initialValue: s.others,
            onChanged: enabled
                ? (value) => _emit(data.copyWith(
                      surroundings: s.copyWith(others: value),
                    ))
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildUsage() {
    final usage = data.usage;
    return TextFormField(
      enabled: enabled,
      initialValue: usage.note,
      minLines: 3,
      maxLines: 6,
      decoration: InputDecoration(labelText: stringsKo['usage']),
      onChanged: enabled
          ? (value) => _emit(data.copyWith(usage: usage.copyWith(note: value)))
          : null,
    );
  }

  Widget _toggleTile({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile.adaptive(
      title: Text(label),
      value: value,
      onChanged: enabled ? onChanged : null,
    );
  }
}
