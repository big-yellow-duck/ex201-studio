import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../application/bootstrap.dart';
import '../application/controller.dart';
import '../domain/models.dart';
import 'controls.dart';
import 'effect_page.dart';
import 'pages.dart';
import 'theme.dart';

class StudioApp extends StatefulWidget {
  final StudioBundle bundle;
  final StudioController controller;
  final bool autoConnect;
  const StudioApp({
    super.key,
    required this.bundle,
    required this.controller,
    this.autoConnect = true,
  });
  @override
  State<StudioApp> createState() => _StudioAppState();
}

class _StudioAppState extends State<StudioApp> {
  late StudioController c;
  final messenger = GlobalKey<ScaffoldMessengerState>(),
      navigator = GlobalKey<NavigatorState>();
  String page = 'overview', search = '';
  bool learning = true, hasDraft = false;
  int revision = 0;

  @override
  void initState() {
    super.initState();
    c = widget.controller;
    c.addListener(_updated);
    learning = c.storage.settings['learning'] != false;
    if (widget.autoConnect) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final address = c.demo
            ? c.transport.address
            : c.storage.settings['last_board'];
        if (address != null) unawaited(perform(() => c.connect(address)));
      });
    }
  }

  void _updated() {
    if (mounted) setState(() {});
  }

  BuildContext get uiContext => navigator.currentContext!;
  void toast(String text, {bool error = false}) =>
      messenger.currentState?.showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: error ? StudioColors.danger : StudioColors.dark,
          behavior: SnackBarBehavior.floating,
        ),
      );
  Future<bool> perform(Future<void> Function() operation) async {
    try {
      await operation();
      if (mounted) {
        setState(() {
          revision++;
          hasDraft = false;
        });
        toast(c.progress);
      }
      return true;
    } catch (e) {
      toast(e is FormatException ? e.message : e.toString(), error: true);
      return false;
    }
  }

  Future<bool> discardPrompt() async =>
      !hasDraft ||
      await confirmAction(
        uiContext,
        title: 'Leave this editor draft?',
        message: 'Your unapplied edits are local to this editor. Leaving discards them. The running board settings stay unchanged.',
        action: 'Discard & continue',
      );
  Future<void> navigate(String next) async {
    if (next == page || !await discardPrompt()) return;
    if (mounted) {
      setState(() {
        hasDraft = false;
        page = next;
      });
    }
  }

  Future<void> refresh() async {
    if (await discardPrompt()) await perform(c.refresh);
  }

  Future<void> store() async {
    if (hasDraft) {
      toast('Apply or discard the editor draft before storing board settings.');
      return;
    }
    final slot = (c.board['scene']?['value'] as int? ?? 0) + 1;
    if (!await confirmAction(
      uiContext,
      title: c.demo
          ? 'Simulate saving the demo?'
          : 'Store tuning in preset $slot?',
      message: c.demo
          ? 'This only updates the demo session. No Bluetooth hardware is used.'
          : 'Save the currently applied DSP settings on the EX201 so they survive power-off. A local backup is created before the save command.',
      action: c.demo ? 'Simulate save' : 'Store on board',
    )) {
      return;
    }
    await perform(c.store);
  }

  Future<void> exportPreset() async {
    if (c.effects.isEmpty) return;
    try {
      final path = await getSaveLocation(
        suggestedName:
            '${c.demo ? 'demo-' : ''}ex201-${DateTime.now().toIso8601String().substring(0, 10)}.json',
        acceptedTypeGroups: [
          const XTypeGroup(label: 'EX201 preset', extensions: ['json']),
        ],
      );
      if (path == null) return;
      await XFile.fromData(
        utf8.encode(
          '${const JsonEncoder.withIndent('  ').convert(c.preset())}\n',
        ),
        mimeType: 'application/json',
        name: 'preset.json',
      ).saveTo(path.path);
      toast(
        'Full DSP preset exported${hasDraft ? ' · unapplied drafts are excluded' : ''}.',
      );
    } catch (e) {
      toast('Export failed: $e', error: true);
    }
  }

  Future<void> importPreset() async {
    if (!await discardPrompt()) return;
    try {
      final file = await openFile(
        acceptedTypeGroups: [
          const XTypeGroup(label: 'EX201 preset', extensions: ['json']),
        ],
      );
      if (file == null) return;
      if (await file.length() > 1024 * 1024) {
        throw const FormatException('Preset file is too large.');
      }
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Choose a JSON preset object.');
      }
      if (!mounted) return;
      c.validatePreset(decoded);
      if (await confirmAction(
        uiContext,
        title: 'Import this DSP preset?',
        message: 'This applies the saved effect parameters to your current board slot. Device identity and firmware match. Use Store on board afterwards to keep the result across power-off.',
        action: 'Import & apply',
      )) {
        await perform(() => c.restore(decoded));
      }
    } catch (e) {
      toast(e is FormatException ? e.message : e.toString(), error: true);
    }
  }

  Future<void> connect() async {
    if (!await discardPrompt()) return;
    if (!mounted) return;
    final address = TextEditingController(
      text: c.storage.settings['last_board'] ?? '',
    );
    await showDialog<void>(
      context: uiContext,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Connect your EX201'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Choose the BLE control device. The audio connection appears separately in Linux Bluetooth settings.',
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: address,
                  decoration: const InputDecoration(
                    labelText: 'Control Bluetooth address',
                    hintText: 'AA:BB:CC:DD:EE:FF',
                  ),
                ),
                const SizedBox(height: 16),
                if (c.busy) const LinearProgressIndicator(),
                for (final device in c.devices)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.bluetooth_rounded),
                    title: Text(
                      device.name,
                      style: const TextStyle(fontSize: 13),
                    ),
                    subtitle: Text(
                      device.address,
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: device.remembered
                        ? const Tag('Remembered')
                        : null,
                    onTap: () => address.text = device.address,
                  ),
                if (c.error.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    c.error,
                    style: const TextStyle(
                      color: StudioColors.danger,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: c.busy ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            OutlinedButton(
              onPressed: c.busy
                  ? null
                  : () async {
                      final job = perform(c.scan);
                      setDialogState(() {});
                      await job;
                      if (dialogContext.mounted) setDialogState(() {});
                    },
              child: const Text('Scan for boards'),
            ),
            FilledButton(
              onPressed: c.busy
                  ? null
                  : () async {
                      final value = address.text.trim().toUpperCase();
                      if (!RegExp(r'^([0-9A-F]{2}:){5}[0-9A-F]{2}$')
                          .hasMatch(value)) {
                        toast(
                          'Enter a complete Bluetooth address.',
                          error: true,
                        );
                        return;
                      }
                      final job = perform(() => c.connect(value));
                      setDialogState(() {});
                      final ok = await job;
                      if (dialogContext.mounted) {
                        if (ok) {
                          Navigator.pop(dialogContext);
                        } else {
                          setDialogState(() {});
                        }
                      }
                    },
              child: const Text('Connect'),
            ),
          ],
        ),
      ),
    );
    address.dispose();
  }

  Future<void> toggleDemo() async {
    if (!await discardPrompt()) return;
    final wasDemo = c.demo, old = c;
    old.removeListener(_updated);
    await old.shutdown();
    final base =
        '${Platform.environment['XDG_DATA_HOME'] ?? '${Platform.environment['HOME']}/.local/share'}/ex201-studio';
    final next = await widget.bundle.controller(
      demo: !wasDemo,
      dataDirectory: Directory(wasDemo ? base : '$base/demo'),
    );
    if (!mounted) {
      await next.shutdown();
      return;
    }
    setState(() {
      c = next;
      c.addListener(_updated);
      hasDraft = false;
      page = 'overview';
      revision++;
    });
    if (c.demo) await perform(() => c.connect(c.transport.address!));
  }

  Future<void> disconnectBoard() async {
    if (!await discardPrompt()) return;
    final previous = c;
    previous.removeListener(_updated);
    await previous.shutdown();
    final next = await widget.bundle.controller(
      dataDirectory: previous.storage.root,
    );
    if (!mounted) {
      await next.shutdown();
      return;
    }
    setState(() {
      c = next;
      c.addListener(_updated);
      page = 'overview';
      hasDraft = false;
      revision++;
    });
  }

  Widget _navigation({bool drawer = false}) {
    Widget item(
      String id,
      String label,
      IconData icon, {
      bool active = false,
    }) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: page == id ? const Color(0xff36503d) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          key: ValueKey('nav-$id'),
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            if (drawer) Navigator.pop(uiContext);
            navigate(id);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 17,
                  color: page == id
                      ? const Color(0xffd5e9ba)
                      : const Color(0xff94a895),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(
                        alpha: page == id ? 1 : .8,
                      ),
                      fontSize: 11,
                      fontWeight: page == id
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
                if (active)
                  Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: Color(0xffb0cd8b),
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    return Container(
      width: 246,
      color: StudioColors.dark,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 24, 18, 17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  AvocadoMark(size: 35),
                  SizedBox(width: 11),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'EX201 Studio',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -.4,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'A LITTLE MORE YOUR SOUND',
                        style: TextStyle(
                          color: Color(0xff96ad91),
                          fontSize: 7,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 26),
              TextField(
                style: const TextStyle(color: Colors.white, fontSize: 11),
                decoration: InputDecoration(
                  hintText: 'Find an effect…',
                  hintStyle: const TextStyle(
                    color: Color(0xff8da08d),
                    fontSize: 11,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 17,
                    color: Color(0xff95a58e),
                  ),
                  fillColor: Colors.white.withValues(alpha: .055),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: .08),
                    ),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                onChanged: (v) => setState(() => search = v),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  primary: false,
                  children: [
                    item(
                      'overview',
                      'Workspace',
                      Icons.space_dashboard_outlined,
                    ),
                    item(
                      'board',
                      'Board controls',
                      Icons.developer_board_outlined,
                    ),
                    item(
                      'backups',
                      'Presets & backups',
                      Icons.inventory_2_outlined,
                    ),
                    item(
                      'guide',
                      'Learn & explore',
                      Icons.auto_stories_outlined,
                    ),
                    const SizedBox(height: 12),
                    for (final group in ['Music', 'DACX', 'Gain']) ...[
                      if (c.effects.any(
                        (e) =>
                            e.group == group &&
                            ('${e.title} ${e.name}').toLowerCase().contains(
                              search.toLowerCase(),
                            ),
                      ))
                        Padding(
                          padding: const EdgeInsets.fromLTRB(13, 16, 0, 8),
                          child: Text(
                            group == 'Gain'
                                ? 'INPUT / OUTPUT GAIN'
                                : group == 'DACX'
                                ? 'DACX · MIXED OUTPUT'
                                : 'MUSIC PROCESSING',
                            style: const TextStyle(
                              color: Color(0xff8da28a),
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.3,
                            ),
                          ),
                        ),
                      for (final effect in c.effects.where(
                        (e) =>
                            e.group == group &&
                            ('${e.title} ${e.name}').toLowerCase().contains(
                              search.toLowerCase(),
                            ),
                      ))
                        item(
                          '${effect.address}',
                          effect.title,
                          _effectIcon(effect),
                          active: effect.enabled,
                        ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .07),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          c.demo
                              ? Icons.science_outlined
                              : c.connected
                              ? Icons.bluetooth_connected
                              : Icons.bluetooth_disabled,
                          size: 15,
                          color: const Color(0xffc0d4ac),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          c.demo
                              ? 'Demo workspace'
                              : c.connected
                              ? 'EX201 connected'
                              : 'No board connected',
                          style: const TextStyle(
                            color: Color(0xffd6e2cf),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      c.demo
                          ? 'SIMULATED · NO HARDWARE'
                          : c.connected
                          ? '${c.firmware['chip_family']} · FW ${(c.firmware['firmware_version'] as List?)?.join('.') ?? '—'}'
                          : 'Local Bluetooth · no account',
                      style: const TextStyle(
                        color: Color(0xff90a28b),
                        fontSize: 9,
                      ),
                    ),
                    if (c.demo)
                      TextButton(
                        onPressed: c.busy ? null : toggleDemo,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xffd5e9ba),
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 32),
                        ),
                        child: const Text(
                          'Return to real hardware →',
                          style: TextStyle(fontSize: 9),
                        ),
                      ),
                    if (!c.demo && c.connected)
                      TextButton(
                        onPressed: c.busy ? null : disconnectBoard,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xffd5e9ba),
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 32),
                        ),
                        child: const Text(
                          'Disconnect control',
                          style: TextStyle(fontSize: 9),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => showAboutDialog(
                  context: uiContext,
                  applicationName: 'EX201 Studio',
                  applicationVersion: '1.0.0',
                  applicationIcon: const AvocadoMark(size: 50),
                  applicationLegalese: '© 2026 EX201 Studio contributors · MIT',
                  children: [
                    const SizedBox(height: 16),
                    const SelectableText(
                      'https://github.com/big-yellow-duck/ex201-studio',
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'A native Bluetooth DSP workspace. Charts are teaching models; board settings are verified by complete readback.',
                    ),
                  ],
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 5),
                  child: Text(
                    'EX201 STUDIO  /  1.0.0  ⓘ',
                    style: TextStyle(
                      color: Color(0xff92a68e),
                      fontSize: 8,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _effectIcon(DspEffect effect) => effect.isEq
      ? Icons.graphic_eq_rounded
      : effect.type == 2
      ? Icons.stacked_line_chart_rounded
      : effect.type == 15
      ? Icons.tune_rounded
      : effect.type == 20
      ? Icons.waves_rounded
      : effect.type == 13 || effect.type == 23
      ? Icons.speaker_outlined
      : Icons.blur_on_rounded;
  Widget _page() {
    if (page == 'overview') {
      return OverviewPage(
        controller: c,
        help: widget.bundle.help,
        navigate: navigate,
        connect: connect,
        demo: toggleDemo,
      );
    }
    if (page == 'guide') return GuidePage(help: widget.bundle.help);
    if (page == 'board') {
      return BoardPage(
        key: ValueKey('board-$revision'),
        controller: c,
        perform: perform,
        connect: connect,
      );
    }
    if (page == 'backups') {
      return BackupsPage(
        key: ValueKey('backups-$revision'),
        controller: c,
        perform: perform,
        exportPreset: exportPreset,
        importPreset: importPreset,
      );
    }
    final address = int.tryParse(page),
        effect = c.effects
            .where((e) => e.address == int.tryParse(page))
            .firstOrNull;
    if (effect == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.bluetooth_searching,
              size: 35,
              color: StudioColors.muted,
            ),
            const SizedBox(height: 15),
            const Text('Connect and read your board to open its editors.'),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: connect,
              child: const Text('Connect EX201'),
            ),
          ],
        ),
      );
    }
    return EffectPage(
      key: ValueKey('$address-$revision'),
      effect: effect,
      help: widget.bundle.help,
      learning: learning,
      busy: c.busy,
      connected: c.connected,
      apply: (address, changes) => perform(() => c.edit(address, changes)),
      onDirty: (v) {
        hasDraft = v;
      },
    );
  }

  Widget _header(bool narrow) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: StudioColors.line)),
    ),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 18,
      runSpacing: 10,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (narrow)
              Builder(
                builder: (context) => IconButton(
                  tooltip: 'Open navigation',
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  icon: const Icon(Icons.menu_rounded, size: 20),
                ),
              ),
            Tag(
              c.demo
                  ? 'Demo · no hardware'
                  : c.connected
                  ? 'Control link connected'
                  : 'Offline',
              color: c.demo
                  ? StudioColors.ochre
                  : c.connected
                  ? StudioColors.green
                  : StudioColors.muted,
              icon: c.demo
                  ? Icons.science_outlined
                  : c.connected
                  ? Icons.bluetooth_connected
                  : Icons.bluetooth_disabled,
            ),
            if (c.needsStore) ...[
              const SizedBox(width: 10),
              Tag(
                narrow ? 'Not stored' : 'Applied · not stored',
                color: StudioColors.ochre,
              ),
            ],
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Tooltip(
              message: 'Show explanations and visual lessons',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Learn',
                    style: TextStyle(fontSize: 11, color: StudioColors.muted),
                  ),
                  Transform.scale(
                    scale: .7,
                    child: Switch(
                      key: const ValueKey('learning-toggle'),
                      value: learning,
                      onChanged: (v) {
                        setState(() => learning = v);
                        c.storage.settings['learning'] = v;
                        unawaited(c.storage.saveSettings());
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              tooltip: 'Read all settings from board',
              onPressed: c.connected && !c.busy ? refresh : null,
              icon: const Icon(Icons.refresh_rounded, size: 19),
            ),
            IconButton(
              tooltip: 'Export preset file',
              onPressed: c.effects.isNotEmpty && !c.busy ? exportPreset : null,
              icon: const Icon(Icons.ios_share_rounded, size: 18),
            ),
            const SizedBox(width: 8),
            c.connected
                ? FilledButton.icon(
                    key: const ValueKey('store-on-board'),
                    onPressed: !c.busy ? store : null,
                    icon: const Icon(Icons.bookmark_border_rounded, size: 16),
                    label: Text(narrow ? 'Store' : 'Store on board'),
                  )
                : FilledButton.icon(
                    onPressed: !c.busy ? connect : null,
                    icon: const Icon(Icons.bluetooth_searching, size: 17),
                    label: const Text('Connect'),
                  ),
          ],
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'EX201 Studio',
    debugShowCheckedModeBanner: false,
    theme: studioTheme(),
    navigatorKey: navigator,
    scaffoldMessengerKey: messenger,
    home: Builder(
      builder: (context) => LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 950;
          return PopScope(
            canPop: !hasDraft,
            child: Scaffold(
              drawer: narrow
                  ? Drawer(width: 270, child: _navigation(drawer: true))
                  : null,
              body: Row(
                children: [
                  if (!narrow) _navigation(),
                  Expanded(
                    child: Column(
                      children: [
                        _header(narrow),
                        if (c.demo)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 25,
                              vertical: 7,
                            ),
                            color: const Color(0xfffaf1de),
                            child: const Text(
                              'DEMO WORKSPACE  ·  Controls are simulated in memory. No Bluetooth hardware is connected.',
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xff8b6b2d),
                              ),
                            ),
                          ),
                        if (c.busy) const LinearProgressIndicator(minHeight: 2),
                        Expanded(child: _page()),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 9,
                          ),
                          decoration: const BoxDecoration(
                            border: Border(
                              top: BorderSide(color: StudioColors.line),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                c.busy
                                    ? Icons.sync_rounded
                                    : c.error.isNotEmpty
                                    ? Icons.error_outline
                                    : Icons.check_circle_outline_rounded,
                                size: 13,
                                color: c.error.isNotEmpty
                                    ? StudioColors.danger
                                    : StudioColors.muted,
                              ),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  c.busy
                                      ? c.progress
                                      : c.error.isNotEmpty
                                      ? c.error
                                      : c.progress,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: c.error.isNotEmpty
                                        ? StudioColors.danger
                                        : StudioColors.muted,
                                  ),
                                ),
                              ),
                              if (!narrow)
                                const Text(
                                  'LOCAL CONTROL  ·  NO ACCOUNT REQUIRED',
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: StudioColors.muted,
                                    letterSpacing: .7,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
  @override
  void dispose() {
    c.removeListener(_updated);
    c.dispose();
    super.dispose();
  }
}
