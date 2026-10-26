import 'dart:convert';
import 'dart:io';

import '../domain/models.dart';

class AppStorage {
  final Directory root;
  Map<String, dynamic> settings = {};
  AppStorage(this.root);
  factory AppStorage.standard() {
    final base =
        Platform.environment['XDG_DATA_HOME'] ??
        '${Platform.environment['HOME']}/.local/share';
    return AppStorage(Directory('$base/ex201-studio'));
  }
  Future<void> init() async {
    await root.create(recursive: true);
    try {
      settings = Map<String, dynamic>.from(
        jsonDecode(await File('${root.path}/settings.json').readAsString()),
      );
    } catch (_) {
      settings = {};
    }
  }

  Future<void> atomicJson(File file, Object data) async {
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(data)}\n',
      flush: true,
    );
    await temporary.rename(file.path);
  }

  Future<void> saveSettings() async =>
      atomicJson(File('${root.path}/settings.json'), settings);
  Future<String> snapshot(Map<String, dynamic> data, String reason) async {
    final now = DateTime.now().toUtc();
    final name =
        '${now.toIso8601String().replaceAll(':', '').replaceAll('.', '')}-$reason.json';
    final file = File('${root.path}/backups/$name');
    await atomicJson(file, {
      ...data,
      'saved_at': now.toIso8601String(),
      'reason': reason,
    });
    return file.path;
  }

  Future<List<BackupEntry>> backups() async {
    final folder = Directory('${root.path}/backups');
    if (!await folder.exists()) return [];
    final result = <BackupEntry>[];
    await for (final file in folder.list()) {
      if (file is! File || !file.path.endsWith('.json')) continue;
      try {
        final j = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        result.add(
          BackupEntry(
            file.path,
            j['reason'] ?? 'backup',
            DateTime.parse(j['saved_at']),
            (j['effects'] as List).length,
          ),
        );
      } catch (_) {}
    }
    result.sort((a, b) => b.time.compareTo(a.time));
    return result.take(100).toList();
  }

  void trace(String direction, List<int> bytes) {
    final row = jsonEncode({
      'at': DateTime.now().toUtc().toIso8601String(),
      'direction': direction,
      'hex': bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' '),
    });
    File('${root.path}/protocol-trace.jsonl')
        .writeAsStringSync('$row\n', mode: FileMode.append);
  }
}
