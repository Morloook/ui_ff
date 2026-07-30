import 'package:ffmpeg_ui/services/filter_complex_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = FilterComplexService();

  test('accepts labeled audio and video chains', () {
    final result = service.validate(
      '[0:v]scale=1280:-2[video];[0:a]anull[audio]',
      inputCount: 1,
    );

    expect(result.isValid, isTrue);
    expect(result.labels, containsAll(['0:v', 'video', '0:a', 'audio']));
  });

  test('rejects a stream reference outside available inputs', () {
    final result = service.validate('[2:v]null[out]', inputCount: 2);

    expect(result.isValid, isFalse);
    expect(result.errors.single, contains('wejście 3'));
  });

  test('keeps escaped and quoted semicolons inside one chain', () {
    final result = service.validate(
      r"[0:v]drawtext=text='a;b':x=10\;y=20[out]",
      inputCount: 1,
    );

    expect(result.isValid, isTrue);
    expect(result.labels, containsAll(['0:v', 'out']));
  });

  test('reports unclosed labels and quotes', () {
    final result = service.validate(
      "[0:vdrawtext=text='test[out]",
      inputCount: 1,
    );

    expect(result.isValid, isFalse);
    expect(result.errors, hasLength(2));
  });
}
