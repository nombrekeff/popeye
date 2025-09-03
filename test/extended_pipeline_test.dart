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
  void onCancel() => events.add('cancel');
  @override
  void onComplete(Object? finalValue) => events.add('complete:$finalValue');
}

void main() {
  group('Pipeline advanced behaviour', () {
    test('tap preserves value and order', () async {
      final adapter = RecordingAdapter();
      final calls = <String>[];
      final p = Pipe.input<int>()
          .map((c, v, ctl) => v + 1) // -> 2
          .tap((c, v) => calls.add('tap:$v'))
          .map((c, v, ctl) => v * 5) // -> 10
          .build();
      final res = await p.run(1, state: adapter);
      expect(res.value, 10);
      expect(calls, ['tap:2']);
      // ensure tap data event also emitted
      expect(adapter.events.contains('data:2'), isTrue);
      expect(adapter.events.last, 'complete:10');
    });

    test('context stores and retrieves data across steps', () async {
      final key = Object();
      final p = Pipe.input<int>()
          .map((ctx, v, ctl) {
            ctx.set(key, v + 3); // store 4
            return v;
          })
          .map((ctx, v, ctl) => (ctx.get<int>(key)! * 2)) // 8
          .build();
      final res = await p.run(1);
      expect(res.value, 8);
    });

    test('uncaught throw becomes failure', () async {
      final error = StateError('boom');
      final p = Pipe.input<void>()
          .map((c, v, ctl) => 1)
          .map((c, v, ctl) {
            throw error; // not via ctl.fail
          })
          .map((c, v, ctl) => 3) // skipped
          .build();
      final res = await p.run(null);
      expect(res.isError, isTrue);
      expect(res.error, error);
    });

    test('fail signal prevents subsequent onData emissions', () async {
      final adapter = RecordingAdapter();
      final e = Exception('x');
      final p = Pipe.input<int>()
          .map((c, v, ctl) => v + 1)
          .map((c, v, ctl) => ctl.fail(e))
          .map((c, v, ctl) => (v as int) + 99) // skipped (cast to satisfy NN)
          .build();
      final res = await p.run(1, state: adapter);
      expect(res.isError, isTrue);
      // last event should be error, no complete, no data for skipped step
      expect(adapter.events.last.startsWith('error:'), isTrue);
      expect(
        adapter.events.where((e) => e.startsWith('complete')).isEmpty,
        isTrue,
      );
    });

    test('cancel inside async step stops further processing', () async {
      final adapter = RecordingAdapter();
      final p = Pipe.input<int>()
          .map((c, v, ctl) => v + 1) // 2
          .then((c, v, ctl) async {
            ctl.cancel();
            await Future.delayed(const Duration(milliseconds: 5));
            return v * 100; // ignored
          })
          .map((c, v, ctl) => v + 1) // skipped
          .build();
      final res = await p.run(1, state: adapter);
      expect(res.isCancelled, isTrue);
      expect(adapter.events.last, 'cancel');
      // ensure no complete event
      expect(adapter.events.any((e) => e.startsWith('complete')), isFalse);
    });

    test('map3 and runArgs3 produce correct value', () async {
      final p = pipe3<int, int, int>()
          .map3((a, b, c) => a + b + c)
          .map((cxt, sum, ctl) => sum * 2)
          .build();
      final res = await p.runArgs(2, 3, 5);
      expect(res.isSuccess, isTrue);
      expect(res.value, 20); // (2+3+5)*2
    });

    test('adapter event ordering success path', () async {
      final adapter = RecordingAdapter();
      final p = Pipe.input<String>()
          .map((c, v, ctl) => v.trim())
          .map((c, v, ctl) => v.toUpperCase())
          .build();
      final res = await p.run(' hi ', state: adapter);
      expect(res.value, 'HI');
      expect(adapter.events.first, 'start');
      expect(adapter.events.last, 'complete:HI');
      // ensure we have intermediate data emissions (trim, uppercase)
      expect(adapter.events.where((e) => e.startsWith('data:')).length, 2);
    });

    test('adapter event ordering failure path', () async {
      final adapter = RecordingAdapter();
      final error = ArgumentError('bad');
      final p = Pipe.input<int>()
          .map((c, v, ctl) => v + 1)
          .map((c, v, ctl) => ctl.fail(error))
          .map((c, v, ctl) => (v as int) + 10) // skipped (cast for NN)
          .build();
      final res = await p.run(1, state: adapter);
      expect(res.isError, isTrue);
      expect(res.error, error);
      expect(adapter.events.first, 'start');
      // ArgumentError toString prefixes with 'Invalid argument(s): '
      expect(adapter.events.last, contains('error:Invalid argument'));
      expect(adapter.events.last, contains('bad'));
      expect(adapter.events.any((e) => e.startsWith('complete')), isFalse);
    });

    test('context cancellation flag visible inside later steps', () async {
      final seen = <bool>[];
      final p = Pipe.input<int>()
          .map((c, v, ctl) {
            ctl.cancel();
            seen.add(c.isCancelled);
            return v;
          })
          .map((c, v, ctl) {
            // should not run, but defensive check if it did
            seen.add(c.isCancelled);
            return v;
          })
          .build();
      final res = await p.run(5);
      expect(res.isCancelled, isTrue);
      expect(seen, [true]);
    });
  });
}
