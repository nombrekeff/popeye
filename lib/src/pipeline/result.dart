/// Experimental pipeline Result type.
/// Represents either a success value or an error (with optional stack trace)
/// plus cancellation flag.
class PipeResult<T> {
  final T? value;
  final Object? error;
  final StackTrace? stackTrace;
  final bool _cancelled;

  const PipeResult._({this.value, this.error, this.stackTrace, bool cancelled = false})
      : _cancelled = cancelled;

  bool get isSuccess => error == null && !_cancelled;
  bool get isError => error != null;
  bool get isCancelled => _cancelled;

  static PipeResult<T> success<T>(T value) => PipeResult._(value: value);
  static PipeResult<T> failure<T>(Object error, [StackTrace? st]) =>
      PipeResult._(error: error, stackTrace: st);
  static PipeResult<T> cancelled<T>() => PipeResult._(cancelled: true);

  @override
  String toString() => isCancelled
      ? 'PipeResult.cancelled()'
      : isError
          ? 'PipeResult.error($error)'
          : 'PipeResult.success($value)';
}
