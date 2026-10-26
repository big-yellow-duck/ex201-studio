import 'parameters.dart';

const effectTitles = {
  129: 'Noise suppression',
  130: '3D spatial',
  131: 'Music virtual bass',
  132: 'DACX virtual bass',
  133: 'Classic virtual bass',
  134: 'Stereo widening',
  135: 'Harmonic exciter',
  136: 'Polarity',
  137: 'Music pre EQ',
  138: 'Music dynamics',
  139: 'Music output EQ',
  140: 'Left channel EQ',
  141: 'Right channel EQ',
  142: 'DACX pre EQ',
  143: 'DACX dynamics',
  144: 'DACX output EQ',
  145: 'Music output gain',
  146: 'Bluetooth input gain',
  147: 'USB / card input gain',
};

class DspEffect {
  final int address, type;
  final String name;
  List<int> words;
  final List<Parameter> parameters;
  DspEffect({
    required this.address,
    required this.type,
    required this.name,
    required this.words,
    required this.parameters,
  });
  String get title => effectTitles[address] ?? name;
  String get group => name.split(':').first;
  bool get enabled => words.isNotEmpty && words.first != 0;
  bool get isEq => type == 4;
  bool get editable => parameters.isNotEmpty;
  Object value(String key) {
    final f = parameters.firstWhere((f) => f.key == key);
    return f.decode(words[f.index]);
  }

  Map<String, Object> get values => {
    for (final f in parameters) f.key: f.decode(words[f.index]),
  };
  Map<String, dynamic> toJson() => {
    'address': address,
    'type': type,
    'name': name,
    'raw_words': List.of(words),
  };
  factory DspEffect.fromJson(
    Map<String, dynamic> j,
    ParameterRegistry registry,
  ) {
    final words = List<int>.from(j['raw_words']);
    List<Parameter> fields;
    try {
      fields = registry.schema(j['type'], words.length);
    } on FormatException {
      fields = [];
    }
    return DspEffect(
      address: j['address'],
      type: j['type'],
      name: j['name'],
      words: words,
      parameters: fields,
    );
  }
}

class DiscoveredBoard {
  final String address, name;
  final bool remembered;
  const DiscoveredBoard(this.address, this.name, {this.remembered = false});
}

class BackupEntry {
  final String path, reason;
  final DateTime time;
  final int effects;
  const BackupEntry(this.path, this.reason, this.time, this.effects);
}
