import 'dart:async';

import 'result.dart';
import 'adapter.dart';

/// Signature of a pipeline processing step.
typedef PipeStep<I, O> =
    FutureOr<O> Function(PipeContext ctx, I input, StepController ctl);

/// Internal representation of a step.
class _StepEntry {
  final String? label;
  final PipeStep<dynamic, dynamic> fn;
  _StepEntry(this.fn, {this.label});
}

/// Context passed to each step (shared mutable but scoped to a single run).
class PipeContext {
  final Map<Object, Object?> _data = {};
  bool _cancelled = false;

  T? get<T>(Object key) => _data[key] as T?;
  void set(Object key, Object? value) => _data[key] = value;
  bool get isCancelled => _cancelled;
}

/// Controller given to steps to emit progress / fail / cancel.
class StepController {
  final void Function(Object? data)? _onData;
  final void Function(Object error, StackTrace st)? _onError;
  final void Function()? _onCancel;
  final PipeContext _ctx;

  StepController(this._ctx, this._onData, this._onError, this._onCancel);

  PipeContext get context => _ctx;

  void emit(Object? intermediate) => _onData?.call(intermediate);
  Never fail(Object error, [StackTrace? st]) {
    final trace = st ?? StackTrace.current;
    _onError?.call(error, trace);
    throw _FailSignal(error, trace);
  }

  void cancel() {
    _ctx._cancelled = true;
    _onCancel?.call();
  }
}

class _FailSignal implements Exception {
  final Object error;
  final StackTrace stackTrace;
  _FailSignal(this.error, this.stackTrace);
}

/// Builder for a pipeline.
class PipeBuilder<I, O> {
  final List<_StepEntry> _steps;
  PipeBuilder._(this._steps);

  // Transform current output to a new output.
  PipeBuilder<I, NO> map<NO>(PipeStep<O, NO> step) {
    // Avoid brittle generic cast issues by deferring to dynamic; Dart's strong
    // mode will still enforce types at call sites of map.
    _steps.add(
      _StepEntry((ctx, input, ctl) => step(ctx, input as dynamic, ctl)),
    );
    return PipeBuilder<I, NO>._(_steps);
  }

  // Alias for map to keep fluent semantics.
  PipeBuilder<I, NO> then<NO>(PipeStep<O, NO> step) => map(step);

  PipeBuilder<I, O> tap(
    FutureOr<void> Function(PipeContext ctx, O value) sideEffect,
  ) {
    _steps.add(
      _StepEntry((ctx, input, ctl) async {
        final val = input as O;
        await sideEffect(ctx, val);
        return val;
      }),
    );
    return this;
  }

  PipeBuilder<I, O> label(String name) {
    if (_steps.isNotEmpty) {
      final last = _steps.removeLast();
      _steps.add(_StepEntry(last.fn, label: name));
    }
    return this;
  }

  Pipeline<I, O> build() => Pipeline<I, O>._(List.unmodifiable(_steps));
}

/// Executable built pipeline.
class Pipeline<I, O> {
  final List<_StepEntry> _steps;
  const Pipeline._(this._steps);

  Future<PipeResult<O>> run(I input, {PipelineStateAdapter? state}) async {
    final ctx = PipeContext();
    state?.onStart();
    dynamic current = input;
    for (final entry in _steps) {
      if (ctx.isCancelled) {
        state?.onCancel();
        return PipeResult.cancelled();
      }
      final controller = StepController(
        ctx,
        state?.onData,
        (e, st) => state?.onError(e, st),
        state?.onCancel,
      );
      try {
        final out = await entry.fn(ctx, current, controller);
        current = out;
        if (ctx.isCancelled) {
          state?.onCancel();
          return PipeResult.cancelled();
        }
        state?.onData(out);
      } on _FailSignal catch (fs) {
        state?.onError(fs.error, fs.stackTrace);
        return PipeResult.failure(fs.error, fs.stackTrace);
      } catch (e, st) {
        state?.onError(e, st);
        return PipeResult.failure(e, st);
      }
    }
    if (ctx.isCancelled) {
      state?.onCancel();
      return PipeResult.cancelled();
    }
    state?.onComplete(current);
    return PipeResult.success(current as O);
  }
}

/// Entry point helper.
class Pipe {
  static PipeBuilder<I, I> input<I>() => PipeBuilder<I, I>._([]);
}
