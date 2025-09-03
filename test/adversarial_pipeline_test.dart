import 'dart:async';
import 'package:popeye/popeye.dart';
import 'package:test/test.dart';

class RecordingAdapter implements PipelineStateAdapter {
  final events = <String>[];
  @override
  void onStart() => events.add('start');
  @override
  void onData(Object? value) => events.add('data:$value');
  @override
  void onError(Object error, StackTrace? stackTrace) =>
      events.add('error:$error');
  @override
  void onComplete(Object? finalValue) => events.add('complete:$finalValue');
  @override
  void onCancel() => events.add('cancel');
}

void main() {
  group('Adversarial pipeline tests', () {
    test('zero steps returns input unchanged', () async {
      final p = Pipe.input<int>().build();
      final r = await p.run(42);
      expect(r.isSuccess, isTrue);
      expect(r.value, 42);
    });

    test('context does not leak between runs', () async {
      final key = Object();
      final p = Pipe.input<int>().map((ctx, v, ctl) {
        ctx.set(key, v + 1);
        return ctx.get<int>(key)!;
      }).build();
      final r1 = await p.run(1);
      final r2 = await p.run(5);
      expect(r1.value, 2);
      expect(r2.value, 6); // independent context
    });

    test('emit multiple intermediates before step completes', () async {
      final adapter = RecordingAdapter();
      final p = Pipe.input<int>().map((c, v, ctl) {
        ctl.emit(v + 1);
        ctl.emit(v + 2);
        return v + 3;
      }).build();
      final r = await p.run(1, state: adapter);
      expect(r.value, 4);
      // Expect two early emits + final data
      final dataEvents = adapter.events
          .where((e) => e.startsWith('data:'))
          .toList();
      expect(dataEvents, containsAll(['data:2', 'data:3', 'data:4']));
    });

    test('cancel then fail: fail takes precedence (error result)', () async {
      final adapter = RecordingAdapter();
      final error = Exception('boom');
      final p = Pipe.input<int>().map((c, v, ctl) {
        ctl.cancel();
        return ctl.fail(error);
      }).build();
      final r = await p.run(1, state: adapter);
      expect(r.isError, isTrue);
      expect(r.error, error);
      // Ensure no complete event
      expect(adapter.events.any((e) => e.startsWith('complete')), isFalse);
    });

    test('type error inside step surfaces as failure', () async {
      final p = Pipe.input<Object>()
          .map(
            (c, v, ctl) => (v as String).length,
          ) // if v not String -> CastError
          .build();
      final r = await p.run(123); // int instead of String
      expect(r.isError, isTrue);
      expect(r.error, isA<TypeError>()); // Cast failure type
    });

    test('loop cancellation prevents subsequent steps', () async {
      final adapter = RecordingAdapter();
      final p = Pipe.input<int>()
          .loop(
            predicate: (v) => v < 5,
            body: (c, v, ctl) {
              if (v == 3) ctl.cancel();
              return v + 1;
            },
          )
          .map((c, v, ctl) => v + 10) // should be skipped after cancel
          .build();
      final r = await p.run(1, state: adapter);
      expect(r.isCancelled, isTrue);
      // ensure no complete event (cancellation path)
      expect(adapter.events.any((e) => e.startsWith('complete')), isFalse);
    });

    test(
      'async error thrown after intermediate emits becomes failure',
      () async {
        final adapter = RecordingAdapter();
        final p = Pipe.input<int>()
            .then((c, v, ctl) async {
              ctl.emit(v + 1);
              await Future.delayed(const Duration(milliseconds: 5));
              throw StateError('late');
            })
            .map((c, v, ctl) => v) // skipped
            .build();
        final r = await p.run(1, state: adapter);
        expect(r.isError, isTrue);
        expect(r.error, isA<StateError>());
        // data:2 should still be present from emit
        expect(adapter.events.where((e) => e == 'data:2').length, 1);
      },
    );

    test(
      'microtask fail after completion does not affect result (best effort)',
      () async {
        final adapter = RecordingAdapter();
        final p = Pipe.input<int>().map((c, v, ctl) {
          // schedule fail AFTER return
          scheduleMicrotask(() {
            try {
              ctl.fail(Exception('late-fail'));
            } catch (_) {}
          });
          return v + 1;
        }).build();
        final r = await p.run(5, state: adapter);
        expect(r.isSuccess, isTrue);
        expect(r.value, 6);
        // we expect no error event before complete
        expect(adapter.events.last, startsWith('complete:'));
      },
    );
  });
}
