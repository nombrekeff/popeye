import 'package:popeye/popeye.dart';
import 'package:test/test.dart';

void main() {
  group('branch combinator', () {
    test('predicate true path', () async {
      final p = Pipe.input<int>()
          .map((c,v,ctl) => v + 1) // 2
          .branch(
            predicate: (v) => v.isEven,
            ifTrue: (c,v,ctl) => 'even:$v',
            ifFalse: (c,v,ctl) => 'odd:$v',
          )
          .build();
      final res = await p.run(1);
      expect(res.value, 'even:2');
    });

    test('predicate false path', () async {
      final p = Pipe.input<int>()
          .map((c,v,ctl) => v + 2) // 3
          .branch(
            predicate: (v) => v.isEven,
            ifTrue: (c,v,ctl) => 'even:$v',
            ifFalse: (c,v,ctl) => 'odd:$v',
          )
          .build();
      final res = await p.run(1);
      expect(res.value, 'odd:3');
    });
  });

  group('loop combinator', () {
    test('increments until predicate false', () async {
      final p = Pipe.input<int>()
          .loop(
            predicate: (v) => v < 5,
            body: (c,v,ctl) => v + 2,
          )
          .build();
      final res = await p.run(1);
      expect(res.value, 5); // 1 -> 3 -> 5 (stop because 5 !< 5)
    });

    test('loop cancellation inside body', () async {
      final p = Pipe.input<int>()
          .loop(
            predicate: (v) => v < 10,
            body: (c,v,ctl) {
              if (v >= 4) ctl.cancel();
              return v + 1;
            },
          )
          .build();
      final res = await p.run(1);
      expect(res.isCancelled, isTrue);
    });

    test('loop max iterations failure', () async {
      final p = Pipe.input<int>()
          .loop(
            predicate: (v) => true, // infinite without guard
            body: (c,v,ctl) => v,
            maxIterations: 5,
          )
          .build();
      final res = await p.run(0);
      expect(res.isError, isTrue);
      expect(res.error, isA<StateError>());
    });
  });
}
