import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../application/controller.dart';
import '../application/help_book.dart';
import '../domain/audio_math.dart';
import '../domain/models.dart';
import 'charts.dart';
import 'controls.dart';
import 'filter_lab.dart';
import 'theme.dart';

class PageCanvas extends StatelessWidget {
  final List<Widget> children;
  const PageCanvas({super.key, required this.children});
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(28),
    child: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    ),
  );
}

class OverviewPage extends StatelessWidget {
  final StudioController controller;
  final HelpBook help;
  final ValueChanged<String> navigate;
  final VoidCallback connect, demo;
  const OverviewPage({
    super.key,
    required this.controller,
    required this.help,
    required this.navigate,
    required this.connect,
    required this.demo,
  });
  @override
  Widget build(BuildContext context) {
    final c = controller;
    final samples = [
      const EqBand(1, 0, true, 160, .8, -3),
      const EqBand(2, 0, true, 2000, 1.3, 2),
      const EqBand(3, 2, true, 8000, .707, -2),
    ];
    return PageCanvas(
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'A workspace for your sound.',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            Tag(
              c.demo
                  ? 'Demo · no hardware'
                  : c.connected
                  ? 'EX201 connected'
                  : 'Connect your board',
              icon: c.demo
                  ? Icons.science_outlined
                  : c.connected
                  ? Icons.bluetooth_connected
                  : Icons.bluetooth,
            ),
          ],
        ),
        const SizedBox(height: 9),
        Text(
          'Tune with a clearer picture. Explore a change, hear the difference, then keep the settings you like.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 25),
        SurfaceCard(
          color: const Color(0xffedf2e7),
          padding: const EdgeInsets.all(27),
          child: ResponsiveColumns(
            minimum: 380,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Tag('YOUR NEXT SESSION', icon: Icons.tune_rounded),
                  const SizedBox(height: 19),
                  Text(
                    c.connected
                        ? 'Small changes. Clear feedback.'
                        : 'Your board. Your controls.',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    c.connected
                        ? 'Your DSP editors are ready. Changes stay in a draft until you apply them. The EX201 confirms every parameter block by readback.'
                        : 'Connect to the EX201’s Bluetooth control link to read its actual settings. Or open the labelled demo to explore without hardware.',
                  ),
                  const SizedBox(height: 22),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        key: const ValueKey('overview-primary'),
                        onPressed: c.busy
                            ? null
                            : c.connected
                            ? () => navigate('137')
                            : connect,
                        icon: Icon(
                          c.connected
                              ? Icons.graphic_eq
                              : Icons.bluetooth_searching,
                          size: 18,
                        ),
                        label: Text(
                          c.connected ? 'Open music EQ' : 'Connect EX201',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => navigate('guide'),
                        icon: const Icon(Icons.menu_book_outlined, size: 17),
                        label: const Text('Beginner guide'),
                      ),
                    ],
                  ),
                  if (!c.connected) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: demo,
                      child: const Text('Explore a demo workspace →'),
                    ),
                  ],
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FrequencyChart(bands: samples, showHandles: false, range: 12),
                  Text(
                    'Illustrative EQ curve · not a live signal or board measurement',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        ResponsiveColumns(
          minimum: 220,
          children: [
            _metric(
              context,
              '${c.effects.length}',
              'DSP effect editors',
              Icons.dashboard_customize_outlined,
            ),
            _metric(
              context,
              '${c.effects.where((e) => e.isEq).length}',
              'Parametric EQ blocks',
              Icons.graphic_eq_rounded,
            ),
            _metric(
              context,
              '${c.board['scene']?['count'] ?? '—'}',
              'Board preset slots',
              Icons.layers_outlined,
            ),
          ],
        ),
        const SizedBox(height: 30),
        const SectionHeading(
          'Find your starting point',
          subtitle:
              'One feature at a time is easier to understand and compare.',
        ),
        ResponsiveColumns(
          minimum: 250,
          children: [
            _route(
              context,
              'Shape the tone',
              'Ten filters, a combined curve, and room for precise adjustments.',
              Icons.graphic_eq_rounded,
              '137',
            ),
            _route(
              context,
              'Understand dynamics',
              'See what threshold, ratio and timing do before you apply.',
              Icons.stacked_line_chart_rounded,
              '138',
            ),
            _route(
              context,
              'Keep your tuning',
              'Export a preset, create a backup or restore a previous session.',
              Icons.inventory_2_outlined,
              'backups',
            ),
          ],
        ),
        const SizedBox(height: 30),
        const SectionHeading(
          'Preview → Apply → Store',
          subtitle: 'Three distinct steps, so you always know what changes the board.',
        ),
        ResponsiveColumns(
          minimum: 250,
          children: List.generate(
            3,
            (i) => SurfaceCard(
              color: StudioColors.background,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Tag('0${i + 1}'),
                  const SizedBox(height: 12),
                  Text(
                    [
                      'Explore a draft',
                      'Apply & compare',
                      'Store for next time',
                    ][i],
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    [
                      'Move a slider or copy a filter example. Everything stays local until Apply.',
                      'Apply sends the editor draft to the running board and verifies the returned settings.',
                      'Store on board saves applied DSP settings across power-off. Export keeps a separate file.',
                    ][i],
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          help.data['routing'],
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _metric(
    BuildContext context,
    String value,
    String label,
    IconData icon,
  ) => SurfaceCard(
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: StudioColors.pale,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: StudioColors.green, size: 22),
        ),
        const SizedBox(width: 17),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    ),
  );
  Widget _route(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    String page,
  ) => InkWell(
    borderRadius: BorderRadius.circular(18),
    onTap: () => navigate(page),
    child: SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 25, color: StudioColors.green),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const Icon(
                Icons.north_east_rounded,
                size: 17,
                color: StudioColors.muted,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(description, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    ),
  );
}

class GuidePage extends StatefulWidget {
  final HelpBook help;
  const GuidePage({super.key, required this.help});
  @override
  State<GuidePage> createState() => _GuidePageState();
}

class _GuidePageState extends State<GuidePage> {
  String search = '';
  @override
  Widget build(BuildContext context) {
    final h = widget.help;
    bool includes(String text) =>
        text.toLowerCase().contains(search.toLowerCase());
    final basics = h
        .list('basics')
        .where((x) => includes('${x['term']} ${x['text']}'))
        .toList();
    final fixes = h
        .list('troubleshooting')
        .where((x) => includes('${x['title']} ${x['text']}'))
        .toList();
    return PageCanvas(
      children: [
        Text(
          'Learn your way around sound.',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 8),
        const Text(
          'A practical reference for each control, with visual examples you can explore.',
        ),
        const SizedBox(height: 22),
        TextField(
          key: const ValueKey('guide-search'),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_rounded, size: 20),
            hintText: 'Find a term, effect or troubleshooting topic…',
          ),
          onChanged: (v) => setState(() => search = v),
        ),
        const SizedBox(height: 24),
        if (search.isEmpty) ...[
          const SectionHeading('Your first tuning session'),
          ResponsiveColumns(
            minimum: 300,
            children: h
                .list('quickstart')
                .indexed
                .map(
                  (x) => SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Tag('STEP ${x.$1 + 1}'),
                        const SizedBox(height: 12),
                        Text(
                          x.$2['title'],
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 9),
                        Text(
                          x.$2['text'],
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 28),
        ],
        if (basics.isNotEmpty) ...[
          const SectionHeading('The terms, in plain language'),
          ResponsiveColumns(
            minimum: 330,
            children: basics
                .map(
                  (x) => SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          x['term'],
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          x['text'],
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 28),
        ],
        const SectionHeading(
          'Choose the right filter',
          subtitle: 'Each thumbnail is a separate example. Open the explorer for sliders and a larger view.',
        ),
        ResponsiveColumns(
          minimum: 245,
          children: List.generate(9, (i) {
            final f = h.filter(i), ex = f['example'];
            if (!includes('${f['name']} ${f['what']} ${f['use']}')) {
              return const SizedBox.shrink();
            }
            return InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => showDialog<Map<String, Object>>(
                context: context,
                builder: (context) => FilterLab(
                  help: h,
                  band: 1,
                  initialType: i,
                  previewOnly: true,
                ),
              ),
              child: SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FrequencyChart(
                      bands: [
                        EqBand(
                          1,
                          i,
                          true,
                          (ex['frequency'] as num).toDouble(),
                          (ex['q'] as num).toDouble(),
                          (ex['gain'] as num).toDouble(),
                        ),
                      ],
                      compact: true,
                      showHandles: false,
                    ),
                    Text(
                      f['name'],
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      f['what'],
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 28),
        const SectionHeading('Every effect, explained'),
        ...h.data['effects'].values
            .where(
              (dynamic x) => includes('${x['title']} ${x['what']} ${x['try']}'),
            )
            .map<Widget>(
              (dynamic x) => Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: SurfaceCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 4,
                  ),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(
                      x['title'],
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    subtitle: Text(
                      x['what'],
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(0, 10, 0, 16),
                    children: [Text('Try it: ${x['try']}\n\n${x['watch']}')],
                  ),
                ),
              ),
            ),
        const SizedBox(height: 24),
        if (search.isEmpty) ...[
          const SectionHeading('Which action changes what?'),
          SurfaceCard(
            child: Column(
              children: h
                  .list('workflow')
                  .indexed
                  .expand(
                    (entry) => [
                      if (entry.$1 > 0) const Divider(height: 26),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: MediaQuery.sizeOf(context).width > 700
                                ? 200
                                : 130,
                            child: Text(
                              entry.$2['action'],
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Text(
                              entry.$2['effect'],
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 28),
        ],
        if (fixes.isNotEmpty) ...[
          const SectionHeading('When a change does not do what you expect'),
          ...fixes.map(
            (x) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: SurfaceCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 4,
                ),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(
                    x['title'],
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  childrenPadding: const EdgeInsets.only(bottom: 15),
                  children: [
                    Text(
                      x['text'],
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 28),
        const SectionHeading('Sources & scope'),
        const Text(
          'The control definitions come from the manufacturer’s client and live EX201 readback tests. EQ and dynamics charts are teaching models; proprietary bass, exciter and spatial algorithms have not been acoustically measured.',
        ),
        const SizedBox(height: 12),
        ...h
            .list('sources')
            .map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SelectableText(
                  '${s['title']}\n${s['url']}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
      ],
    );
  }
}

class BoardPage extends StatefulWidget {
  final StudioController controller;
  final Future<bool> Function(Future<void> Function()) perform;
  final VoidCallback connect;
  const BoardPage({
    super.key,
    required this.controller,
    required this.perform,
    required this.connect,
  });
  @override
  State<BoardPage> createState() => _BoardPageState();
}

class _BoardPageState extends State<BoardPage> {
  late double volume;
  late int scene;
  late TextEditingController name;
  @override
  void initState() {
    super.initState();
    volume = (widget.controller.board['volume']?['value'] as num? ?? 0)
        .toDouble();
    scene = widget.controller.board['scene']?['value'] ?? 0;
    name = TextEditingController(
      text: widget.controller.board['bluetooth_name']?['value'] ?? '',
    );
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller,
        b = c.board,
        vol = b['volume'] as Map? ?? {},
        preset = b['scene'] as Map? ?? {},
        status = b['system_status'] as Map? ?? {},
        enabled = c.connected && !c.busy;
    return PageCanvas(
      children: [
        Text(
          'Board controls',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 8),
        const Text(
          'The device connection, overall level, preset slots and last-read diagnostics.',
        ),
        const SizedBox(height: 24),
        ResponsiveColumns(
          minimum: 380,
          children: [
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeading(
                    'Master volume',
                    subtitle:
                        'Board steps · separate from input and output gain',
                    trailing: Tag(
                      vol['supported'] == true
                          ? '${vol['value']} / ${vol['max']}'
                          : 'Unavailable',
                    ),
                  ),
                  if (vol['supported'] == true) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Icon(
                          Icons.volume_down_rounded,
                          size: 23,
                          color: StudioColors.muted,
                        ),
                        Expanded(
                          child: Slider(
                            key: const ValueKey('master-volume-slider'),
                            value: volume.clamp(
                              0.0,
                              (vol['max'] as num).toDouble(),
                            ),
                            min: 0,
                            max: (vol['max'] as num).toDouble(),
                            divisions: vol['max'],
                            label: volume.round().toString(),
                            onChanged: enabled
                                ? (v) => setState(() => volume = v)
                                : null,
                          ),
                        ),
                        const Icon(
                          Icons.volume_up_rounded,
                          size: 23,
                          color: StudioColors.muted,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        FilledButton(
                          onPressed: enabled && volume.round() != vol['value']
                              ? () => widget.perform(
                                  () => c.editDevice('volume', volume.round()),
                                )
                              : null,
                          child: Text('Apply volume · ${volume.round()}'),
                        ),
                        OutlinedButton.icon(
                          onPressed: enabled
                              ? () => widget.perform(
                                  () => c.editDevice('mute', vol['value'] != 0),
                                )
                              : null,
                          icon: Icon(
                            vol['value'] == 0
                                ? Icons.volume_up_rounded
                                : Icons.volume_off_outlined,
                            size: 16,
                          ),
                          label: Text(
                            vol['value'] == 0 ? 'Unmute now' : 'Mute now',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Text(
                      'Master mute sets volume to zero. Unmute restores the last nonzero level. Enabled gain blocks can also have their own mute flags.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ] else
                    Text(
                      'Connect and read the board to see its volume range.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeading(
                    'Board preset',
                    subtitle: 'A slot inside your EX201',
                  ),
                  if (preset['supported'] == true) ...[
                    DropdownButtonFormField<int>(
                      initialValue: scene,
                      isExpanded: true,
                      items: List.generate(
                        preset['count'],
                        (i) => DropdownMenuItem(
                          value: i,
                          child: Text(
                            'Preset ${i + 1}${i == preset['value'] ? ' · current' : ''}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      onChanged: enabled
                          ? (v) => setState(() => scene = v!)
                          : null,
                    ),
                    const SizedBox(height: 17),
                    FilledButton.icon(
                      onPressed: enabled && scene != preset['value']
                          ? () async {
                              if (c.needsStore) {
                                final ok = await confirmAction(
                                  context,
                                  title: 'Load another board preset?',
                                  message: 'The current DSP tuning has changes that have not been stored. Loading another slot replaces the running tuning.',
                                  action: 'Load preset',
                                );
                                if (!ok) return;
                              }
                              await widget.perform(
                                () => c.editDevice('scene', scene),
                              );
                            }
                          : null,
                      icon: const Icon(Icons.layers_outlined, size: 17),
                      label: const Text('Load selected preset'),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      'Loading applies a board slot immediately and reloads all effects. Export your tuning first if you want a separate copy.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ] else
                    const Text(
                      'Preset selection is unavailable until the board is read.',
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        ResponsiveColumns(
          minimum: 380,
          children: [
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeading(
                    'Audio input',
                    subtitle: 'Capability reported by the connected firmware',
                  ),
                  if (b['input']?['supported'] == true)
                    DropdownButtonFormField<int>(
                      initialValue: b['input']['value'],
                      items: (b['input']['options'] as Map).entries
                          .map(
                            (e) => DropdownMenuItem(
                              value: int.parse(e.key.toString()),
                              child: Text(e.value.toString()),
                            ),
                          )
                          .toList(),
                      onChanged: enabled
                          ? (v) {
                              if (v != null) {
                                widget.perform(() => c.editDevice('input', v));
                              }
                            }
                          : null,
                    )
                  else
                    const _Unavailable(
                      'This EX201 firmware returns no remote input-selection status. Select the source using the board’s own controls.',
                    ),
                ],
              ),
            ),
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeading(
                    'Bluetooth name',
                    subtitle: 'Control connection identity',
                  ),
                  if (b['bluetooth_name']?['supported'] == true) ...[
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(
                        labelText: 'Device name',
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: enabled
                          ? () => widget.perform(
                              () => c.editDevice('bluetooth_name', name.text),
                            )
                          : null,
                      child: const Text('Rename on board'),
                    ),
                  ] else
                    _Unavailable(
                      '${c.transport.name}\n\nRenaming is not exposed by this firmware through the known interface.',
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
              SectionHeading(
                'Inside the DSP',
                subtitle:
                    'Values from the last board read · not live audio meters',
                trailing: OutlinedButton.icon(
                  onPressed: enabled ? () => widget.perform(c.refresh) : null,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Read board'),
                ),
              ),
              if (status['supported'] == true)
                ResponsiveColumns(
                  minimum: 300,
                  children: [
                    _usage(
                      context,
                      'DSP compute',
                      status['cpu_used_mhz'],
                      status['cpu_max_mhz'],
                      'MHz',
                    ),
                    _usage(
                      context,
                      'Memory',
                      status['memory_used_kb'],
                      status['memory_max_kb'],
                      'KB',
                    ),
                  ],
                )
              else
                const Text('Connect and read the board to view diagnostics.'),
              const Divider(height: 32),
              Wrap(
                spacing: 25,
                runSpacing: 12,
                children: [
                  Text(
                    'Chip ${c.firmware['chip_family'] ?? '—'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    'Firmware ${(c.firmware['firmware_version'] as List?)?.join('.') ?? '—'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    'Library ${(c.firmware['library_version'] as List?)?.join('.') ?? '—'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeading(
                'Connection & storage',
                trailing: TextButton(
                  onPressed: widget.connect,
                  child: const Text('Choose board'),
                ),
              ),
              SelectableText(
                c.transport.address ?? 'No board selected',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'The Bluetooth control link carries settings. Audio playback uses its own connection. This app controls the board’s DSP and does not play or capture audio.',
              ),
              const Divider(height: 28),
              SelectableText(
                'Local files: ${c.storage.root.path}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text(
                  'Readback details',
                  style: TextStyle(fontSize: 12),
                ),
                children: [
                  SelectableText(
                    const JsonEncoder.withIndent('  ').convert(b),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _usage(
    BuildContext context,
    String label,
    int used,
    int max,
    String unit,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            '$used / $max $unit',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      const SizedBox(height: 14),
      LinearProgressIndicator(
        value: max == 0 ? 0 : used / max,
        minHeight: 7,
        borderRadius: BorderRadius.circular(10),
        backgroundColor: StudioColors.pale,
      ),
    ],
  );
}

class _Unavailable extends StatelessWidget {
  final String message;
  const _Unavailable(this.message);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: StudioColors.background,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.info_outline_rounded,
          size: 17,
          color: StudioColors.muted,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(message, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    ),
  );
}

class BackupsPage extends StatefulWidget {
  final StudioController controller;
  final Future<bool> Function(Future<void> Function()) perform;
  final VoidCallback exportPreset, importPreset;
  const BackupsPage({
    super.key,
    required this.controller,
    required this.perform,
    required this.exportPreset,
    required this.importPreset,
  });
  @override
  State<BackupsPage> createState() => _BackupsPageState();
}

class _BackupsPageState extends State<BackupsPage> {
  late Future<List<BackupEntry>> entries;
  @override
  void initState() {
    super.initState();
    entries = widget.controller.storage.backups();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return PageCanvas(
      children: [
        Text(
          'Keep a tuning worth coming back to.',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 8),
        const Text(
          'Files live on your computer. Preset slots live on your board. Keep a copy of both.',
        ),
        const SizedBox(height: 24),
        ResponsiveColumns(
          minimum: 300,
          children: [
            _action(
              context,
              'Export a preset',
              'Download a compact file containing the last-read values of all DSP effects.',
              Icons.ios_share_rounded,
              'Export preset file',
              c.effects.isEmpty || c.busy ? null : widget.exportPreset,
            ),
            _action(
              context,
              'Import a preset',
              'Apply a saved file to the current board slot. Device identity and firmware must match.',
              Icons.file_open_outlined,
              'Choose preset file',
              c.connected && !c.busy ? widget.importPreset : null,
            ),
            _action(
              context,
              'Create a fresh backup',
              'Read the physical board and save a new recovery copy on this computer.',
              Icons.add_to_photos_outlined,
              'Read & back up',
              c.connected && !c.busy
                  ? () async {
                      await widget.perform(c.backup);
                      if (mounted) {
                        setState(() => entries = c.storage.backups());
                      }
                    }
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 25),
        SurfaceCard(
          color: StudioColors.pale.withValues(alpha: .5),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.bookmark_outline_rounded,
                color: StudioColors.green,
                size: 21,
              ),
              SizedBox(width: 13),
              Expanded(
                child: Text(
                  'Import and Restore apply running DSP settings. Store on board keeps those settings across power-off. Exported files contain board values, not unapplied editor drafts.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        const SectionHeading(
          'Recovery history',
          subtitle: 'The controller saves snapshots before and after changes.',
        ),
        FutureBuilder<List<BackupEntry>>(
          future: entries,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(30),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            final all = snapshot.data!;
            if (all.isEmpty) {
              return const SurfaceCard(
                child: Text(
                  'Your recovery history starts after the first board read.',
                ),
              );
            }
            return SurfaceCard(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
              child: Column(
                children: all.indexed.expand((entry) {
                  final b = entry.$2;
                  final time = b.time.toLocal(),
                      label =
                          '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}  ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                  return [
                    if (entry.$1 > 0) const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.history_rounded,
                            size: 18,
                            color: StudioColors.muted,
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  b.reason.replaceAll('-', ' '),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '$label · ${b.effects} effects',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton(
                            onPressed: !c.busy && c.connected
                                ? () async {
                                    Map<String, dynamic> data;
                                    try {
                                      data = Map<String, dynamic>.from(
                                        jsonDecode(
                                          await File(b.path).readAsString(),
                                        ),
                                      );
                                      c.validatePreset(data);
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(content: Text(e.toString())),
                                        );
                                      }
                                      return;
                                    }
                                    if (!context.mounted) return;
                                    final ok = await confirmAction(
                                      context,
                                      title: 'Restore this backup?',
                                      message: 'This replaces running DSP parameters in the current board preset. A recovery snapshot is created first. Store on board is still needed to keep the result after power-off.',
                                      action: 'Restore backup',
                                    );
                                    if (ok) {
                                      await widget.perform(
                                        () => c.restore(data),
                                      );
                                    }
                                  }
                                : null,
                            child: const Text('Restore'),
                          ),
                        ],
                      ),
                    ),
                  ];
                }).toList(),
              ),
            );
          },
        ),
        const SizedBox(height: 18),
        SelectableText(
          c.storage.root.path,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _action(
    BuildContext context,
    String title,
    String text,
    IconData icon,
    String action,
    VoidCallback? onTap,
  ) => SurfaceCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: StudioColors.green, size: 25),
        const SizedBox(height: 18),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Text(text, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 20),
        OutlinedButton(onPressed: onTap, child: Text(action)),
      ],
    ),
  );
}
