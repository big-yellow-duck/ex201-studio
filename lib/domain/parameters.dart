import 'dart:math' as math;

int roundEven(num value) {
  final lower = value.floor();
  return value - lower == .5
      ? (lower.isEven ? lower : lower + 1)
      : value.round();
}

class Parameter {
  final String key, label, kind, section, unit;
  final int index, selector, groupStart, groupCount;
  final double min, max;
  final Object scale;
  final Map<int, String> options;

  Parameter.fromJson(Map<String, dynamic> j)
    : key = j['key'],
      label = j['label'],
      kind = j['kind'],
      section = j['section'],
      unit = j['unit'] ?? '',
      index = j['index'],
      selector = j['selector'],
      groupStart = j['group_start'],
      groupCount = j['group_count'],
      min = (j['min'] as num).toDouble(),
      max = (j['max'] as num).toDouble(),
      scale = j['scale'],
      options = (j['options'] as Map<String, dynamic>? ?? {}).map(
        (k, v) => MapEntry(int.parse(k), v.toString()),
      );

  Object decode(int raw) {
    if (kind == 'boolean') return raw != 0;
    if (scale == 'linear') {
      return raw == 0
          ? -72.0
          : math.max(-72.0, 20 * math.log((raw & 65535) / 4096) / math.ln10);
    }
    return raw / (scale as num);
  }

  int encode(Object? value) {
    if (kind == 'boolean') {
      if (value is bool) return value ? 1 : 0;
      if (value is int && (value == 0 || value == 1)) return value;
      throw FormatException('$label must be on or off');
    }
    if (value is! num || !value.isFinite) {
      throw FormatException('$label needs a finite number');
    }
    if (value < min || value > max) {
      throw FormatException('$label must be between $min and $max $unit');
    }
    if (kind == 'select' &&
        (value != value.round() || !options.containsKey(value.toInt()))) {
      throw FormatException('Choose a valid $label');
    }
    final raw = roundEven(
      scale == 'linear'
          ? 4096 * math.pow(10, value / 20)
          : value * (scale as num),
    );
    if (raw < -32768 || raw > 32767) {
      throw FormatException('$label exceeds the board encoding range');
    }
    return raw;
  }
}

class ParameterGroup {
  final int selector, start, count;
  const ParameterGroup(this.selector, this.start, this.count);
}

class Patch {
  final List<int> words;
  final List<ParameterGroup> groups;
  const Patch(this.words, this.groups);
}

class ParameterRegistry {
  final Map<String, List<Parameter>> _schemas;
  ParameterRegistry.fromJson(Map<String, dynamic> json)
    : _schemas = json.map(
        (k, v) => MapEntry(
          k,
          (v as List)
              .map((f) => Parameter.fromJson(Map<String, dynamic>.from(f)))
              .toList(),
        ),
      );

  List<Parameter> schema(int type, int length) {
    final value = _schemas['$type:$length'];
    if (value == null) {
      throw FormatException('Unsupported effect layout $type / $length words');
    }
    return value;
  }

  Patch plan(int type, List<int> old, Map<String, Object?> changes) {
    final fields = {
      for (final field in schema(type, old.length)) field.key: field,
    };
    if (changes.isEmpty) return Patch(List.of(old), []);
    final expected = List<int>.of(old), groups = <int, ParameterGroup>{};
    for (final entry in changes.entries) {
      final f = fields[entry.key];
      if (f == null) throw FormatException('Unknown control ${entry.key}');
      expected[f.index] = f.encode(entry.value);
      groups[f.selector] = ParameterGroup(
        f.selector,
        f.groupStart,
        f.groupCount,
      );
    }
    if (type == 2 && expected[5] >= expected[6]) {
      throw const FormatException(
        'Lower crossover must be below upper crossover',
      );
    }
    if (type == 4) {
      for (var start = 3; start < expected.length; start += 5) {
        if (expected[start] != 0 &&
            (expected[start + 2] < 20 ||
                expected[start + 2] > 24000 ||
                expected[start + 3] < 51 ||
                expected[start + 3] > 30720)) {
          throw FormatException(
            'Set valid frequency and Q before enabling band ${(start - 3) ~/ 5 + 1}',
          );
        }
      }
    }
    final bypass = {
      for (final f in fields.values)
        if (f.key == 'enabled' || f.key.endsWith('_enabled'))
          f.selector: f.index,
    };
    int priority(int selector) => bypass.containsKey(selector)
        ? (expected[bypass[selector]!] == 0 ? 0 : 2)
        : 1;
    final ordered = groups.values.toList()
      ..sort((a, b) {
        final d = priority(a.selector).compareTo(priority(b.selector));
        return d == 0 ? a.selector.compareTo(b.selector) : d;
      });
    return Patch(expected, ordered);
  }
}
