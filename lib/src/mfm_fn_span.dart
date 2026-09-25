import 'dart:math';

import 'package:flutter/material.dart';
import 'package:mfm/src/functions/mfm_fn_border.dart';
import 'package:mfm_parser/mfm_parser.dart';
import 'package:mfm/mfm.dart';
import 'package:mfm/src/extension/string_extension.dart';
import 'package:mfm/src/functions/mfm_fn_bounce.dart';
import 'package:mfm/src/functions/mfm_fn_jump.dart';
import 'package:mfm/src/functions/mfm_fn_ruby.dart';
import 'package:mfm/src/functions/mfm_fn_shake.dart';
import 'package:mfm/src/functions/mfm_fn_sparkle.dart';
import 'package:mfm/src/functions/mfm_fn_spin.dart';
import 'package:mfm/src/functions/mfm_fn_tada.dart';
import 'package:mfm/src/functions/mfm_fn_twitch.dart';
import 'package:mfm/src/functions/mfm_jelly.dart';
import 'package:mfm/src/mfm_element_widget.dart';
import 'package:mfm/src/mfm_gesture_recognizer_pool.dart';
import 'package:mfm/src/functions/mfm_fn_rainbow.dart';
import 'package:mfm/src/mfm_inline_span.dart';

UnixTimeBuilder _defaultUnixTimeBuilder = (context, date, style) {
  return TextSpan(text: date?.toIso8601String() ?? "");
};

class MfmFnSpan extends TextSpan {
  final MfmFn function;
  final BuildContext context;
  final int depth;

  /// タップ領域の recognizer を貸し出すプール。[MfmInlineSpan] から引き継ぐ。
  final MfmGestureRecognizerPool? pool;

  late final List<InlineSpan> _cachedSpan;

  /// 子孫に改行が含まれるか。ノードごとに 1 度だけ判定する。
  late final bool _hasNewLine = findChildrenNewLine(function.children ?? []);

  /// [_hasNewLine] から決まる配置。
  PlaceholderAlignment get _alignment => _hasNewLine
      ? PlaceholderAlignment.aboveBaseline
      : PlaceholderAlignment.middle;

  MfmFnSpan({
    required this.function,
    required super.style,
    required this.context,
    required this.depth,
    this.pool,
    super.recognizer,
  }) {
    _cachedSpan = buildChildren();
  }

  bool findChildrenNewLine(List<MfmNode> nodes) {
    for (final node in nodes) {
      if (node is MfmText) {
        if (node.text.contains("\n")) {
          return true;
        }
      } else {
        return findChildrenNewLine(node.children ?? []);
      }
    }
    return false;
  }

  double? validTime(String? time) {
    if (time == null) return null;
    final value =
        RegExp(r'^([0-9\.]+)s$').allMatches(time).firstOrNull?.group(1);
    if (value != null) {
      return double.tryParse(value);
    }
    return null;
  }

  List<InlineSpan> buildChildren() {
    // Mfm.of は依存登録を伴うので、buildChildren 1 回につき 1 度だけ引く。
    final mfm = Mfm.of(context);

    if (function.name == "x2") {
      return [
        MfmInlineSpan(
          context: context,
          pool: pool,
          style: style?.merge(
              TextStyle(height: 0, fontSize: (style?.fontSize ?? 22) * 2)),
          nodes: function.children,
          depth: depth + 1,
        )
      ];
    }
    if (function.name == "x3") {
      return [
        MfmInlineSpan(
          context: context,
          pool: pool,
          style: style?.merge(
              TextStyle(height: 0, fontSize: (style?.fontSize ?? 22) * 4)),
          nodes: function.children,
          depth: depth + 1,
        )
      ];
    }

    if (function.name == "x4") {
      return [
        MfmInlineSpan(
          context: context,
          pool: pool,
          style: style?.merge(TextStyle(
              height: 0,
              fontSize:
                  (DefaultTextStyle.of(context).style.fontSize ?? 22) * 6)),
          nodes: function.children,
          depth: depth + 1,
        )
      ];
    }

    if (function.name == "fg") {
      return [
        WidgetSpan(
          style: style,
          alignment: _alignment,
          baseline: TextBaseline.alphabetic,
          child: MfmElementWidget(
            nodes: function.children,
            style: style?.merge(TextStyle(
                color: (function.args["color"] as String?)?.color ?? Colors.red,
                height: mfm.lineHeight)),
            depth: depth + 1,
          ),
        )
      ];
    }

    if (function.name == "bg") {
      return [
        WidgetSpan(
          style: style,
          alignment: _alignment,
          baseline: TextBaseline.alphabetic,
          child: Container(
            decoration: BoxDecoration(
              color: (function.args["color"] as String?).color ?? Colors.red,
            ),
            child: MfmElementWidget(
              nodes: function.children,
              style: style?.copyWith(height: mfm.lineHeight),
              depth: depth + 1,
            ),
          ),
        )
      ];
    }

    if (function.name == "border") {
      final color = (function.args["color"] as String?)?.color ??
          mfm.defaultBorderColor;
      final styleIndex = MfmFnBorderStyle.values
          .map((e) => e.name)
          .toList()
          .indexOf(function.args["style"] ?? "solid");
      final borderStyle = styleIndex == -1
          ? MfmFnBorderStyle.solid
          : MfmFnBorderStyle.values[styleIndex];
      final width = function.args["width"]?.isEmpty == true
          ? 0.0
          : double.tryParse(function.args["width"] ?? "1") ?? 1.0;
      final radius = double.tryParse(function.args["radius"] ?? "0") ?? 0.0;
      final isClip = function.args["noclip"] == null;

      return [
        WidgetSpan(
          style: style,
          alignment: _alignment,
          baseline: TextBaseline.alphabetic,
          child: MfmFnBorder(
            color: color,
            style: borderStyle,
            width: width,
            radius: radius,
            isClip: isClip,
            child: MfmElementWidget(
              nodes: function.children,
              depth: depth + 1,
              style: style?.copyWith(height: mfm.lineHeight),
            ),
          ),
        )
      ];
    }

    if (function.name == "font") {
      var fontStyle = style;
      if (function.args.containsKey("serif")) {
        fontStyle = style?.merge(mfm.serifStyle);
      } else if (function.args.containsKey("monospace")) {
        fontStyle = style?.merge(mfm.monospaceStyle);
      } else if (function.args.containsKey("cursive")) {
        fontStyle = style?.merge(mfm.cursiveStyle);
      } else if (function.args.containsKey("fantasy")) {
        fontStyle = style?.merge(mfm.fantasyStyle);
      }

      return [
        MfmInlineSpan(
            nodes: function.children,
            context: context,
            pool: pool,
            style: fontStyle,
            depth: depth + 1)
      ];
    }

    if (function.name == "rotate") {
      final deg = double.tryParse(function.args["deg"] ?? "") ?? 90.0;
      return [
        WidgetSpan(
          alignment: _alignment,
          baseline: TextBaseline.alphabetic,
          child: Transform.rotate(
              angle: deg * pi / 180,
              child: MfmElementWidget(
                nodes: function.children,
                style: style,
                depth: depth + 1,
              )),
        )
      ];
    }

    if (function.name == "scale") {
      final x = min(double.tryParse(function.args["x"] ?? "") ?? 1.0, 5.0);
      final y = min(double.tryParse(function.args["y"] ?? "") ?? 1.0, 5.0);

      // scale.x=0, scale.y=0は表示しない
      if (x == 0 || y == 0) {
        return const [TextSpan()];
      }

      return [
        WidgetSpan(
          alignment: _alignment,
          baseline: TextBaseline.alphabetic,
          child: Transform.scale(
            scaleX: x,
            scaleY: y,
            child: MfmElementWidget(
              nodes: function.children,
              style: style,
              depth: depth + 1,
            ),
          ),
        )
      ];
    }

    if (function.name == "position") {
      final x = double.tryParse(function.args["x"] ?? "") ?? 0;
      final y = double.tryParse(function.args["y"] ?? "") ?? 0;
      final double defaultFontSize = (style?.fontSize ?? 22);

      return [
        WidgetSpan(
          alignment: _alignment,
          baseline: TextBaseline.alphabetic,
          child: Transform.translate(
            offset: Offset(x * defaultFontSize, y * defaultFontSize),
            child: MfmElementWidget(
              nodes: function.children,
              style: style,
              depth: depth + 1,
            ),
          ),
        )
      ];
    }

    if (function.name == "tada") {
      final speed = mfm.isUseAnimation
          ? validTime(function.args["speed"]) ?? 1
          : 0.0;

      final delay = validTime(function.args["delay"]) ?? 0;
      return [
        WidgetSpan(
            alignment: _alignment,
            baseline: TextBaseline.alphabetic,
            child: MfmFnTada(
              speed: speed,
              delay: delay,
              child: MfmElementWidget(
                nodes: function.children,
                style: style
                    ?.merge(TextStyle(fontSize: (style?.fontSize ?? 22) * 1.5)),
                depth: depth + 1,
              ),
            ))
      ];
    }

    if (function.name == "blur") {
      return [
        WidgetSpan(
          alignment: _alignment,
          baseline: TextBaseline.alphabetic,
          child: MfmFnBlur(
            child: MfmElementWidget(
              nodes: function.children,
              style: style,
              depth: depth + 1,
            ),
          ),
        )
      ];
    }

    if (function.name == "flip") {
      final isVertical = function.args.containsKey("v");
      final isHorizontal = function.args.containsKey("h");

      if ((!isVertical && !isHorizontal) || (isHorizontal && !isVertical)) {
        return [
          WidgetSpan(
            alignment: _alignment,
            baseline: TextBaseline.alphabetic,
            child: Transform(
              transform: Matrix4.rotationY(pi),
              alignment: Alignment.center,
              child: MfmElementWidget(
                nodes: function.children,
                style: style,
                depth: depth + 1,
              ),
            ),
          )
        ];
      }

      if (isVertical && !isHorizontal) {
        return [
          WidgetSpan(
            alignment: _alignment,
            baseline: TextBaseline.alphabetic,
            child: Transform(
              transform: Matrix4.rotationX(pi),
              alignment: Alignment.center,
              child: MfmElementWidget(
                nodes: function.children,
                style: style,
                depth: depth + 1,
              ),
            ),
          )
        ];
      }

      return [
        WidgetSpan(
          alignment: _alignment,
          baseline: TextBaseline.alphabetic,
          child: Transform(
            transform: Matrix4.rotationZ(pi),
            alignment: Alignment.center,
            child: MfmElementWidget(
              nodes: function.children,
              style: style,
              depth: depth + 1,
            ),
          ),
        )
      ];
    }

    if (function.name == "ruby") {
      final children = function.children;
      if (children == null) return [];
      final alignment = _hasNewLine
          ? PlaceholderAlignment.middle
          : PlaceholderAlignment.aboveBaseline;

      if (children.length == 1) {
        final child = children[0];
        final text = child is MfmText
            ? mfm.isNyaize
                ? child.text.nyaize
                : child.text
            : "";

        final splited = text.split(' ');

        return [
          WidgetSpan(
            style: style,
            alignment: alignment,
            baseline: TextBaseline.ideographic,
            child: MfmFnRuby(
              rt: splited.length >= 2 ? splited[1] : "",
              style: style,
              child: Text.rich(
                textScaler: TextScaler.noScaling,
                TextSpan(text: splited[0]),
                style: style?.copyWith(height: 1.2),
              ),
            ),
          )
        ];
      } else {
        final rt = children.last;
        final text = rt is MfmText
            ? mfm.isNyaize
                ? rt.text.nyaize
                : rt.text
            : "";

        return [
          WidgetSpan(
            style: style,
            alignment: alignment,
            baseline: TextBaseline.ideographic,
            child: MfmFnRuby(
              rt: text.trim(),
              style: style?.copyWith(height: 1.2),
              child: MfmElementWidget(
                nodes: children.sublist(0, children.length - 1),
                depth: depth + 1,
                style: style?.copyWith(height: 1.2),
              ),
            ),
          )
        ];
      }
    }

    if (function.name == "unixtime") {
      final child = function.children?.firstOrNull;
      final unixtime = child is MfmText ? int.tryParse(child.text) : null;
      DateTime? date;
      try {
        date = unixtime == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(unixtime * 1000);
      } catch (e) {
        date = null;
      }

      return [
        mfm.unixTimeBuilder?.call(context, date, style) ??
            _defaultUnixTimeBuilder(context, date, style)
      ];
    }

    if (function.name == "rainbow" && mfm.isUseAnimation) {
      final speed = validTime(function.args["speed"]) ?? 1;
      final delay = validTime(function.args["delay"]) ?? 0;
      return [
        WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: MfmRainbow(
              speed: speed,
              delay: delay,
              child: MfmElementWidget(
                  nodes: function.children, style: style, depth: depth + 1),
            ))
      ];
    }

    if (function.name == "shake" && mfm.isUseAnimation) {
      final speed = validTime(function.args["speed"]) ?? 0.5;
      final delay = validTime(function.args["delay"]) ?? 0;
      return [
        WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: MfmFnShake(
              speed: speed,
              delay: delay,
              child: MfmElementWidget(
                  nodes: function.children, style: style, depth: depth + 1),
            ))
      ];
    }

    if (function.name == "jelly" && mfm.isUseAnimation) {
      final speed = validTime(function.args["speed"]) ?? 1.0;
      final delay = validTime(function.args["delay"]) ?? 0;
      return [
        WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: MfmFnJelly(
              speed: speed,
              delay: delay,
              child: MfmElementWidget(
                  nodes: function.children, style: style, depth: depth + 1),
            ))
      ];
    }

    if (function.name == "twitch" && mfm.isUseAnimation) {
      final speed = validTime(function.args["speed"]) ?? 0.5;
      final delay = validTime(function.args["delay"]) ?? 0;
      return [
        WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: MfmFnTwitch(
              speed: speed,
              delay: delay,
              child: MfmElementWidget(
                  nodes: function.children, style: style, depth: depth + 1),
            ))
      ];
    }

    if (function.name == "bounce" && mfm.isUseAnimation) {
      final speed = validTime(function.args["speed"]) ?? 0.75;
      final delay = validTime(function.args["delay"]) ?? 0;
      return [
        WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: MfmFnBounce(
              speed: speed,
              delay: delay,
              child: MfmElementWidget(
                  nodes: function.children, style: style, depth: depth + 1),
            ))
      ];
    }

    if (function.name == "jump" && mfm.isUseAnimation) {
      final speed = validTime(function.args["speed"]) ?? 0.75;
      final delay = validTime(function.args["delay"]) ?? 0;
      return [
        WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: MfmFnJump(
              speed: speed,
              delay: delay,
              child: MfmElementWidget(
                  nodes: function.children, style: style, depth: depth + 1),
            ))
      ];
    }

    if (function.name == "spin" && mfm.isUseAnimation) {
      final speed = validTime(function.args["speed"]) ?? 1.5;
      final delay = validTime(function.args["delay"]) ?? 0;
      final type = function.args.containsKey("x")
          ? MfmFnSpinType.x
          : function.args.containsKey("y")
              ? MfmFnSpinType.y
              : MfmFnSpinType.both;
      final direction = function.args.containsKey("left")
          ? MfmFnSpinDirection.reverse
          : function.args.containsKey("alternate")
              ? MfmFnSpinDirection.alternate
              : MfmFnSpinDirection.normal;
      return [
        WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: MfmFnSpin(
              speed: speed,
              delay: delay,
              direction: direction,
              type: type,
              child: MfmElementWidget(
                  nodes: function.children, style: style, depth: depth + 1),
            ))
      ];
    }

    if (function.name == "sparkle") {
      final speed = validTime(function.args["speed"]) ?? 1.5;
      return [
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: MfmFnSparkle(
            speed: speed,
            child: MfmElementWidget(
              nodes: function.children,
              style: style,
              depth: depth + 1,
            ),
          ),
        )
      ];
    }

    return [
      MfmInlineSpan(
          context: context,
          pool: pool,
          nodes: function.children,
          style: style,
          depth: depth + 1)
    ];
  }

  @override
  List<InlineSpan> get children => _cachedSpan;
}
