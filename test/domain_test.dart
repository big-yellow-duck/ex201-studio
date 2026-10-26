import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ex201_studio/domain/parameters.dart';
import 'package:ex201_studio/domain/protocol.dart';
import 'package:ex201_studio/domain/audio_math.dart';

void main() {
  final registry = ParameterRegistry.fromJson(
    jsonDecode(File('assets/effect-schemas.json').readAsStringSync()),
  );
  test('Dart matches all 1,436 parameter plans from the Python reference', () {
    final vectors = jsonDecode(
      File('test/fixtures/python-reference-vectors.json').readAsStringSync(),
    ) as List;
    expect(vectors.length, 1436);
    for (final v in vectors) {
      final patch = registry.plan(
        v['type'],
        List<int>.from(v['before']),
        Map<String, Object?>.from(v['changes']),
      );
      expect(patch.words, v['after'], reason: '${v['type']} ${v['changes']}');
      expect(
        patch.groups.map((g) => [g.selector, g.start, g.count]).toList(),
        v['groups'],
      );
    }
  });
  test('Raw frames handle padding, coalescing, truncation and signed word boundaries', () {
    final f = frame(137, [
      255,
      ...wordBytes([-32768, -1, 0, 1, 32767]),
    ]);
    expect(signedWords(f.sublist(5, f.length - 1)), [-32768, -1, 0, 1, 32767]);
    expect(
      framesIn([
        0,
        0,
        ...f,
        0,
        ...frame(0, [48, 0, 3, 1, 2, 30, 0]),
        0,
      ]).length,
      2,
    );
    expect(framesIn(f.sublist(0, f.length - 1)), isEmpty);
    expect(() => signedWords([1]), throwsFormatException);
  });
  test('Invalid and out-of-scope parameters fail before transport', () {
    final old = List<int>.filled(53, 0);
    for (final changes in [
      {'pregain_db': double.nan},
      {'pregain_db': 1},
      {'band_1_type': 9},
      {'band_11_gain_db': 0},
      {'enabled': 'yes'},
      {'band_1_enabled': true},
    ]) {
      expect(() => registry.plan(4, old, changes), throwsFormatException);
    }
    final drc = List<int>.filled(27, 0)
      ..[5] = 300
      ..[6] = 2000;
    expect(
      () => registry.plan(2, drc, {'crossover_low': 2001}),
      throwsFormatException,
    );
  });
  test(
    'Zero-gain EQ, center gain, pass slopes and notch retain known behavior',
    () {
      for (final type in [0, 1, 2]) {
        for (final f in [20.0, 100.0, 1000.0, 10000.0, 20000.0]) {
          expect(filterDb(type, 1000, .707, 0, f), closeTo(0, .02));
        }
      }
      expect(filterDb(0, 1000, 1, -6, 1000), closeTo(-6, .02));
      expect(filterDb(6, 1000, 3, 0, 1000), lessThan(-70));
      expect(filterDb(3, 1000, .707, 0, 10000), lessThan(-35));
      expect(filterDb(4, 1000, .707, 0, 100), lessThan(-35));
      expect(filterDb(7, 100, .707, 0, 100), closeTo(-3.0103, .02));
      expect(compressDb(-10, -18, 4), -16);
      expect(expandDb(-60, -50, 3), -80);
    },
  );
  test('Every advertised filter boundary remains finite', () {
    for (var type = 0; type < 9; type++) {
      for (final f in [20.0, 1000.0, 24000.0]) {
        for (final q in [.05, .707, 30.0]) {
          for (final gain in [-36.0, 0.0, 36.0]) {
            for (final at in [20.0, 1000.0, 20000.0]) {
              expect(filterDb(type, f, q, gain, at).isFinite, isTrue);
            }
          }
        }
      }
    }
  });
  test(
    'Board slot response is a count, with unavailable controls explicit',
    () {
      expect(decodeBoard('scene', [3, 0])['max'], 2);
      expect(() => decodeBoard('scene', [3, 3]), throwsFormatException);
      expect(() => decodeBoard('input', []), throwsFormatException);
      expect(decodeBoard('volume', [16, 6])['value'], 6);
    },
  );
}
