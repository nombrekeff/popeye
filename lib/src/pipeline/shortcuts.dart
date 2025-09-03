import 'dart:async';
import 'pipeline.dart';

/// Convenience extensions to reduce boilerplate when the full
/// (ctx, value, controller) signature is not needed.
extension PipeBuilderShortcuts<I, O> on PipeBuilder<I, O> {
  /// Map using only the current value.
  PipeBuilder<I, NO> mapVal<NO>(NO Function(O value) fn) =>
      map<NO>((_, v, __) => fn(v));

  /// Async map using only the current value.
  PipeBuilder<I, NO> thenVal<NO>(FutureOr<NO> Function(O value) fn) =>
      map<NO>((_, v, __) => fn(v));

  /// Map with access to controller (for fail/cancel) but without ctx.
  PipeBuilder<I, NO> thenCtl<NO>(
    FutureOr<NO> Function(O value, StepController ctl) fn,
  ) => map<NO>((_, v, ctl) => fn(v, ctl));

  /// Side-effect (sync) without changing the value.
  PipeBuilder<I, O> tapVal(void Function(O value) side) => map<O>((_, v, __) {
    side(v);
    return v;
  });

  /// Side-effect (async) without changing the value.
  PipeBuilder<I, O> tapAsync(FutureOr<void> Function(O value) side) =>
      map<O>((_, v, __) async {
        await side(v);
        return v;
      });

  /// Branch using only value predicate.
  PipeBuilder<I, NO> branchVal<NO>({
    required bool Function(O value) predicate,
    required NO Function(O value) ifTrue,
    required NO Function(O value) ifFalse,
  }) => map<NO>((_, v, __) => predicate(v) ? ifTrue(v) : ifFalse(v));

  ///  executes [onError] (e.g. cleanup) before failing.
  PipeBuilder<I, NO> tryOr<NO>(
    FutureOr<NO> Function(O value) body, {
    void Function(Object error, StackTrace st, O value)? onError,
  }) => map<NO>((_, v, ctl) async {
    try {
      return await body(v);
    } catch (e, st) {
      if (onError != null) {
        try {
          onError(e, st, v);
        } catch (_) {
          /* swallow cleanup errors */
        }
      }
      ctl.fail(e, st);
    }
  });
}
