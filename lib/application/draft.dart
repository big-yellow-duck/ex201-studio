import 'package:flutter/foundation.dart';

import '../domain/models.dart';

class EffectDraft extends ChangeNotifier {
  DspEffect effect;
  int resetEpoch = 0;
  late Map<String, Object> values;
  final Map<String, String> errors = {};
  EffectDraft(this.effect) {
    reset();
  }
  void reset() {
    resetEpoch++;
    values = effect.values;
    errors.clear();
    notifyListeners();
  }

  void set(String key, Object value) {
    values[key] = value;
    errors.remove(key);
    notifyListeners();
  }

  void setMany(Map<String, Object> changes) {
    values.addAll(changes);
    for (final key in changes.keys) {
      errors.remove(key);
    }
    notifyListeners();
  }

  void invalid(String key, String message) {
    errors[key] = message;
    notifyListeners();
  }

  Object value(String key) => values[key]!;
  double number(String key) => (values[key] as num).toDouble();
  bool flag(String key) => values[key] == true;
  Map<String, Object> get changes {
    final result = <String, Object>{};
    for (final f in effect.parameters) {
      final value = values[f.key]!;
      if (value == f.decode(effect.words[f.index])) continue;
      if (f.encode(value) != effect.words[f.index]) result[f.key] = value;
    }
    return result;
  }

  int get changedCount {
    try {
      return changes.length;
    } on FormatException {
      return errors.isEmpty ? 1 : errors.length;
    }
  }

  bool get dirty => errors.isNotEmpty || changedCount > 0;
  void flatEq() {
    final changes = <String, Object>{'enabled': false, 'pregain_db': 0.0};
    const frequencies = [31, 63, 125, 250, 500, 1000, 2000, 4000, 8000, 16000];
    for (var i = 1; i <= 10; i++) {
      changes.addAll({
        'band_${i}_enabled': true,
        'band_${i}_type': 0,
        'band_${i}_frequency_hz': frequencies[i - 1].toDouble(),
        'band_${i}_q': .70703125,
        'band_${i}_gain_db': 0.0,
      });
    }
    setMany(changes);
  }
}
