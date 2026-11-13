import 'package:flutter/material.dart';
import 'package:hifz_helper/features/hifz_engine/models/hifz_tier_model.dart';

Future<HifzTierLengthSettings?> showTierLengthSettingsSheet(
  BuildContext context,
  HifzTierLengthSettings initialSettings,
) {
  return showModalBottomSheet<HifzTierLengthSettings>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _TierLengthSettingsSheet(initialSettings: initialSettings),
  );
}

class _TierLengthSettingsSheet extends StatefulWidget {
  final HifzTierLengthSettings initialSettings;

  const _TierLengthSettingsSheet({required this.initialSettings});

  @override
  State<_TierLengthSettingsSheet> createState() =>
      _TierLengthSettingsSheetState();
}

class _TierLengthSettingsSheetState extends State<_TierLengthSettingsSheet> {
  late HifzRangeUnit _sabaqUnit;
  late int _ayahCount;
  late int _sabqiDays;
  late HifzRangeUnit _manzilUnit;
  late final TextEditingController _sabaqCountController;
  late final TextEditingController _manzilCountController;
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    final settings = widget.initialSettings;
    _sabaqUnit = settings.sabaqUnit;
    _ayahCount = settings.sabaqCount;
    _sabqiDays = settings.sabqiDays;
    _manzilUnit = settings.manzilUnit;
    _sabaqCountController = TextEditingController(
      text: '${settings.sabaqCount}',
    );
    _manzilCountController = TextEditingController(
      text: '${settings.manzilCount}',
    );
  }

  @override
  void dispose() {
    _sabaqCountController.dispose();
    _manzilCountController.dispose();
    super.dispose();
  }

  void _save() {
    final sabaqCount = _sabaqUnit == HifzRangeUnit.ayah
        ? _ayahCount
        : int.tryParse(_sabaqCountController.text);
    final manzilCount = int.tryParse(_manzilCountController.text);
    if (sabaqCount == null ||
        sabaqCount <= 0 ||
        manzilCount == null ||
        manzilCount <= 0) {
      setState(
        () => _validationMessage = 'Enter a positive whole-number count.',
      );
      return;
    }

    final settings = HifzTierLengthSettings(
      sabaqUnit: _sabaqUnit,
      sabaqCount: sabaqCount,
      sabqiDays: _sabqiDays,
      manzilUnit: _manzilUnit,
      manzilCount: manzilCount,
    );
    settings.validate();
    Navigator.of(context).pop(settings);
  }

  String _unitLabel(HifzRangeUnit unit) => switch (unit) {
    HifzRangeUnit.ayah => 'Ayah',
    HifzRangeUnit.page => 'Page',
    HifzRangeUnit.ruku => 'Ruku',
    HifzRangeUnit.juz => 'Juz',
  };

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 8),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
  );

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomInset),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.tune),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Lesson Lengths',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _sectionTitle('Sabaq'),
                      DropdownButtonFormField<HifzRangeUnit>(
                        initialValue: _sabaqUnit,
                        decoration: const InputDecoration(labelText: 'Unit'),
                        items:
                            const [
                                  HifzRangeUnit.ayah,
                                  HifzRangeUnit.page,
                                  HifzRangeUnit.ruku,
                                ]
                                .map(
                                  (unit) => DropdownMenuItem(
                                    value: unit,
                                    child: Text(_unitLabel(unit)),
                                  ),
                                )
                                .toList(),
                        onChanged: (unit) {
                          if (unit != null) {
                            setState(() {
                              _sabaqUnit = unit;
                              if (unit == HifzRangeUnit.ayah &&
                                  !HifzTierLengthSettings.sabaqAyahPresets
                                      .contains(_ayahCount)) {
                                _ayahCount = 5;
                              }
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      if (_sabaqUnit == HifzRangeUnit.ayah)
                        DropdownButtonFormField<int>(
                          initialValue: _ayahCount,
                          decoration: const InputDecoration(labelText: 'Ayahs'),
                          items: HifzTierLengthSettings.sabaqAyahPresets
                              .map(
                                (count) => DropdownMenuItem(
                                  value: count,
                                  child: Text('$count ayahs'),
                                ),
                              )
                              .toList(),
                          onChanged: (count) {
                            if (count != null) {
                              setState(() => _ayahCount = count);
                            }
                          },
                        )
                      else
                        TextField(
                          controller: _sabaqCountController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText:
                                'Number of ${_unitLabel(_sabaqUnit).toLowerCase()}s',
                          ),
                        ),
                      _sectionTitle('Sabqi'),
                      DropdownButtonFormField<int>(
                        initialValue: _sabqiDays,
                        decoration: const InputDecoration(
                          labelText: 'Previous days',
                        ),
                        items: const [5, 7, 10]
                            .map(
                              (days) => DropdownMenuItem(
                                value: days,
                                child: Text('$days days'),
                              ),
                            )
                            .toList(),
                        onChanged: (days) {
                          if (days != null) setState(() => _sabqiDays = days);
                        },
                      ),
                      _sectionTitle('Manzil'),
                      DropdownButtonFormField<HifzRangeUnit>(
                        initialValue: _manzilUnit,
                        decoration: const InputDecoration(labelText: 'Unit'),
                        items:
                            const [
                                  HifzRangeUnit.ruku,
                                  HifzRangeUnit.page,
                                  HifzRangeUnit.juz,
                                ]
                                .map(
                                  (unit) => DropdownMenuItem(
                                    value: unit,
                                    child: Text(_unitLabel(unit)),
                                  ),
                                )
                                .toList(),
                        onChanged: (unit) {
                          if (unit != null) setState(() => _manzilUnit = unit);
                        },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _manzilCountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText:
                              'Number of ${_unitLabel(_manzilUnit).toLowerCase()}s',
                        ),
                      ),
                      if (_validationMessage != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _validationMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check),
                label: const Text('Apply changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
