import 'package:flutter/material.dart';

abstract final class StudioColors {
  static const background = Color(0xfff4f5ef),
      paper = Color(0xffffffff),
      ink = Color(0xff243b30),
      muted = Color(0xff6c7b6d),
      green = Color(0xff346344),
      pale = Color(0xffe9f0e1),
      line = Color(0xffdfe5d8),
      ochre = Color(0xffb88742),
      dark = Color(0xff1d3328),
      danger = Color(0xffad4738);
}

ThemeData studioTheme() => ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  scaffoldBackgroundColor: StudioColors.background,
  fontFamily: 'Manrope',
  colorScheme: ColorScheme.fromSeed(
    seedColor: StudioColors.green,
    brightness: Brightness.light,
    surface: StudioColors.paper,
    onSurface: StudioColors.ink,
  ),
  textTheme: const TextTheme(
    headlineLarge: TextStyle(
      fontSize: 30,
      fontWeight: FontWeight.w700,
      letterSpacing: -1,
    ),
    headlineMedium: TextStyle(
      fontSize: 25,
      fontWeight: FontWeight.w700,
      letterSpacing: -.6,
    ),
    titleLarge: TextStyle(
      fontSize: 19,
      fontWeight: FontWeight.w700,
      letterSpacing: -.4,
    ),
    titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
    bodyMedium: TextStyle(fontSize: 13, height: 1.65),
    bodySmall: TextStyle(fontSize: 11, height: 1.6, color: StudioColors.muted),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: StudioColors.green,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
      textStyle: const TextStyle(
        fontFamily: 'Manrope',
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: StudioColors.ink,
      side: const BorderSide(color: StudioColors.line),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      textStyle: const TextStyle(
        fontFamily: 'Manrope',
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      textStyle: const TextStyle(
        fontFamily: 'Manrope',
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    isDense: true,
    filled: true,
    fillColor: StudioColors.paper,
    labelStyle: const TextStyle(fontSize: 12, color: StudioColors.muted),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: StudioColors.line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: StudioColors.line),
    ),
  ),
  sliderTheme: const SliderThemeData(
    trackHeight: 3,
    thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
    overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
  ),
  dividerColor: StudioColors.line,
  splashFactory: InkSparkle.splashFactory,
);

class SurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(22),
    this.color,
  });
  @override
  Widget build(BuildContext context) => Material(
    color: color ?? StudioColors.paper,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: StudioColors.line),
      borderRadius: BorderRadius.circular(18),
    ),
    clipBehavior: Clip.antiAlias,
    child: Padding(padding: padding, child: child),
  );
}

class Tag extends StatelessWidget {
  final String text;
  final Color? color;
  final IconData? icon;
  const Tag(this.text, {super.key, this.color, this.icon});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: (color ?? StudioColors.green).withValues(alpha: .09),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: color ?? StudioColors.green),
          const SizedBox(width: 5),
        ],
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color ?? StudioColors.green,
            ),
          ),
        ),
      ],
    ),
  );
}

class SectionHeading extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  const SectionHeading(this.title, {super.key, this.subtitle, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 17),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
      ],
    ),
  );
}

String displayNumber(num value, {int digits = 2}) {
  if (value == 0) return '0';
  if (value.abs() < .01) return value.toStringAsPrecision(3);
  final s = value.toStringAsFixed(digits);
  return s.replaceFirst(RegExp(r'\.?0+$'), '');
}

class AvocadoMark extends StatelessWidget {
  final double size;
  const AvocadoMark({super.key, this.size = 38});
  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _MarkPainter());
}

class _MarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 48, size.height / 48);
    final path = Path()
      ..moveTo(24, 3)
      ..cubicTo(15, 3, 16, 15, 10, 24)
      ..cubicTo(-2, 43, 18, 49, 24, 45)
      ..cubicTo(42, 49, 47, 34, 37, 23)
      ..cubicTo(31, 16, 33, 3, 24, 3);
    canvas.drawPath(path, Paint()..color = const Color(0xff87a769));
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xffc9dba4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawCircle(
      const Offset(24, 31),
      9,
      Paint()..color = const Color(0xffb98555),
    );
    canvas.drawCircle(
      const Offset(22, 29),
      3,
      Paint()..color = const Color(0xffd6ab7a),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
