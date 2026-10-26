import 'dart:async';

import '../domain/protocol.dart';
import '../domain/models.dart';
import '../domain/parameters.dart';
import 'transport.dart';

/// Explicit simulator for previews/tests. It has no BlueZ client or radio access.
class DemoTransport implements BoardTransport {
  final Map<String, dynamic> fixture;
  final ParameterRegistry registry;
  final _events = StreamController<bool>.broadcast();
  final Map<int, List<int>> _words = {};
  int volume = 6, scene = 0;
  bool _connected = false;
  DemoTransport(this.fixture, this.registry) {
    for (final e in fixture['effects']) {
      _words[e['address']] = List<int>.from(e['raw_words']);
    }
  }
  @override
  bool get connected => _connected;
  @override
  bool get isDemo => true;
  @override
  String get address => 'DE:00:00:00:00:01';
  @override
  String get name => 'Demo EX201';
  @override
  Stream<bool> get connectionChanges => _events.stream;
  @override
  Future<List<DiscoveredBoard>> scan() async => [
    DiscoveredBoard(address, name),
  ];
  @override
  Future<void> connect(String address) async {
    _connected = true;
    _events.add(true);
  }

  @override
  Future<void> send(List<int> command) async {}
  @override
  Future<List<int>> exchange(
    List<int> command, {
    int? selector,
    bool ack = false,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    if (!connected) throw StateError('Connect the demo first');
    final a = command[2], p = command.sublist(4, command.length - 1);
    await Future<void>.delayed(const Duration(milliseconds: 1));
    if (a == 0) return frame(0, [48, 0, 3, 1, 2, 30, 0]);
    if (a == 128) {
      final items = fixture['effects'] as List;
      if (p.first == 0) {
        return frame(a, [
          0,
          items.length,
          ...items.expand((e) => [e['type'] as int, 0]),
        ]);
      }
      return frame(a, [
        p.first,
        ...(items[p.first - 1]['name'] as String).codeUnits,
      ]);
    }
    if (_words.containsKey(a)) {
      if (p.isEmpty) return frame(a, [255, ...wordBytes(_words[a]!)]);
      final effect = (fixture['effects'] as List).firstWhere(
        (e) => e['address'] == a,
      );
      final f = registry
          .schema(effect['type'], _words[a]!.length)
          .firstWhere((f) => f.selector == p.first);
      final values = signedWords(p.sublist(1));
      _words[a]!.replaceRange(
        f.groupStart,
        f.groupStart + f.groupCount,
        values,
      );
      return [a, 0, 0, 0, 0];
    }
    if (a == 18) {
      if (p.isEmpty) return frame(a, 'EX201 preview'.codeUnits);
      switch (p.first) {
        case 1:
          return frame(a, [16, volume]);
        case 2:
          volume = p[1];
          return [18, 0, 0, 0, 0];
        case 6:
          return frame(a, [3, scene]);
        case 5:
          scene = p[1];
          return [18, 0, 0, 0, 0];
        default:
          return frame(a);
      }
    }
    if (a == 2) return frame(a, [255, 233, 0, 25, 0, 0, 44, 1, 64, 1]);
    if (a == 252) return frame(a, 'Preview'.codeUnits);
    return frame(a);
  }

  @override
  Future<void> close() async {
    _connected = false;
    await _events.close();
  }
}
