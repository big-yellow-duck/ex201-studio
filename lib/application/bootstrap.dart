import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'controller.dart';
import 'help_book.dart';
import '../domain/parameters.dart';
import '../infrastructure/bluez_transport.dart';
import '../infrastructure/demo_transport.dart';
import '../infrastructure/storage.dart';
import '../infrastructure/transport.dart';

class StudioBundle {
  final ParameterRegistry registry;
  final HelpBook help;
  final Map<String, dynamic> fixture;
  const StudioBundle(this.registry, this.help, this.fixture);
  static Future<StudioBundle> load() async => StudioBundle(
    ParameterRegistry.fromJson(
      jsonDecode(await rootBundle.loadString('assets/effect-schemas.json')),
    ),
    HelpBook(
      jsonDecode(await rootBundle.loadString('assets/help-content.json')),
    ),
    jsonDecode(await rootBundle.loadString('assets/demo-board.json')),
  );
  Future<StudioController> controller({
    bool demo = false,
    Directory? dataDirectory,
  }) async {
    final storage = dataDirectory == null
        ? AppStorage.standard()
        : AppStorage(dataDirectory);
    await storage.init();
    final BoardTransport transport = demo
        ? DemoTransport(fixture, registry)
        : BluezTransport(trace: storage.trace);
    return StudioController(registry, storage, transport);
  }
}
