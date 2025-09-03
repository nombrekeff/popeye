import 'pipeline.dart';

/// Branch on the current value inside the pipeline, choosing one of two continuations.
extension BranchCombinator<I, O> on PipeBuilder<I, O> {
  PipeBuilder<I, NO> branch<NO>({
    required bool Function(O value) predicate,
    required PipeStep<O, NO> ifTrue,
    required PipeStep<O, NO> ifFalse,
  }) {
    return map<NO>((ctx, value, ctl) {
      if (predicate(value)) {
        return ifTrue(ctx, value, ctl);
      } else {
        return ifFalse(ctx, value, ctl);
      }
    });
  }
}

/// Loop while [predicate] is true, applying [body] each iteration.
/// Safeguarded by [maxIterations] to avoid infinite loops.
extension LoopCombinator<I, O> on PipeBuilder<I, O> {
  PipeBuilder<I, O> loop({
    required bool Function(O value) predicate,
    required PipeStep<O, O> body,
    int maxIterations = 1000,
  }) {
    return map<O>((ctx, value, ctl) async {
      var current = value;
      var iterations = 0;
      while (predicate(current)) {
        if (iterations++ >= maxIterations) {
          return ctl.fail(
            StateError('loop exceeded $maxIterations iterations'),
          );
        }
        final next = await body(ctx, current, ctl);
        current = next;
        if (ctx.isCancelled) break;
      }
      return current;
    });
  }
}
