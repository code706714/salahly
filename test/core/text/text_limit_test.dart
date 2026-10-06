import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salahly/core/text/text_limit.dart';

void main() {
  group('clipToCodePoints', () {
    test('keeps text within the limit', () {
      expect(clipToCodePoints('سلام', 4), 'سلام');
    });

    test('counts each harakah as its own code point', () {
      expect(clipToCodePoints('سَلام', 3), 'سَل');
    });

    test('never splits an emoji in half', () {
      expect(clipToCodePoints('a😀b', 2), 'a😀');
    });
  });

  group('CodePointLimit', () {
    const limit = CodePointLimit(4);

    TextEditingValue value(String text) => TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );

    test('lets an edit within the limit through', () {
      expect(limit.formatEditUpdate(value('سل'), value('سلا')).text, 'سلا');
    });

    test('refuses typing past the limit', () {
      expect(
        limit.formatEditUpdate(value('سَلا'), value('سَلام')).text,
        'سَلا',
      );
    });

    test('keeps what fits of a long paste', () {
      final pasted = limit.formatEditUpdate(value(''), value('سَلامات'));

      expect(pasted.text, 'سَلا');
      expect(pasted.selection, const TextSelection.collapsed(offset: 4));
    });
  });
}
