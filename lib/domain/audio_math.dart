import 'dart:math' as m;

/// Standard teaching models at assumed 48 kHz, never a speaker measurement.
double filterDb(int type, double frequency, double q, double gain, double at) {
  if (![frequency, q, gain, at].every((v) => v.isFinite) ||
      frequency <= 0 ||
      q <= 0 ||
      at <= 0) {
    return 0;
  }
  const fs = 48000.0;
  final f = m.min(frequency, 23999.0),
      w0 = 2 * m.pi * f / fs,
      c = m.cos(w0),
      s = m.sin(w0),
      alpha = s / (2 * q),
      a = m.pow(10, gain / 40).toDouble();
  double b0 = 1, b1 = 0, b2 = 0, a0 = 1, a1 = 0, a2 = 0;
  if (type == 7 || type == 8) {
    final k = m.tan(m.pi * f / fs), r = 1 / (1 + k);
    b0 = type == 7 ? k * r : r;
    b1 = type == 7 ? b0 : -b0;
    a1 = (k - 1) * r;
  } else if (type == 0) {
    b0 = 1 + alpha * a;
    b1 = -2 * c;
    b2 = 1 - alpha * a;
    a0 = 1 + alpha / a;
    a1 = -2 * c;
    a2 = 1 - alpha / a;
  } else if (type == 1) {
    final x = 2 * m.sqrt(a) * alpha;
    b0 = a * ((a + 1) - (a - 1) * c + x);
    b1 = 2 * a * ((a - 1) - (a + 1) * c);
    b2 = a * ((a + 1) - (a - 1) * c - x);
    a0 = (a + 1) + (a - 1) * c + x;
    a1 = -2 * ((a - 1) + (a + 1) * c);
    a2 = (a + 1) + (a - 1) * c - x;
  } else if (type == 2) {
    final x = 2 * m.sqrt(a) * alpha;
    b0 = a * ((a + 1) + (a - 1) * c + x);
    b1 = -2 * a * ((a - 1) + (a + 1) * c);
    b2 = a * ((a + 1) + (a - 1) * c - x);
    a0 = (a + 1) - (a - 1) * c + x;
    a1 = 2 * ((a - 1) - (a + 1) * c);
    a2 = (a + 1) - (a - 1) * c - x;
  } else {
    a0 = 1 + alpha;
    a1 = -2 * c;
    a2 = 1 - alpha;
    if (type == 3) {
      b0 = (1 - c) / 2;
      b1 = 1 - c;
      b2 = b0;
    } else if (type == 4) {
      b0 = (1 + c) / 2;
      b1 = -(1 + c);
      b2 = b0;
    } else if (type == 5) {
      b0 = alpha;
      b2 = -alpha;
    } else if (type == 6) {
      b0 = 1;
      b1 = -2 * c;
      b2 = 1;
    }
  }
  final w = 2 * m.pi * m.min(at, 23999) / fs;
  double power(double x, double y, double z) =>
      m.pow(x + y * m.cos(w) + z * m.cos(2 * w), 2).toDouble() +
      m.pow(-y * m.sin(w) - z * m.sin(2 * w), 2).toDouble();
  return 10 *
      m.log(m.max(1e-15, power(b0, b1, b2)) / m.max(1e-15, power(a0, a1, a2))) /
      m.ln10;
}

double compressDb(double input, double threshold, double ratio) =>
    input <= threshold
    ? input
    : threshold + (input - threshold) / m.max(1, ratio);
double expandDb(double input, double threshold, double ratio) =>
    input >= threshold
    ? input
    : threshold + (input - threshold) * m.max(1, ratio);

class EqBand {
  final int band, type;
  final bool enabled;
  final double frequency, q, gain;
  const EqBand(
    this.band,
    this.type,
    this.enabled,
    this.frequency,
    this.q,
    this.gain,
  );
  bool get valid =>
      frequency >= 20 && frequency <= 24000 && q >= .049 && q <= 30;
  double response(double at) =>
      valid ? filterDb(type, frequency, q, gain, at) : 0;
  static List<EqBand> fromValues(Map<String, Object> values) => [
    for (var i = 1; i <= 10; i++)
      EqBand(
        i,
        (values['band_${i}_type'] as num).toInt(),
        values['band_${i}_enabled'] == true,
        (values['band_${i}_frequency_hz'] as num).toDouble(),
        (values['band_${i}_q'] as num).toDouble(),
        (values['band_${i}_gain_db'] as num).toDouble(),
      ),
  ];
}

double combinedDb(List<EqBand> bands, double preamp, double frequency) =>
    preamp +
    bands
        .where((b) => b.enabled)
        .fold<double>(0, (sum, b) => sum + b.response(frequency));
double peakDb(List<EqBand> bands, double preamp) {
  double peak = -double.infinity;
  for (var i = 0; i <= 800; i++) {
    peak = m.max(
      peak,
      combinedDb(bands, preamp, (20 * m.pow(1000, i / 800)).toDouble()),
    );
  }
  for (final band in bands.where(
    (b) => b.enabled && b.valid && b.frequency <= 20000,
  )) {
    peak = m.max(peak, combinedDb(bands, preamp, band.frequency));
  }
  return peak;
}
