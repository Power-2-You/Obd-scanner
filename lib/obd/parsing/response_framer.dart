import 'dart:convert';

/// Splits the raw ELM327 byte stream into complete responses.
///
/// The ELM327 ends every response with the `>` prompt character, which means
/// "ready for the next command". BLE delivers data in arbitrary chunks (often
/// 20 bytes), so a response may arrive split across many notifications, or a
/// notification may contain the end of one response and the start of the
/// next. The framer buffers until a prompt arrives.
class ResponseFramer {
  ResponseFramer({this.maxBufferLength = 8192});

  /// Guards against a misbehaving device streaming data with no prompt.
  final int maxBufferLength;
  final StringBuffer _buffer = StringBuffer();
  bool _overflowed = false;

  /// True when data had to be discarded because no prompt arrived.
  bool get overflowed => _overflowed;

  String get pending => _buffer.toString();

  /// Adds bytes and returns every response completed by them (text before
  /// each prompt, prompt excluded).
  List<String> add(List<int> bytes) {
    // ELM327 output is ASCII. Some clones emit NUL padding bytes.
    final chunk = latin1
        .decode(bytes.where((b) => b != 0).toList(), allowInvalid: true);
    _buffer.write(chunk);

    final completed = <String>[];
    var text = _buffer.toString();
    var idx = text.indexOf('>');
    while (idx >= 0) {
      completed.add(text.substring(0, idx));
      text = text.substring(idx + 1);
      idx = text.indexOf('>');
    }
    _buffer
      ..clear()
      ..write(text);

    if (_buffer.length > maxBufferLength) {
      _overflowed = true;
      _buffer.clear();
    }
    return completed;
  }

  void reset() {
    _buffer.clear();
    _overflowed = false;
  }
}
