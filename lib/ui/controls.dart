import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../application/draft.dart';
import '../application/help_book.dart';
import '../domain/parameters.dart';
import 'theme.dart';

class NumberControl extends StatefulWidget {
  final String label, unit;
  final double value, min, max;
  final bool logarithmic, integer, enabled;
  final String? help;
  final ValueChanged<double> onChanged;
  final ValueChanged<String?>? onValidation;
  const NumberControl({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.unit = '',
    this.logarithmic = false,
    this.integer = false,
    this.help,
    this.enabled = true,
    this.onValidation,
  });
  @override
  State<NumberControl> createState() => _NumberControlState();
}

class _NumberControlState extends State<NumberControl> {
  late final TextEditingController text;
  final focus = FocusNode();
  String? error;
  @override
  void initState() {
    super.initState();
    text = TextEditingController(text: displayNumber(widget.value, digits: 4));
    focus.addListener(_focusChanged);
  }

  void _focusChanged() {
    if (!focus.hasFocus) {
      final value = double.tryParse(text.text);
      if (value != null && value >= widget.min && value <= widget.max) {
        text.text = displayNumber(widget.value, digits: 4);
      }
    }
  }

  @override
  void didUpdateWidget(covariant NumberControl old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value && !focus.hasFocus) {
      text.text = displayNumber(widget.value, digits: 4);
      error = null;
    }
  }

  void _input(String input) {
    final value = double.tryParse(input);
    String? issue;
    if (value == null || !value.isFinite) {
      issue = 'Enter a number';
    } else if (value < widget.min || value > widget.max) {
      issue =
          '${displayNumber(widget.min)}–${displayNumber(widget.max)} ${widget.unit}';
    }
    setState(() => error = issue);
    widget.onValidation?.call(issue);
    if (issue == null) {
      widget.onChanged(widget.integer ? value!.roundToDouble() : value!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.value.clamp(widget.min, widget.max);
    double toSlider(double v) => widget.logarithmic
        ? math.log(v / widget.min) / math.log(widget.max / widget.min)
        : (v - widget.min) / (widget.max - widget.min);
    double fromSlider(double v) => widget.logarithmic
        ? widget.min * math.pow(widget.max / widget.min, v)
        : widget.min + v * (widget.max - widget.min);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 115,
              child: TextField(
                controller: text,
                focusNode: focus,
                enabled: widget.enabled,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  suffixText: widget.unit.isEmpty ? null : widget.unit,
                  errorText: error,
                  errorMaxLines: 2,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 11,
                  ),
                ),
                onChanged: _input,
                onSubmitted: _input,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Slider(
          value: toSlider(value).clamp(0.0, 1.0),
          onChanged: widget.enabled
              ? (v) {
                  var n = fromSlider(v);
                  if (widget.integer) n = n.roundToDouble();
                  if (!focus.hasFocus) text.text = displayNumber(n, digits: 4);
                  setState(() => error = null);
                  widget.onValidation?.call(null);
                  widget.onChanged(n);
                }
              : null,
          semanticFormatterCallback: (v) =>
              '${displayNumber(fromSlider(v))} ${widget.unit}',
        ),
        if (widget.help?.isNotEmpty ?? false)
          Text(widget.help!, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  @override
  void dispose() {
    focus.removeListener(_focusChanged);
    text.dispose();
    focus.dispose();
    super.dispose();
  }
}

class ParameterControl extends StatelessWidget {
  final Parameter field;
  final EffectDraft draft;
  final HelpBook help;
  final bool learning, enabled;
  const ParameterControl({
    super.key,
    required this.field,
    required this.draft,
    required this.help,
    required this.learning,
    this.enabled = true,
  });
  @override
  Widget build(BuildContext context) {
    final f = field,
        value = draft.value(f.key),
        hint = learning ? help.field(draft.effect.type, f.key) : null;
    if (f.kind == 'boolean') {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  f.key == 'enabled' ? 'Enable this effect' : f.label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (hint?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 5),
                  Text(hint!, style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
          const SizedBox(width: 15),
          Switch(
            value: value == true,
            onChanged: enabled ? (v) => draft.set(f.key, v) : null,
          ),
        ],
      );
    }
    if (f.kind == 'select') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            f.label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            initialValue: (value as num).toInt(),
            isExpanded: true,
            decoration: const InputDecoration(),
            items: f.options.entries
                .map(
                  (entry) => DropdownMenuItem(
                    value: entry.key,
                    child: Text(
                      entry.value,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                )
                .toList(),
            onChanged: enabled
                ? (v) {
                    if (v != null) draft.set(f.key, v);
                  }
                : null,
          ),
          if (hint?.isNotEmpty ?? false) ...[
            const SizedBox(height: 8),
            Text(hint!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      );
    }
    return NumberControl(
      key: ValueKey('${draft.effect.address}-${f.key}-${draft.resetEpoch}'),
      label: f.label,
      value: (value as num).toDouble(),
      min: f.min,
      max: f.max,
      unit: f.unit,
      integer: f.scale == 1,
      logarithmic: f.min > 0 && f.max / f.min > 100,
      enabled: enabled,
      help: hint,
      onValidation: (issue) {
        if (issue != null) {
          draft.invalid(f.key, issue);
        } else {
          draft.errors.remove(f.key);
        }
      },
      onChanged: (v) => draft.set(f.key, v),
    );
  }
}

class ResponsiveColumns extends StatelessWidget {
  final List<Widget> children;
  final double minimum, gap;
  const ResponsiveColumns({
    super.key,
    required this.children,
    this.minimum = 330,
    this.gap = 18,
  });
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final count = math.max(
        1,
        math.min(children.length, (c.maxWidth / (minimum + gap)).floor()),
      );
      final width = (c.maxWidth - gap * (count - 1)) / count;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: children
            .map((child) => SizedBox(width: width, child: child))
            .toList(),
      );
    },
  );
}

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(width: 420, child: Text(message)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;
