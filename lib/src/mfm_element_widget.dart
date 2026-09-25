import 'package:flutter/material.dart';
import 'package:mfm_parser/mfm_parser.dart';
import 'package:mfm/src/mfm_align_scope.dart';
import 'package:mfm/src/mfm_gesture_recognizer_pool.dart';
import 'package:mfm/src/mfm_inline_span.dart';

class MfmElementWidget extends StatefulWidget {
  final List<MfmNode>? nodes;
  final TextStyle? style;
  final int depth;

  const MfmElementWidget({
    super.key,
    required this.nodes,
    required this.style,
    required this.depth,
  });

  @override
  State<StatefulWidget> createState() => MfmElementWidgetState();
}

class MfmElementWidgetState extends State<MfmElementWidget> {
  MfmInlineSpan? inlineSpan;

  /// このスパンツリーが使う recognizer の所有者。
  /// スパンは再ビルドごとに作り直されるので、recognizer は使い回して最後にまとめて破棄する。
  final MfmGestureRecognizerPool _pool = MfmGestureRecognizerPool();

  @override
  void didUpdateWidget(covariant MfmElementWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    inlineSpan = null;
  }

  @override
  void dispose() {
    _pool.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (inlineSpan == null) {
      _pool.reset();
      inlineSpan = MfmInlineSpan(
          nodes: widget.nodes ?? [],
          style: widget.style,
          context: context,
          depth: widget.depth,
          pool: _pool);
      _pool.trim();
    }

    return Text.rich(
      inlineSpan!,
      textAlign: MfmAlignScope.of(context),
      textScaler: TextScaler.noScaling,
    );
  }
}
