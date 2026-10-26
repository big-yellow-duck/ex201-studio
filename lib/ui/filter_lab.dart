import 'package:flutter/material.dart';

import '../application/help_book.dart';
import '../domain/audio_math.dart';
import 'charts.dart';
import 'controls.dart';
import 'theme.dart';

class FilterLab extends StatefulWidget {
  final HelpBook help;
  final int band;
  final int initialType;
  final bool previewOnly;
  const FilterLab({
    super.key,
    required this.help,
    required this.band,
    this.initialType = 0,
    this.previewOnly = false,
  });
  @override
  State<FilterLab> createState() => _FilterLabState();
}

class _FilterLabState extends State<FilterLab> {
  int type = 0;
  double frequency = 1000, q = 1, gain = -3;
  @override
  void initState() {
    super.initState();
    type = widget.initialType;
    final example = widget.help.filter(type)['example'];
    frequency = (example['frequency'] as num).toDouble();
    q = (example['q'] as num).toDouble();
    gain = (example['gain'] as num).toDouble();
  }

  void choose(int value) {
    final ex = widget.help.filter(value)['example'];
    setState(() {
      type = value;
      frequency = (ex['frequency'] as num).toDouble();
      q = (ex['q'] as num).toDouble();
      gain = (ex['gain'] as num).toDouble();
    });
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.help.filter(type),
        band = EqBand(1, type, true, frequency, q, gain);
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 850),
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: SectionHeading(
                      'The filter explorer',
                      subtitle:
                          'A local lesson. Nothing is sent to your board.',
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close explorer',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ResponsiveColumns(
                        minimum: 380,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FrequencyChart(bands: [band], showHandles: false),
                              Text(
                                f['what'],
                                style: const TextStyle(fontSize: 13),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                f['use'],
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              DropdownButtonFormField<int>(
                                key: ValueKey('lab-$type'),
                                initialValue: type,
                                isExpanded: true,
                                items: List.generate(
                                  9,
                                  (i) => DropdownMenuItem(
                                    value: i,
                                    child: Text(
                                      widget.help.filter(i)['name'],
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ),
                                onChanged: (v) {
                                  if (v != null) choose(v);
                                },
                              ),
                              const SizedBox(height: 18),
                              NumberControl(
                                label: 'Frequency',
                                unit: 'Hz',
                                value: frequency,
                                min: 20,
                                max: 20000,
                                logarithmic: true,
                                onChanged: (v) => setState(() => frequency = v),
                                help: f['frequency'],
                              ),
                              const SizedBox(height: 15),
                              NumberControl(
                                label: 'Q',
                                value: q,
                                min: .1,
                                max: 10,
                                logarithmic: true,
                                enabled: f['usesQ'],
                                onChanged: (v) => setState(() => q = v),
                                help: f['q'],
                              ),
                              const SizedBox(height: 15),
                              NumberControl(
                                label: 'Gain',
                                unit: 'dB',
                                value: gain,
                                min: -12,
                                max: 12,
                                enabled: f['gain'],
                                onChanged: (v) => setState(() => gain = v),
                                help: f['gain']
                                    ? 'Negative cuts; positive boosts.'
                                    : 'This filter does not use gain in the preview.',
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const SectionHeading(
                        'Nine ways to shape a signal',
                        subtitle: 'Choose a shape to see how it behaves.',
                      ),
                      LayoutBuilder(
                        builder: (context, c) {
                          final count = c.maxWidth > 650 ? 3 : 2,
                              width = (c.maxWidth - (count - 1) * 10) / count;
                          return Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: List.generate(9, (i) {
                              final filter = widget.help.filter(i),
                                  ex = filter['example'];
                              return SizedBox(
                                width: width,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => choose(i),
                                  child: Container(
                                    padding: const EdgeInsets.all(13),
                                    decoration: BoxDecoration(
                                      color: i == type
                                          ? StudioColors.pale
                                          : StudioColors.background,
                                      border: Border.all(
                                        color: i == type
                                            ? StudioColors.green
                                            : StudioColors.line,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        FrequencyChart(
                                          bands: [
                                            EqBand(
                                              1,
                                              i,
                                              true,
                                              (ex['frequency'] as num)
                                                  .toDouble(),
                                              (ex['q'] as num).toDouble(),
                                              (ex['gain'] as num).toDouble(),
                                            ),
                                          ],
                                          compact: true,
                                          showHandles: false,
                                        ),
                                        Text(
                                          filter['name'],
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        Text(
                                          filter['short'],
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Calculated at an assumed 48 kHz. These are standard filter models, not measurements of the EX201 or your speakers.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.icon(
                    key: const ValueKey('copy-filter-draft'),
                    onPressed: () => Navigator.pop(
                      context,
                      widget.previewOnly
                          ? null
                          : {
                              'band_${widget.band}_enabled': true,
                              'band_${widget.band}_type': type,
                              'band_${widget.band}_frequency_hz': frequency
                                  .roundToDouble(),
                              'band_${widget.band}_q': q,
                              'band_${widget.band}_gain_db': f['gain']
                                  ? gain
                                  : 0.0,
                            },
                    ),
                    icon: const Icon(Icons.south_east_rounded, size: 16),
                    label: Text(
                      widget.previewOnly
                          ? 'Done exploring'
                          : 'Use in band ${widget.band} draft',
                    ),
                  ),
                  Text(
                    widget.previewOnly
                        ? 'Open an EQ editor to use an example in a band draft.'
                        : 'Apply the editor draft when you are ready to listen.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
