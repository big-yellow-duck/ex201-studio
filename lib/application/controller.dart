import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../domain/models.dart';
import '../domain/parameters.dart';
import '../domain/protocol.dart';
import '../infrastructure/storage.dart';
import '../infrastructure/transport.dart';

class StudioController extends ChangeNotifier {
  final ParameterRegistry registry;
  final AppStorage storage;
  final BoardTransport transport;
  List<DspEffect> effects = [];
  List<DiscoveredBoard> devices = [];
  Map<String, dynamic> firmware = {}, board = {};
  bool busy = false, needsStore = false;
  String progress = 'Ready when you are', error = '';
  String? lastBackup;
  StreamSubscription<bool>? _subscription;
  StudioController(this.registry, this.storage, this.transport) {
    _subscription = transport.connectionChanges.listen((connected) {
      if (!connected) progress = 'Control Bluetooth disconnected';
      notifyListeners();
    });
  }
  bool get connected => transport.connected;
  bool get demo => transport.isDemo;
  DspEffect effect(int address) => effects.firstWhere(
    (e) => e.address == address,
    orElse: () => throw StateError('Read this effect from the board first.'),
  );
  void _progress(String value) {
    progress = value;
    notifyListeners();
  }

  Future<T> run<T>(String label, Future<T> Function() operation) async {
    if (busy) {
      throw StateError('Wait for the current board operation to finish.');
    }
    busy = true;
    error = '';
    _progress(label);
    try {
      return await operation();
    } catch (e) {
      error = e is FormatException ? e.message : e.toString();
      progress = 'Operation stopped';
      rethrow;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> scan() async =>
      run('Looking for EX201 control devices…', () async {
        devices = await transport.scan();
        _progress(
          devices.isEmpty
              ? 'No control devices found. Power on the board and scan again.'
              : 'Choose a control device to connect.',
        );
      });
  Future<void> connect(String address) async =>
      run('Connecting to EX201…', () async {
        await transport.connect(address);
        await _refresh();
        if (!demo) {
          storage.settings['last_board'] = address;
          await storage.saveSettings();
        }
      });
  Future<void> refresh() async => run('Reading board settings…', _refresh);
  Future<List<int>> readWords(int address) async {
    final reply = await transport.exchange(frame(address), selector: 255);
    return signedWords(reply.sublist(5, reply.length - 1));
  }

  Future<void> _refresh() async {
    _progress('Reading firmware…');
    final f = await transport.exchange(frame(0)),
        p = f.sublist(4, f.length - 1);
    if (p.length < 7 || ![48, 49, 72].contains(p[0])) {
      throw const FormatException(
        'Only the BP10 protocol family is supported.',
      );
    }
    firmware = {
      'chip_code': p[0],
      'chip_family': {48: 'BP10_B1', 49: 'BP10_OB2', 72: 'BP10_B2'}[p[0]],
      'firmware_version': p.sublist(1, 4),
      'library_version': p.sublist(4, 7),
      'raw_hex': hex(f),
    };
    final reply = await transport.exchange(frame(128, [0]), selector: 0),
        catalogue = reply.sublist(4, reply.length - 1);
    if (catalogue.length < 2 ||
        catalogue[1] > 64 ||
        catalogue.length != 2 + catalogue[1] * 2) {
      throw const FormatException('Unrecognized effect catalogue.');
    }
    final result = <DspEffect>[];
    for (var i = 0; i < catalogue[1]; i++) {
      _progress('Reading effect ${i + 1} of ${catalogue[1]}…');
      final type = catalogue[2 + i * 2] | catalogue[3 + i * 2] << 8,
          address = 129 + i;
      final nameReply = await transport.exchange(
        frame(128, [i + 1]),
        selector: i + 1,
      );
      final name = boardText(nameReply.sublist(5, nameReply.length - 1));
      final words = await readWords(address);
      result.add(
        DspEffect.fromJson({
          'address': address,
          'type': type,
          'name': name,
          'raw_words': words,
        }, registry),
      );
    }
    effects = result;
    await _readBoard();
    await snapshot('read');
    _progress(
      demo
          ? 'Demo workspace · no radio connection'
          : 'All settings read from the EX201',
    );
  }

  Future<Map<String, dynamic>> _readControl(String key) async {
    final query = boardQueries[key]!;
    final reply = await transport.exchange(
      frame(query.$1, query.$2),
      timeout: const Duration(milliseconds: 1400),
    );
    try {
      final decoded = {
        'supported': true,
        'raw_hex': hex(reply),
        ...decodeBoard(key, reply.sublist(4, reply.length - 1)),
      };
      board[key] = decoded;
      return decoded;
    } on FormatException catch (e) {
      final unavailable = {
        'supported': false,
        'raw_hex': hex(reply),
        'reason': e.message,
      };
      board[key] = unavailable;
      return unavailable;
    }
  }

  Future<void> _readBoard() async {
    board = {};
    for (final key in boardQueries.keys) {
      _progress('Reading ${key.replaceAll('_', ' ')}…');
      try {
        await _readControl(key);
      } catch (e) {
        board[key] = {'supported': false, 'reason': e.toString()};
      }
    }
  }

  Map<String, dynamic> preset() => {
    'format': 'ex201-studio-preset',
    'version': 2,
    'exported_at': DateTime.now().toUtc().toIso8601String(),
    'device': {
      'name': transport.name,
      'address': transport.address,
      'service': controlService,
      'write': controlChannel,
      'read': controlChannel,
    },
    'firmware': firmware,
    'effects': effects.map((e) => e.toJson()).toList(),
    'board': board,
  };
  Future<String> snapshot(String reason) async {
    lastBackup = await storage.snapshot(
      preset(),
      demo ? 'demo-$reason' : reason,
    );
    return lastBackup!;
  }

  Future<void> _writeGroup(
    DspEffect effect,
    ParameterGroup group,
    List<int> values,
  ) async {
    if (!effect.parameters.any(
      (f) => f.selector == group.selector && f.groupCount == values.length,
    )) {
      throw const FormatException('Unsupported parameter group');
    }
    await transport.exchange(
      frame(effect.address, [group.selector, ...wordBytes(values)]),
      ack: true,
    );
  }

  Future<void> _restoreWords(DspEffect effect, List<int> target) async {
    var actual = await readWords(effect.address);
    if (actual.length != target.length) {
      throw const FormatException(
        'Effect layout changed. Read the board again.',
      );
    }
    final groups = {
      for (final f in effect.parameters)
        f.selector: ParameterGroup(f.selector, f.groupStart, f.groupCount),
    };
    final covered = {
      for (final g in groups.values)
        for (var i = g.start; i < g.start + g.count; i++) i,
    };
    for (var i = 0; i < actual.length; i++) {
      if (!covered.contains(i) && actual[i] != target[i]) {
        throw const FormatException(
          'Preset changes a preserved firmware word.',
        );
      }
    }
    if (actual[0] != 0 && !listEquals(actual, target)) {
      await _writeGroup(effect, groups[0]!, [0]);
      actual[0] = 0;
    }
    final bypass = {
      for (final f in effect.parameters)
        if (f.key.endsWith('_enabled')) f.selector: f.index,
    };
    final ordered = groups.values.where((g) => g.selector != 0).toList()
      ..sort((a, b) {
        int rank(ParameterGroup g) => bypass.containsKey(g.selector)
            ? (target[bypass[g.selector]!] == 0 ? 0 : 2)
            : 1;
        final r = rank(a).compareTo(rank(b));
        return r == 0 ? a.selector.compareTo(b.selector) : r;
      });
    for (final g in ordered) {
      final desired = target.sublist(g.start, g.start + g.count);
      if (listEquals(actual.sublist(g.start, g.start + g.count), desired)) {
        continue;
      }
      await _writeGroup(effect, g, desired);
      final expected = List<int>.of(actual)
        ..replaceRange(g.start, g.start + g.count, desired);
      actual = await readWords(effect.address);
      effect.words = actual;
      if (!listEquals(actual, expected)) {
        throw StateError(
          'Readback mismatch while restoring ${effect.title}. Recovery backup: $lastBackup',
        );
      }
    }
    if (actual[0] != target[0]) {
      await _writeGroup(effect, groups[0]!, [target[0]]);
    }
    actual = await readWords(effect.address);
    effect.words = actual;
    if (!listEquals(actual, target)) {
      throw StateError('Complete restored block did not match its snapshot.');
    }
  }

  Future<void> edit(int address, Map<String, Object?> changes) async => run(
    'Applying changes…',
    () async {
      final block = effect(address);
      registry.plan(block.type, block.words, changes);
      final old = await readWords(address);
      if (old.length != block.words.length) {
        throw const FormatException(
          'Effect layout changed. Read the board again.',
        );
      }
      block.words = old;
      final patch = registry.plan(block.type, old, changes);
      await snapshot('before-edit');
      var actual = List<int>.of(old);
      try {
        for (final group in patch.groups) {
          final values = patch.words.sublist(
            group.start,
            group.start + group.count,
          );
          if (listEquals(
            actual.sublist(group.start, group.start + group.count),
            values,
          )) {
            continue;
          }
          await _writeGroup(block, group, values);
          final expected = List<int>.of(actual)
            ..replaceRange(group.start, group.start + group.count, values);
          actual = await readWords(address);
          block.words = actual;
          if (!listEquals(actual, expected)) {
            throw StateError('Complete block readback did not match the edit.');
          }
        }
      } catch (original) {
        try {
          await _restoreWords(block, old);
        } catch (recovery) {
          throw StateError(
            '$original Recovery also failed: $recovery. Backup: $lastBackup',
          );
        }
        rethrow;
      }
      block.words = actual;
      needsStore = true;
      await snapshot('after-edit');
      _progress('Applied and verified · Store to keep after power-off');
    },
  );
  List<(DspEffect, List<int>)> _planRestore(Map<String, dynamic> data) {
    final device = data['device'];
    if (device is! Map || device['address'] != transport.address) {
      throw const FormatException('This preset belongs to a different board.');
    }
    if (data['firmware'] is! Map ||
        data['firmware']['raw_hex'] != firmware['raw_hex']) {
      throw const FormatException('Preset firmware differs from this board.');
    }
    if (data['effects'] is! List) {
      throw const FormatException('Preset has no effect list.');
    }
    final planned = <(DspEffect, List<int>)>[], addresses = <int>{};
    for (final dynamic entry in data['effects']) {
      if (entry is! Map || entry['address'] is! int) {
        throw const FormatException('Invalid preset effect.');
      }
      final raw =
          entry['raw_words'] ??
          (entry['eq'] is Map ? entry['eq']['raw_words'] : null);
      if (raw == null) continue;
      final e = effect(entry['address']);
      if (entry['type'] != e.type ||
          raw is! List ||
          raw.length != e.words.length ||
          raw.any((x) => x is! int || x < -32768 || x > 32767) ||
          !e.editable) {
        throw const FormatException(
          'Preset contains a different or invalid effect layout.',
        );
      }
      if (!addresses.add(e.address)) {
        throw const FormatException('Preset repeats an effect.');
      }
      final words = List<int>.from(raw);
      final covered = {
        for (final f in e.parameters)
          for (var i = f.groupStart; i < f.groupStart + f.groupCount; i++) i,
      };
      for (var i = 0; i < words.length; i++) {
        if (!covered.contains(i) && words[i] != e.words[i]) {
          throw const FormatException(
            'Preset changes an unverified firmware field.',
          );
        }
      }
      planned.add((e, words));
    }
    if (planned.isEmpty) {
      throw const FormatException(
        'No compatible effect parameters in this file.',
      );
    }
    return planned;
  }

  void validatePreset(Map<String, dynamic> data) {
    _planRestore(data);
  }

  Future<void> restore(Map<String, dynamic> data) async => run(
    'Restoring preset…',
    () async {
      final plan = _planRestore(data), before = <(DspEffect, List<int>)>[];
      for (final item in plan) {
        before.add((item.$1, await readWords(item.$1.address)));
      }
      for (final item in before) {
        item.$1.words = item.$2;
      }
      await snapshot('before-restore');
      try {
        for (final item in plan) {
          _progress('Restoring ${item.$1.title}…');
          await _restoreWords(item.$1, item.$2);
        }
      } catch (original) {
        try {
          for (final item in before) {
            await _restoreWords(item.$1, item.$2);
          }
        } catch (recovery) {
          throw StateError(
            '$original Recovery failed: $recovery. Backup: $lastBackup',
          );
        }
        rethrow;
      }
      needsStore = true;
      await snapshot('after-restore');
      _progress('Preset restored and verified · Store to keep after power-off');
    },
  );
  Future<void> store() async =>
      run('Saving DSP tuning to the board…', () async {
        if (effects.isEmpty) throw StateError('Read the board first.');
        await _refresh();
        await snapshot('before-store');
        await transport.send(frame(253));
        await Future<void>.delayed(const Duration(milliseconds: 500));
        needsStore = false;
        _progress(
          demo
              ? 'Demo save simulated'
              : 'Store command sent · current preset saved',
        );
      });
  Future<void> backup() async =>
      run('Reading and backing up your tuning…', () async {
        await _refresh();
        await snapshot('manual');
        _progress('Full DSP backup saved on this computer');
      });
  Future<void> editDevice(String field, Object value) async => run(
    'Updating board ${field.replaceAll('_', ' ')}…',
    () async {
      if (field == 'volume' || field == 'mute') {
        final status = await _readControl('volume');
        if (status['supported'] != true) {
          throw StateError('Master volume is not exposed by this firmware.');
        }
        final current = status['value'] as int, max = status['max'] as int;
        if (current > 0) storage.settings['last_volume'] = current;
        final int target;
        if (field == 'mute') {
          if (value is! bool) {
            throw const FormatException('Mute must be on or off.');
          }
          target = value
              ? 0
              : (storage.settings['last_volume'] as int? ?? 6).clamp(1, max);
        } else {
          if (value is! int || value < 0 || value > max) {
            throw const FormatException('Volume is outside the board range.');
          }
          target = value;
        }
        await snapshot('before-volume');
        await transport.exchange(frame(18, [2, target]), ack: true);
        final actual = await _readControl('volume');
        if (actual['value'] != target) {
          throw StateError('Volume readback did not match.');
        }
        if (target > 0) storage.settings['last_volume'] = target;
        await storage.saveSettings();
      } else if (field == 'scene') {
        final status = await _readControl('scene');
        if (status['supported'] != true ||
            value is! int ||
            value < 0 ||
            value > status['max']) {
          throw const FormatException('Unknown board preset.');
        }
        await snapshot('before-preset-switch');
        await transport.exchange(frame(18, [5, value]), ack: true);
        final actual = await _readControl('scene');
        if (actual['value'] != value) {
          throw StateError('Preset selection did not match readback.');
        }
        await _refresh();
        needsStore = false;
      } else if (field == 'input') {
        final status = await _readControl('input');
        if (status['supported'] != true) {
          throw StateError('Input selection is unavailable on this firmware.');
        }
        if (value is! int || ![1, 2, 4, 5].contains(value)) {
          throw const FormatException('Unknown audio input.');
        }
        await transport.exchange(frame(18, [3, value]), ack: true);
        final actual = await _readControl('input');
        if (actual['value'] != value) {
          throw StateError('Input readback did not match.');
        }
      } else if (field == 'bluetooth_name') {
        final status = await _readControl('bluetooth_name');
        if (status['supported'] != true) {
          throw StateError('Renaming is unavailable on this firmware.');
        }
        if (value is! String ||
            value.trim().isEmpty ||
            utf8.encode(value).length > 32 ||
            value.runes.any((c) => c < 32)) {
          throw const FormatException('Bluetooth name needs 1–32 UTF-8 bytes.');
        }
        await transport.exchange(
          frame(18, [7, ...utf8.encode(value), 0]),
          ack: true,
        );
        final actual = await _readControl('bluetooth_name');
        if (actual['value'] != value) {
          throw StateError('Name readback did not match.');
        }
      } else {
        throw const FormatException('Unknown board control.');
      }
      _progress('Board ${field.replaceAll('_', ' ')} confirmed by readback');
    },
  );
  Future<void> restoreFile(String path) async => restore(
    Map<String, dynamic>.from(jsonDecode(await File(path).readAsString())),
  );
  Future<void> shutdown() async {
    await _subscription?.cancel();
    await transport.close();
  }

  @override
  void dispose() {
    unawaited(shutdown());
    super.dispose();
  }
}
