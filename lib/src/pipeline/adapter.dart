/// Lightweight immutable snapshot for pipeline state.
/// Provides small convenience helpers instead of a verbose copyWith sentinel pattern.
class PipelineSnapshot<T> {
  final bool loading;
  final bool cancelled;
  final T? data;
  final Object? error;
  const PipelineSnapshot({
    this.loading = false,
    this.cancelled = false,
    this.data,
    this.error,
  });

  static PipelineSnapshot<X> initial<X>() => PipelineSnapshot<X>();

  bool get hasError => error != null;
  bool get hasData => data != null;

  PipelineSnapshot<T> loadingState() =>
      PipelineSnapshot<T>(loading: true, cancelled: false, data: data);
  PipelineSnapshot<T> withData(T value) => PipelineSnapshot<T>(data: value);
  PipelineSnapshot<T> withError(Object e) => PipelineSnapshot<T>(error: e);
  PipelineSnapshot<T> cancelledState() =>
      PipelineSnapshot<T>(cancelled: true, data: data, error: error);

  PipelineSnapshot<T> clearLoading() => PipelineSnapshot<T>(
    loading: false,
    cancelled: cancelled,
    data: data,
    error: error,
  );

  @override
  String toString() =>
      'PipelineSnapshot(loading=$loading,cancelled=$cancelled,data=$data,error=$error)';
}

/// Base adapter interface (untyped) consumed by pipeline runtime.
/// Adapters can choose to only act upon values matching a target type.
abstract class PipelineStateAdapter {
  void onStart();
  void onData(Object? value);
  void onError(Object error, StackTrace? stackTrace);
  void onComplete(Object? finalValue);
  void onCancel();
}

/// A lightweight adapter that just invokes provided callbacks.
/// Does not keep a snapshot; useful when you want side effects only.
class EffectAdapter implements PipelineStateAdapter {
  final void Function()? _onStart;
  final void Function(Object? value)? _onData;
  final void Function(Object error, StackTrace? st)? _onError;
  final void Function(Object? finalValue)? _onComplete;
  final void Function()? _onCancel;

  const EffectAdapter({
    void Function()? onStart,
    void Function(Object? value)? onData,
    void Function(Object error, StackTrace? st)? onError,
    void Function(Object? finalValue)? onComplete,
    void Function()? onCancel,
  })  : _onStart = onStart,
        _onData = onData,
        _onError = onError,
        _onComplete = onComplete,
        _onCancel = onCancel;

  @override
  void onStart() => _onStart?.call();

  @override
  void onData(Object? value) => _onData?.call(value);

  @override
  void onError(Object error, StackTrace? stackTrace) =>
      _onError?.call(error, stackTrace);

  @override
  void onComplete(Object? finalValue) => _onComplete?.call(finalValue);

  @override
  void onCancel() => _onCancel?.call();
}

/// Typed adapter that maintains a strongly typed [PipelineSnapshot].
/// Values that are not of type T are ignored for data assignment (common when
/// pipeline transforms change types before reaching final T).
class TypedStateAdapter<T> implements PipelineStateAdapter {
  PipelineSnapshot<T> snapshot = PipelineSnapshot.initial<T>();
  final void Function(PipelineSnapshot<T>)? listener;
  final bool captureIntermediates;
  TypedStateAdapter({this.listener, this.captureIntermediates = true});

  void _emit() => listener?.call(snapshot);

  @override
  void onStart() {
    snapshot = snapshot.loadingState();
    _emit();
  }

  @override
  void onData(Object? value) {
    if (captureIntermediates && value is T) {
      snapshot = PipelineSnapshot<T>(data: value); // reset error/loading
      _emit();
    }
  }

  @override
  void onError(Object error, StackTrace? stackTrace) {
    snapshot = PipelineSnapshot<T>(error: error);
    _emit();
  }

  @override
  void onComplete(Object? finalValue) {
    if (finalValue is T) {
      snapshot = PipelineSnapshot<T>(data: finalValue);
    } else {
      snapshot = snapshot.clearLoading();
    }
    _emit();
  }

  @override
  void onCancel() {
    snapshot = snapshot.cancelledState();
    _emit();
  }
}

/// Flutter setState adapter wrapping a strongly typed snapshot.
class SetStateSnapshotAdapter<T> extends TypedStateAdapter<T> {
  final void Function(void Function()) _setState;
  SetStateSnapshotAdapter(this._setState, {super.captureIntermediates});

  @override
  void _emit() {
    _setState(() {});
    super._emit();
  }
}
