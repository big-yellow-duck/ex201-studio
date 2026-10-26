import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../application/draft.dart';
import '../application/help_book.dart';
import '../domain/audio_math.dart';
import '../domain/models.dart';
import '../domain/parameters.dart';
import 'charts.dart';
import 'controls.dart';
import 'filter_lab.dart';
import 'theme.dart';

class EffectPage extends StatefulWidget {
  final DspEffect effect;
  final HelpBook help;
  final bool learning, busy, connected;
  final Future<bool> Function(int, Map<String, Object?>) apply;
  final ValueChanged<bool> onDirty;
  const EffectPage({
    super.key,
    required this.effect,
    required this.help,
    required this.learning,
    required this.busy,
    required this.connected,
    required this.apply,
    required this.onDirty,
  });
  @override
  State<EffectPage> createState() => _EffectPageState();
}

class _EffectPageState extends State<EffectPage> {
  late final EffectDraft draft;
  int band = 1, path = 3;
  double chartRange = 24;
  @override
  void initState() {
    super.initState();
    draft = EffectDraft(widget.effect);
    draft.addListener(_changed);
  }

  void _changed() {
    widget.onDirty(draft.dirty);
    setState(() {});
  }

  @override
  void dispose() {
    draft.removeListener(_changed);
    draft.dispose();
    super.dispose();
  }

  Widget _help() {
    final data = widget.help.effect(widget.effect.type);
    if (data.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: SurfaceCard(
        color: StudioColors.pale.withValues(alpha: .5),
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.lightbulb_outline_rounded,
              size: 19,
              color: StudioColors.green,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data['what']),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: const EdgeInsets.only(bottom: 8),
                    visualDensity: VisualDensity.compact,
                    title: const Text(
                      'How to use this effect',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    children: [
                      Text(
                        '${data['try']}\n\n${data['watch']}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _apply() async {
    if (draft.errors.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Check the highlighted numeric fields first.'),
        ),
      );
      return;
    }
    try {
      final changes = draft.changes;
      if (changes.isEmpty) return;
      final success = await widget.apply(widget.effect.address, changes);
      if (success && mounted) {
        draft.reset();
      }
    } on FormatException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Widget _footer() => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 23, vertical: 14),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: StudioColors.line)),
    ),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 15,
      runSpacing: 10,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              draft.dirty
                  ? Icons.edit_note_rounded
                  : Icons.check_circle_outline_rounded,
              size: 20,
              color: draft.dirty ? StudioColors.ochre : StudioColors.green,
            ),
            const SizedBox(width: 10),
            Text(
              draft.dirty
                  ? '${draft.changedCount} draft change${draft.changedCount == 1 ? '' : 's'} · not yet applied'
                  : 'Matches the last board read',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              key: const ValueKey('discard-draft'),
              onPressed: draft.dirty && !widget.busy ? draft.reset : null,
              child: const Text('Discard drafts'),
            ),
            const SizedBox(width: 10),
            FilledButton.icon(
              key: const ValueKey('apply-draft'),
              onPressed:
                  draft.dirty &&
                      draft.errors.isEmpty &&
                      widget.connected &&
                      !widget.busy
                  ? _apply
                  : null,
              icon: const Icon(Icons.check_rounded, size: 17),
              label: const Text('Apply changes'),
            ),
          ],
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    if (!widget.effect.editable) {
      return const Center(
        child: Text('This effect layout is available for inspection only.'),
      );
    }
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 25, 28, 30),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.effect.title,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineLarge,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${widget.effect.group} processing  /  ${widget.effect.name.split(':').last}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Tag(
                          widget.effect.enabled
                              ? 'Applied · enabled'
                              : 'Applied · bypassed',
                          icon: widget.effect.enabled
                              ? Icons.graphic_eq_rounded
                              : Icons.pause_rounded,
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    if (widget.learning) _help(),
                    if (widget.effect.isEq) ..._eq() else ..._generic(),
                    const SizedBox(height: 15),
                    Text(
                      'Applied edits are checked against the complete parameter block. Store on board keeps your tuning across power-off.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        _footer(),
      ],
    );
  }

  List<Widget> _eq() {
    final bands = EqBand.fromValues(draft.values),
        selected = bands[band - 1],
        preamp = draft.number('pregain_db'),
        peak = peakDb(bands, preamp),
        filter = widget.help.filter(selected.type);
    return [
      SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeading(
              'Your EQ curve',
              subtitle:
                  'Green: combined draft + preamp   ·   Ochre: selected band',
              trailing: DropdownButton<double>(
                value: chartRange,
                underline: const SizedBox.shrink(),
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 11,
                  color: StudioColors.muted,
                ),
                items: [6.0, 12.0, 24.0, 48.0]
                    .map(
                      (v) => DropdownMenuItem(
                        value: v,
                        child: Text('±${v.round()} dB'),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => chartRange = v!),
              ),
            ),
            FrequencyChart(
              bands: bands,
              preamp: preamp,
              range: chartRange,
              selected: band,
              onDrag: widget.busy
                  ? null
                  : (i, f, g) {
                      setState(() => band = i);
                      final type = bands[i - 1].type;
                      draft.setMany({
                        'band_${i}_frequency_hz': f.roundToDouble(),
                        if (type <= 2)
                          'band_${i}_gain_db': (g * 10).round() / 10,
                      });
                    },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 7,
              children: bands
                  .map(
                    (b) => ChoiceChip(
                      key: ValueKey('band-${b.band}'),
                      label: Text(b.band.toString().padLeft(2, '0')),
                      selected: band == b.band,
                      onSelected: (_) => setState(() => band = b.band),
                      avatar: Icon(
                        b.enabled ? Icons.circle : Icons.circle_outlined,
                        size: 9,
                        color: StudioColors.green,
                      ),
                      labelStyle: const TextStyle(fontSize: 11),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 7,
                      ),
                      side: const BorderSide(color: StudioColors.line),
                      showCheckmark: false,
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 17),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Tag(
                  draft.flag('enabled')
                      ? 'Enabled in draft'
                      : 'Bypassed in draft',
                  color: draft.flag('enabled')
                      ? StudioColors.green
                      : StudioColors.ochre,
                  icon: draft.flag('enabled')
                      ? Icons.play_arrow_rounded
                      : Icons.pause_rounded,
                ),
                Text(
                  '48 kHz assumed · calculated response',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (widget.learning)
                  TextButton.icon(
                    key: const ValueKey('open-filter-explorer'),
                    onPressed: () async {
                      final result = await showDialog<Map<String, Object>>(
                        context: context,
                        builder: (context) =>
                            FilterLab(help: widget.help, band: band),
                      );
                      if (result != null && mounted) draft.setMany(result);
                    },
                    icon: const Icon(Icons.auto_stories_outlined, size: 16),
                    label: const Text('Explore filter shapes'),
                  ),
              ],
            ),
            if (widget.learning) ...[
              const Divider(height: 26),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    peak > .1
                        ? Icons.space_dashboard_outlined
                        : Icons.check_circle_outline_rounded,
                    size: 16,
                    color: peak > .1 ? StudioColors.ochre : StudioColors.green,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Estimated peak ${displayNumber(peak)} dB. ${peak > .1 ? 'About ${displayNumber(peak)} dB of extra preamp cut would offset this model’s peak boost.' : 'No positive peak boost in this preview.'} Source level and other effects also affect headroom.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 18),
      ResponsiveColumns(
        minimum: 400,
        children: [
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeading(
                  'Band ${band.toString().padLeft(2, '0')}',
                  subtitle: filter['short'],
                  trailing: Switch(
                    key: const ValueKey('selected-band-enabled'),
                    value: selected.enabled,
                    onChanged: widget.busy
                        ? null
                        : (v) {
                            final update = <String, Object>{
                              'band_${band}_enabled': v,
                            };
                            if (v && !selected.valid) {
                              update.addAll({
                                'band_${band}_frequency_hz': 1000.0,
                                'band_${band}_q': .70703125,
                              });
                            }
                            draft.setMany(update);
                          },
                  ),
                ),
                DropdownButtonFormField<int>(
                  key: ValueKey('band-filter-$band-${selected.type}'),
                  initialValue: selected.type,
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
                  onChanged: widget.busy
                      ? null
                      : (v) {
                          if (v != null) draft.set('band_${band}_type', v);
                        },
                ),
                const SizedBox(height: 20),
                NumberControl(
                  key: ValueKey('frequency-$band-${draft.resetEpoch}'),
                  label: 'Frequency',
                  unit: 'Hz',
                  value: selected.frequency,
                  min: 20,
                  max: 24000,
                  logarithmic: true,
                  integer: true,
                  enabled: !widget.busy,
                  help: widget.learning ? filter['frequency'] : null,
                  onValidation: (issue) =>
                      _validate('band_${band}_frequency_hz', issue),
                  onChanged: (v) => draft.set('band_${band}_frequency_hz', v),
                ),
                const SizedBox(height: 12),
                NumberControl(
                  key: ValueKey('q-$band-${draft.resetEpoch}'),
                  label: 'Q',
                  value: math.max(.05, selected.q),
                  min: .05,
                  max: 30,
                  logarithmic: true,
                  enabled: !widget.busy && filter['usesQ'],
                  help: widget.learning ? filter['q'] : null,
                  onValidation: (issue) => _validate('band_${band}_q', issue),
                  onChanged: (v) => draft.set('band_${band}_q', v),
                ),
                const SizedBox(height: 12),
                NumberControl(
                  key: ValueKey('gain-$band-${draft.resetEpoch}'),
                  label: 'Gain',
                  unit: 'dB',
                  value: selected.gain,
                  min: -36,
                  max: 36,
                  enabled: !widget.busy && filter['gain'],
                  help: widget.learning
                      ? (filter['gain']
                            ? 'Negative cuts; positive boosts.'
                            : 'Gain is unused for this filter type.')
                      : null,
                  onValidation: (issue) =>
                      _validate('band_${band}_gain_db', issue),
                  onChanged: (v) => draft.set('band_${band}_gain_db', v),
                ),
              ],
            ),
          ),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeading(
                  'EQ block',
                  subtitle:
                      'The parent block and each desired band must be enabled.',
                ),
                ParameterControl(
                  field: widget.effect.parameters.firstWhere(
                    (f) => f.key == 'enabled',
                  ),
                  draft: draft,
                  help: widget.help,
                  learning: widget.learning,
                  enabled: !widget.busy,
                ),
                const Divider(height: 30),
                ParameterControl(
                  field: widget.effect.parameters.firstWhere(
                    (f) => f.key == 'pregain_db',
                  ),
                  draft: draft,
                  help: widget.help,
                  learning: false,
                  enabled: !widget.busy,
                ),
                if (widget.learning) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Preamp turns the whole EQ curve down to leave room for boosts.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const Divider(height: 30),
                const Text(
                  'A clean starting point',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Text(
                  'Set ten neutral bell filters and bypass this block in your draft. The board changes only when you apply.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  key: const ValueKey('flat-eq-draft'),
                  onPressed: widget.busy ? null : draft.flatEq,
                  icon: const Icon(Icons.restart_alt_rounded, size: 17),
                  label: const Text('Flat starting point'),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 18),
      SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeading(
              'All ten bands',
              subtitle: 'Select a row to edit its filter above.',
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 38,
                dataRowMinHeight: 48,
                dataRowMaxHeight: 48,
                columnSpacing: 28,
                showCheckboxColumn: false,
                headingTextStyle: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: StudioColors.muted,
                ),
                dataTextStyle: const TextStyle(
                  fontSize: 11,
                  color: StudioColors.ink,
                ),
                columns: const [
                  DataColumn(label: Text('BAND')),
                  DataColumn(label: Text('STATE')),
                  DataColumn(label: Text('FILTER')),
                  DataColumn(label: Text('FREQUENCY')),
                  DataColumn(label: Text('Q')),
                  DataColumn(label: Text('GAIN')),
                ],
                rows: bands
                    .map(
                      (b) => DataRow(
                        selected: b.band == band,
                        onSelectChanged: (_) => setState(() => band = b.band),
                        cells: [
                          DataCell(
                            Text(
                              b.band.toString().padLeft(2, '0'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          DataCell(Text(b.enabled ? 'On' : 'Off')),
                          DataCell(Text(widget.help.filter(b.type)['name'])),
                          DataCell(
                            Text('${displayNumber(b.frequency, digits: 0)} Hz'),
                          ),
                          DataCell(
                            Text(b.q == 0 ? 'Unset' : displayNumber(b.q)),
                          ),
                          DataCell(
                            Text(
                              b.type <= 2 ? '${displayNumber(b.gain)} dB' : '—',
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  void _validate(String key, String? issue) {
    if (issue == null) {
      draft.errors.remove(key);
    } else {
      draft.invalid(key, issue);
    }
  }

  List<int> get activePaths {
    final mode = draft.number('mode').toInt();
    return switch (mode) {
      0 => [3],
      1 => [0, 1],
      2 => [0, 1, 3],
      3 => [0, 1, 2],
      _ => [0, 1, 2, 3],
    };
  }

  List<Widget> _generic() {
    final sections = <String, List<Parameter>>{};
    for (final f in widget.effect.parameters) {
      sections.putIfAbsent(f.section, () => []).add(f);
    }
    return [
      if (widget.learning) ...[_visual(), const SizedBox(height: 18)],
      ResponsiveColumns(
        children: sections.entries.map((entry) {
          final index = [
                'Low',
                'Mid / upper in two-band mode',
                'High in three-band mode',
                'Full band',
              ].indexOf(entry.key),
              active =
                  widget.effect.type != 2 ||
                  index < 0 ||
                  activePaths.contains(index);
          return SurfaceCard(
            color: active ? null : const Color(0xfff9faf6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeading(
                  entry.key,
                  subtitle: index >= 0
                      ? (active
                            ? 'Used by the draft processing mode'
                            : 'Stored · inactive in the draft mode')
                      : null,
                ),
                ...entry.value.indexed.expand(
                  (item) => [
                    if (item.$1 > 0) const SizedBox(height: 22),
                    ParameterControl(
                      field: item.$2,
                      draft: draft,
                      help: widget.help,
                      learning: widget.learning,
                      enabled: !widget.busy,
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    ];
  }

  Widget _visual() {
    if (widget.effect.type == 2) {
      final active = activePaths;
      if (!active.contains(path)) path = active.first;
      final threshold = draft.number('threshold_$path'),
          ratio = draft.number('ratio_$path'),
          input = math.min(0.0, threshold + 8),
          output = compressDb(input, threshold, ratio);
      return SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeading(
              'See the dynamics',
              subtitle: 'Ideal teaching models · no live level meter',
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(
                4,
                (i) => ChoiceChip(
                  label: Text(
                    'Path ${i + 1} · ${['Low', 'Mid / upper', 'High', 'Full band'][i]}',
                  ),
                  selected: path == i,
                  onSelected: active.contains(i)
                      ? (_) => setState(() => path = i)
                      : null,
                  showCheckmark: false,
                  labelStyle: const TextStyle(fontSize: 10),
                ),
              ),
            ),
            const SizedBox(height: 15),
            ResponsiveColumns(
              minimum: 350,
              children: [
                DynamicsChart(threshold: threshold, ratio: ratio),
                Column(
                  children: [
                    TimingChart(
                      attack: draft.number('attack_$path'),
                      release: draft.number('release_$path'),
                    ),
                    Text(
                      'Attack ${displayNumber(draft.number('attack_$path'))} ms  ·  Release ${displayNumber(draft.number('release_$path'))} ms',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
            Text(
              'At ${displayNumber(ratio)}:1, an example input of ${displayNumber(input)} dB becomes ${displayNumber(output)} dB. Reduction: ${displayNumber(input - output)} dB.',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Text(
              'Threshold and ratio only. Pre-gain placement, detector behavior, crossover summation and firmware timing are not measured.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const ValueKey('drc-example'),
              onPressed: widget.busy
                  ? null
                  : () {
                      draft.setMany({
                        'mode': 0,
                        'threshold_3': -18.0,
                        'ratio_3': 4.0,
                        'attack_3': 10.0,
                        'release_3': 150.0,
                        'pregain_3': 0.0,
                      });
                      setState(() => path = 3);
                    },
              icon: const Icon(Icons.school_outlined, size: 16),
              label: const Text('Try a 4:1 draft example'),
            ),
          ],
        ),
      );
    }
    if (widget.effect.type == 5) {
      return SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeading(
              'Quieter gaps, clearer detail',
              subtitle: 'Ideal downward expansion · firmware knee and timing are not measured',
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 650),
              child: DynamicsChart(
                threshold: draft.number('threshold_db'),
                ratio: draft.number('ratio'),
                expansion: true,
              ),
            ),
            Text(
              'Below ${displayNumber(draft.number('threshold_db'))} dB, this model turns quieter material down further. Raising the threshold can remove quiet notes too.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(
            widget.effect.type == 15
                ? 'Level, without changing the tone'
                : widget.effect.type == 20
                ? 'A flip in polarity'
                : 'An illustration of the effect',
            subtitle: widget.effect.type == 15
                ? 'Relative amplitude of a fixed example signal'
                : 'Conceptual illustration · no live audio measurement',
          ),
          SizedBox(
            height: 130,
            width: double.infinity,
            child: CustomPaint(
              painter: _EffectIllustration(widget.effect.type, draft.values),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _visualDescription(),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  String _visualDescription() {
    switch (widget.effect.type) {
      case 15:
        final gain = draft.number('gain_db');
        return '${displayNumber(gain)} dB = ${displayNumber(math.pow(10, gain / 20))}× signal amplitude while enabled and unmuted. 0 dB is unchanged level. Master mute and path mute are independent.';
      case 20:
        return 'Inverted polarity turns positive into negative, with no horizontal time shift. This is a sine-wave illustration, not a time-delay control.';
      case 13:
      case 23:
        return 'Virtual bass uses harmonic processing to suggest bass weight. The bar heights are conceptual, not a prediction of this firmware’s spectrum.';
      case 25:
        return 'Original and excited contributions have independent mix controls. The harmonic illustration does not predict the exact spectrum or gain.';
      default:
        return 'Spatial processing changes perceived space. This sketch does not establish actual speaker angles or the proprietary algorithm. Compare mono as well as stereo playback.';
    }
  }
}

class _EffectIllustration extends CustomPainter {
  final int type;
  final Map<String, Object> values;
  _EffectIllustration(this.type, Map<String, Object> values)
    : values = Map.of(values);
  double n(String key, [double fallback = 0]) =>
      (values[key] as num?)?.toDouble() ?? fallback;
  @override
  void paint(Canvas c, Size s) {
    if (type == 15) {
      final gain = math.pow(10, n('gain_db') / 20),
          actual = values['enabled'] != true
              ? 1.0
              : values['mute'] == true
              ? 0.0
              : gain;
      final base = (s.width - 50) / 4;
      chartText(c, 'INPUT · 1×', const Offset(5, 4));
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(5, 25, base, 14),
          const Radius.circular(4),
        ),
        Paint()..color = const Color(0xffb6c8a6),
      );
      chartText(
        c,
        'OUTPUT · ${displayNumber(actual)}×${values['enabled'] != true ? ' (bypassed)' : ''}',
        const Offset(5, 67),
      );
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(5, 91, base * actual, 14),
          const Radius.circular(4),
        ),
        Paint()..color = StudioColors.green,
      );
      return;
    }
    if (type == 20) {
      for (final flip in [false, true]) {
        final path = Path();
        for (var i = 0; i <= 200; i++) {
          final x = i / 200 * s.width,
              y =
                  s.height / 2 +
                  math.sin(i / 200 * 4 * math.pi) *
                      43 *
                      (flip && n('inverted') == 1 ? -1 : 1);
          if (i == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        c.drawPath(
          path,
          Paint()
            ..color = flip ? StudioColors.green : const Color(0xffb6c8a6)
            ..strokeWidth = flip ? 2.5 : 1.4
            ..style = PaintingStyle.stroke,
        );
      }
      return;
    }
    if ([13, 23, 25].contains(type)) {
      final wet = type == 25 ? n('wet') : n('intensity');
      c.drawLine(
        Offset(10, s.height - 22),
        Offset(s.width - 10, s.height - 22),
        Paint()..color = StudioColors.line,
      );
      for (var i = 0; i < 5; i++) {
        final height = i == 0 ? 70.0 : wet * .7 / (i * .5 + 1),
            x = 20 + i * (s.width - 60) / 5;
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, s.height - 22 - height, 22, height),
            const Radius.circular(4),
          ),
          Paint()
            ..color = i == 0 ? const Color(0xffb6c8a6) : StudioColors.green,
        );
      }
      chartText(c, 'Original', Offset(15, s.height - 14), size: 8);
      chartText(
        c,
        'Illustrative harmonics',
        Offset(s.width * .55, s.height - 14),
        size: 8,
      );
      return;
    }
    final amount = type == 12
            ? n('intensity')
            : values['shaping'] == true
            ? 75.0
            : 45.0,
        spread = 30 + amount * .6,
        center = Offset(s.width / 2, s.height - 12);
    for (final sign in [-1, 1]) {
      final p = Offset(s.width / 2 + spread * sign, 35);
      c.drawLine(
        center,
        p,
        Paint()
          ..color = StudioColors.line
          ..strokeWidth = 1.5,
      );
      c.drawCircle(p, 22, Paint()..color = StudioColors.pale);
      chartText(
        c,
        sign == -1 ? 'L' : 'R',
        p - const Offset(0, 8),
        align: TextAlign.center,
        color: StudioColors.green,
        size: 12,
      );
    }
    chartText(
      c,
      'Listener',
      center - const Offset(0, 7),
      align: TextAlign.center,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}
