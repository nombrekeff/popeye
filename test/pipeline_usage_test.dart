import 'dart:async';

import 'package:popeye/popeye.dart';
import 'package:test/test.dart';

void main() {
  group('Pipeline usage examples', () {
    test('linear success', () async {
      final pipeline = Pipe.input<int>()
          .map((ctx, v, ctl) => v + 1)
          .then((ctx, v, ctl) async => v * 2) // async step
          .map((ctx, v, ctl) => v.toString())
          .build();

      final res = await pipeline.run(3);
      expect(res.isSuccess, isTrue);
      expect(res.value, '8'); // (3+1)*2 => 8 => toString
    });

    test('failure propagation', () async {
      final err = Exception('boom');
      final pipeline = Pipe.input<String>()
          .map((ctx, v, ctl) => v.length)
          .then((ctx, v, ctl) {
            ctl.fail(err); // triggers failure
          })
          .map((ctx, v, ctl) => v) // should never run
          .build();

      final res = await pipeline.run('abc');
      expect(res.isError, isTrue);
      expect(res.error, err);
    });

    test('cancellation mid-step', () async {
      final pipeline = Pipe.input<int>()
          .map((ctx, v, ctl) => v + 1)
          .then((ctx, v, ctl) async {
            ctl.cancel();
            // simulate work after cancel
            await Future.delayed(const Duration(milliseconds: 10));
            return v * 99; // should be ignored
          })
          .map((ctx, v, ctl) => v * 2) // should not run
          .build();

      final res = await pipeline.run(1);
      expect(res.isCancelled, isTrue);
      expect(res.value, isNull);
    });

    test('multi-arg map2', () async {
      final pipeline = pipe2<int, int>()
          .map2((a, b) => a + b)
          .map((ctx, sum, ctl) => sum * 3)
          .build();

      final res = await pipeline.runArgs(2, 5);
      expect(res.isSuccess, isTrue);
      expect(res.value, 21); // (2+5)*3
    });
  });
}