import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ex201_studio/application/controller.dart';
import 'package:ex201_studio/domain/models.dart';
import 'package:ex201_studio/domain/parameters.dart';
import 'package:ex201_studio/infrastructure/demo_transport.dart';
import 'package:ex201_studio/infrastructure/storage.dart';
import 'package:ex201_studio/infrastructure/transport.dart';

class RecordingTransport implements BoardTransport {
  final BoardTransport delegate;
  final commands = <List<int>>[];
  bool failNextReadAfterWrite = false, _pendingFailure = false;
  RecordingTransport(this.delegate);
  @override
  bool get connected => delegate.connected;
  @override
  bool get isDemo => delegate.isDemo;
  @override
  String? get address => delegate.address;
  @override
  String get name => delegate.name;
  @override
  Stream<bool> get connectionChanges => delegate.connectionChanges;
  @override
  Future<List<DiscoveredBoard>> scan() => delegate.scan();
  @override
  Future<void> connect(String address) => delegate.connect(address);
  @override
  Future<void> send(List<int> command) {
    commands.add(List.of(command));
    return delegate.send(command);
  }

  @override
  Future<List<int>> exchange(
    List<int> command, {
    int? selector,
    bool ack = false,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    commands.add(List.of(command));
    final reply = await delegate.exchange(
      command,
      selector: selector,
      ack: ack,
      timeout: timeout,
    );
    if (_pendingFailure &&
        command[3] == 0 &&
        command[2] >= 129 &&
        command[2] <= 147) {
      _pendingFailure = false;
      final corrupt = List<int>.of(reply);
      corrupt[5] ^= 1;
      return corrupt;
    }
    if (failNextReadAfterWrite &&
        command[3] > 0 &&
        command[2] >= 129 &&
        command[2] <= 147) {
      failNextReadAfterWrite = false;
      _pendingFailure = true;
    }
    return reply;
  }

  @override
  Future<void> close() => delegate.close();
}

void main() {
  final registry = ParameterRegistry.fromJson(
    jsonDecode(File('assets/effect-schemas.json').readAsStringSync()),
  );
  final fixture = jsonDecode(
    File('assets/demo-board.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  late StudioController c;
  late RecordingTransport t;
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('ex201-controller-test-');
    final storage = AppStorage(directory);
    await storage.init();
    t = RecordingTransport(DemoTransport(fixture, registry));
    c = StudioController(registry, storage, t);
    await c.connect(t.address!);
    t.commands.clear();
  });
  tearDown(() async {
    await c.shutdown();
    await directory.delete(recursive: true);
  });
  test('Full dynamic catalogue exposes all 19 blocks and 401 typed fields', () {
    expect(c.effects.length, 19);
    expect(c.effects.fold<int>(0, (n, e) => n + e.parameters.length), 401);
    expect(c.board['scene']['count'], 3);
    expect(c.board['input']['supported'], false);
  });
  test('Grouped DRC edit preserves all other paths and round-trips an existing preset', () async {
    final original = c.preset(), before = List<int>.of(c.effect(138).words);
    await c.edit(138, {'threshold_0': -.1, 'threshold_1': -.2});
    expect(c.effect(138).words.sublist(7, 11), [
      -10,
      -20,
      ...before.sublist(9, 11),
    ]);
    final writes = t.commands.where((p) => p[2] == 138 && p[3] > 0).toList();
    expect(writes.length, 1);
    expect(writes.single[4], 6);
    expect(writes.single[3], 9);
    await c.restore(original);
    expect(c.effect(138).words, before);
    expect((await c.storage.backups()).length, greaterThanOrEqualTo(5));
  });
  test('New EQ bands are configured before enable, and the preserved header never changes', () async {
    final before = List<int>.of(c.effect(137).words);
    await c.edit(137, {
      'band_10_enabled': true,
      'band_10_type': 0,
      'band_10_frequency_hz': 1000,
      'band_10_q': 1,
      'band_10_gain_db': -3,
    });
    final selectors = t.commands
        .where((p) => p[2] == 137 && p[3] > 0)
        .map((p) => p[4])
        .toList();
    expect(selectors.last, 48);
    expect(c.effect(137).words[2], before[2]);
  });
  test(
    'Invalid UI changes and preset identities cause zero settings commands',
    () async {
      await expectLater(
        c.edit(137, {'pregain_db': double.infinity}),
        throwsFormatException,
      );
      final preset = c.preset();
      preset['device'] = {'address': 'WRONG'};
      await expectLater(c.restore(preset), throwsFormatException);
      final valid = c.preset();
      (valid['effects'] as List).add((valid['effects'] as List).first);
      await expectLater(c.restore(valid), throwsFormatException);
      expect(t.commands, isEmpty);
    },
  );
  test(
    'A corrupt readback rolls the complete block back to its previous words',
    () async {
      final before = List<int>.of(c.effect(137).words);
      t.failNextReadAfterWrite = true;
      await expectLater(c.edit(137, {'pregain_db': -.5}), throwsStateError);
      expect(await c.readWords(137), before);
      expect(c.effect(137).words, before);
      expect(c.busy, false);
    },
  );
  test(
    'Master volume, mute recovery and all three preset selectors use readback',
    () async {
      await c.editDevice('volume', 8);
      expect(c.board['volume']['value'], 8);
      await c.editDevice('mute', true);
      expect(c.board['volume']['value'], 0);
      await c.editDevice('mute', false);
      expect(c.board['volume']['value'], 8);
      for (final slot in [0, 1, 2]) {
        await c.editDevice('scene', slot);
        expect(c.board['scene']['value'], slot);
      }
      await expectLater(c.editDevice('scene', 3), throwsFormatException);
      await expectLater(c.editDevice('input', 1), throwsStateError);
    },
  );
}
