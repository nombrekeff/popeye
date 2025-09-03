import 'package:popeye/popeye.dart';
import 'package:test/test.dart';

void main() {
  group('TypedStateAdapter', () {
    test('captures intermediates and final value', () async {
      final adapter = TypedStateAdapter<int>(captureIntermediates: true);
      final pipeline = Pipe.input<int>()
          .map((c, v, ctl) => v + 1) // 2
          .then((c, v, ctl) => v * 3) // 6
          .build();
      final result = await pipeline.run(1, state: adapter);
      expect(result.isSuccess, isTrue);
      expect(adapter.snapshot.data, 6);
      expect(adapter.snapshot.loading, isFalse);
      expect(adapter.snapshot.hasError, isFalse);
    });

    test('ignores non-matching intermediates', () async {
      final adapter = TypedStateAdapter<String>(captureIntermediates: true);
      final pipeline = Pipe.input<int>()
          .map((c, v, ctl) => v + 1) // int
          .then((c, v, ctl) => 'value=$v') // String
          .build();
      final result = await pipeline.run(5, state: adapter);
      expect(result.isSuccess, isTrue);
      expect(adapter.snapshot.data, 'value=6');
      expect(adapter.snapshot.error, isNull);
    });

    test('error updates snapshot', () async {
      final adapter = TypedStateAdapter<int>();
      final error = Exception('fail');
      final pipeline = Pipe.input<int>()
          .map((c, v, ctl) => ctl.fail(error))
          .build();
      final result = await pipeline.run(1, state: adapter);
      expect(result.isError, isTrue);
      expect(adapter.snapshot.error, error);
      expect(adapter.snapshot.loading, isFalse);
    });

    test('cancellation updates snapshot', () async {
      final adapter = TypedStateAdapter<int>();
      final pipeline = Pipe.input<int>().map((c, v, ctl) {
        ctl.cancel();
        return v + 10; // ignored
      }).build();
      final result = await pipeline.run(2, state: adapter);
      expect(result.isCancelled, isTrue);
      expect(adapter.snapshot.cancelled, isTrue);
      expect(adapter.snapshot.data, isNull);
    });
  });
}
