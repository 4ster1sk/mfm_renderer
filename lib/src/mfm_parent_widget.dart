import 'package:flutter/material.dart';
import 'package:mfm_parser/mfm_parser.dart';
import 'package:mfm/mfm.dart';
import 'package:mfm/src/mfm_blur_state_scope.dart';
import 'package:mfm/src/mfm_element_widget.dart';

class MfmParentWidget extends StatefulWidget {
  const MfmParentWidget({super.key});

  @override
  State<StatefulWidget> createState() => MfmParentWidgetState();
}

class MfmParentWidgetState extends State<MfmParentWidget> {
  List<MfmNode>? nodes;

  /// [nodes] がどのテキストをパースした結果なのか。
  /// 同じテキストの再ビルドでパースをやり直さないために持つ。
  String? _parsedText;

  @override
  Widget build(BuildContext context) {
    // Mfm.of は InheritedWidget への依存登録を伴うので、ビルド 1 回につき 1 度だけ引く。
    final mfm = Mfm.of(context);

    final List<MfmNode> actualNode;
    final parentMfmNode = mfm.mfmNode;
    if (parentMfmNode != null) {
      actualNode = parentMfmNode;
    } else {
      final mfmText = mfm.mfmText!;
      if (nodes == null || _parsedText != mfmText) {
        nodes = const MfmParser().parse(mfmText);
        _parsedText = mfmText;
      }
      actualNode = nodes!;
    }

    final style = Theme.of(context)
        .textTheme
        .bodyMedium!
        .merge(mfm.style ?? const TextStyle())
        .merge(const TextStyle(height: 0));

    final scaledStyle = style.copyWith(
        fontSize: MediaQuery.of(context).textScaler.scale(style.fontSize!));

    return MfmFnBlurStateScope(
      child: DefaultTextStyle.merge(
        style: scaledStyle,
        overflow: mfm.overflow,
        maxLines: mfm.maxLines,
        child: Text.rich(
          TextSpan(style: style, children: [
            WidgetSpan(
              alignment: PlaceholderAlignment.aboveBaseline,
              baseline: TextBaseline.alphabetic,
              child: MfmElementWidget(
                nodes: actualNode,
                style: style,
                depth: 0,
              ),
            ),
          ]),
          strutStyle: StrutStyle(height: mfm.lineHeight),
          textScaler: MediaQuery.of(context).textScaler,
        ),
      ),
    );
  }
}
