import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ex201_studio/application/bootstrap.dart';
import 'package:ex201_studio/application/controller.dart';
import 'package:ex201_studio/ui/app.dart';
import 'package:ex201_studio/ui/effect_page.dart';
import 'package:ex201_studio/ui/pages.dart';
import 'package:ex201_studio/ui/filter_lab.dart';

void main() {
  testWidgets('All native editors, learning drafts and responsive layouts', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1080));
    final material = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await material.load();
    final fonts = FontLoader('Manrope')
      ..addFont(rootBundle.load('assets/fonts/Manrope.ttf'));
    await fonts.load();
    final bundle = (await tester.runAsync(StudioBundle.load))!;
    late Directory folder;
    late StudioController c;
    await tester.runAsync(() async {
      folder = await Directory.systemTemp.createTemp('ex201-ui-');
      c = await bundle.controller(demo: true, dataDirectory: folder);
      await c.connect(c.transport.address!);
    });
    const boundaryKey = ValueKey('qa-boundary');
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: StudioApp(bundle: bundle, controller: c, autoConnect: false),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    Future<void> capture(String name) async {
      debugPrint('Capturing $name');
      await tester.pump();
      final render = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(boundaryKey),
      );
      await tester.runAsync(() async {
        final image = await render.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('screenshots').create(recursive: true);
        await File('screenshots/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    Future<void> go(String page) async {
      debugPrint('Checking page $page');
      final button = find.byKey(ValueKey('nav-$page'));
      final sidebar = find
          .descendant(
            of: find.byType(ListView).first,
            matching: find.byType(Scrollable),
          )
          .first;
      tester.state<ScrollableState>(sidebar).position.jumpTo(0);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(button, 250, scrollable: sidebar);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pump();
      for (var tick = 0; tick < (page == 'backups' ? 20 : 1); tick++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Page $page');
    }

    await capture('workspace');
    for (final e in c.effects) {
      await go('${e.address}');
      expect(find.byType(EffectPage), findsOneWidget);
      expect(
        tester.widget<EffectPage>(find.byType(EffectPage)).effect.address,
        e.address,
      );
    }
    await go('137');
    await capture('equalizer');
    final before = c.effect(137).words.toList();
    await tester.tap(find.byKey(const ValueKey('open-filter-explorer')));
    await tester.pumpAndSettle();
    expect(find.byType(FilterLab), findsOneWidget);
    await capture('filter-explorer');
    await tester.tap(find.byKey(const ValueKey('copy-filter-draft')));
    await tester.pumpAndSettle();
    expect(c.effect(137).words, before);
    expect(find.textContaining('draft change'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('discard-draft')));
    await tester.pumpAndSettle();
    expect(c.effect(137).words, before);
    await go('138');
    await tester.tap(find.byKey(const ValueKey('drc-example')));
    await tester.pumpAndSettle();
    await capture('dynamics');
    expect(c.effect(138).words[14], 100); // Example remained a local draft.
    await tester.tap(find.byKey(const ValueKey('discard-draft')));
    await tester.pumpAndSettle();
    await go('board');
    await capture('board-controls');
    await go('backups');
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 40));
    });
    await tester.pumpAndSettle();
    await capture('backups');
    await go('guide');
    expect(find.byType(GuidePage), findsOneWidget);
    await capture('beginner-guide');
    for (final width in [1100.0, 820.0, 600.0, 390.0]) {
      await tester.binding.setSurfaceSize(Size(width, 1000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Guide at width $width');
    }
    await tester.binding.setSurfaceSize(const Size(1440, 1080));
    await tester.pumpAndSettle();
    await go('137');
    for (final width in [1100.0, 820.0, 600.0, 390.0]) {
      await tester.binding.setSurfaceSize(Size(width, 1000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'EQ at width $width');
    }
    await capture('compact-equalizer');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await folder.delete(recursive: true);
    });
    await tester.binding.setSurfaceSize(null);
  });
}
