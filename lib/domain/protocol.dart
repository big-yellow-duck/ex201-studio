import 'dart:convert';
import 'dart:typed_data';

const controlService = '0000ab00-0000-1000-8000-00805f9b34fb';
const controlChannel = '0000ab01-0000-1000-8000-00805f9b34fb';

Uint8List frame(int address, [List<int> payload = const []]) {
  if (address < 0 ||
      address > 255 ||
      payload.length > 250 ||
      payload.any((b) => b < 0 || b > 255)) {
    throw const FormatException('Invalid protocol frame');
  }
  return Uint8List.fromList([165, 90, address, payload.length, ...payload, 22]);
}

Iterable<Uint8List> framesIn(List<int> data) sync* {
  for (var i = 0; i + 4 < data.length; i++) {
    if (data[i] != 165 || data[i + 1] != 90) continue;
    final end = i + data[i + 3] + 5;
    if (end <= data.length && data[end - 1] == 22) {
      yield Uint8List.fromList(data.sublist(i, end));
      i = end - 1;
    }
  }
}

String hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
String boardText(List<int> bytes) => utf8
    .decode(bytes.takeWhile((b) => b != 0).toList(), allowMalformed: true)
    .trim();
List<int> signedWords(List<int> bytes) {
  if (bytes.length.isOdd) {
    throw const FormatException('Odd byte count in parameter reply');
  }
  final data = ByteData.sublistView(Uint8List.fromList(bytes));
  return [
    for (var i = 0; i < bytes.length; i += 2) data.getInt16(i, Endian.little),
  ];
}

List<int> wordBytes(List<int> words) {
  final data = ByteData(words.length * 2);
  for (var i = 0; i < words.length; i++) {
    if (words[i] < -32768 || words[i] > 32767) {
      throw const FormatException(
        'Parameter word is outside the signed 16-bit range',
      );
    }
    data.setInt16(i * 2, words[i], Endian.little);
  }
  return data.buffer.asUint8List();
}

Map<String, dynamic> decodeBoard(String key, List<int> p) {
  int word(int i) => p[i] | p[i + 1] << 8;
  const inputs = {
    1: 'Bluetooth',
    2: 'USB drive',
    4: 'AUX',
    5: 'USB sound card',
  };
  switch (key) {
    case 'device_id':
    case 'bluetooth_name':
    case 'scene_tag':
      final text = boardText(p);
      if (text.isEmpty || text.runes.any((c) => c < 32)) {
        throw const FormatException('No valid text returned');
      }
      return {'value': text};
    case 'volume':
      if (p.length != 2 || p[0] > 100 || p[1] > p[0]) {
        throw const FormatException('Unexpected volume response');
      }
      return {'max': p[0], 'value': p[1]};
    case 'scene':
      if (p.length != 2 || p[0] < 1 || p[0] > 32 || p[1] >= p[0]) {
        throw const FormatException('Unexpected preset response');
      }
      return {'count': p[0], 'max': p[0] - 1, 'value': p[1]};
    case 'input':
      if (p.length != 1 || !inputs.containsKey(p[0])) {
        throw const FormatException(
          'Input selection is not exposed by this firmware',
        );
      }
      return {
        'value': p[0],
        'label': inputs[p[0]],
        'options': {for (final e in inputs.entries) e.key.toString(): e.value},
      };
    case 'connectors':
      const names = [
        'power_key',
        'vr',
        'encoder',
        'reboot',
        'reset',
        'stereo_test',
        'music_test',
        'mute',
        'frequency_mode',
        'bluetooth_visibility',
      ];
      if (p.length < names.length) {
        throw const FormatException('Connector status unavailable');
      }
      return {
        'values': {for (var i = 0; i < names.length; i++) names[i]: p[i]},
      };
    case 'system_status':
      if (p.length < 10 || p[0] != 255) {
        throw const FormatException('System diagnostics unavailable');
      }
      return {
        'memory_used_kb': word(1),
        'cpu_used_mhz': word(3),
        'parameter_change_flag': p[5],
        'cpu_max_mhz': word(6),
        'memory_max_kb': word(8),
      };
    default:
      return {'raw_payload_hex': hex(p)};
  }
}

const boardQueries = <String, (int, List<int>)>{
  'device_id': (18, []),
  'volume': (18, [1]),
  'input': (18, [4]),
  'scene': (18, [6]),
  'bluetooth_name': (18, [8]),
  'connectors': (18, [16]),
  'system_config': (1, []),
  'system_status': (2, []),
  'scene_tag': (252, []),
};
