import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'application/bootstrap.dart';
import 'infrastructure/storage.dart';
import 'ui/app.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Manrope',
    ], await rootBundle.loadString('assets/fonts/OFL.txt'));
  });
  final bundle = await StudioBundle.load();
  final demo = args.contains('--demo');
  final data = args
      .where((a) => a.startsWith('--data-dir='))
      .firstOrNull
      ?.substring(11);
  final controller = await bundle.controller(
    demo: demo,
    dataDirectory: data != null
        ? Directory(data)
        : demo
        ? Directory('${AppStorage.standard().root.path}/demo')
        : null,
  );
  final audit = args
      .where((a) => a.startsWith('--audit-readonly='))
      .firstOrNull
      ?.substring(17);
  if (audit != null) {
    final address =
        args.where((a) => a.startsWith('--board=')).firstOrNull?.substring(8) ??
        controller.storage.settings['last_board'];
    try {
      if (address == null) {
        throw StateError('Pass --board=BLE_ADDRESS for an audit.');
      }
      await controller.connect(address);
      await controller.storage.atomicJson(File(audit), {
        'at': DateTime.now().toUtc().toIso8601String(),
        'mode': demo ? 'demo' : 'physical-board-readonly',
        'connected': controller.connected,
        'effects': controller.effects.length,
        'editable_controls': controller.effects.fold<int>(
          0,
          (n, e) => n + e.parameters.length,
        ),
        'snapshot': controller.preset(),
      });
      await controller.shutdown();
      exit(0);
    } catch (error) {
      await File(audit).writeAsString(jsonEncode({'error': error.toString()}));
      await controller.shutdown();
      exit(1);
    }
  }
  runApp(StudioApp(bundle: bundle, controller: controller));
}
