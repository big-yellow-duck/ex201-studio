import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ex201_studio/application/bootstrap.dart';

void main() {
  test(
    'Physical EX201 Dart read/write/restore migration check',
    () async {
      final address = Platform.environment['EX201_TEST_BOARD'];
      if (address == null) return;
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      final bundle = await StudioBundle.load();
      final storage = Directory('${Directory.current.path}/docs/live-session');
      final c = await bundle.controller(dataDirectory: storage);
      final results = <Map<String, dynamic>>[];
      Map<String, dynamic>? original;
      try {
        await c.connect(address);
        original = c.preset();
        await c.storage.atomicJson(
          File('docs/native-live-baseline.json'),
          original,
        );
        expect(c.effects.length, 19);
        expect(c.effects.fold<int>(0, (n, e) => n + e.parameters.length), 401);
        // Only quiet edits inside already-bypassed blocks. Never enable an effect,
        // switch preset slots, save flash, or change the audible master level.
        for (final spec in [
          (4, 'pregain_db', .5),
          (2, 'threshold_0', .1),
          (15, 'gain_db', .5),
        ]) {
          final block = c.effects.firstWhere(
            (e) => e.type == spec.$1 && !e.enabled,
          );
          final value = (block.value(spec.$2) as num).toDouble(),
              before = List<int>.of(block.words);
          await c.edit(block.address, {spec.$2: value - spec.$3});
          final desired = c.registry.plan(block.type, before, {
            spec.$2: value - spec.$3,
          }).words;
          expect(await c.readWords(block.address), desired);
          await c.edit(block.address, {spec.$2: value});
          expect(await c.readWords(block.address), before);
          results.add({
            'address': block.address,
            'effect': block.title,
            'control': spec.$2,
            'temporary_cut': spec.$3,
            'write_verified': true,
            'original_restored': true,
            'effect_remained_bypassed': true,
          });
        }
        final volume = c.board['volume']['value'] as int;
        await c.editDevice('volume', volume);
        expect(c.board['volume']['value'], volume);
        results.add({
          'control': 'master_volume',
          'write_same_value': volume,
          'readback_verified': true,
        });
      } finally {
        if (original != null && c.connected) {
          await c.restore(original);
          await c.refresh();
          final expected = {
            for (final e in original['effects']) e['address']: e['raw_words'],
          };
          for (final e in c.effects) {
            expect(e.words, expected[e.address], reason: e.title);
          }
          expect(
            c.board['volume']['value'],
            original['board']['volume']['value'],
          );
          expect(
            c.board['scene']['value'],
            original['board']['scene']['value'],
          );
          await c.storage.atomicJson(File('docs/native-live-validation.json'), {
            'at': DateTime.now().toUtc().toIso8601String(),
            'passed': true,
            'scope': 'Physical EX201 BLE control from Dart; cuts in already-bypassed blocks; no flash save or preset switch.',
            'tests': results,
            'all_19_original_blocks_restored': true,
            'original_volume_restored': true,
            'original_preset_unchanged': true,
            'snapshot': c.preset(),
          });
        }
        await c.shutdown();
      }
      expect(binding, isNotNull);
    },
    skip: Platform.environment['EX201_TEST_BOARD'] == null,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
