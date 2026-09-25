import 'package:flutter/gestures.dart';

/// スパンツリー内の [TapGestureRecognizer] を再利用・破棄するためのプール。
///
/// mention / hashtag / URL のスパンは再ビルドごとに作り直されるため、
/// 素朴に `TapGestureRecognizer()` を new すると確保コストが毎回かかるうえ、
/// 誰も `dispose()` しないためリークする。
///
/// スパンツリーは同じノード列から同じ順序で決定的に構築されるので、
/// 構築順のインデックスで recognizer を貸し出して `onTap` だけ差し替える。
class MfmGestureRecognizerPool {
  final List<TapGestureRecognizer> _pool = [];
  int _index = 0;

  /// スパンツリーの構築を始める前に呼ぶ。貸し出し位置を先頭に戻す。
  void reset() {
    _index = 0;
  }

  /// [onTap] を割り当てた recognizer を貸し出す。
  TapGestureRecognizer tap(GestureTapCallback onTap) {
    if (_index < _pool.length) {
      return _pool[_index++]..onTap = onTap;
    }
    final recognizer = TapGestureRecognizer()..onTap = onTap;
    _pool.add(recognizer);
    _index++;
    return recognizer;
  }

  /// スパンツリーの構築を終えた後に呼ぶ。今回使われなかった分を破棄する。
  void trim() {
    while (_pool.length > _index) {
      _pool.removeLast().dispose();
    }
  }

  void dispose() {
    for (final recognizer in _pool) {
      recognizer.dispose();
    }
    _pool.clear();
    _index = 0;
  }
}
