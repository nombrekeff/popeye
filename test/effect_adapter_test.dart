import 'package:popeye/popeye.dart';
import 'package:test/test.dart';

void main() {
  test('EffectAdapter invokes lifecycle callbacks', () async {
    final events = <String>[];
    final adapter = EffectAdapter(
      onStart: () => events.add('start'),
      onData: (v) => events.add('data:$v'),
      onComplete: (v) => events.add('complete:$v'),
      onError: (e, _) => events.add('error:$e'),
      onCancel: () => events.add('cancel'),
    );

    final p = Pipe.input<int>()
        .map((c, v, ctl) => v + 1)
        .tap((c, v) => events.add('tap:$v'))
        .build();

    final result = await p.run(1, state: adapter);
    expect(result.value, 2);
    // start must be first, complete last
    expect(events.first, 'start');
    expect(events.contains('data:2'), isTrue);
    expect(events.last, 'complete:2');
  });
}